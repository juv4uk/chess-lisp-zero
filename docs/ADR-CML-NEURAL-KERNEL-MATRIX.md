# ADR: CML Neural Kernel Matrix — AlphaZero Inference Gap Analysis

**Status:** PROPOSED
**Date:** 2026-08-27
**Task:** CHESS-LISP-ZERO-CML-NEURAL-KERNEL-MATRIX
**Author:** Vyasa (compiler steward)
**Depends on:** CHESS-LISP-ZERO-TENSOR-DESCRIPTOR-ADR (completed, SHA fc11dae)

---

## Context

AlphaZero inference requires a set of neural network operations. This ADR maps
each operation against live CML Compute IR to classify what is implemented,
expressible, or missing, and to define the minimum viable path forward.

This is **design only** — no kernel implementations.

## Source Evidence

All findings verified against live CML codebase at HEAD:
- `compute-contract.my` v0.28 (CML repo)
- `compatibility.my` v0.3.0 (claims my-lisp 2.0, observes 3.0)
- `src/compute.rs` (504 lines) — compute analysis
- `src/execution.rs` (456 lines) — execution graph
- `src/gpu_cuda.rs` (71 lines) — CUDA C emitter
- `src/gpu_cuda_runtime.rs` (158 lines) — CUDA runtime via cudarc
- `src/gpu_wgsl.rs` (69 lines) — WGSL emitter
- `src/gpu_wgpu_runtime.rs` (331 lines) — wgpu runtime
- `src/ir.rs` (104 lines) — IR definitions
- `src/lower.rs` (307 lines) — AST to IR lowering

## CML Current Compute Model

CML's compute capabilities are deliberately narrow:

| Layer | What exists |
|---|---|
| **Bulk operations** | `numeric-buffer-map` (element-wise 1D map), `reduce` (recognized but not executed) |
| **Scalar kernel language** | `Parameter(usize)`, `ExactInteger(i64)`, `CheckedAdd` — three constructors only |
| **Buffer types** | `I32(Vec<i32>)`, `F32(Vec<u32>)` — 1D contiguous only |
| **f32 restriction** | Only affine offset `x + C` is proven and emitted |
| **GPU admission** | Requires element-wise or reduction shape, pure effect, contiguous buffer, fixed-width integer or f32 domain |
| **Backends** | CPU (reference), CUDA (NVRTC→PTX→launch), wgpu (portable GPU), FPGA (command bridge) |
| **PrimOp** | `Add | Cons | Car | Cdr | Eq | Atom | EqualP` — 7 primitives, closed set |

**What CML is NOT:** CML is not a tensor library. It is a my-lisp compiler
middle-end that lowers 1D element-wise buffer maps to backend-neutral IR,
then emits CUDA C or WGSL for GPU dispatch.

## AlphaZero Inference Operations Matrix

| Operation | CML Status | Evidence | Gap severity |
|---|---|---|---|
| **matmul** (GEMM) | **MISSING** | `compute.rs:168-184` — only Map/Reduce; `PrimOp` (ir.rs:31-39) has no Mul; no 2D buffers | **FOUNDATIONAL** |
| **conv2d** | **MISSING** | No multi-dimensional buffers; no sliding-window semantics; no 2D thread indexing | **FOUNDATIONAL** |
| **relu** | **MISSING** | Scalar expr has no comparison/conditional; only Parameter, ExactInteger, CheckedAdd | **MODERATE** |
| **reduce-sum** | **EXPRESSIBLE** | REDUCE form recognized (`compute.rs:176-182`); binary-add lambda works for i32; but no ExecutionOperation for reduce in graph | **MODERATE** |
| **reduce-max** | **MISSING** | No `Max` in PrimOp or ScalarExpr | **MODERATE** |
| **softmax** | **MISSING** | Requires: reduce-max, exp, reduce-sum, div. None of exp/div/multi-pass exist | **FOUNDATIONAL** |
| **batch-norm-inference** | **MISSING** | Requires: sub, div, sqrt, multi-param kernel. No Sub/Div/Sqrt in scalar expr | **FOUNDATIONAL** |
| **element-wise add** | **IMPLEMENTED** | `compute.rs:287-301`, `gpu_cuda.rs:57-61` | — |
| **element-wise affine (x+C)** | **IMPLEMENTED** | `compute.rs:242-260`, `gpu_cuda.rs:32-34` | — |
| **1D buffer map** | **IMPLEMENTED** | All backends support i32 and affine f32 | — |

## Gap Classification

### FOUNDATIONAL gaps (cannot be bridged incrementally)
These require new IR nodes, new scalar primitives, new kernel signatures,
and new GPU emitter capabilities simultaneously:

1. **Multiplication** — no `Mul` in PrimOp or ScalarExpr. Matmul, conv2d,
   batch-norm, and softmax all require multiplication.
2. **Multi-dimensional buffers** — all buffers are `Vec<T>` (1D). Matmul
   needs 2D, conv2d needs 4D (NCHW).
