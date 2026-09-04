; lib/puct.wsm - PUCT/MCTS reference for chess-lisp-zero
; Main loader - loads all PUCT modules in order

(load "lib/puct/nodes.wsm")
(load "lib/puct/selection.wsm")
(load "lib/puct/expansion.wsm")
(load "lib/puct/evaluation.wsm")
(load "lib/puct/backup.wsm")
(load "lib/puct/search.wsm")

;; ============================================================
;; Main entry point
;; ============================================================

(def mcts-move
  (lambda (position num-simulations)
    (best-move (mcts-search position num-simulations default-evaluator 1.414))))

(quote ())
