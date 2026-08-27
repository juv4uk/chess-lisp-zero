# План оригінальної реалізації та ліцензійної межі

**Статус:** `OWNER-RATIFIED`  
**Дата:** 2026-08-27  
**Рішення власника:** не включати до `chess-lisp-zero` матеріали під іншими
ліцензіями; шаховий продукт створюється як оригінальна робота проєкту.

## 1. Що означає це рішення

У репозиторій не копіюються й не адаптуються сторонні:

- шахові рушії та бібліотеки правил;
- UI-компоненти й вихідний код інших шахових застосунків;
- таблиці policy labels або готові feature encodings;
- моделі, ваги, дебюти, бази партій і навчальні корпуси;
- іконки, фігури, звуки та інші product assets.

Увесь шаховий код, UI, fixtures, search і learning pipeline пишуться тут
самостійно та поширюються під ліцензією репозиторію MIT.

Публічні правила шахів, математичні формули й числові perft-результати можуть
бути використані як факти з точним посиланням на джерело. Код або таблиці з
джерела не копіюються.

## 2. Неминуча межа Tauri

Tauri, Serde, Rust toolchain та інші package dependencies не стають нашим
кодом і зберігають власні permissive licenses. Без них вимога Tauri-продукту
технічно неможлива. Тому рішення означає:

```text
product code/data/assets  = original MIT work
package dependencies      = external build/runtime infrastructure
vendored third-party code = forbidden
```

Перед першим distributable build CI має сформувати dependency-license
inventory. Нова залежність допускається лише коли вона потрібна продукту,
має сумісну permissive license і не приносить шахової семантики або даних.

## 3. Авторитетна архітектура

```text
original WSM chess rules/search
        -> canonical my-lisp runtime
        -> original typed chess API
        -> original Tauri UI
        -> measured CML/CUDA kernels
        -> bounded fpga-lisp kernels
```

- `my-lisp` визначає семантику мови.
- `chess-lisp-zero` визначає шахову модель, правила, пошук, self-play schema,
  UI meaning та fixtures.
- `CML` визначає compute admission і lowering.
- `fpga-lisp` визначає hardware execution evidence.
- `chess-tauri-zero` та інші зовнішні шахові проєкти не є dependencies,
  teachers, oracles або джерелами коду цього продукту.

## 4. Оновлена послідовність

### M0 — правильні шахи

1. Завершити original WSM rules: FEN, castling, en passant, promotion.
2. Довести deterministic perft і terminal fixtures.
3. Звірити лише числові публічні perft-факти з citation; не імпортувати код.

### M1 — жива гра

1. Відкрити шахове WSM API через persistent my-lisp WASM/native session.
2. Реалізувати оригінальну шахівницю та interaction state.
3. З'єднати Tauri UI з єдиним авторитетним WSM runtime.

### M2 — власний інтелект

1. Реалізувати deterministic minimax/alpha-beta baseline.
2. Реалізувати original PUCT/MCTS із injectable handcrafted evaluator.
3. Генерувати власні self-play games і training records із provenance,
   versioned rules та deterministic seeds.

### M3 — власна модель

1. Спроєктувати власне board-plane і policy-index кодування з round-trip
   fixtures; не копіювати сторонні label tables.
2. Реалізувати CPU reference operations у CML.
3. Переносити в CUDA лише виміряні kernels із CPU differential evidence.
4. Тренувати лише на власному self-play corpus; pretrained weights заборонені.

### M4 — FPGA

1. Обрати kernel після CPU/CUDA profiling.
2. Розділяти model, RTL simulation, synthesis і physical-board evidence.
3. Не називати bounded kernel повним FPGA chess engine.

## 5. Gates

Перед кожним новим файлом даних, asset, dependency або model artifact:

```text
origin known?
originally produced here?
license compatible?
needed for current milestone?
recorded in inventory/NOTICE when required?
```

Будь-яке `UNKNOWN` блокує включення. Штучний fallback або копіювання
«тимчасово» заборонені.

