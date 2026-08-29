import math

from training.exploration import (
    EXPLORATION_SCHEMA,
    RootExplorationConfig,
    exploration_manifest,
    mix_root_dirichlet,
)


def expect_value_error(callable_, text: str) -> None:
    try:
        callable_()
    except ValueError as error:
        assert text in str(error)
    else:
        raise AssertionError(f"expected ValueError containing {text!r}")


def main() -> None:
    policy = [[3, 0.1], [8, 0.2], [55, 0.7]]
    config = RootExplorationConfig(alpha=0.3, fraction=0.25)

    first = mix_root_dirichlet(policy, seed=20260829, config=config)
    twin = mix_root_dirichlet(policy, seed=20260829, config=config)
    other = mix_root_dirichlet(policy, seed=20260830, config=config)
    assert first == twin
    assert first != other
    assert [entry[0] for entry in first] == [3, 8, 55]
    assert math.isclose(sum(entry[1] for entry in first), 1.0)
    assert all(entry[1] >= 0 for entry in first)
    assert policy == [[3, 0.1], [8, 0.2], [55, 0.7]]

    unchanged = mix_root_dirichlet(
        policy, seed=20260829, config=RootExplorationConfig(fraction=0)
    )
    assert unchanged == policy

    manifest = exploration_manifest(20260829, config)
    assert manifest == {
        "schema": EXPLORATION_SCHEMA,
        "mode": "from-zero",
        "root_only": True,
        "seed": 20260829,
        "alpha": 0.3,
        "fraction": 0.25,
    }

    expect_value_error(
        lambda: mix_root_dirichlet([], seed=1), "at least one legal move"
    )
    expect_value_error(
        lambda: mix_root_dirichlet([[3, 0.4], [3, 0.6]], seed=1), "unique"
    )
    expect_value_error(
        lambda: mix_root_dirichlet([[3, 0.4]], seed=1), "sum to one"
    )
    expect_value_error(
        lambda: mix_root_dirichlet(
            policy, seed=1, config=RootExplorationConfig(alpha=0)
        ),
        "alpha",
    )
    expect_value_error(
        lambda: mix_root_dirichlet(
            policy, seed=1, config=RootExplorationConfig(fraction=1.1)
        ),
        "fraction",
    )

    print("FROM-ZERO-EXPLORATION-PASS")


if __name__ == "__main__":
    main()
