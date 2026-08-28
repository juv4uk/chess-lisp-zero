import tempfile
from pathlib import Path

import torch

from training.from_zero_torch import (
    INPUT_SIZE,
    ModelConfig,
    PolicyValueNetwork,
    batch_from_records,
    load_checkpoint,
    save_checkpoint,
    seed_everything,
    train_step,
)


def records() -> list[dict]:
    first = [0.0] * INPUT_SIZE
    second = [0.0] * INPUT_SIZE
    first[0] = 1.0
    second[64] = 1.0
    return [
        {"mode": "from-zero", "teacher_data": False, "planes": first,
         "policy": [[7, 1.0]], "z": 1},
        {"mode": "from-zero", "teacher_data": False, "planes": second,
         "policy": [[11, 1.0]], "z": -1},
    ]


def main() -> None:
    seed = 20260829
    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    seed_everything(seed)
    config = ModelConfig(channels=32, residual_blocks=3)
    model = PolicyValueNetwork(config).to(device)
    optimizer = torch.optim.Adam(model.parameters(), lr=0.01)
    batch = batch_from_records(records(), device)

    first_loss = train_step(model, optimizer, batch)
    second_loss = train_step(model, optimizer, batch)
    assert second_loss < first_loss
    model.eval()
    with torch.no_grad():
        expected = model(batch.planes)

    with tempfile.TemporaryDirectory() as temporary:
        directory = Path(temporary)
        save_checkpoint(directory, model, optimizer, seed=seed, iteration=2)
        loaded, loaded_optimizer, manifest = load_checkpoint(directory, device)
        loaded.eval()
        with torch.no_grad():
            actual = loaded(batch.planes)
        assert torch.equal(expected[0], actual[0])
        assert torch.equal(expected[1], actual[1])
        assert manifest["iteration"] == 2
        assert loaded_optimizer.state_dict()["state"]
        with (directory / "state.pt").open("ab") as stream:
            stream.write(b"tampered")
        try:
            load_checkpoint(directory, device)
        except ValueError as error:
            assert "checksum mismatch" in str(error)
        else:
            raise AssertionError("tampered checkpoint was accepted")

    contaminated = records()
    contaminated[0]["teacher_data"] = True
    try:
        batch_from_records(contaminated, device)
    except ValueError as error:
        assert "pure from-zero" in str(error)
    else:
        raise AssertionError("teacher-contaminated record was accepted")
    parameters = sum(parameter.numel() for parameter in model.parameters())
    peak_vram = torch.cuda.max_memory_allocated() if device.type == "cuda" else 0
    print(
        f"FROM-ZERO-TORCH-PASS device={device} torch={torch.__version__} "
        f"parameters={parameters} peak_vram_bytes={peak_vram}"
    )


if __name__ == "__main__":
    main()
