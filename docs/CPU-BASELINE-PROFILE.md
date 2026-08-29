# CPU-BASELINE-PROFILE — vector-based my-lisp baseline

Date: 2026-08-29. Task: CHESS-LISP-ZERO-CPU-BASELINE-PROFILE.
Measured with `net/net=15`, `my-lisp` release build
(my-lisp HEAD bf68044 at measurement time), mono-ms timers
(`tests/bench-baseline.my`), running on:

| | |
|---|---|
| CPU | Intel Core i5-6400 @ 2.70 GHz (4 cores, no turbo throttling observed) |
| RAM | 8 GB |
| Load during run | ~4.0 (mostly normal swarm activity) |
| OS / host | WSL2 Ubuntu, user-count 5 |

Method: correctness asserted separately (all fixtures `ok t`); timings are
report lines, not assertions. `mean-ms` = mean mono-ms over `reps` calls
(mono-ms is process-local milliseconds since first call).

## CONFIRMED — perft nodes per millisecond

| fixture | depth | nodes | mean-ms/call | per-node ms |
|---|---|---|---|---|
| initial | 1 | 20 | 1054/3 ≈ 351 | 17.6 |
| initial | 2 | 400 | 7,087 | 17.7 |
| kiwipete | 1 | 48 | 2425/3 ≈ 808 | 16.8 |
| kiwipete | 2 | 2,039 | 39,030 | 19.1 |
| position-6 | 2 | 2,079 | 40,959 | 19.7 |

Per-node cost is stable across fixtures/depths: **≈ 17-20 ms per perft
node** in the current interpreter on this host. This explains the earlier
"hangs": perft(3)=8902 nodes ≈ 8902 × 18 ms ≈ 160 s single-process
(observed as p10 timeouts), and kiwipete d3 (97,862 nodes) ≈ 30 min.

## CONFIRMED — component latencies

| component | fixture | mean-ms/call | notes |
|---|---|---|---|
| `chess-legal-moves` | kiwipete root (48 legal) | ≈ 665 | 48 pseudo-candidates × per-candidate filter |
| `chess-apply-move` | initial (first legal root move) | ≈ 7.2 | 64-cell `chess-copy-board` + rights/EP bookkeeping |
| `chess-best-move` d1 | tests/search.wsm board | ≈ 1,313 | move scoring + sort |

## Dominant operation (OBSERVED, not a proposal)

Per perft node the work is roughly:

```
perft node ≈ chess-apply-move (board copy) + chess-legal-moves (filter)
apply-move (64-cell copy + meta)   ≈ 7 ms
legal-filter share of a node        ≈ 10-13 ms   ← dominant
```
With ~20-30 candidates per mid-tree node and in-check king-safety scans
(sliding-ray probes) per candidate, legal-move filtering accounts for the
majority of perft node time. This matches the kiwipete-root datum
(665 ms / 48 candidates ≈ 13.9 ms per filtered move).

Per the task wording, this report only identifies the dominant operation;
**no bitboard or new-primitive change is proposed here.** Any such proposal
should first (a) separate pseudo-generation vs king-safety vs copy with
finer probes, and (b) budget the expected win against the copy+filter split
above. Follow-up: CHESS-LISP-ZERO-CPU-BASELINE-PROFILE is intentionally
evidence-only.

## Honest limits

- mono-ms precision: 1 ms; per-node values are exact rationals from the
  bench; interpretation rounded.
- Machine state (load, turbo, WSL sharing) affects absolute numbers; the
  cross-fixture stability (17-20 ms/node) is the more robust finding.
- Deeper fixtures (kiwipete d3+) are bounded here by the gate mandate in
  CHESSJS-DIFFERENTIAL-GATE.md; single-process d3 for kiwipete would take
  ~30 min and was not run for this report.
- Bench measured release build at my-lisp HEAD bf68044; numbers belong to
  that snapshot, not to any future primitive set.
- Commit SHAs: gate/driver `tests/bench-baseline.my` + this report —
  see `git log` for SHAs.