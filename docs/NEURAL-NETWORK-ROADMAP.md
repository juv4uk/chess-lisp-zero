# Neural Network Roadmap

**Status:** IMPLEMENTING
**Date:** 2026-08-28
**Authority:** chess-lisp-zero owns chess feature meaning and fixtures;
my-lisp owns language semantics; CML owns compute admission and backend
selection.

## Goal

Build a visible, replaceable policy/value system that demonstrates the whole
ecosystem without reimplementing mature tools merely for ideological purity:

```text
WSM chess authority -> policy/value contract -> PUCT search
                    -> CML execution graph -> CPU/CUDA/bounded FPGA kernels
                    -> Tauri explanation and evidence view
```

The chess library remains the authority for legal moves. A network proposes
scores; it cannot legalize a move.

## Adopt-or-build rule

Use a mature external implementation when it is materially better and there
is no product reason to recreate it. PyTorch/CUDA may train and execute the
first teacher model; a strong existing engine may generate licensed teacher
evaluations. Our work remains the stable semantic boundary, WSM search,
cross-substrate evidence, and explainable orchestration. External tools are
replaceable adapters, never implicit language or chess authorities.

## Ratified first boundary

### Input: 18 x 8 x 8, CHW

All squares are normalized to the side-to-move viewpoint. For Black, ranks
are vertically mirrored; files are preserved.

| Plane | Meaning |
|---:|---|
| 0..5 | own pawn, knight, bishop, rook, queen, king |
| 6..11 | opponent pawn, knight, bishop, rook, queen, king |
| 12..13 | own king-side and queen-side castling rights |
| 14..15 | opponent king-side and queen-side castling rights |
| 16 | one-hot en-passant target |
| 17 | absolute-color witness: all ones for White to move, zero otherwise |

Castling and side planes are constant across all 64 cells. Piece and
en-passant planes are binary. This first contract contains no position
history; adding history requires a versioned contract.

### Policy: deterministic 1968 UCI labels

The policy vocabulary is implementation-independent:

1. Iterate `from = 0..63`, then `to = 0..63`; include every distinct
   queen-line or knight-geometry pair. This yields 1792 four-character UCI
   labels.
2. Append every promotion geometry from ranks 2/7 to ranks 1/8, ordered by
   `from`, then `to`, then promotion `q, r, b, n`. This yields 176 five-character
   labels.
3. Total: 1968 unique labels. Index is position in this ordered vocabulary.

Black-view policy normalization mirrors both squares vertically and preserves
the promotion suffix. Flip is an involution and must round-trip.

### Output

- `policy[1968]`: logits, masked by authoritative WSM legal moves before
  normalization.
- `value`: scalar in `[-1, 1]`, from the side-to-move perspective.

## Execution stages

1. **Contract and fixtures** — executable planes, labels, flip round-trips.
2. **CPU reference** — deterministic inference and a handcrafted evaluator.
3. **PUCT/MCTS in WSM** — injectable evaluator, fixed-tree evidence first.
4. **Teacher adapter** — optional PyTorch/engine process with provenance.
5. **CUDA differential** — only measured bulk kernels admitted by CML.
6. **FPGA selection** — one bounded kernel after profiling; simulation,
   synthesis and hardware evidence remain distinct.
7. **Tauri evidence view** — policy proposals, legality mask, search visits,
   value changes and substrate comparisons.

## Owner hardware profile and model budget

Measured on 2026-08-28 from the actual WSL machine:

| Resource | Observed |
|---|---|
| CPU | Intel Core i5-6400, 4 cores / 4 threads, AVX2 |
| RAM visible to WSL | 7.7 GiB + 2 GiB swap |
| GPU | NVIDIA GeForce GTX 1050 Ti |
| VRAM | 4096 MiB |
| CUDA capability | 6.1 (Pascal, no Tensor Cores) |
| Driver / toolkit | 582.66 / CUDA 12.1 |

This changes the first network from an aspirational large AlphaZero clone to
a measured compact family:

| Profile | Channels | Residual blocks | Purpose |
|---|---:|---:|---|
| `tiny` | 32 | 3 | correctness, pipeline and overfit-one-batch test |
| `owner-gpu` | 64 | 5 | default training/search candidate for GTX 1050 Ti |
| `stretch` | 96 | 6 | only if measured VRAM/time leave useful headroom |

Operational constraints:

- begin with batch 32; probe 64 and 128 rather than assuming they fit;
- stream or memory-map training examples instead of retaining a large corpus
  in 8 GiB RAM;
- use one data-loader worker initially and cap CPU parallelism at 3 workers so
  WSL remains responsive;
- FP32 is the correctness baseline. FP16 may reduce VRAM, but Pascal has no
  Tensor Cores, so it is not claimed faster without a benchmark;
- do not train a 256-channel/19-block network on this machine;
- export a compact inference format and measure INT8 only after FP32 parity;
- CUDA training/inference is appropriate; large self-play generation should
  be resumable and bounded, never an uninterruptible all-core job.

The first success criterion is not Elo. It is: `tiny` deliberately overfits a
small licensed fixture set, reloads identical weights, and produces stable
policy/value outputs through the adapter boundary.

## Evidence states

`DESIGNED -> EXECUTED -> DIFFERENTIAL-PASS -> BENCHMARKED -> PLAY-STRENGTH-TESTED`

No stage implies the next. In particular, a fast kernel does not prove a
strong chess player, and a teacher agreement does not make the teacher a
semantic authority.
