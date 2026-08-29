import tempfile
from pathlib import Path

from training.replay import ReplayBuffer
from training.from_zero_torch import INPUT_SIZE


def record(identity: int) -> dict:
    planes = [0.0] * INPUT_SIZE
    planes[identity] = 1.0
    return {
        "mode": "from-zero",
        "teacher_data": False,
        "planes": planes,
        "policy": [[identity, 1.0]],
        "z": (-1, 0, 1)[identity % 3],
        "identity": identity,
    }


def main() -> None:
    replay = ReplayBuffer(capacity=3, seed=20260829)
    replay.extend([record(0), record(1), record(2), record(3)])
    assert len(replay.records) == 3
    assert sorted(item["identity"] for item in replay.records) == [1, 2, 3]

    first_sample = [item["identity"] for item in replay.sample(8)]
    twin = ReplayBuffer(capacity=3, seed=20260829)
    twin.extend([record(0), record(1), record(2), record(3)])
    assert first_sample == [item["identity"] for item in twin.sample(8)]

    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        replay.save(directory)
        restored = ReplayBuffer.load(directory)
        assert [item["identity"] for item in replay.sample(8)] == [
            item["identity"] for item in restored.sample(8)
        ]
        with (directory / "replay.json").open("a") as stream:
            stream.write("tampered")
        try:
            ReplayBuffer.load(directory)
        except ValueError as error:
            assert "checksum mismatch" in str(error)
        else:
            raise AssertionError("tampered replay was accepted")

    contaminated = record(4)
    contaminated["teacher_data"] = True
    try:
        replay.append(contaminated)
    except ValueError as error:
        assert "pure from-zero" in str(error)
    else:
        raise AssertionError("teacher-contaminated replay record was accepted")
    print("FROM-ZERO-REPLAY-PASS")


if __name__ == "__main__":
    main()
