# Third-Party Material — chess-lisp-zero

## Current status

As of the initial MVP commit, this repository contains **no third-party code,
data, model weights, or game corpora**.

All source files in `src-tauri/`, `src/`, `lib/`, and `tests/` are original
work authored for this project.

## Owner policy: original chess product only

Owner decision, 2026-08-27: third-party chess code, UI code, model weights,
game corpora, training data and product assets are not planned for inclusion.
The UI, engine, fixtures and learning artifacts are original project work.

Tauri, Serde and transitive Rust packages remain external build/runtime
dependencies under their own compatible licenses; they are not vendored
project source or chess-semantic authority. A distributable build requires a
generated dependency-license inventory before release.

## Decided against: chess.js

Owner decision, 2026-08-27 ("то хай буде чиста моя ліцензія"): chess.js
(BSD-2-Clause) is not used anywhere in this project, not even as an
out-of-tree differential-testing witness (the earlier
`tools/witness-chessjs.mjs`, removed). CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL
may compare original fixtures with cited public perft facts. No code, fixture
table, or executable artifact is copied from those sources.

## License of this repository

This repository is licensed under the MIT License. See `LICENSE`.

## Chess piece icons

The icon files in `src-tauri/icons/` were generated programmatically for this
project and are not derived from any third-party icon set.
