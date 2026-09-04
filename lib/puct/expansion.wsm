; lib/puct/expansion.wsm - Node expansion
; Load order: 3 (depends on nodes.wsm, selection.wsm)

;; ============================================================
;; Expansion
;; ============================================================

;; Default uniform prior for each legal move
(def uniform-prior
  (lambda (moves)
    (let ((n (length moves)))
      (cond ((eq n 0) 0)
            (t (/ 1.0 n))))))

;; Expand node with legal moves
(def expand-node
  (lambda (node)
    (let* ((pos (node-position node))
           (moves (chess-legal-moves pos))
           (prior-value (uniform-prior moves))
           (children (map (lambda (move)
                            (let ((child-pos (chess-apply-move pos move)))
                              (cons move (make-node child-pos move prior-value node))))
                          moves)))
      ((lambda ()
        (node-set-children! node children)
        (node-set-expanded! node)
        moves)))))

(quote ())
