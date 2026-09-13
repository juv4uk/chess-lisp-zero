; tests/full-rules-fen.wsm — FULL-RULES-FEN fixtures (fast tests only)
; Deterministic FEN parse/print, castling, en-passant, promotion.
; Run: my-lisp tests/full-rules-fen.wsm

(load "lib/chess.my")
(load "lib/fen.wsm")

(def assert-eq
  (lambda (label actual expected)
    (cond ((equal? actual expected) (print (list (quote PASS) label actual)))
          (t ((lambda ()
                (print (list (quote FAIL) label actual expected))
                (chess-test-failure label actual expected)))))))

(def assert-fen-roundtrip
  (lambda (name fen)
    (let* ((pos (chess-position-from-fen fen))
           (reconstructed (chess-position-to-fen pos)))
      (cond ((eq fen reconstructed)
             (print (list (quote FEN-ROUNDTRIP) name fen)))
            (t ((lambda ()
                  (print (list (quote FAIL) name "roundtrip" fen reconstructed))
                  (chess-test-failure name fen reconstructed))))))))

;; ============================================================
;; 1. FEN Round-trip Tests (deterministic parse → print → parse)
;; ============================================================

(assert-fen-roundtrip (quote initial)
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")

(assert-fen-roundtrip (quote kiwipete)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1")

(assert-fen-roundtrip (quote position-3)
  "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1")

(assert-fen-roundtrip (quote position-4)
  "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1")

(assert-fen-roundtrip (quote position-5)
  "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8")

(assert-fen-roundtrip (quote position-6)
  "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10")

;; ============================================================
;; 2. Castling Rights Preservation
;; ============================================================

(def initial-pos (chess-initial-position))

(assert-eq (quote initial-castling-rights)
  (chess-position-castling initial-pos)
  (quote (K Q k q)))

;; ============================================================
;; 3. En-passant Target Preservation
;; ============================================================

(def ep-pos
  (chess-position-from-fen
    "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1"))

(assert-eq (quote ep-target-e3)
  (chess-position-ep ep-pos)
  20) ; e3 = square 20

;; ============================================================
;; 4. Halfmove/Fullmove Clock Preservation
;; ============================================================

(def clock-pos
  (chess-position-from-fen
    "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 3 5"))

(assert-eq (quote halfmove-clock)
  (chess-position-halfmove clock-pos)
  3)

(assert-eq (quote fullmove-number)
  (chess-position-fullmove clock-pos)
  5)

;; ============================================================
;; 5. Promotion Move Representation
;; ============================================================

(def promo-move (chess-promotion-move 52 60 (quote q)))
(assert-eq (quote promo-move-from) (chess-move-from promo-move) 52)
(assert-eq (quote promo-move-to) (chess-move-to promo-move) 60)
(assert-eq (quote promo-move-piece) (chess-move-promotion promo-move) (quote q))

(print (quote FULL-RULES-FEN-PASS))