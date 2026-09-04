; lib/puct/evaluation.wsm - Position evaluation
; Load order: 4 (depends on nodes.wsm)

;; ============================================================
;; Evaluation
;; ============================================================

;; Default evaluator: material + simple heuristics
(def default-evaluator
  (lambda (position)
    (let ((terminal (chess-terminal-state position)))
      (cond ((eq terminal (quote checkmate))
             (cond ((eq (chess-position-side position) (quote white))
                    -1.0)
                   (t 1.0)))
            ((eq terminal (quote stalemate)) 0.0)
            (t
             ;; Simple material evaluation
             (let ((board (chess-position-board position))
                   (side (chess-position-side position)))
               (material-balance board side)))))))

;; Material balance from perspective of side
(def material-balance
  (lambda (board side)
    (let ((white-score (board-material board (quote white)))
          (black-score (board-material board (quote black))))
      (cond ((eq side (quote white))
             (- white-score black-score))
            (t
             (- black-score white-score))))))

;; my-lisp has no named let -- board-material-loop/count-pieces-loop are
;; explicit accumulator-passing recursive helpers instead.
(def board-material-loop
  (lambda (board remaining total)
    (cond ((atom remaining) total)
          (t (board-material-loop board (cdr remaining)
               (+ total (count-pieces board (car remaining))))))))

;; Material score for one color
(def board-material
  (lambda (board color)
    (let ((pieces (cond ((eq color (quote white))
                         (quote (wp wn wb wr wq wk)))
                        (t
                         (quote (bp bn bb br bq bk))))))
      (board-material-loop board pieces 0))))

(def count-pieces-loop
  (lambda (board piece i count)
    (cond ((eq i 64) count)
          (t (count-pieces-loop board piece (+ i 1)
               (cond ((eq (vector-ref board i) piece)
                      (+ count 1))
                     (t count)))))))

(def count-pieces
  (lambda (board piece)
    (count-pieces-loop board piece 0 0)))

(quote ())
