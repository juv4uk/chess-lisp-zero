# Архітектурне дослідження: Tauri + my-lisp + CUDA + FPGA

**Дата:** 2026-08-27

**Статус:** `RESEARCHED` — перевірено за живим кодом і малими виконуваними
пробами; реалізацію в цьому репозиторії ще не розпочато.

**Оновлення (2026-08-27, рішення власника "чиста моя ліцензія"):** усі
згадки `chess.js` нижче — це історія дослідження, не поточний план.
Реально: `chess.js` у проєкті не використовується взагалі, навіть
поза деревом як witness — замість нього differential-gate працює на
публічних perft-даних (chess-programming-wiki). Деталі: `NOTICE-third-party.md`,
задача `CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL` у `tasks.my`.

> **SUPERSEDED:** активний план більше не передбачає адаптацію жодного
> стороннього шахового коду, UI, teacher-моделі, ваг або корпусів. Цей файл
> збережено як історію дослідження. Чинне рішення:
> [`ORIGINAL-WORK-LICENSE-PLAN.md`](ORIGINAL-WORK-LICENSE-PLAN.md).

## 1. Мета

`chess-lisp-zero` — не спроба негайно наздогнати Stockfish або відтворити
весь `chess-tauri-zero`. Це контрольований demonstrator однієї семантики на
кількох обчислювальних субстратах:

```text
шахова програма на my-lisp
        |
        +-- Rust reference runtime / CPU
        +-- CML Compute IR / CUDA
        `-- CML + fpga-lisp / FPGA
```

Tauri є інтерактивною оболонкою й інструментом спостереження, а не новим
джерелом шахової або мовної семантики.

## 2. Що можна адаптувати з chess-tauri-zero

| Компонент | Рішення | Обґрунтування |
|---|---|---|
| Шахова дошка, контролери, heatmap, журнал | Адаптувати | Це UI, незалежний від PyTorch |
| Tauri v2 shell і конфігурація | Адаптувати | Уже збирається на Linux і Windows |
| Busy-state, generation guard, recovery | Перенести як патерн | Закриває реально знайдені process/race bugs |
| `chess.js` | Тимчасово зберегти | UI-validation і незалежний differential oracle |
| UCI | Зберегти як зовнішню сумісну межу | Дає порівняння з попереднім рушієм |
| Python/PyTorch engine | Не робити ядром | Лишається зовнішнім reference/oracle |
| Python sidecar launcher | Замінити | Новий Tauri backend має вбудовувати my-lisp |
| `.h5` weights | Не копіювати автоматично | Потребують окремого provenance/data рішення |
| Linux/Windows CI | Адаптувати після shell MVP | Спершу потрібен buildable продукт |
| Готові binaries | Не переносити | Вони прив'язані до старого runtime layout |

## 3. Ліцензійна межа

Код `chess-tauri-zero` походить із MIT-проєкту Samuel Gravan / Ken
Morishita. Vendored `chess.js` має BSD-2-Clause. Повторне використання
можливе лише зі збереженням відповідних copyright/ліцензійних повідомлень.

До першого перенесення коду потрібно:

1. ратифікувати ліцензію `chess-lisp-zero`;
2. додати `NOTICE-third-party.md`;
3. окремо перевірити походження й умови ваг та наборів партій;
4. не трактувати ліцензію коду як автоматичну ліцензію model/data artifact.

## 4. Рекомендована runtime-архітектура

```text
Tauri GUI
   |
   +-- chess.js
   |     rendering + frontend validation + differential witness
   |
   `-- Rust ChessRuntime
          |
          +-- embedded my-lisp Session
          |     chess rules + position + search orchestration
          |
          +-- CML Execution Graph
          |     CPU / CUDA dispatch
          |
          `-- fpga-lisp command transport
                bounded hardware experiments
