; tensor-test.my - validates tensor descriptor library
; Expected: all assertions print t

(load "lib/chess.my")
(load "lib/tensor.my")

; helper: construct a tensor descriptor
; structure: (tensor (shape ...) (layout ...) (channels ...) (data ...))
(def make-tensor
  (lambda (shape layout channels data)
    (list (quote tensor) (list (quote shape) shape) (list (quote layout) layout) (list (quote channels) channels) (list (quote data) data))))

; Test 1: tensor-size for 3x4
(def buf1 (i32-buffer 1 2 3 4 5 6 7 8 9 10 11 12))
(def t1 (make-tensor (list 3 4) (quote flat) () buf1))
(print (list (quote test-1-size) (= (tensor-size t1) 12)))

; Test 2: tensor-rank
(print (list (quote test-2-rank) (= (tensor-rank t1) 2)))

; Test 3: shape-validate matches
(print (list (quote test-3-validate-match) (tensor-shape-validate t1)))

; Test 4: shape-validate mismatch
(def buf2 (i32-buffer 1 2 3))
(def t2-bad (make-tensor (list 3 4) (quote flat) () buf2))
(print (list (quote test-4-validate-mismatch) (not (tensor-shape-validate t2-bad))))

; Test 5: nchw offset
; shape (2 3 4), offset(1, 2, 3) = 1*3*4 + 2*4 + 3 = 12+8+3 = 23
(print (list (quote test-5-nchw-offset) (= (tensor-nchw-offset 1 2 3 (list 2 3 4)) 23)))
