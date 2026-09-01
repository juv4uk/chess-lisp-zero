# Карта повторного використання екосистеми для chess-lisp-zero

**Статус:** READ-ONLY ARCHITECTURE REVIEW

**Дата:** 2026-08-27

**Автор огляду:** Viveka (`wsl-viveka-1`)

## Висновок

`chess-lisp-zero` не є новим шаховим рушієм з нуля. Це місце, де вже
реалізовані шахові, Lisp, WASM, Tauri, CUDA і FPGA компоненти збираються
навколо одного авторитетного шахового ядра в `my-lisp`.

```text
chess-tauri-zero = бібліотека перевірених ідей та oracle
my-lisp          = шахова семантика й пошук
my-lisp-wasm     = найкоротший шлях до живої гри
Tauri            = application shell
CML              = планувальник CPU/CUDA/FPGA
fpga-lisp        = апаратний виконавець
```

Це не дозвіл автоматично копіювати код між репозиторіями. Перед перенесенням
стороннього коду, даних або ваг діють `ecosystem/docs/policy/LICENSE-MATRIX.md` і
окреме provenance-рішення.

## Карта вже реалізованого

| Шар | Уже реалізовано | Чого бракує |
|---|---|---|
| Шахові правила | У `chess-lisp-zero/lib/chess.my`: 64-клітинна дошка, звичайні ходи, check, mate/stalemate, perft 1–2 | Рокіровка, en passant, promotion, FEN, виконаний perft-3 |
| Шаховий AI | У `chess-tauri-zero`: MCTS/PUCT, 1968 policy labels, self-play | Семантична адаптація до Lisp-моделі |
| Нейромережа | Реальний PyTorch ResNet: 18×8×8, 7 residual blocks, policy/value heads | CML ще не виконує повну мережу |
| GUI | Старий Tauri chess UI; новий Tauri v2 shell у shared worktree | З'єднання з реальним Lisp runtime |
| WASM | Persistent `my-lisp` Session, preload `core.my`, diagnostics | Завантаження `chess.my` та typed chess API |
| CUDA | CML execution graph, admission і CUDA map-kernel | Conv2D, matmul, ReLU, BN, reductions, softmax |
| FPGA | ISA 1.1, evaluator, assembler, UART transport, CML job protocol | Виміряний і обмежений шаховий kernel |
| Tooling | LSP, FASL, semantic oracle, differential infrastructure | Шахові diagnostics, fixtures і CI |

## 1. chess-tauri-zero: не залежність, а шаховий oracle

Старий репозиторій уже містить більшість предметних конструкцій, які не треба
винаходити повторно:

- `src/chess_zero/env/chess_env.py` — FEN, визначення завершення партії та
  canonical 18-plane input;
- `src/chess_zero/config.py` — генератор повного простору з 1968 UCI policy
  labels, включно з promotion;
- `src/chess_zero/agent/player_chess_torch.py` — MCTS/PUCT, visit statistics,
  temperature, root noise і policy з visit counts;
- `src/chess_zero/agent/torch_model.py` — policy/value ResNet;
- `src/chess_zero/worker/self_play_torch.py` — self-play та формат навчальних
  прикладів;
- `src/chess_zero/play_game/uci_torch.py` і `src/tests/test_uci_protocol.py` —
  UCI lifecycle та regression scenarios;
- `app/` — Tauri shell, шахівниця, UCI sidecar bridge і перевірені UX-патерни.

### Що адаптувати як контракт або fixture

- FEN та UCI encoding;
- 18-plane position representation;
- алгоритм генерації 1968 policy labels;
- PUCT/MCTS формули;
- `(fen, policy, value)` self-play schema;
- UCI crash/lifecycle fixtures;
- board rendering, busy-state, engine lifecycle і heatmap UX.

### Що не робити авторитетною основою

- Python sidecar;
- `python-chess` як семантичний авторитет правил;
- стара TensorFlow/Keras лінія;
- PyTorch усередині шахового semantic core;
- pretrained weights без окремого provenance-рішення.

PyTorch не треба відкидати. Він може залишатися практичним teacher/oracle і
backend доти, доки CML не має повного neural stack. Це відповідає принципу:
якщо перевірена реалізація краща і немає сенсу механічно наздоганяти її,
використовуємо її за чіткою межею, не підміняючи нею власну свободу розвитку.

## 2. my-lisp: потрібна основа вже є

У `my-lisp` уже реалізовано:

- persistent `Session` та embedding API;
- vectors для першої шахової дошки;
- точні числа й bignum;
- `NumericBuffer` для майбутніх tensor/compute меж;
- WASM runtime;
- LSP для агентів і редакторів;
- FASL parse-output cache;
- host capability boundary;
- semantic oracle і test infrastructure.

Отже, для першого шахового вертикального зрізу не потрібен новий runtime type.
Правила, позиція і пошук можуть лишатися бібліотечним `.my` кодом. Rust
примітиви допускаються лише після профілювання конкретного bottleneck.

## 3. my-lisp-wasm: найкоротший шлях до живої гри

`crates/my-lisp-wasm/src/lib.rs` уже має:

- persistent browser session;
- автоматичний preload `core.my`;
- `evaluate()`;
- `reset_session()`;
- parse та arity diagnostics;
- native regression tests.

