# Third-Party Material — chess-lisp-zero

## Current status

This repository contains **no vendored third-party code, data, model weights,
or game corpora**. The optional training backend uses PyTorch as a replaceable
runtime dependency; PyTorch is distributed under its BSD-style license and is
not copied into this repository.

All source files in `src-tauri/`, `src/`, `lib/`, and `tests/` are original
work authored for this project.

## Future third-party material

The following items are planned but not yet incorporated. Each requires a
separate provenance decision and license check before inclusion:

| Material | Source | License | Status |
|---|---|---|---|
| chess-tauri-zero UI patterns (board rendering, busy-state guard) | chess-tauri-zero (MIT, Samuel Gravan / Ken Morishita) | MIT | planned, not imported |
| Model weights / game corpora | TBD | TBD | not yet decided |

## Decided against: chess.js

Owner decision, 2026-08-27 ("то хай буде чиста моя ліцензія"): chess.js
(BSD-2-Clause) is not used anywhere in this project, not even as an
out-of-tree differential-testing witness (the earlier
`tools/witness-chessjs.mjs`, removed). CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL
uses published perft reference data for standard chess-programming-wiki
test positions instead — public facts/numbers, not third-party code, so
no license/NOTICE entry is needed for it at all.

## License of this repository

This repository is licensed under the MIT License. See `LICENSE`.

## Chess piece icons

The icon files in `src-tauri/icons/` were generated programmatically for this
project and are not derived from any third-party icon set.
