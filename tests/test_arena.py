from training.arena import ArenaConfig, decide_arena


CANDIDATE = "a" * 64
CURRENT = "b" * 64


def decide(outcomes, threshold="0.55"):
    return decide_arena(
        outcomes,
        ArenaConfig(len(outcomes), threshold),
        seed=20260829,
        candidate_sha256=CANDIDATE,
        current_sha256=CURRENT,
    )


def main() -> None:
    accepted = decide([1] * 6 + [-1] * 4, "0.60")
    assert accepted["decision"] == "accept-candidate"
    assert accepted["score"] == "3/5"
    assert accepted["noise"] is False
    assert accepted["deterministic_move_selection"] is True
    assert accepted["candidate_sha256"] == CANDIDATE

    rejected = decide([1] * 5 + [-1] * 5, "0.55")
    assert rejected["decision"] == "retain-current"
    assert rejected["score"] == "1/2"

    draws = decide([1, 1, 0, 0], "0.75")
    assert draws["decision"] == "accept-candidate"
    assert draws["score"] == "3/4"
    assert draws["candidate_wins"] == 2
    assert draws["draws"] == 2

    assert decide([1, 0, -1], "0.55") == decide([1, 0, -1], "0.55")

    invalid = (
        lambda: ArenaConfig(0),
        lambda: ArenaConfig(2, "0.5"),
        lambda: decide_arena(
            [1], ArenaConfig(2), seed=1,
            candidate_sha256=CANDIDATE, current_sha256=CURRENT,
        ),
        lambda: decide_arena(
            [2], ArenaConfig(1), seed=1,
            candidate_sha256=CANDIDATE, current_sha256=CURRENT,
        ),
        lambda: decide_arena(
            [1], ArenaConfig(1), seed=1,
            candidate_sha256="not-a-hash", current_sha256=CURRENT,
        ),
    )
    for operation in invalid:
        try:
            operation()
        except ValueError:
            pass
        else:
            raise AssertionError("invalid arena input was accepted")

    print("FROM-ZERO-ARENA-PASS")


if __name__ == "__main__":
    main()
