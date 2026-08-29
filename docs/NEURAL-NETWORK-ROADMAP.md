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

## Training modes

### `from-zero` — primary independent-learning mode

`from-zero` starts with randomly initialized weights and consumes no engine
evaluations, opening books, pretrained weights or teacher games. The only
prior knowledge is the ratified chess environment itself: legal moves,
terminal outcomes and the policy-plane contract.

```text
random checkpoint + reproducible seed
  -> PUCT self-play (WSM legal moves)
  -> examples (planes, visit-policy, final outcome)
  -> bounded replay buffer
  -> policy loss + value loss
  -> candidate checkpoint
  -> candidate-vs-current arena
  -> accept or retain current checkpoint
  -> repeat, with resumable state
```

For each visited position:

- input `x` is the canonical 18×8×8 encoding;
- target `pi` is normalized root visit counts over the 1968 policy labels;
- target `z` is the final game result from that position's side-to-move
  perspective;
- network loss begins as `cross_entropy(policy, pi) + mse(value, z)` plus
  explicitly recorded regularization.

Exploration is a training concern, not a change to chess semantics. Root
Dirichlet noise and temperature are enabled only in `from-zero` self-play,
with an explicit seed for reproducibility; evaluation/arena games use no
noise and deterministic move selection.

The initial owner-hardware profile uses `tiny` (32 channels, 3 blocks), batch
32, one self-play worker and a bounded cyclic replay buffer. Checkpoints must
include model config, optimizer state, RNG seed, training iteration and policy
contract version so training can resume after interruption.

### `teacher` — optional acceleration mode

Teacher positions/evaluations may accelerate experiments but live in a
separate provenance-labelled dataset and adapter. They are never silently
mixed into a `from-zero` run. A run manifest must state `from-zero`, `teacher`
or a separately ratified `hybrid` mode.

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
4. **From-zero self-play** — replay/checkpoint loop with deterministic smoke
   mode before any long training run.
5. **Teacher adapter** — optional PyTorch/engine process with provenance.
6. **CUDA differential** — only measured bulk kernels admitted by CML.
7. **FPGA selection** — one bounded kernel after profiling; simulation,
   synthesis and hardware evidence remain distinct.
8. **Tauri evidence view** — policy proposals, legality mask, search visits,
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
| Verified PyTorch runtime | 2.8.0+cu126, real `sm_61` GPU matmul PASS |

This changes the first network from an aspirational large AlphaZero clone to
a measured compact family:

| Profile | Channels | Residual blocks | Purpose |
|---|---:|---:|---|
| `tiny` | 32 | 3 | correctness, pipeline and overfit-one-batch test |
| `owner-gpu` | 128 | 8 | measured default for GTX 1050 Ti |
| `stretch` | 192 | 10 | only after a separate measured probe |

Operational constraints:

- begin real training with measured batch 128; batch 256 also passed a bounded
  allocation/gradient-step probe and remains an opt-in throughput experiment;
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

The profile decision and raw bounded measurements are recorded in
`docs/GPU-PROFILE-BENCHMARK-2026-08-29.md`.

## Evidence states

`DESIGNED -> EXECUTED -> DIFFERENTIAL-PASS -> BENCHMARKED -> PLAY-STRENGTH-TESTED`

No stage implies the next. In particular, a fast kernel does not prove a
strong chess player, and a teacher agreement does not make the teacher a
semantic authority.

## Current implementation evidence

| Slice | State | Evidence |
|---|---|---|
| 18×8×8 planes + 1968 policy vocabulary | EXECUTED | `tests/neural-contract.wsm` |
| Deterministic single-threaded PUCT | EXECUTED | `lib/puct.wsm`, `tests/puct.wsm` |
| PUCT policy → `(planes, sparse pi, side, z)` records | EXECUTED | `lib/self-play.wsm`, `tests/self-play.wsm` |
| Bounded WSM self-play game driver | EXECUTED | `self-play-game`, bounded one-ply fixture |
| Seeded PyTorch train step + strict checkpoint/reload | EXECUTED | `training/from_zero_torch.py`, `tests/test_from_zero_torch.py` |
| WSM semantic replay pin | EXECUTED | `tests/replay-verify.wsm`, `tests/fixtures/self-play-replay-fix.my` |
| Bounded deterministic runtime replay + resume | EXECUTED | `training/replay.py`, `tests/test_replay.py` |
| Fixed-tree selection and alternating backup | EXECUTED | deterministic fixtures |
| Authoritative chess expansion | EXECUTED | 20-child initial-position fixture |
| Injectable evaluator | EXECUTED | material evaluator selects forced queen capture |
| Injectable policy priors | EXECUTED | normalized provider weights guide PUCT; uniform API preserved |
| Policy priors → self-play `pi` | EXECUTED | injected provider reaches bounded WSM game record |
| Seeded root Dirichlet exploration | EXECUTED | deterministic root-only mixer + provenance manifest fixture |
| Neural training and play strength | DESIGNED | no trained checkpoint yet |
