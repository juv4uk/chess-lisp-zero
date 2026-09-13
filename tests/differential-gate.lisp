(load "lib/chess.my")
(load "lib/fen.wsm")

; ============================================================================
; CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL — normalized differential gate.
;
; Source: Chess Programming Wiki, "Perft Results":
;     https://www.chessprogramming.org/Perft_Results   (accessed 2026-08-29)
; Expected node counts below are transcribed verbatim from that page.
; Every fixture is asserted twice:
;   1. perft depth d == published count
;   2. FEN -> position -> FEN round-trip stability
; legal-move count at depth 1 equals the published count directly.
;
; Failure convention (matches tests/perft.my, tests/fen.wsm,
; tests/perft-standard.wsm): on mismatch, print (fail ...) then call the
; intentionally-undefined `chess-test-failure`, which errors the process and
; yields a non-zero exit. NOTE found while building this gate:
; `chess-test-failure` has NO definitions anywhere in this repo — sibling
; tests share the same latent dependency. Flagged in
; docs/CHESSJS-DIFFERENTIAL-GATE.md; recommend one central definition.
; ============================================================================

(def differential-gate-assert
  (lambda (name actual expected)
    (cond ((equal? actual expected)
           (print (list (quote pass) name actual)))
          (t ((lambda ()
                (print (list (quote fail) name actual expected))
                (chess-test-failure name actual expected)))))))

(def differential-fen-roundtrip
  (lambda (name fen)
    (differential-gate-assert
      (list (quote fen-roundtrip) name)
      (chess-position-to-fen (chess-position-from-fen fen))
      fen)))

(def differential-position
  (lambda (name fen depth published)
    (differential-fen-roundtrip name fen)
    (differential-gate-assert
      (list (quote perft) name (quote depth) depth)
      (chess-perft (chess-position-from-fen fen) depth)
      published)))

; --- Initial position -------------------------------------------------------
; full FEN as published; counts: d1=20, d2=400, d3=8,902 (d3 asserted in
; tests/perft.my and verified per-root in docs/PERFT-VERIFY.md).
(differential-position
  (quote initial) "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 1 20)
(differential-position
  (quote initial) "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 2 400)

; --- Position 2 (Kiwipete, Peter McKenzie) ----------------------------------
; published FEN header omits move counters; standard full FEN used here.
; counts: d1=48, d2=2,039, d3=97,862.
(differential-position
  (quote kiwipete) "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" 1 48)
(differential-position
  (quote kiwipete) "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" 2 2039)

; --- Position 3 -------------------------------------------------------------
; counts: d1=14, d2=191, d3=2,812.
(differential-position
  (quote position-3) "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1" 1 14)
(differential-position
  (quote position-3) "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1" 2 191)

; --- Position 4 (mirror has identical counts) -------------------------------
; counts: d1=6, d2=264, d3=9,467.
(differential-position
  (quote position-4) "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1" 1 6)
(differential-position
  (quote position-4) "r3k2r/Pppp1ppp/1b3nbN/nP6/BBP1P3/q4N2/Pp1P2PP/R2Q1RK1 w kq - 0 1" 2 264)

; --- Position 5 -------------------------------------------------------------
; counts: d1=44, d2=1,486, d3=62,379.
(differential-position
  (quote position-5) "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8" 1 44)
(differential-position
  (quote position-5) "rnbq1k1r/pp1Pbppp/2p5/8/2B5/8/PPP1NnPP/RNBQK2R w KQ - 1 8" 2 1486)

; --- Position 6 -------------------------------------------------------------
; counts: d1=46, d2=2,079, d3=89,890.
(differential-position
  (quote position-6) "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10" 1 46)
(differential-position
  (quote position-6) "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10" 2 2079)

(print (quote CHESS-DIFFERENTIAL-GATE-PASS))