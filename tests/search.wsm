(load "lib/chess.my")
(load "lib/evaluation.wsm")
(load "lib/search.wsm")

(def search-assert
  (lambda (name actual expected)
    (cond ((equal? actual expected)
           (print (list (quote pass) name actual)))
          (t (print (list (quote fail) name actual expected))))))

; White rook on a2 can capture the black queen on a3. At depth one this is
; the unique material-best move; kings keep the fixture legally grounded.
(def search-board (make-vector 64))
(vector-set! search-board 4 (quote wk))
(vector-set! search-board 60 (quote bk))
(vector-set! search-board 8 (quote wr))
(vector-set! search-board 16 (quote bq))
(def search-position
  (chess-position search-board (quote white) () () 0 1))
(def search-result (chess-best-move search-position 1))

(search-assert (quote best-capture) (car search-result) (chess-move 8 16))
(search-assert (quote best-score) (second search-result) 500)

; Terminal scores are explicit and separate from the material evaluator.
(def search-mate-board (make-vector 64))
(vector-set! search-mate-board 56 (quote bk))
(vector-set! search-mate-board 49 (quote wq))
(vector-set! search-mate-board 42 (quote wk))
(search-assert (quote checkmated-side-score)
  (chess-search-score
    (chess-position search-mate-board (quote black) () () 0 1)
    1
    (quote black))
  -100000)
