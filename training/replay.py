"""Bounded, resumable replay storage for pure from-zero records."""

from __future__ import annotations

import base64
import hashlib
import json
from pathlib import Path

import torch

from training.from_zero_torch import INPUT_SIZE, POLICY_SIZE

REPLAY_SCHEMA = "chess-lisp-zero-replay-v1"


def validate_record(record: dict) -> None:
    if record.get("mode") != "from-zero" or record.get("teacher_data") is not False:
        raise ValueError("record provenance is not pure from-zero")
    if len(record.get("planes", ())) != INPUT_SIZE:
        raise ValueError(f"record must contain {INPUT_SIZE} input values")
    policy_total = 0.0
    for entry in record.get("policy", ()):
        if len(entry) != 2:
            raise ValueError("policy entry must be [index, probability]")
        index, probability = entry
        if not isinstance(index, int) or not 0 <= index < POLICY_SIZE:
            raise ValueError("policy index outside canonical vocabulary")
        if probability < 0:
            raise ValueError("policy probability cannot be negative")
        policy_total += probability
    if abs(policy_total - 1.0) > 1e-6:
        raise ValueError("policy target must sum to one")
    if record.get("z") not in (-1, 0, 1):
        raise ValueError("outcome must be -1, 0 or 1")


def _encode_rng_state(generator: torch.Generator) -> str:
    return base64.b64encode(generator.get_state().numpy().tobytes()).decode("ascii")


def _decode_rng_state(encoded: str) -> torch.Tensor:
    raw = base64.b64decode(encoded, validate=True)
    return torch.frombuffer(bytearray(raw), dtype=torch.uint8).clone()


class ReplayBuffer:
    def __init__(self, capacity: int, seed: int) -> None:
        if capacity <= 0:
            raise ValueError("replay capacity must be positive")
        self.capacity = capacity
        self.seed = seed
        self.records: list[dict] = []
        self.next_index = 0
        self.generator = torch.Generator(device="cpu")
        self.generator.manual_seed(seed)

    def append(self, record: dict) -> None:
        validate_record(record)
        owned = json.loads(json.dumps(record))
        if len(self.records) < self.capacity:
            self.records.append(owned)
        else:
            self.records[self.next_index] = owned
        self.next_index = (self.next_index + 1) % self.capacity

    def extend(self, records: list[dict]) -> None:
        for record in records:
            self.append(record)

    def sample(self, count: int) -> list[dict]:
        if count <= 0:
            raise ValueError("sample count must be positive")
        if not self.records:
            raise ValueError("cannot sample an empty replay buffer")
        indices = torch.randint(
            len(self.records), (count,), generator=self.generator, device="cpu"
        ).tolist()
        return [json.loads(json.dumps(self.records[index])) for index in indices]

    def save(self, directory: Path) -> Path:
        directory.mkdir(parents=True, exist_ok=True)
        replay_path = directory / "replay.json"
        payload = {
            "schema": REPLAY_SCHEMA,
            "capacity": self.capacity,
            "seed": self.seed,
            "next_index": self.next_index,
            "rng_state": _encode_rng_state(self.generator),
            "records": self.records,
        }
        replay_path.write_text(json.dumps(payload, separators=(",", ":")) + "\n")
        digest = hashlib.sha256(replay_path.read_bytes()).hexdigest()
        manifest_path = directory / "replay-manifest.json"
        manifest_path.write_text(
            json.dumps(
                {"schema": REPLAY_SCHEMA, "file": replay_path.name, "sha256": digest},
                indent=2,
                sort_keys=True,
            )
            + "\n"
        )
        return manifest_path

    @classmethod
    def load(cls, directory: Path) -> "ReplayBuffer":
        manifest = json.loads((directory / "replay-manifest.json").read_text())
        if manifest.get("schema") != REPLAY_SCHEMA:
            raise ValueError("unsupported replay manifest schema")
        replay_path = directory / manifest["file"]
        actual = hashlib.sha256(replay_path.read_bytes()).hexdigest()
        if actual != manifest.get("sha256"):
            raise ValueError("replay checksum mismatch")
        payload = json.loads(replay_path.read_text())
        if payload.get("schema") != REPLAY_SCHEMA:
            raise ValueError("unsupported replay payload schema")
        replay = cls(payload["capacity"], payload["seed"])
        if len(payload["records"]) > replay.capacity:
            raise ValueError("replay payload exceeds capacity")
        replay.extend(payload["records"])
        if not 0 <= payload["next_index"] < replay.capacity:
            raise ValueError("invalid replay cursor")
        replay.next_index = payload["next_index"]
        replay.generator.set_state(_decode_rng_state(payload["rng_state"]))
        return replay
