# PERFT-VERIFY — perft(3) = 8902 confirmation, 2026-08-29

## Verdict

`chess-perft` (lib/chess.my) is **correct**. Deterministic perft depths 1..3:

- perft(1) = 20  (instant)
- perft(2) = 400 (instant)
- perft(3) = 8902 (confirmed by 20 independent per-root subtree runs)

No chess-logic bug. The earlier appearance of a "hang" at depth 3 is
**interpreter throughput only**: a single-process perft(3) evaluates
8902 nodes and takes on the order of minutes in the my-lisp tree-walking
host, far beyond the 90 s probes used initially. Each per-root subtree
(~400-600 nodes) completes in well under a minute.

## Method

`chess-perft init 3` = sum over the 20 initial root moves of
`chess-perft (apply init root-move) 2`. Each per-root subtree was
evaluated in its own interpreter process (bounded, ~25 s each) and summed.

Run (bash loop, my-lisp release binary):

```rust
(let* ((init (chess-initial-position))
       (roots (chess-legal-moves init))
       (p1 (chess-apply-move init (ld roots k))))
  (print (list 'rootk (chess-perft p1 2))))
```

## Per-root counts (engine, my-lisp release)

| root | move (from to) | perft(P1,2) |
|------|----------------|-------------|
| 0  | (15 31) h-pawn double | 420 |
| 1  | (15 23) h-pawn single | 380 |
| 2  | (14 30) g-pawn double | 421 |
| 3  | (14 22) g-pawn single | 420 |
| 4  | (13 29) f-pawn double | 401 |
| 5  | (13 21) f-pawn single | 380 |
| 6  | (12 28) e-pawn double | 600 |
| 7  | (12 20) e-pawn single | 599 |
| 8  | (11 27) d-pawn double | 560 |
| 9  | (11 19) d-pawn single | 539 |
| 10 | (10 26) c-pawn double | 441 |
| 11 | (10 18) c-pawn single | 420 |
| 12 | (9 25)  b-pawn double | 421 |
| 13 | (9 17)  b-pawn single | 420 |
| 14 | (8 24)  a-pawn double | 420 |
| 15 | (8 16)  a-pawn single | 380 |
| 16 | knight   | 440 |
| 17 | knight   | 400 |
| 18 | knight   | 400 |
| 19 | knight   | 440 |

**Sum = 8902** — matches the canonical perft(3) = 8902.

## Canonical cross-check

The engine's per-root multiset equals the chess-programming-wiki
standard per-root perft(3) breakdown (move order a-h, then knights):

`380,420,421,420,420,441,539,560,599,600,380,401,420,421,380,420,400,440,440,400`

Sorted multiset comparison with the table above: identical.
Both totals 8902. (Reference numbers taken from the published perft
divide table; source citation: chess-programming-wiki / perft results.)

## Consequences

- `tests/perft.my` asserts d1=20, d2=400, d3=8902 — correct. Running
  the full d3 assertion takes minutes in one process; use per-root
  subtrees when a bounded check is needed (see Method).
- The earlier "hang at depth 3" reports were caused by sub-90 s timeouts
  being shorter than the single-process run, not by evaluation
  non-termination. `chess-legal-moves`/`chess-apply-move`/perft
  terminate on all positions probed (initial + 20 roots + 400 ply-2
  positions).
- No code change required for correctness. If perft speed matters for
  CI, the per-root decomposition above is the recommended bounded check.