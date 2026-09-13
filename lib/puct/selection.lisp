; lib/puct/selection.wsm - PUCT selection formula
; Load order: 2 (depends on nodes.wsm)

;; ============================================================
;; PUCT selection formula
;; score = Q + c_puct * P * sqrt(N) / (1 + n)
;; ============================================================

(def puct-score
  (lambda (child parent-visits c-puct)
    (let* ((visits (node-visits child))
           (total-value (node-total-value child))
           (prior (node-prior child))
           (q (cond ((eq visits 0) 0)
                    (t (/ total-value visits))))
           (u (* c-puct prior (sqrt parent-visits) (/ (+ visits 1)))))
      (+ q u))))

;; Select best child according to PUCT.
;; my-lisp has no named let and no set! -- an explicit accumulator-passing
;; recursive helper replaces the loop, same pattern the old monolithic
;; lib/puct.wsm used for puct-select-best-from.
(def select-child-from
  (lambda (remaining parent-visits c-puct best-child best-score)
    (cond ((atom remaining) best-child)
          (t (let* ((child (cdr (car remaining)))
                    (score (puct-score child parent-visits c-puct)))
               (cond ((> score best-score)
                      (select-child-from (cdr remaining) parent-visits c-puct child score))
                     (t (select-child-from (cdr remaining) parent-visits c-puct best-child best-score))))))))

(def select-child
  (lambda (node c-puct)
    (select-child-from (node-children node) (node-visits node) c-puct (quote ()) -999999)))

(quote ())
