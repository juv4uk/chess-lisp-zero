(load "lib/chess.my")

(def assert-eq
  (lambda (label actual expected)
    (cond ((eq actual expected) (print (list (quote PASS) label actual)))
          (t ((lambda ()
                (print (list (quote FAIL) label actual expected))
                (chess-test-failure label actual expected)))))))

(def initial (chess-initial-position))
(assert-eq (quote initial-legal-moves) (length (chess-legal-moves initial)) 20)
(assert-eq (quote perft-depth-1) (chess-perft initial 1) 20)
(assert-eq (quote perft-depth-2) (chess-perft initial 2) 400)
(assert-eq (quote perft-depth-3) (chess-perft initial 3) 8902)
(assert-eq (quote initial-terminal-state) (chess-terminal-state initial) (quote ongoing))
(assert-eq (quote board-restored-a1)
  (vector-ref (chess-position-board initial) 0) (quote wr))
(assert-eq (quote board-restored-e2)
  (vector-ref (chess-position-board initial) 12) (quote wp))

(def mate-board (make-vector 64))
(vector-set! mate-board 56 (quote bk))
(vector-set! mate-board 49 (quote wq))
(vector-set! mate-board 42 (quote wk))
(assert-eq (quote terminal-checkmate)
  (chess-terminal-state
    (chess-position mate-board (quote black) (quote ()) (quote ()) 0 1))
  (quote checkmate))

(def stale-board (make-vector 64))
(vector-set! stale-board 56 (quote bk))
(vector-set! stale-board 41 (quote wq))
(vector-set! stale-board 42 (quote wk))
(assert-eq (quote terminal-stalemate)
  (chess-terminal-state
    (chess-position stale-board (quote black) (quote ()) (quote ()) 0 1))
  (quote stalemate))
(print (quote CHESS-PERFT-PASS))