3. **Multi-input kernels** — current kernels accept exactly one input buffer.
   Matmul needs two. Batch-norm needs five (x, mean, var, scale, bias).
4. **Non-affine f32** — f32 path only handles `x + C`. Everything else
   (exp, div, sqrt, max) needs general f32 lowering.

### MODERATE gaps (can be bridged with focused additions)
1. **relu** — needs one new scalar expr variant (`CheckedMax` or `IfPos`)
   and kernel emitter support for conditional expressions
2. **reduce-sum** — needs `ExecutionOperation::NumericBufferReduce` and
   reduce executor in all backends (analysis already recognizes REDUCE)
3. **reduce-max** — needs `Max` in PrimOp + ScalarExpr + reduce executor

## Minimum Viable Path

### Phase 1: Extend scalar kernel language (CML-only)
Add to `ScalarExpr`:
- `CheckedMul(Box, Box)` — multiplication with overflow check
- `CheckedMax(Box, Box)` — element-wise max (for relu)
- `CheckedSub(Box, Box)` — subtraction with overflow check

Add to `PrimOp`:
- `Mul`, `Sub`, `Max`

This is **CML authority** — no my-lisp language changes needed.

### Phase 2: Multi-input kernel support (CML + tensor descriptor)
Extend `ComputeRegion` to carry multiple input buffer references.
Kernel emitters generate multi-parameter signatures:
```cuda
// Current:   __global__ void cml_map(const int32_t* in, int32_t* out, int n)
// Phase 2:   __global__ void cml_map(const int32_t* a, const int32_t* b, int32_t* out, int n)
```

### Phase 3: 2D buffer support (CML + tensor descriptor)
Add `BufferLiteral::I32_2D(Vec<i32>, usize rows, usize cols)` or,
preferably, keep 1D buffers and add **shape metadata** at the IR level
that kernel emitters use for ND thread indexing.

This is where the tensor descriptor ADR connects: the chess library
creates `(tensor (shape C H W) (layout nchw) (data #f32(...)))`, and
CML reads `(shape ...)` to generate correct thread indexing.

### Phase 4: reduce executor (CML-only)
Add `ExecutionOperation::NumericBufferReduce` and implement parallel
reduction trees in GPU backends. The analysis layer already recognizes
REDUCE — only execution is missing.

### Phase 5: Non-affine f32 (CML)
General f32 scalar expression lowering. This is the hardest single
addition because f32 rounding contracts must be proven for every new
operation (not just affine offset).

## What is NOT in scope

- **Full AlphaZero network** — this ADR does not claim CML can run a
  complete ResNet. That requires kernel fusion, shared memory tiling,
  and potentially custom CUDA kernels beyond what CML's emitter can
  generate.
- **Training** — backpropagation, gradient computation, optimizer steps
  are all out of scope. This ADR covers inference only.
- **FPGA neural kernels** — FPGA is a separate evidence class. The
  bounded FPGA kernel selection task (CHESS-LISP-ZERO-FPGA-KERNEL-SELECTION)
  handles that separately.
- **my-lisp language changes** — all additions are CML-internal. The
  my-lisp `NumericBuffer` contract is not modified.

## Authority Boundaries

| Concern | Owner |
|---|---|
| Scalar kernel language | CML |
| Buffer types and semantics | my-lisp (NumericBuffer) |
| Tensor shape/layout | chess-lisp-zero (library datum) |
| GPU kernel emission | CML |
| Physical GPU execution | Backend (CUDA/wgpu) |
| Neural network architecture | chess-lisp-zero |

CML extends its own IR and emitters. my-lisp provides the backing
NumericBuffer. chess-lisp-zero provides tensor shape metadata.

## Decision

**Design ratified:** CML's current compute model is insufficient for
AlphaZero inference. The gap is foundational (no multiplication, no
multi-dimensional buffers, no multi-input kernels, no non-affine f32).

**Recommended order:**
1. Scalar kernel extensions (Mul, Sub, Max) — smallest change, unblocks relu
2. Multi-input kernels — unblocks matmul decomposition
3. 2D buffer shape metadata — unblocks matmul/conv2d thread indexing
4. Reduce executor — unblocks reduce-sum/max
5. Non-affine f32 — unblocks softmax, batch-norm

**No implementation until:** owner ratifies this design and the tensor
descriptor ADR is proven with fixtures.

## Evidence

- `compute.rs:280-304` — ScalarExpr has exactly 3 constructors
- `ir.rs:31-39` — PrimOp has exactly 7 primitives, no Mul/Sub/Max
- `gpu_cuda.rs:55` — rejects Parameter(_) where index != 0 (single-input only)
- `compute.rs:209-227` — f32 rounding proof only for affine offset
- `execution.rs:31-45` — ExecutionOperation has no Reduce/MatMul/Conv2D
- `compute-contract.my:56` — `automatic-offload absent`
- `compatibility.my:73` — `no-inexact-numbers no-rationals`