```

`my-lisp` уже має публічний Rust embedding API (`Session`, `eval_program`,
`parse`, `Value`). `my-idea` доводить, що канонічний runtime можна викликати
безпосередньо з Tauri command. Тому окремий CLI process не потрібен для
звичайного Lisp evaluation.

### Persistent session

`Session` містить `Rc`-значення і не є звичайним `Send + Sync` state для
довільного конкурентного доступу з Tauri commands. Рекомендована модель:

```text
Tauri command
   -> typed request channel
   -> one ChessRuntime worker thread
   -> Session + core.my + chess/*.my
   -> typed response/event
```

Worker створює й утримує `Session` усередині власного потоку. Це дає одну
послідовну владу над станом, не вимагаючи unsafe-sharing.

UCI доцільно зберегти як зовнішній adapter для GUI/engine compatibility, але
внутрішній Tauri API може бути структурованим (`position`, `move`, `result`,
`trace`), а не текстовим UCI transport усередині процесу.

## 5. Фактично наявні можливості my-lisp

Перевірено поточним release binary `my-lisp v0.32.0`:

```text
64-element vector                    PASS
vector-set! + vector-ref             PASS
i32-buffer                           PASS
numeric-buffer-map (+1)              PASS
```

Результат малої проби:

```text
8
rook
#i32(2 3 4)
```

Також наявні:

- exact integers, rationals і explicit inexact numbers;
- mutable indexed `Vector`;
- immutable contiguous `NumericBuffer<I32|F32>`;
- `+`, `-`, `*`, `/`, comparisons, `abs`, `min`, `max`;
- library-level `sqrt`;
- JSON parsing і canonical Lisp serialization;
- monotonic `mono-ms` / `mono-ns`;
- FASL parser-output cache;
- filesystem, process і TCP через окремий host-capability layer;
- WASM, LSP і native Rust embedding;
- CML execution graph і optional CUDA/wgpu/FPGA executors.

Фактично відсутні (`UnknownSymbol` у release runtime):

```text
bit-and
shift-left
popcount
exp
random
```

Відсутність не означає автоматичну потребу додавати primitive.

## 6. Що спочатку пишеться звичайним my-lisp

Рекомендована бібліотечна структура:

```text
lib/chess/position.my
lib/chess/move.my
lib/chess/rules.my
lib/chess/fen.my
lib/chess/uci.my
lib/chess/perft.my
lib/chess/search.my
lib/chess/prng.my
```

Перший вертикальний зріз:

```text
start-position
-> pseudo-legal moves
-> king-safety filter
-> apply-move
-> terminal-state
-> perft depth 1..3
```

Початкове board representation — `Vector` із 64 клітинок. Воно простіше для
перевірки, ніж bitboards, і не вимагає нового language contract.

Для гілок пошуку не можна неявно ділити один mutable vector через `Rc`.
Потрібна library-функція, яка явно створює новий 64-element vector і лише
потім застосовує хід. Її можна виразити через `make-vector`, `vector-ref` і
`vector-set!`; новий Rust primitive на MVP не потрібен.

Детермінований PRNG із explicit seed також спершу є бібліотечною функцією.
Глобальний магічний `random` створив би прихований state і погіршив би
відтворюваність self-play.

## 7. Коли можуть бути заслужені bit primitives

Після correct vector/perft baseline профіль може обґрунтувати bitboards:

```text
bit-and / bit-or / bit-xor / bit-not
shift-left / shift-right
popcount
```

Перед ратифікацією треба визначити:

- семантику над arbitrary-precision exact integers;
- поведінку від'ємних значень і right shift;
- fixed-width boundary для CUDA;
- representable subset для 28-bit FPGA fixnum або окремого data plane;
- differential fixtures Rust/CML/FPGA.

Без цього одна назва операції приховає різні семантики на трьох субстратах.

## 8. Поточна CUDA-межа

CUDA в екосистемі вже реальна, але вузька. CML `compute-contract.my` фіксує:

- typed `i32/f32` buffers;
- fail-closed admission;
- CPU reference backend;
- CUDA source emitter і live runtime;
- physical `i32 map` evidence на GTX 1050 Ti;
- execution graph CPU -> CUDA -> host-staged FPGA;
- відсутність direct device-to-device transfer.

Поточна kernel-підмножина переважно підтримує:

```text
i32 checked addition trees
f32 affine x + constant
numeric-buffer-map
```

Цього недостатньо для AlphaZero network. Розширення належить CML Compute
IR/backend layer, а не vendor-примітивам у my-lisp:

```text
matmul
conv2d
relu
reduce-sum
reduce-max
softmax
batch-normalization inference
```

Кожна операція потребує CPU oracle, semantic obligations, CUDA differential
test і planner threshold. Automatic offload до появи цих доказів відсутній.

## 9. Tensor representation

Поточний `NumericBuffer` має element type і length, але не shape/layout.
Початкова форма може бути звичайним Lisp datum:

```lisp
(tensor
  (shape 18 8 8)
  (layout nchw)
  (data #f32(...)))
```

`chess-lisp-zero` володіє шаховим meaning каналів, CML — перевіркою descriptor
і lowering, my-lisp — лише значеннями, з яких descriptor складено.

First-class `Tensor` у language contract варто додавати лише після доказу,
що бібліотечний descriptor реально заважає correctness, interchange або
performance.

## 10. Поточна FPGA-межа

`fpga-lisp` ISA 1.1 має:

- 32-bit tagged word, 28-bit payload;
- 16 registers;
- 4,096 program words;
- 4,096 cons cells;
- Lisp primitives і `ADD/SUB`;
- extended boot input до 16 tagged registers;
- один physical host-staged Execution Graph path.

Це не основа для негайного перенесення повного MCTS або ResNet. Перші чесні
FPGA-кандидати:

```text
move encoding/decoding
board-plane transform
attack mask for one piece class
material evaluation
small fixed reduction
```

Вибір kernel має відбуватися після CPU profiling. FPGA simulation,
synthesis і physical-board result залишаються різними evidence classes.

## 11. Differential evidence plan

На першому етапі `chess.js` не є backend authority. Він є незалежним
свідком для move legality/perft:

```text
FEN fixture
  |-- chess.js expected legal moves
  `-- my-lisp actual legal moves
             -> normalized comparison
```

Наступний рівень:

```text
same position / same typed input
  |-- my-lisp Rust CPU
  |-- CML CPU reference
  |-- CML CUDA
  `-- fpga-lisp bounded kernel

compare observable result + error + elapsed time
```

Однаковий result доводить parity лише для конкретного fixture/kernel.
Швидкість не доводить силу гри; arena/perft/backend parity — різні метрики.

## 12. Послідовність реалізації

1. Ратифікувати ліцензію й створити third-party NOTICE.
2. Адаптувати мінімальний Tauri shell і chess-board UI.
3. Додати single-owner embedded my-lisp actor.
4. Реалізувати position/move/rules/perft у `.my`.
5. Побудувати `my-lisp <-> chess.js` perft differential gate.
6. Додати UCI adapter і порівняння з Python reference engine.
7. Профілювати CPU baseline; не оптимізувати до вимірювання.
8. Ввести library-level tensor descriptor.
9. Розширювати CML Compute IR по одній нейромережевій операції.
10. Вибрати один bounded FPGA kernel і провести його через simulation ->
    synthesis -> hardware evidence.

## 13. Головне рішення

Для першого працюючого `chess-lisp-zero` розширення ядра `my-lisp` не
потрібне. Потрібні:

```text
Tauri shell
+ embedded my-lisp actor
+ шахова .my бібліотека
+ perft/differential fixtures
```

Bit primitives, Tensor value, CUDA neural kernels і FPGA blocks додаються
тільки після того, як попередній, простіший рівень дав correct baseline і
профіль довів конкретну потребу.
