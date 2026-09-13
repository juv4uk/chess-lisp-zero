; lib/puct/search.wsm - MCTS search
; Load order: 6 (depends on nodes.wsm, selection.wsm, expansion.wsm, evaluation.wsm, backup.wsm)

;; ============================================================
;; MCTS Search
;; ============================================================

(def mcts-search-loop
  (lambda (root i num-simulations evaluator c-puct)
    (cond ((>= i num-simulations) root)
          (t ((lambda ()
                (simulate root evaluator c-puct)
                (mcts-search-loop root (+ i 1) num-simulations evaluator c-puct)))))))

(def mcts-search
  (lambda (root-position num-simulations evaluator c-puct)
    (let ((root (make-node root-position (quote ()) 1.0 (quote ()))))
      (mcts-search-loop root 0 num-simulations evaluator c-puct))))

;; Single simulation: select -> expand -> evaluate -> backup
(def simulate
  (lambda (node evaluator c-puct)
    (cond
      ;; Terminal node
      ((not (eq (chess-terminal-state (node-position node)) (quote ongoing)))
       (backup! node (evaluator (node-position node))))
      ;; Not expanded -> expand, then evaluate this node's own position
      ;; (whether or not expansion produced moves -- both cases evaluate
      ;; and back up the same way, so no separate branch is needed here)
      ((eq (node-expanded? node) (quote ()))
       ((lambda ()
          (expand-node node)
          (backup! node (evaluator (node-position node))))))
      ;; Has children -> select best and recurse
      (t (let ((child (select-child node c-puct)))
           (cond ((atom child) ; no children
                  (backup! node (evaluator (node-position node))))
                 (t (simulate child evaluator c-puct))))))))

;; ============================================================
;; Get best move from root after search
;; ============================================================
;; my-lisp has no named let and no set! -- an explicit accumulator-passing
;; recursive helper replaces the loop, same pattern as select-child-from.

(def best-move-from
  (lambda (remaining best-move best-visits)
    (cond ((atom remaining) best-move)
          (t (let* ((child (cdr (car remaining)))
                    (visits (node-visits child)))
               (cond ((> visits best-visits)
                      (best-move-from (cdr remaining) (node-move child) visits))
                     (t (best-move-from (cdr remaining) best-move best-visits))))))))

(def best-move
  (lambda (root)
    (best-move-from (node-children root) (quote ()) -1)))

(quote ())
