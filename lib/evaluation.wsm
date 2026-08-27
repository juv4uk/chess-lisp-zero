; Original deterministic chess evaluation for chess-lisp-zero.
; Positive values favor White; perspective conversion happens at the edge.

(def chess-piece-material
  (lambda (piece)
    (cond ((eq piece (quote wp)) 100)
          ((eq piece (quote wn)) 320)
          ((eq piece (quote wb)) 330)
          ((eq piece (quote wr)) 500)
          ((eq piece (quote wq)) 900)
          ((eq piece (quote wk)) 0)
          ((eq piece (quote bp)) -100)
          ((eq piece (quote bn)) -320)
          ((eq piece (quote bb)) -330)
          ((eq piece (quote br)) -500)
          ((eq piece (quote bq)) -900)
          ((eq piece (quote bk)) 0)
          (t 0))))

(def chess-material-board-score-from
  (lambda (board square total)
    (cond ((eq square 64) total)
          (t (chess-material-board-score-from
               board
               (+ square 1)
               (+ total (chess-piece-material (vector-ref board square))))))))

(def chess-material-board-score
  (lambda (board)
    (chess-material-board-score-from board 0 0)))

(def chess-material-score
  (lambda (position perspective)
    (let ((white-score (chess-material-board-score
                         (chess-position-board position))))
      (cond ((eq perspective (quote white)) white-score)
            ((eq perspective (quote black)) (- 0 white-score))
            (t white-score)))))
