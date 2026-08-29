# ADR: Policy Plane and Labels ML Boundary Contract

## 1. Context and Motivation

The `chess-lisp-zero` system integrates a semantic core in `my-lisp` (and WebAssembly) with PyTorch ML models. To avoid historical Python code or opaque neural network implementations becoming the source of truth, we must ratify an implementation-independent ML boundary.

This ADR defines the exact canonical input planes (18x8x8), side-to-move normalization, and deterministic UCI policy labels (1968 total) that constitute the semantic contract for all downstream backends (CML, PyTorch, CUDA, FPGA).

## 2. Decision: Side-to-Move Normalization

All inputs and policy outputs are evaluated from the perspective of the **side to move**.
* For Black, the board is vertically flipped (rank 1 becomes rank 8, rank 2 becomes rank 7, etc.).
* Consequently, a Black pawn moving from `e7` to `e5` is represented identically to a White pawn moving from `e2` to `e4`.

## 3. Input Planes Contract (18x8x8)

The input to the neural network is an 18x8x8 tensor (18 planes of 64 squares each, conceptually a 1152-element flattened vector).

The 18 planes are structurally defined as follows:

| Plane Index | Content (from side-to-move perspective) |
|-------------|-----------------------------------------|
| 0           | Own Pawns                               |
| 1           | Own Knights                             |
| 2           | Own Bishops                             |
| 3           | Own Rooks                               |
| 4           | Own Queens                              |
| 5           | Own King                                |
| 6           | Opponent Pawns                          |
| 7           | Opponent Knights                        |
| 8           | Opponent Bishops                        |
| 9           | Opponent Rooks                          |
| 10          | Opponent Queens                         |
| 11          | Opponent King                           |
| 12          | Own Kingside Castling Rights (all 1s if true, else 0) |
| 13          | Own Queenside Castling Rights           |
| 14          | Opponent Kingside Castling Rights       |
| 15          | Opponent Queenside Castling Rights      |
| 16          | En Passant Target Square (1 at the valid target square, else 0) |
| 17          | Side-to-move witness (all 1s if White, all 0s if Black) |

## 4. Policy Labels Contract (1968)

The neural network outputs a policy vector of 1968 logits, representing every possible geometric move from the perspective of the current side.

### 4.1. Base Labels (1792)
There are 1792 pseudo-legal geometric moves (non-promoting) on a chessboard. These correspond to all valid queen and knight moves from all 64 squares.
They are generated in deterministic order (lexicographically: `a1b1`, `a1c1`, etc.).

### 4.2. Promotion Labels (176)
There are 176 possible promotion moves. 
A promotion move occurs from rank 7 to rank 8 (88 moves) and from rank 2 to rank 1 (88 moves, used for symmetric mapping/flipping).
Each square on rank 7 can move straight or capture diagonally, generating 22 geometric paths. Multiplied by 4 promotion pieces (`q`, `r`, `b`, `n`), this gives 88 promotion moves for one side, and 88 for the other, totaling 176.

Total Policy Labels = 1792 + 176 = 1968.

## 5. Round-trip and Differential Checks

All downstream ML implementations (e.g., PyTorch inference in Tauri, CML offloading to CUDA, or FPGA logic) MUST NOT recreate the chess logic. They must rely on the exported fixtures derived from `my-lisp` (the semantic authority).

Fixtures (like `self-play-replay-fix.my`) provide a FEN, the resulting 1152-element flat vector, and the deterministic policy labels. Any ML backend MUST bit-exactly reproduce the same flattening and indexing behavior or consume the data blindly.

Historical Python data-loaders are consumers, not authorities.
