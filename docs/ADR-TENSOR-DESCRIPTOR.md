# ADR: Library-Level Tensor Descriptor

**Status:** PROPOSED
**Date:** 2026-08-27
**Task:** CHESS-LISP-ZERO-TENSOR-DESCRIPTOR-ADR
**Author:** Vyasa (compiler steward)

---

## Context

The chess-lisp-zero architecture requires multi-dimensional tensor operations
(matmul, conv2d, reductions) for AlphaZero inference. The current runtime
provides `NumericBuffer` — a flat, homogeneous, immutable array of i32 or
f32 elements — and CML's compute analysis recognizes only flat buffer
operations (`numeric-buffer-map` with element-wise or reduction shape).

Neither my-lisp nor CML currently represents shape, layout, or semantic
channel meaning. This ADR specifies a **library-level tensor descriptor**
that layers that information on top of the ratified `NumericBuffer`,
without modifying the language contract or CML compute primitives.

## Decision

Define a tensor as a **library-level Lisp datum** — a list containing a
shape, layout, channel description, and a reference to an existing
`NumericBuffer`. This is data, not a new runtime type.

### 1. Tensor descriptor shape

```lisp
(tensor
  (shape C H W)          ; exact positive integers, row-major dimension order
  (layout nchw)          ; symbolic layout tag
  (channels.input  18)   ; channel semantics: plane-stack count for input
  (channels.output 1)    ; channel semantics: policy/value head
  (data #f32(...)))      ; the backing NumericBuffer (ratified type)
```

**Fields:**

| Field | Type | Description |
|---|---|---|
| `shape` | list of exact positive integers | Dimension sizes. Length = rank. Product must equal `numeric-buffer-length` of data. |
| `layout` | symbol | Memory layout tag. Recognized values: `nchw`, `nhwc`, `chw`, `hw`, `flat`. Custom tags permitted but must be declared to CML for compute analysis. |
| `channels.*` | symbol -> integer | Semantic meaning of each axis. Prefixed by domain. `chess-lisp-zero` owns `channels.input`, `channels.output`, `channels planes`, etc. CML owns nothing here — channel meaning is chess-domain, not compute-domain. |
| `data` | `NumericBuffer` | The backing storage. Must be a ratified `#i32(...)` or `#f32(...)` value. |

### 2. Rank constraints

| Rank | Typical use | Backing buffer size |
|---|---|---|
| 1 | Vector | N |
| 2 | Matrix | N × M |
| 3 | Single batch image: C × H × W | C × H × W |
| 4 | Batched: N × C × H × W | N × C × H × W |

Maximum rank for initial implementation: **4**. Higher ranks require
separate evidence.

### 3. Layout semantics

`layout` is an **advisory tag**, not a reordering guarantee. The data
in `data` is always stored in the order implied by `shape` read
left-to-right. For `nchw` with shape `(3 8 8)`, element `(c, h, w)`
is at offset `c * 64 + h * 8 + w`.

Layout tags are meaningful for:
- CML compute analysis: choosing kernel dispatch order
- FPGA memory planning: selecting transpose or padding strategy
- Human debugging: understanding buffer intent

**Rule:** A library function MUST NOT reorder data based on layout tags.
Layout is metadata, not an instruction to the runtime.

### 4. Channel semantics

Channel descriptions are **domain-owned strings** with integer values:

```lisp
(channels.input 18)     ; chess-lisp-zero owns: 18-plane stack
(channels.output 1)     ; chess-lisp-zero owns: policy or value head
(channels spatial 8)    ; chess-lisp-zero owns: spatial dimension
```

Channel names are not computed on. They exist for:
- CML graph documentation
- Human inspection
- Fixture validation (shape product must be consistent)

**Authority:** `chess-lisp-zero` defines channel names for chess.
`my-lisp` does not interpret them. `CML` reads them for documentation
but does not dispatch on them.

### 5. Authority boundaries

```
chess-lisp-zero                my-lisp                    CML
   |                              |                         |
   |  defines channel names       |                         |
   |  defines shape for fixtures  |                         |
   |  creates tensors as data     |                         |
   |                              |                         |
   +---- tensor descriptor ------->+---- NumericBuffer ----->+
        (library datum)             (runtime type)            |
                                                              |
                                   computes shape product     |
                                   validates data length      |
                                                              |
                                                         CML reads
                                                         descriptor
                                                         for analysis
```

