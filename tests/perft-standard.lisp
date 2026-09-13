(load "lib/chess.my")
(load "lib/fen.wsm")

; Published reference positions from Chess Programming Wiki, Perft Results.
; Depths 1 and 2 form a bounded semantic gate for special-rule generation and
; state transitions; deeper start-position coverage remains in tests/perft.my.
(def standard-perft-assert
  (lambda (name fen depth expected)
    (let ((actual (chess-perft (chess-position-from-fen fen) depth)))
      (cond ((eq actual expected)
             (print (list (quote pass) name actual)))
            (t ((lambda ()
                  (print (list (quote fail) name actual expected))
                  (chess-test-failure name actual expected))))))))

(standard-perft-assert
  (quote kiwipete-depth-1)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
  1
  48)

(standard-perft-assert
  (quote kiwipete-depth-2)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1"
  2
  2039)

(standard-perft-assert
  (quote position-3-depth-1)
  "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
  1
  14)

(standard-perft-assert
  (quote position-3-depth-2)
  "8/2p5/3p4/KP5r/1R3p1k/8/4P1P1/8 w - - 0 1"
  2
  191)

(print (quote CHESS-STANDARD-PERFT-PASS))
