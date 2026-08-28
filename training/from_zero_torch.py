"""PyTorch policy/value backend for pure from-zero chess training.

Chess meaning remains owned by WSM.  This module consumes the ratified
18x8x8 planes and sparse 1968-policy targets; it never generates legal moves.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable

import torch
from torch import nn
from torch.nn import functional as functional

INPUT_PLANES = 18
BOARD_SIZE = 8
INPUT_SIZE = INPUT_PLANES * BOARD_SIZE * BOARD_SIZE
POLICY_SIZE = 1968
POLICY_CONTRACT = "chess-policy-v0.1-1968"
CHECKPOINT_SCHEMA = "chess-lisp-zero-checkpoint-v1"


@dataclass(frozen=True)
class ModelConfig:
    channels: int = 128
    residual_blocks: int = 8


MODEL_PROFILES = {
    "tiny": ModelConfig(32, 3),
    "owner-gpu": ModelConfig(128, 8),
    "stretch": ModelConfig(192, 10),
}
DEFAULT_PROFILE = "owner-gpu"
DEFAULT_BATCH_SIZE = 128


@dataclass
class Batch:
    planes: torch.Tensor
    policy: torch.Tensor
    outcome: torch.Tensor


class ResidualBlock(nn.Module):
    def __init__(self, channels: int) -> None:
        super().__init__()
        self.conv1 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn1 = nn.BatchNorm2d(channels)
        self.conv2 = nn.Conv2d(channels, channels, 3, padding=1, bias=False)
        self.bn2 = nn.BatchNorm2d(channels)

    def forward(self, inputs: torch.Tensor) -> torch.Tensor:
        hidden = functional.relu(self.bn1(self.conv1(inputs)))
        return functional.relu(inputs + self.bn2(self.conv2(hidden)))


class PolicyValueNetwork(nn.Module):
    def __init__(self, config: ModelConfig) -> None:
        super().__init__()
        self.config = config
        self.stem = nn.Sequential(
            nn.Conv2d(INPUT_PLANES, config.channels, 3, padding=1, bias=False),
            nn.BatchNorm2d(config.channels),
            nn.ReLU(),
        )
        self.tower = nn.Sequential(
            *(ResidualBlock(config.channels) for _ in range(config.residual_blocks))
        )
        self.policy_head = nn.Sequential(
            nn.Conv2d(config.channels, 2, 1, bias=False),
            nn.BatchNorm2d(2),
            nn.ReLU(),
            nn.Flatten(),
            nn.Linear(2 * BOARD_SIZE * BOARD_SIZE, POLICY_SIZE),
        )
        self.value_conv = nn.Sequential(
            nn.Conv2d(config.channels, 1, 1, bias=False),
            nn.BatchNorm2d(1),
            nn.ReLU(),
            nn.Flatten(),
        )
        self.value_head = nn.Sequential(
            nn.Linear(BOARD_SIZE * BOARD_SIZE, config.channels),
            nn.ReLU(),
            nn.Linear(config.channels, 1),
            nn.Tanh(),
        )

    def forward(self, planes: torch.Tensor) -> tuple[torch.Tensor, torch.Tensor]:
        hidden = self.tower(self.stem(planes))
        return self.policy_head(hidden), self.value_head(self.value_conv(hidden)).squeeze(1)


def seed_everything(seed: int) -> None:
    torch.set_num_threads(3)
    torch.manual_seed(seed)
    torch.backends.cudnn.benchmark = False
    torch.backends.cudnn.deterministic = True
    if torch.cuda.is_available():
        torch.cuda.manual_seed_all(seed)


def batch_from_records(records: Iterable[dict], device: torch.device) -> Batch:
    records = list(records)
    if not records:
        raise ValueError("from-zero batch must contain at least one record")
    planes = torch.tensor([record["planes"] for record in records], dtype=torch.float32)
    if tuple(planes.shape) != (len(records), INPUT_SIZE):
        raise ValueError(f"planes must have shape (N, {INPUT_SIZE})")
    planes = planes.reshape(-1, INPUT_PLANES, BOARD_SIZE, BOARD_SIZE)

    policy = torch.zeros((len(records), POLICY_SIZE), dtype=torch.float32)
    outcome = torch.empty(len(records), dtype=torch.float32)
    for row, record in enumerate(records):
        if record.get("mode") != "from-zero" or record.get("teacher_data") is not False:
            raise ValueError("record provenance is not pure from-zero")
        for index, probability in record["policy"]:
            if not 0 <= index < POLICY_SIZE:
                raise ValueError("policy index outside canonical vocabulary")
            policy[row, index] += probability
        if not torch.isclose(policy[row].sum(), torch.tensor(1.0)):
            raise ValueError("policy target must sum to one")
        outcome[row] = record["z"]
        if outcome[row].item() not in (-1.0, 0.0, 1.0):
            raise ValueError("outcome must be -1, 0 or 1")
    return Batch(planes.to(device), policy.to(device), outcome.to(device))


def train_step(
    model: PolicyValueNetwork, optimizer: torch.optim.Optimizer, batch: Batch
) -> float:
    model.train()
    optimizer.zero_grad(set_to_none=True)
    logits, value = model(batch.planes)
    policy_loss = -(batch.policy * functional.log_softmax(logits, dim=1)).sum(1).mean()
    value_loss = functional.mse_loss(value, batch.outcome)
    loss = policy_loss + value_loss
    loss.backward()
    optimizer.step()
    return float(loss.detach().cpu())


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def save_checkpoint(
    directory: Path,
    model: PolicyValueNetwork,
    optimizer: torch.optim.Optimizer,
    *,
    seed: int,
    iteration: int,
) -> Path:
    directory.mkdir(parents=True, exist_ok=True)
    state_path = directory / "state.pt"
    torch.save(
        {
            "model": model.state_dict(),
            "optimizer": optimizer.state_dict(),
            "cpu_rng_state": torch.get_rng_state(),
            "cuda_rng_state": torch.cuda.get_rng_state_all()
            if torch.cuda.is_available()
            else [],
        },
        state_path,
    )
    manifest = {
        "schema": CHECKPOINT_SCHEMA,
        "mode": "from-zero",
        "teacher_data": False,
        "seed": seed,
        "iteration": iteration,
        "policy_contract": POLICY_CONTRACT,
        "model": {
            "backend": "pytorch-residual",
            "input_planes": INPUT_PLANES,
            "policy_size": POLICY_SIZE,
            "channels": model.config.channels,
            "residual_blocks": model.config.residual_blocks,
        },
        "optimizer": {"name": optimizer.__class__.__name__},
        "runtime": {
            "torch": torch.__version__,
            "cuda_runtime": torch.version.cuda,
            "device": next(model.parameters()).device.type,
        },
        "state": {"file": state_path.name, "sha256": _sha256(state_path)},
    }
    manifest_path = directory / "manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    return manifest_path


def load_checkpoint(
    directory: Path, device: torch.device
) -> tuple[PolicyValueNetwork, torch.optim.Optimizer, dict]:
    manifest = json.loads((directory / "manifest.json").read_text())
    if manifest.get("schema") != CHECKPOINT_SCHEMA:
        raise ValueError("unsupported checkpoint schema")
    if manifest.get("mode") != "from-zero" or manifest.get("teacher_data") is not False:
        raise ValueError("checkpoint is not pure from-zero")
    if manifest.get("policy_contract") != POLICY_CONTRACT:
        raise ValueError("policy contract mismatch")
    model_info = manifest.get("model", {})
    if model_info.get("backend") != "pytorch-residual":
        raise ValueError("model backend mismatch")
    if model_info.get("input_planes") != INPUT_PLANES or model_info.get("policy_size") != POLICY_SIZE:
        raise ValueError("model contract mismatch")

    state_path = directory / manifest["state"]["file"]
    if _sha256(state_path) != manifest["state"]["sha256"]:
        raise ValueError("checkpoint state checksum mismatch")
    state = torch.load(state_path, map_location=device, weights_only=True)
    config = ModelConfig(model_info["channels"], model_info["residual_blocks"])
    model = PolicyValueNetwork(config).to(device)
    optimizer = torch.optim.Adam(model.parameters())
    model.load_state_dict(state["model"])
    optimizer.load_state_dict(state["optimizer"])
    torch.set_rng_state(state["cpu_rng_state"].cpu())
    if torch.cuda.is_available() and state["cuda_rng_state"]:
        torch.cuda.set_rng_state_all(
            [rng_state.cpu() for rng_state in state["cuda_rng_state"]]
        )
    return model, optimizer, manifest
