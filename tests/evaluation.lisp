(load "lib/chess.my")
(load "lib/evaluation.wsm")

(def evaluation-assert
  (lambda (name actual expected)
    (cond ((eq actual expected)
           (print (list (quote pass) name actual)))
          (t (print (list (quote fail) name actual expected))))))

; The initial position is materially balanced.
(def evaluation-initial (chess-initial-position))
(evaluation-assert (quote initial-white)
  (chess-material-score evaluation-initial (quote white)) 0)
(evaluation-assert (quote initial-black)
  (chess-material-score evaluation-initial (quote black)) 0)

; A deliberately small fixture makes score direction obvious.
(def evaluation-board (make-vector 64))
(vector-set! evaluation-board 4 (quote wk))
(vector-set! evaluation-board 60 (quote bk))
(vector-set! evaluation-board 3 (quote wq))
(vector-set! evaluation-board 56 (quote br))
(def evaluation-position
  (chess-position evaluation-board (quote white) () () 0 1))

(evaluation-assert (quote white-perspective)
  (chess-material-score evaluation-position (quote white)) 400)
(evaluation-assert (quote black-perspective)
  (chess-material-score evaluation-position (quote black)) -400)
(evaluation-assert (quote empty-square)
  (chess-piece-material ()) 0)
