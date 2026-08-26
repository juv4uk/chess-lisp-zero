# Third-Party Material — chess-lisp-zero

## Current status

As of the initial MVP commit, this repository contains **no third-party code,
data, model weights, or game corpora**.

All source files in `src-tauri/`, `src/`, `lib/`, and `tests/` are original
work authored for this project.

## Future third-party material

The following items are planned but not yet incorporated. Each requires a
separate provenance decision and license check before inclusion:

| Material | Source | License | Status |
|---|---|---|---|
| chess.js (frontend validation, differential witness) | [chess.js](https://github.com/jhlywa/chess.js) | BSD-2-Clause | planned, not imported |
| chess-tauri-zero UI patterns (board rendering, busy-state guard) | chess-tauri-zero (MIT, Samuel Gravan / Ken Morishita) | MIT | planned, not imported |
| Model weights / game corpora | TBD | TBD | not yet decided |

## License of this repository

This repository is licensed under the MIT License. See `LICENSE`.

## Chess piece icons

The icon files in `src-tauri/icons/` were generated programmatically for this
project and are not derived from any third-party icon set.
