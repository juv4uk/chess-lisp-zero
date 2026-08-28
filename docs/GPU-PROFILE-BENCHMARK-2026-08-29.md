# GTX 1050 Ti training-profile probe — 2026-08-29

## Environment

- GPU: NVIDIA GeForce GTX 1050 Ti, 4096 MiB, compute capability 6.1
- driver: 582.66
- installed toolkit: CUDA 12.1 (`nvcc 12.1.66`)
- PyTorch: `2.8.0+cu126`; real CUDA matmul and training step executed
- input/output: `18×8×8` planes, `1968` policy logits and scalar value
- batch: 128
- precision: FP32

The PyTorch wheel carries its own CUDA 12.6 runtime. It executes correctly on
the installed driver while the local CUDA 12.1 toolkit remains available for
native extension builds. Forcing the older `cu121` wheel index would require a
PyTorch downgrade and is not justified by the measured result.

## Method

Each profile ran one unmeasured warm-up step followed by two measured complete
forward/backward/Adam steps. CPU threads were capped at three. This is a local
throughput probe, not a play-strength benchmark.

| Channels × blocks | Parameters | Peak allocated VRAM | Mean step | Positions/s |
|---:|---:|---:|---:|---:|
| 64×5 | 638,711 | 75.2 MiB | 0.0519 s | 2,463.9 |
| 96×6 | 1,273,879 | 164.4 MiB | 0.0660 s | 1,938.7 |
| 128×8 | 2,647,095 | 210.9 MiB | 0.0775 s | 1,651.0 |

## Decision

`owner-gpu` is `128×8`, batch 128. It uses materially more model capacity than
the earlier conservative 64×5 proposal while retaining high bounded training
throughput and leaving ample VRAM for larger real batches and search adapters.
`tiny` remains `32×3` for correctness/CI. `stretch` is `192×10` and requires a
separate measurement before use.
