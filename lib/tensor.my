; tensor.my - library-level tensor descriptor over NumericBuffer.
; This is DATA, not a new runtime type.
; Authority: chess-lisp-zero owns channel meaning and shape.
; my-lisp owns NumericBuffer semantics.
; CML reads descriptor for compute analysis (future ADR).
;
; Structure: (tensor (shape C H W) (layout nchw) (channels ...) (data #f32(...)))
; Each field is a tagged pair: (tag value). Accessors return the value.

(def tensor-shape (lambda (t) (car (cdr (car (cdr t))))))
(def tensor-layout (lambda (t) (car (cdr (car (cdr (cdr t)))))))
(def tensor-channels (lambda (t) (car (cdr (car (cdr (cdr (cdr t))))))))
(def tensor-data (lambda (t) (car (cdr (car (cdr (cdr (cdr (cdr t)))))))))

(def tensor-rank (lambda (t) (length (tensor-shape t))))

(def tensor-size-helper (lambda (dims acc) (cond ((atom dims) acc) (t (tensor-size-helper (cdr dims) (* acc (car dims)))))))
(def tensor-size (lambda (t) (tensor-size-helper (tensor-shape t) 1)))

(def tensor-shape-validate (lambda (t) (= (tensor-size t) (numeric-buffer-length (tensor-data t)))))

(def tensor-nchw-offset (lambda (c h w shape) (let ((H (car (cdr shape))) (W (car (cdr (cdr shape))))) (+ (* c H W) (* h W) w))))
