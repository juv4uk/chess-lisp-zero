; Deterministic depth-limited minimax for chess-lisp-zero.
; This is a correctness baseline, not a claim about playing strength.

(def chess-search-mate-score 100000)

(def chess-search-terminal-score
  (lambda (position perspective)
    (cond ((chess-in-check? (chess-position-board position)
                            (chess-position-side position))
           (cond ((eq (chess-position-side position) perspective)
                  (- 0 chess-search-mate-score))
                 (t chess-search-mate-score)))
          (t 0))))

(def chess-search-score-moves
  (lambda (position moves depth perspective maximize best seen)
    (cond ((atom moves) best)
          (t (let* ((next-position (chess-apply-move position (car moves)))
                    (score (chess-search-score next-position
                             (- depth 1) perspective))
                    (next-best
                      (cond ((not seen) score)
                            (maximize (cond ((> score best) score) (t best)))
                            (t (cond ((< score best) score) (t best))))))
               (chess-search-score-moves position (cdr moves) depth
                 perspective maximize next-best t))))))

(def chess-search-score
  (lambda (position depth perspective)
    (let ((moves (chess-legal-moves position)))
      (cond ((atom moves) (chess-search-terminal-score position perspective))
            ((eq depth 0) (chess-material-score position perspective))
            (t (chess-search-score-moves position moves depth perspective
                 (eq (chess-position-side position) perspective) 0
                 (quote ())))))))

(def chess-search-better?
  (lambda (seen score best-score)
    (cond ((not seen) t)
          ((> score best-score) t)
          (t (quote ())))))

(def chess-best-move-from
  (lambda (position moves depth perspective best-move best-score seen)
    (cond ((atom moves) (list best-move best-score))
          (t (let* ((move (car moves))
                    (score (chess-search-score
                             (chess-apply-move position move)
                             (- depth 1) perspective)))
               (cond ((chess-search-better? seen score best-score)
                      (chess-best-move-from position (cdr moves) depth
                        perspective move score t))
                     (t (chess-best-move-from position (cdr moves) depth
                          perspective best-move best-score t))))))))

(def chess-best-move
  (lambda (position depth)
    (let ((moves (chess-legal-moves position))
          (perspective (chess-position-side position)))
      (cond ((atom moves)
             (list (quote ())
               (chess-search-terminal-score position perspective)))
            (t (chess-best-move-from position moves depth perspective
                 (quote ()) 0 (quote ())))))))
