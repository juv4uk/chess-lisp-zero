; lib/puct/nodes.wsm - Node structure and accessors
; Load order: 1
;
; Nodes are mutable vectors (my-lisp's own supported mutation primitive --
; vector-set!/vector-ref -- not `set!` on lexical bindings, which my-lisp
; does not have). Field layout mirrors the old monolithic lib/puct.wsm's
; own vector-based node, extended with the parent/expanded? fields this
; module split introduces.

(def node-visits-field 0)
(def node-total-value-field 1)
(def node-children-field 2)
(def node-move-field 3)
(def node-prior-field 4)
(def node-position-field 5)
(def node-expanded-field 6)
(def node-parent-field 7)

(def make-node
  (lambda (position move prior parent)
    (let ((node (make-vector 8)))
      ((lambda ()
        (vector-set! node node-visits-field 0)
        (vector-set! node node-total-value-field 0)
        (vector-set! node node-children-field (quote ()))
        (vector-set! node node-move-field move)
        (vector-set! node node-prior-field prior)
        (vector-set! node node-position-field position)
        (vector-set! node node-expanded-field (quote ()))
        (vector-set! node node-parent-field parent)
        node)))))

(def node-visits (lambda (node) (vector-ref node node-visits-field)))
(def node-total-value (lambda (node) (vector-ref node node-total-value-field)))
(def node-children (lambda (node) (vector-ref node node-children-field)))
(def node-move (lambda (node) (vector-ref node node-move-field)))
(def node-prior (lambda (node) (vector-ref node node-prior-field)))
(def node-position (lambda (node) (vector-ref node node-position-field)))
(def node-expanded? (lambda (node) (vector-ref node node-expanded-field)))
(def node-parent (lambda (node) (vector-ref node node-parent-field)))

(def node-set-visits! (lambda (node value) (vector-set! node node-visits-field value)))
(def node-set-total-value! (lambda (node value) (vector-set! node node-total-value-field value)))
(def node-set-children! (lambda (node value) (vector-set! node node-children-field value)))
(def node-set-expanded! (lambda (node) (vector-set! node node-expanded-field (quote t))))

(quote ())
