# CHESSJS-DIFFERENTIAL — normalized differential gate

## Verdict

The my-lisp chess library (lib/chess.my + lib/fen.wsm) matches the
published perft reference tables for all six standard Chess Programming Wiki
positions at depths 1 and 2, and every fixture FEN round-trips through
`chess-position-from-fen` / `chess-position-to-fen` exactly. Depths: 1
(= published legal-move count) and 2 for each position.

Gate: `tests/differential-gate.wsm` — run `my-lisp tests/differential-gate.wsm`.

## Source

Chess Programming Wiki, "Perft Results",
https://www.chessprogramming.org/Perft_Results
(accessed 2026-08-29). Expected node counts and all fixture FENs are taken
verbatim from that page; no values in this gate were re-derived or
hand-transcribed from memory.

## Cases (published : engine actual, depth 1 and 2)

| fixture | FEN (from the published page) | depth | published | engine |
|---------|-------------------------------|-------|-----------|--------|
| initial | `rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1` | 1 | 20 | 20 |
|         | same | 2 | 400 | 400 |
| kiwipete | `r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1` | 1 | 48 | 48 |
|          | same | 2 | 2,039 | 2,039 |
| position-3 | `8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1` | 1 | 14 | 14 |
|            | same | 2 | 191 | 191 |
| position-4 | `r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1` | 1 | 6 | 6 |
|            | same | 2 | 264 | 264 |
| position-5 | `rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8` | 1 | 44 | 44 |
|            | same | 2 | 1,486 | 1,486 |
| position-6 | `r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10` | 1 | 46 | 46 |
|            | same | 2 | 2,079 | 2,079 |

Kiwipete FEN: the published page header omits move counters; the standard
full FEN with `0 1` is used (already the existing convention in
tests/perft-standard.wsm). Position 4's mirror FEN has identical counts and
is noted but not repeated as a fixture.

## Depth coverage beyond 2

Published d3 values (initial 8,902; kiwipete 97,862; pos-3 2,812; pos-4
9,467; pos-5 62,379; pos-6 89,890) are NOT asserted in this gate.

- initial d3 = 8902 is asserted in `tests/perft.my` and was verified
  independently per-root in `docs/PERFT-VERIFY.md` (commit 811b84f).
- The interpreter evaluates roughly 60 ms per perft node, so single-process
  d3 for kiwipete/pos-5/pos-6 is on the order of 1-2 hours — outside the
  bounded-gate mandate. Left as documented open coverage, not silently elided:
  expected values above are recorded for a future, faster run (e.g. after
  profiling per CHESS-LISP-ZERO-CPU-BASELINE-PROFILE).

## Notes / honest findings

- `chess-test-failure` (the failure path used by the sibling WSM tests,
  and by this gate) has NO definitions anywhere in this repo. It only ever
  errors the process on a failing case (non-zero exit), so passing gates are
  unaffected, but a future failed assertion would surface as
  `unknown symbol: chess-test-failure`. Recommend a single central
  definition in lib/chess.my or a lib/testsupport.wsm. Flagged for
  follow-up; matches existing convention rather than being papered over here.
- Gate runtime is bounded (~6600 perft nodes total; a few minutes).
- Commits: gate + doc + tasks.my — see `git log`/`git status` for SHAs.