# FPGA-KERNEL-SELECTION — first bounded FPGA kernel for chess-lisp-zero

**Task**: CHESS-LISP-ZERO-FPGA-KERNEL-SELECTION (claimed by prajna)
**Depends on**: CHESS-LISP-ZERO-CPU-BASELINE-PROFILE (done, SHA bf98a5c)
**Date**: 2026-09-01

---

## 1. Input Evidence

### 1.1 CPU Baseline (from docs/CPU-BASELINE-PROFILE.md)

| Component | Mean ms/call | Notes |
|---|---|---|
| perft node (depth 1-2) | 17-20 ms | stable across fixtures |
| `chess-legal-moves` (kiwipete root, 48 moves) | ~665 ms | 48 candidates × filter |
| `chess-apply-move` (first legal root move) | ~7.2 ms | 64-cell copy + meta |
| `chess-best-move` d1 | ~1,313 ms | move scoring + sort |

**Dominant operation per perft node** (OBSERVED):
```
apply-move (64-cell copy + meta)   ≈ 7 ms
legal-filter share of a node        ≈ 10-13 ms   ← dominant
```

Legal filtering = pseudo-move generation + king-safety filter (sliding-ray probes per candidate). With ~20-30 candidates per mid-tree node, king-safety scans dominate.

### 1.2 fpga-lisp ISA 1.1 Limits (from fpga-lisp/isa-contract.my)

| Constraint | Value |
|---|---|
| Word size | 32 bits (4 tag + 28 payload) |
| Registers | 16 (R0-R15, args/env/stack/link/value) |
| Program memory | 4096 words (12-bit address) |
| Heap | 4096 cons cells (12-bit address) |
| Primitive IDs | car=0, cdr=1, cons=2, atom=3, eq=4, add=5 |
| Opcodes | 16 (4-bit): nop, loadi, mov, cons, car, cdr, atom, eq, jmp, loadsym, jf, halt, out, add, sub, in |
| Boot header | optional extended: up to 16 register initializers |

No bitwise ops, no vector/matrix instructions, no floating point, no multiply/divide (add/sub only).

---

## 2. Kernel Candidates Assessment

| Candidate | Description | Complexity | ISA Fit | Evidence Scope |
|---|---|---|---|---|
| **Material evaluation** | Sum piece values (P=100, N=320, B=330, R=500, Q=900, K=20000) | LOW | Good: simple add loop, fixed piece types | Exact integer result, easy oracle |
| Move encoding | Pack (from, to, promo) into 16-20 bits | LOW | Good: simple arithmetic | Round-trip encode/decode test |
| Board-plane transform | 64-cell vector → 8×8 or 12×12 mailbox | LOW | Medium: index arithmetic, no bitwise | Structural equality vs CPU |
| **Attack-mask (sliding rays)** | Rook/Bishop/Queen rays for king safety | HIGH | POOR: needs bitboard ops, not in ISA | Complex verification, needs synthesis |
| Fixed reduction | Perft node reduction (fixed-depth count) | MEDIUM | Medium: recursion/call overhead | Matches perft fixtures |

### 2.1 Rationale for Selection

**SELECTED: Material evaluation** (`chess-evaluate-material`)

Reasons:
1. **Trivial ISA fit** — pure add loop over 64 cells, uses only `add` (primitive ID 5) and `car`/`cdr`/`eq` for board traversal
2. **Fits program memory** — < 100 words estimated
3. **Zero heap pressure** — no cons allocation needed if written iteratively
4. **Exact integer oracle** — CPU result is deterministic sum of fixed constants
5. **Already exists in evaluation.wsm** — can be extracted as pure function
6. **Bounded scope** — no king-safety, no move generation, no recursion
7. **Evidence clarity** — simulation/synthesis/board: single integer result

This is the minimal viable kernel that still exercises the FPGA Lisp evaluator end-to-end (load program, initialize registers, run to halt, read result register).

---

## 3. Kernel Specification

### 3.1 Function Signature (my-lisp)

```lisp
(def chess-evaluate-material
  (lambda (board)
    ;; board: vector of 64 tagged words (piece symbols or ())
    ;; returns: fixnum (centipawns, positive = white advantage)
    ...))
```

### 3.2 Piece Values (centipawns)

| Piece | Value |
|---|---|
| wp | 100 |
| wn | 320 |
| wb | 330 |
| wr | 500 |
| wq | 900 |
| wk | 20000 |
| bp | -100 |
| bn | -320 |
| bb | -330 |
| br | -500 |
| bq | -900 |
| bk | -20000 |
| () / empty | 0 |

