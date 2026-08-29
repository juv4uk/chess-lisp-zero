"""Seeded root exploration for pure from-zero self-play.

This module only mixes probabilities for an already-authoritative sparse legal
policy.  It does not generate moves, interpret positions or run during arena
evaluation.  The standard-library RNG keeps the seam independent of NumPy and
GPU availability.
"""

from __future__ import annotations

import math
import random
from dataclasses import dataclass
from typing import Iterable

from training.from_zero_torch import POLICY_SIZE

EXPLORATION_SCHEMA = "chess-lisp-zero-root-exploration-v1"


@dataclass(frozen=True)
class RootExplorationConfig:
    alpha: float = 0.3
    fraction: float = 0.25

    def validate(self) -> None:
        if not math.isfinite(self.alpha) or self.alpha <= 0:
            raise ValueError("Dirichlet alpha must be positive and finite")
        if not math.isfinite(self.fraction) or not 0 <= self.fraction <= 1:
            raise ValueError("exploration fraction must be within [0, 1]")


def _validated_policy(policy: Iterable[Iterable[float]]) -> list[tuple[int, float]]:
    entries: list[tuple[int, float]] = []
    seen: set[int] = set()
    total = 0.0
    for raw_entry in policy:
        entry = list(raw_entry)
        if len(entry) != 2:
            raise ValueError("policy entry must be [index, probability]")
        index, probability = entry
        if not isinstance(index, int) or isinstance(index, bool):
            raise ValueError("policy index must be an integer")
        if not 0 <= index < POLICY_SIZE:
            raise ValueError("policy index outside canonical vocabulary")
        if index in seen:
            raise ValueError("policy indices must be unique")
        seen.add(index)
        probability = float(probability)
        if not math.isfinite(probability) or probability < 0:
            raise ValueError("policy probability must be non-negative and finite")
        entries.append((index, probability))
        total += probability
    if not entries:
        raise ValueError("root policy must contain at least one legal move")
    if not math.isclose(total, 1.0, rel_tol=0.0, abs_tol=1e-6):
        raise ValueError("root policy must sum to one")
    return entries


def mix_root_dirichlet(
    policy: Iterable[Iterable[float]],
    *,
    seed: int,
    config: RootExplorationConfig = RootExplorationConfig(),
) -> list[list[float]]:
    """Return seeded Dirichlet-mixed probabilities in the original index order."""

    if not isinstance(seed, int) or isinstance(seed, bool):
        raise ValueError("exploration seed must be an integer")
    config.validate()
    entries = _validated_policy(policy)
    if config.fraction == 0:
        return [[index, probability] for index, probability in entries]

    generator = random.Random(seed)
    gamma = [generator.gammavariate(config.alpha, 1.0) for _ in entries]
    gamma_total = sum(gamma)
    if not math.isfinite(gamma_total) or gamma_total <= 0:
        raise RuntimeError("Dirichlet sampler produced invalid total weight")

    keep = 1.0 - config.fraction
    mixed = [
        [index, keep * probability + config.fraction * noise / gamma_total]
        for (index, probability), noise in zip(entries, gamma, strict=True)
    ]
    # Remove accumulated floating-point drift without changing index order.
    mixed[-1][1] += 1.0 - sum(entry[1] for entry in mixed)
    return mixed


def exploration_manifest(seed: int, config: RootExplorationConfig) -> dict:
    """Serializable provenance fragment for a from-zero run manifest."""

    config.validate()
    if not isinstance(seed, int) or isinstance(seed, bool):
        raise ValueError("exploration seed must be an integer")
    return {
        "schema": EXPLORATION_SCHEMA,
        "mode": "from-zero",
        "root_only": True,
        "seed": seed,
        "alpha": config.alpha,
        "fraction": config.fraction,
    }
