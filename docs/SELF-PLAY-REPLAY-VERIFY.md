# SELF-PLAY REPLAY VERIFY — driver

Task: `CHESS-LISP-ZERO-SELF-PLAY-REPLAY-VERIFY` (defined by vyasa 2026-08-29).

## What this pins

`tests/replay-verify.wsm` replays the frozen fixture
`tests/fixtures/self-play-replay-fix.my` through the pure-WSM pipeline and
asserts:

| Assert | What it proves |
|---|---|
| `planes-bit-exact` | FEN parse → `chess-neural-position-planes` reproduces all 1152 plane bits |
| `side-match` | side-of-move to move is read back correctly from FEN |
| `policy-roundtrip-indexed` | sparse PUCT policy re-indexes to the exact same vocabulary entries |
| `record-planes-field-identical` | a freshly built `self-play-record` carries the identical planes vector |
| `record-side-field-identical` | fresh record side field matches |
| `record-outcome-fresh-empty` | a fresh record's outcome is still `chess-empty` (unfinalized) |
| `policy-length-2` / `policy-index-*-in-vocabulary` | indexed policy length and bounds within the 1968-entry vocabulary |

Status per run: 9/9 PASS + `SELF-PLAY-REPLAY-VERIFY-PASS`, exit 0.

## Invariant

The fixture is the reference. Any change to the encoding chain
(`lib/chess.my`, `lib/fen.wsm`, `lib/neural-contract.wsm`,
`lib/self-play.wsm`, `lib/puct.wsm`) must re-baseline with a driver
document; the fixture is not edited silently.

## Regenerate

Reproduce the exact fixture values with the release binary:

```bash
cd /home/agents/GitHub/chess-lisp-zero
/home/agents/GitHub/my-lisp/target/release/my-lisp <regenerator.wsm>
```

The regenerator builds the pristine initial position, a PUCT root with two
children (`(chess-move 1 16)` visits 3, `(chess-move 1 18)` visits 1), and
prints FEN / side / sparse PUCT policy / indexed policy / fresh outcome /
1152-plane list. Then rewrite `tests/fixtures/self-play-replay-fix.my` from
that output and re-run `tests/replay-verify.wsm`.

The regenerator itself is not committed (it is the driver procedure above,
not a source artifact); the fixture and the test are.

## Consumers

- PyTorch (`training/from_zero_torch.py`) and any CML/FPGA path may assert
  against `self-play-replay-fix-planes` (1152) and
  `self-play-replay-fix-policy` (indexed entries) as a cross-substrate pin.
- WSM remains the single semantic authority; no torch execution is needed
  to validate these values.