| Concern | Owner | What they do |
|---|---|---|
| Channel meaning | chess-lisp-zero | Defines what planes/axes represent |
| Shape/layout | chess-lisp-zero | Defines tensor dimensions for fixtures |
| Tensor construction | chess-lisp-zero | `(tensor ...)` is library code in `lib/chess/tensor.my` |
| `NumericBuffer` semantics | my-lisp | What `#f32(...)` means, how `numeric-buffer-map` works |
| Shape validation | chess-lisp-zero | `(tensor-shape-validate t)` checks product == buffer length |
| Compute admission | CML | Reads shape/layout to classify execution shape |
| Physical execution | Backend | CUDA/FPGA/CPU dispatch |

### 6. No first-class Tensor in language contract

The tensor descriptor is **not** a new `Value` variant. It is a plain
Lisp list constructed by library code. This means:

- `tensor?` is a library predicate (checks list structure), not a
  runtime type predicate
- `tensor-data` extracts the `NumericBuffer` from the descriptor
- No new Rust code is needed in my-lisp
- No new CML IR nodes are needed
- The CML execution graph continues to operate on `BufferLiteral`

**When to promote to first-class:** Only after evidence that:
1. The library predicate is performance-critical in a measured hot path
2. CML compute analysis needs to pattern-match on tensor metadata
3. The chess rules library grows past 5 tensor operations that benefit
   from type-level dispatch

### 7. CML integration path

CML does not currently see tensor descriptors — it sees the backing
`NumericBuffer` after chess library code extracts it. The path is:

```lisp
; chess library creates a tensor
(define t (tensor (shape 18 8 8) (layout nchw) (data weights)))

; chess library extracts the buffer for CML
(numeric-buffer-map some-kernel (tensor-data t))
```

CML's compute analysis sees `(numeric-buffer-map some-kernel buffer)`
exactly as it does today. The tensor descriptor adds context for the
chess domain without altering the CML admission surface.

**Future CML extension (not in this ADR):** CML could learn to read
a `(shape ...)` annotation on buffer inputs to enable multi-dimensional
kernels. This would be a separate CML ADR with its own evidence
requirements.

### 8. Validation library functions

The chess library provides validation, not the language runtime:

```lisp
; Validates that shape product matches buffer length
(define (tensor-shape-validate t)
  (let ((shape (tensor-shape t))
        (buf   (tensor-data t)))
    (= (apply * shape)
       (numeric-buffer-length buf))))

; Returns the total element count from shape
(define (tensor-size t)
  (apply * (tensor-shape t)))

; Returns element offset for (c, h, w) indexing in nchw layout
(define (tensor-nchw-offset t c h w)
  (let ((shape (tensor-shape t)))
    (+ (* c (nth shape 1) (nth shape 2))
       (* h (nth shape 2))
       w)))
```

### 9. AlphaZero input planes

The initial AlphaZero input has 18 planes of 8×8, encoded as:

```lisp
(define initial-input
  (tensor
    (shape 18 8 8)
    (layout nchw)
    (channels.input 18)
    (data (f32-buffer ...1152-elements...))))
```

The 18 planes represent:
- 6 piece types × 2 colors = 12 planes
- Castling rights = 4 planes
- En-passant = 1 plane
- Side to move = 1 plane

This encoding is chess-lisp-zero's responsibility, not my-lisp's or CML's.

## Consequences

### Positive
- No language contract changes needed
- No new Rust code in my-lisp
- No new CML IR nodes
- Authority boundaries are explicit and documented
- Library validation is testable in `.my` tests
- Tensor metadata is inspectable as plain Lisp data

### Negative
- No type-level distinction between a tensor and an arbitrary list
  (mitigated by convention and library predicates)
- CML cannot currently dispatch on tensor shape (mitigated by
  extracting `tensor-data` before passing to `numeric-buffer-map`)
- Layout tags are advisory only — no automatic transpose

### Risks
- If tensor operations grow complex, the library predicate approach
  may become unwieldy. Promotion to first-class should be considered
  when more than 5 tensor operations exist.

## Evidence

- `NumericBuffer` ratified at contract 3.0 (my-lisp HEAD)
- CML compute analysis recognizes `numeric-buffer-map` as the only
  buffer operation (CML compute-contract.my)
- Architecture research verified 64-element vectors, `numeric-buffer-map`,
  `i32-buffer`, `f32-buffer` work in my-lisp v0.32.0
- No bit-and/shift-left/popcount available yet (per architecture doc §5)
- Tensor descriptor requires zero new primitives

## Status

This ADR is PROPOSED. It requires:
1. Owner review and ratification
2. Implementation of `lib/chess/tensor.my` with validation
3. At least one fixture test proving shape validation works
4. CML team review of the authority boundary (no code changes needed)
