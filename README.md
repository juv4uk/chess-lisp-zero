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
- `tests/perft.my` — повний fixture з очікуваннями 20/400/8902.

Перевірений зараз доказ:

```text
initial legal moves = 20
perft(1) = 20
perft(2) = 400
checkmate fixture = checkmate
stalemate fixture = stalemate
search mutation restores the original board
```

`perft(3) = 8902` записано як acceptance fixture, але його виконання лишається
окремим gate через поточне системне навантаження. Рокіровка, en passant і
promotion ще не входять у перший зріз; стартовий perft 1..3 їх не активує.

Запуск із checkout `chess-lisp-zero`:

```bash
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/perft-quick.my
/home/agents/GitHub/my-lisp/target/release/my-lisp tests/perft.my
```

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

Ліцензію ще не обрано. До її ратифікації не додавати сторонній код або дані.
