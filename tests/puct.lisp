(load "lib/chess.my")
(load "lib/evaluation.wsm")
(load "lib/puct.wsm")

(def puct-assert
  (lambda (name condition)
    (cond (condition (print (list name (quote PASS))))
          (t ((lambda ()
                (print (list name (quote FAIL)))
                (car chess-empty)))))))

; Fixed-tree selection: unvisited high-prior child wins exploration score.
(def fixture-root (puct-node chess-empty chess-empty 1))
(def fixture-a (puct-node chess-empty (chess-move 0 1) (/ 1 4)))
(def fixture-b (puct-node chess-empty (chess-move 0 8) (/ 3 4)))
(vector-set! fixture-root puct-visits-field 4)
(vector-set! fixture-a puct-visits-field 2)
(vector-set! fixture-a puct-value-sum-field 1)
(vector-set! fixture-root puct-children-field (list fixture-a fixture-b))
(puct-assert (quote selection-formula) (eq (puct-select-best fixture-root 1) fixture-b))

; Alternating backup: leaf value is seen with opposite sign at its parent.
(puct-backup! (list fixture-b fixture-root) 1)
(puct-assert (quote leaf-backup-visits) (= (puct-visits fixture-b) 1))
(puct-assert (quote leaf-backup-value) (= (puct-value-sum fixture-b) 1))
(puct-assert (quote root-backup-sign) (= (puct-value-sum fixture-root) -1))

; Real chess integration: legal children and normalized visit policy.
(def chess-root (puct-run (chess-initial-position) 25 1 puct-material-evaluator))
(puct-assert (quote root-visits) (= (puct-visits chess-root) 25))
(puct-assert (quote legal-child-count) (= (length (puct-children chess-root)) 20))
(puct-assert (quote best-is-legal)
  (let ((best (puct-best-move chess-root)))
    (member? best (chess-legal-moves (chess-initial-position)))))
(puct-assert (quote temperature-one-normalizes)
  (= (puct-policy-total-visits (puct-children chess-root) 0) 24))

; External policy weights are aligned with authoritative legal-move order,
; normalized inside PUCT and influence selection.  The provider is deliberately
; plain WSM: a neural process adapter can supply the same list later.
(def preferred-move (chess-move 1 18))
(def preferred-weights
  (lambda (moves)
    (cond ((atom moves) (quote ()))
          (t (cons (cond ((equal? (car moves) preferred-move) 9) (t 1))
               (preferred-weights (cdr moves)))))))
(def preferred-provider
  (lambda (position moves) (preferred-weights moves)))
(def prior-root (puct-node (chess-initial-position) chess-empty 1))
(def prior-children (puct-expand-with-priors! prior-root preferred-provider))
(vector-set! prior-root puct-visits-field 1)
(puct-assert (quote injected-priors-normalize)
  (= (puct-prior-weight-total
       (map (lambda (child) (puct-prior child)) prior-children) 0) 1))
(puct-assert (quote injected-prior-guides-selection)
  (equal? (puct-move (puct-select-best prior-root 1)) preferred-move))
(def injected-run
  (puct-run-with-priors (chess-initial-position) 2 1
    puct-material-evaluator preferred-provider))
(puct-assert (quote injected-run-public-api)
  (equal? (puct-best-move injected-run) preferred-move))

; Compatibility boundary: the original expansion remains exactly uniform.
(def uniform-root (puct-node (chess-initial-position) chess-empty 1))
(def uniform-children (puct-expand! uniform-root))
(puct-assert (quote default-prior-remains-uniform)
  (= (puct-prior (car uniform-children)) (/ 1 20)))

; Injected material evaluator guides a real tree toward the unique queen
; capture, while legality and state transitions remain owned by chess.my.
(def capture-board (make-vector 64))
(vector-set! capture-board 4 (quote wk))
(vector-set! capture-board 60 (quote bk))
(vector-set! capture-board 8 (quote wr))
(vector-set! capture-board 16 (quote bq))
(def capture-root
  (puct-run (chess-position capture-board (quote white)
              chess-empty chess-empty 0 1)
    48 1 puct-material-evaluator))
(puct-assert (quote evaluator-guided-capture)
  (equal? (puct-best-move capture-root) (chess-move 8 16)))

; Terminal outcome is always from the leaf side-to-move perspective.
(def mate-board (make-vector 64))
(vector-set! mate-board 56 (quote bk))
(vector-set! mate-board 49 (quote wq))
(vector-set! mate-board 42 (quote wk))
(puct-assert (quote terminal-checkmate-value)
  (= (puct-terminal-value
       (chess-position mate-board (quote black) chess-empty chess-empty 0 1)) -1))

(print (quote CHESS-PUCT-PASS))