Тому найкоротший наскрізний продукт не потребує Python або CUDA:

```text
lib/chess.my
→ persistent my-lisp WASM session
→ Tauri/web board
→ user move
→ Lisp legal moves
→ Lisp apply-move
→ rendered position
```

Це має бути першим application-level доказом. Native embedded actor у Tauri
може розвиватися паралельно, але не блокує browser/WASM slice.

## 4. CML: execution fabric уже існує

CML уже має:

- semantic/compute admission;
- explicit execution graph;
- CPU fallback;
- CUDA source emission для підтриманого `numeric-buffer-map`;
- live CUDA differential tests;
- версіонований FPGA job/result protocol;
- host-side FPGA transport;
- fail-closed backend capability model.

Тому `chess-lisp-zero` не повинен створювати власний CUDA dispatcher або
власний FPGA transport.

Водночас поточний CUDA backend не є neural backend. Для AlphaZero inference
ще потрібні щонайменше:

- `matmul`;
- `conv2d`;
- `relu`;
- reductions;
- `softmax`;
- batch-normalization inference.

До появи цих операцій PyTorch лишається реалізацією повної мережі, а CML —
доказовим середовищем для вузьких admitted kernels.

## 5. fpga-lisp: не повний шаховий рушій, а bounded executor

`fpga-lisp` уже має загальну Lisp-машину, ISA 1.1, assembler, evaluator,
симуляційні fixtures, UART bootloader/monitor і фізичний transport через CML.

Перший шаховий FPGA-крок має бути вибраний тільки після CPU-профілювання.
Реалістичні кандидати:

- move encoding;
- один attack-mask class;
- 64-cell board-plane transform;
- material evaluation;
- fixed reduction.

Не можна називати один такий kernel повним виконанням шахового рушія на FPGA.
Evidence класи лишаються окремими: model, RTL simulation, synthesis, hardware.

## 6. Tauri й UI

Є три джерела практичних патернів:

- `chess-tauri-zero/app` — шахівниця, engine lifecycle, sidecar bridge;
- `my-idea` — Tauri/ClojureScript, ecosystem evidence і observatory patterns;
- `radio-log` — сучасна Tauri/Svelte packaging та release scripts.

У shared worktree `chess-lisp-zero` вже з'явився мінімальний Tauri v2 shell та
HTML-шахівниця. Це активна паралельна робота Ganaka, не частина шахового
semantic-core коміту `5320bf8`. Shell поки показує статичну стартову позицію і
не під'єднаний до `my-lisp`.

## 7. Tensor descriptor: реалізація почалась, але gate ще червоний

У shared worktree вже є:

- `docs/ADR-TENSOR-DESCRIPTOR.md`;
- `lib/tensor.my`;
- `tests/tensor-test.my`.

Це активна робота Vyasa. Під час цього огляду точний запуск
`tests/tensor-test.my` завершився помилкою `car expects a non-empty list` у
конструкторі descriptor. Крім того, `(def tensor car)` зараз не є
конструктором. Vyasa повідомлено; ці файли не редагувались Viveka.

Статус tensor slice: **DESIGNED / ACTIVE PATCH, NOT TESTED-PASS**.

## 8. Рекомендована послідовність

### M0 — шахова семантика

1. Завершити full rules: castling, en passant, promotion, FEN.
2. Виконати perft 1–3 і tactical terminal fixtures.
3. Додати differential witness через публічні perft-дані (chess-programming-wiki
   стандартні позиції) — не `chess.js`, рішення власника 2026-08-27
   ("чиста моя ліцензія"), див. `NOTICE-third-party.md`.

### M1 — жива гра

1. Preload `chess.my` у WASM session.
2. Визначити typed boundary: position, legal moves, apply move, status.
3. Під'єднати Tauri/web board.

### M2 — інтелект

1. Адаптувати PUCT/MCTS як `.my` бібліотеку або чітко обмежений host helper.
2. Спершу використовувати material/handcrafted evaluator.
3. Зафіксувати deterministic search fixtures.

### M3 — learning/oracle

1. Ратифікувати 18-plane і 1968-label contracts.
2. Використати PyTorch network як teacher/oracle.
3. Визначити provenance self-play corpus і model weights.

### M4 — heterogeneous execution

1. Профілювати CPU baseline.
2. Передати лише виміряні pure bulk kernels у CML/CUDA.
3. Вибрати один bounded FPGA kernel.
4. Зібрати fixture-level CPU ↔ CUDA ↔ FPGA evidence matrix.

## Остаточна межа відповідальності

```text
my-lisp
  owns: language semantics, values, evaluator, WASM, LSP

chess-lisp-zero
  owns: chess position, rules, search, chess tensor meaning, fixtures

chess-tauri-zero
  supplies: historical implementation evidence and comparison oracles

CML
  owns: compute admission, execution graph, CPU/GPU/FPGA planning

fpga-lisp
  owns: ISA, RTL, synthesis and physical hardware evidence
```

Головний критерій: повторно використовувати вже доведені компоненти, але не
змішувати їхні authority boundaries і не піднімати стару реалізацію до
канонічного статусу без окремого рішення.
