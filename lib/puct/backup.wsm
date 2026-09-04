; lib/puct/backup.wsm - Backup propagation
; Load order: 5 (depends on nodes.wsm, evaluation.wsm)

;; ============================================================
;; Backup
;; ============================================================
;; Value is negated at each step up the path: each node's value_sum is
;; from that node's own side-to-move perspective, so a parent's gain is
;; its child's loss (same invariant the old monolithic lib/puct.wsm's
;; puct-backup! documented and implemented).

(def backup!
  (lambda (node value)
    ((lambda ()
      (node-set-visits! node (+ (node-visits node) 1))
      (node-set-total-value! node (+ (node-total-value node) value))
      (let ((parent (node-parent node)))
        (cond ((atom parent) (quote ())) ; root has no parent
              (t (backup! parent (- 0 value)))))))))

(quote ())
