"""Deterministic candidate-vs-current checkpoint promotion gate.

The arena consumes recorded game outcomes from the candidate's perspective.
It does not play chess, invoke a network, or alter WSM chess authority.
"""

from __future__ import annotations

from dataclasses import dataclass
from fractions import Fraction
from typing import Iterable


ARENA_SCHEMA = "chess-lisp-zero-arena-v1"


@dataclass(frozen=True)
class ArenaConfig:
    games: int
    acceptance_score: str = "0.55"

    def __post_init__(self) -> None:
        if isinstance(self.games, bool) or not isinstance(self.games, int):
            raise ValueError("arena games must be an integer")
        if self.games <= 0:
            raise ValueError("arena games must be positive")
        try:
            threshold = Fraction(self.acceptance_score)
        except (ValueError, ZeroDivisionError) as error:
            raise ValueError("arena acceptance score must be rational") from error
        if not Fraction(1, 2) < threshold <= 1:
            raise ValueError("arena acceptance score must be within (0.5, 1]")

    @property
    def threshold(self) -> Fraction:
        return Fraction(self.acceptance_score)


def decide_arena(
    outcomes: Iterable[int],
    config: ArenaConfig,
    *,
    seed: int,
    candidate_sha256: str,
    current_sha256: str,
) -> dict:
    """Return a reproducible promotion decision for completed arena games."""
    if isinstance(seed, bool) or not isinstance(seed, int):
        raise ValueError("arena seed must be an integer")
    for label, digest in (
        ("candidate", candidate_sha256),
        ("current", current_sha256),
    ):
        if not _is_sha256(digest):
            raise ValueError(f"{label} checkpoint sha256 is invalid")

    results = tuple(outcomes)
    if len(results) != config.games:
        raise ValueError("arena result count does not match configured games")
    if any(isinstance(value, bool) or value not in (-1, 0, 1) for value in results):
        raise ValueError("arena outcomes must be -1, 0 or 1")

    wins = results.count(1)
    losses = results.count(-1)
    draws = results.count(0)
    score_units = 2 * wins + draws
    score = Fraction(score_units, 2 * config.games)
    threshold = config.threshold
    accepted = score >= threshold

    return {
        "schema": ARENA_SCHEMA,
        "mode": "from-zero",
        "teacher_data": False,
        "seed": seed,
        "noise": False,
        "deterministic_move_selection": True,
        "candidate_sha256": candidate_sha256,
        "current_sha256": current_sha256,
        "games": config.games,
        "candidate_wins": wins,
        "current_wins": losses,
        "draws": draws,
        "score": f"{score.numerator}/{score.denominator}",
        "acceptance_score": f"{threshold.numerator}/{threshold.denominator}",
        "decision": "accept-candidate" if accepted else "retain-current",
    }


def _is_sha256(value: object) -> bool:
    return (
        isinstance(value, str)
        and len(value) == 64
        and all(character in "0123456789abcdef" for character in value)
    )
