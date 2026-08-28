# chess-lisp-zero

Локальний дослідницький репозиторій для шахового рушія та навчальних
експериментів, виражених через `my-lisp`.

Це полігон повної зв’язки:

```text
шахова семантика в my-lisp
→ CPU-еталон
→ Tauri application shell
→ CML/CUDA-виміряні ядра
→ bounded FPGA kernels
```

## Поточний стан

`EXECUTED — FIRST SEMANTIC SLICE`:

- `lib/chess.my` — 64-клітинна векторна дошка, подання ходу, генерація
  звичайних псевдолегальних ходів, фільтр безпеки короля, чисте застосування
  ходу, `checkmate`/`stalemate` та детермінований `perft`;
- `tests/perft-quick.my` — короткий тест для навантаженого середовища;
- `tests/perft.my` — повний fixture з очікуваннями 20/400/8902;
- `tests/perft-standard.wsm` — перевірка опублікованих Kiwipete та Position 3
  fixtures (depth 1/2: 48/2039 та 14/191), включно зі спеціальними правилами;
- `tests/fen.wsm` — точний round-trip усіх шести полів FEN;
- `tests/apply-move.wsm` — застосування звичайних ходів, рокіровки,
  en-passant і всіх чотирьох перетворень пішака;
- `lib/wasm-api.wsm` + `src/chess-api.mjs` — typed JSON-safe facade над
  persistent `my-lisp-wasm` session без дублювання шахових правил у JS;
- `src/app.mjs` — playable human move slice: authoritative FEN rendering,
  legal-target highlighting, move application and terminal status via WASM;
- `lib/evaluation.wsm` — детермінована material evaluation;
- `lib/search.wsm` — depth-limited minimax correctness baseline без заяви
  про силу гри.

Перевірений зараз доказ:

```text
initial legal moves = 20
perft(1) = 20
perft(2) = 400
checkmate fixture = checkmate
stalemate fixture = stalemate
persistent perft preserves the original board
best capture at depth 1 = (8 16), score = 500
checkmated-side search score = -100000
castling/apply-move fixtures = PASS
```

`perft(3) = 8902` виконано й підтверджено release-інтерпретатором 2026-08-27
разом із перевіркою, що початкова дошка відновлена після обходу. Це повільний
acceptance gate, тому `perft-quick.my` лишається коротким повсякденним тестом.
Генерація й застосування рокіровки, en-passant та всіх чотирьох promotion
choices перевіряються окремими fixtures. Стандартні Kiwipete та Position 3
perft-позиції додатково перевіряють їх у зв'язці з FEN та legal-move filter.

Запуск із checkout `chess-lisp-zero`:

```bash
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/perft-quick.my
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/apply-move.wsm
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/fen.wsm
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/perft-standard.wsm
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/evaluation.wsm
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/search.wsm
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/perft.my
```

## Windows artifact

Workflow `Windows release artifact` збирає на вимогу непідписані Tauri
інсталятори. Результат доступний у GitHub Actions як artifact
`chess-lisp-zero-windows`; signing і публікація GitHub Release навмисно
залишені окремими наступними кроками.

## Межі

- `my-lisp` є авторитетом семантики мови.
- Цей репозиторій володіє шаховою моделлю, шаховими алгоритмами та доказами
  їх виконання на `my-lisp`.
- Після стабілізації шахове ядро є кандидатом до перенесення в `my-lisp/lib`
  як канонічна бібліотека; до того воно лишається дослідницьким.
- `chess-tauri-zero` може бути джерелом перевірених ідей і експериментальних
  порівнянь, але його код, дані та ваги не копіюються автоматично.
- Твердження про швидкість, силу гри або навчання потребують окремого
  відтворюваного тесту.

Ліцензія: MIT (`LICENSE`, `repo.my`). Сторонній код/дані — лише
case-by-case, з провенансом і ревʼю ліцензії (chess.js виключено, див.
`NOTICE-third-party.md`).

## Нейромережа

Практичний план CPU → CUDA → bounded FPGA та бюджет моделі для реального
owner hardware описані в [`docs/NEURAL-NETWORK-ROADMAP.md`](docs/NEURAL-NETWORK-ROADMAP.md).
Виконуваний WSM-контракт `lib/neural-contract.wsm` фіксує 18×8×8 input
planes і детермінований policy vocabulary із 1968 UCI labels.
`lib/puct.wsm` додає детермінований однопотоковий PUCT reference з
авторитетним chess expansion, alternating backup, temperature 0/1 та
підмінним evaluator; це correctness baseline, а не твердження про силу гри.