### 3.3 Expected FPGA Implementation Approach

- Program loads piece-value table into registers or heap
- Iterate 64 board cells: load cell → tag check → if piece: add value → next
- Result in R15 (value register) at halt
- No recursion, no heap allocation, no function calls beyond primitives

---

## 4. Fixtures

### 4.1 Fixture Format

Each fixture: `(fixture-material (board . <64-list>) (expected . <fixnum>))`

### 4.2 Mandatory Fixtures

| ID | Board | Expected | Rationale |
|---|---|---|---|
| `mat-initial` | Standard start position | 0 | White = Black material |
| `mat-white-up-pawn` | White pawn on e4, rest empty | 100 | Single positive piece |
| `mat-black-up-knight` | Black knight on e5, rest empty | -320 | Single negative piece |
| `mat-complex-midgame` | Kiwipete position board | (compute from oracle) | Real position, mixed pieces |
| `mat-endgame-king-pawn` | WK on e1, WP on e2, BK on e8 | 100 + 20000 - 20000 = 100 | Kings cancel, pawn remains |
| `mat-empty` | All empty | 0 | Baseline |

### 4.3 Fixture Generation

Fixtures are derived from CPU oracle:
1. Run `(chess-evaluate-material board)` on my-lisp CPU
2. Record exact fixnum result
3. Embed as `(expected . <fixnum>)` in fixture

---

## 5. Evidence Plan

### 5.1 Evidence Levels (per task wording)

| Level | Artifact | Verification |
|---|---|---|
| **CPU Oracle** | my-lisp release run of fixture | Deterministic fixnum |
| **RTL Simulation** | iverilog run of assembled program | R15 = expected fixnum at halt |
| **Synthesis** | Yosys/nextpnr for GW5A-25A | Resource report (LUTs, FFs, BRAM), Fmax |
| **Physical Board** | GW5A-25A execution via job_transport.py | R15 = expected fixnum, no LDU error |

### 5.2 Evidence Separation (per task)

- Simulation evidence ≠ synthesis evidence ≠ board evidence
- Each fixture produces independent evidence row
- Speed claims only from physical board cycles, not simulation

### 5.3 Evidence Matrix Template

| Fixture | CPU (fixnum) | RTL Sim (R15) | Synth (LUT/FF/BRAM/Fmax) | Board (R15) |
|---|---|---|---|---|
| mat-initial | 0 | | | |
| mat-white-up-pawn | 100 | | | |
| ... | | | | |

---

## 6. Implementation Steps

1. **Extract pure `chess-evaluate-material`** from `lib/evaluation.wsm` into a standalone `.my` file with no dependencies
2. **Write fixtures** as my-lisp data (`tests/fixtures/material.fixtures.my`)
3. **Assemble to fpga-lisp** using `fpga-lisp/assembler.my` (my-lisp version)
4. **RTL simulate** each fixture with `iverilog` + testbench
5. **Synthesize** for GW5A-25A with Yosys/nextpnr, record resources
6. **Board execute** via `job_transport.py` + CML bridge
7. **Record evidence matrix** in `docs/FPGA-KERNEL-SELECTION-EVIDENCE.md`

---

## 7. Out of Scope (per task)

- ❌ Bitboard representation (no bitwise ops in ISA 1.1)
- ❌ Attack-mask / king-safety (too complex, needs sliding rays)
- ❌ Move generation / legal filtering (dominant CPU op but exceeds ISA)
- ❌ Full perft / search on FPGA
- ❌ Any claim of "FPGA chess engine" or speedup

---

## 8. Acceptance Criteria

- [ ] Pure `chess-evaluate-material` extracted and tested on CPU (all fixtures `ok t`)
- [ ] Assembled program < 4096 words, uses ≤ 16 registers, ≤ 4096 heap cells
- [ ] RTL simulation passes for all fixtures (R15 = expected at halt)
- [ ] Synthesis completes for GW5A-25A with resource report
- [ ] Physical board execution matches for at least 1 fixture
- [ ] Evidence matrix documented with clear separation of evidence levels

---

## 9. References

- CPU Baseline: `docs/CPU-BASELINE-PROFILE.md` (SHA bf98a5c)
- fpga-lisp ISA 1.1: `../fpga-lisp/isa-contract.my`
- Assembler: `../fpga-lisp/assembler.my`
- CML job transport: `../fpga-lisp/job_transport.py`
- Evaluation source: `lib/evaluation.wsm`

---

*This document is the design record for the selected kernel. Evidence artifacts will be appended or linked as they are produced.*