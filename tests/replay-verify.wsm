; CHESS-LISP-ZERO-SELF-PLAY-REPLAY-VERIFY
; Pure-WSM export/replay pin on the self-play record contract.
; Replays the frozen fixture (tests/fixtures/self-play-replay-fix.my):
;   FEN -> parse -> re-derive 1152 planes bit-exact
;       -> re-index sparse PUCT policy against the vocabulary
;       -> rebuild a fresh record and compare all fields.
; No PyTorch, no training/ edits, no GPU: WSM stays the single semantic
; authority. Consumers (torch/cml) may assert against the fixture values.

(load "lib/chess.my")
(load "lib/fen.wsm")
(load "lib/neural-contract.wsm")
(load "lib/evaluation.wsm")
(load "lib/puct.wsm")
(load "lib/self-play.wsm")
(load "tests/fixtures/self-play-replay-fix.my")

; --- helpers ----------------------------------------------------------

(def vec->list-from
  (lambda (v i acc)
    (cond ((= i (vector-length v)) (reverse acc))
          (t (vec->list-from v (+ i 1) (cons (vector-ref v i) acc))))))

(def vec->list (lambda (v) (vec->list-from v 0 (quote ()))))

; Structural equality over nested data (nil / exact numbers / lists).
(def fix-equal
  (lambda (a b)
    (cond
      ((and (atom a) (atom b))
         (cond ((eq a (quote ())) (eq b (quote ())))
               ((eq b (quote ())) (quote ()))
               (t (= a b))))
      ((or (atom a) (atom b)) (quote ()))
      ((fix-equal (car a) (car b)) (fix-equal (cdr a) (cdr b)))
      (t (quote ())))))

(def replay-assert
  (lambda (name ok)
    (cond (ok (print (list name (quote PASS))))
          (t (error (string-append
                      "self-play replay-verify failed: "
                      (symbol->string name)))))))

; --- replay -----------------------------------------------------------

(def fix-position (chess-position-from-fen self-play-replay-fix-fen))
(def fix-planes (vec->list (chess-neural-position-planes fix-position)))
(def fix-side (chess-position-side fix-position))
(def fix-policy (self-play-index-policy fix-position self-play-replay-fix-sparse))

(replay-assert (quote planes-bit-exact)
  (fix-equal fix-planes self-play-replay-fix-planes))

(replay-assert (quote side-match)
  (eq fix-side self-play-replay-fix-side))

(replay-assert (quote policy-roundtrip-indexed)
  (fix-equal fix-policy self-play-replay-fix-policy))

(def replay-fresh (self-play-record fix-position fix-policy))

(replay-assert (quote record-planes-field-identical)
  (fix-equal (vec->list (vector-ref replay-fresh self-play-planes-field))
    self-play-replay-fix-planes))

(replay-assert (quote record-side-field-identical)
  (eq (vector-ref replay-fresh self-play-side-field) self-play-replay-fix-side))

(replay-assert (quote record-outcome-fresh-empty)
  (eq (vector-ref replay-fresh self-play-outcome-field) chess-empty))

(replay-assert (quote policy-length-2)
  (eq (length self-play-replay-fix-policy) 2))

(replay-assert (quote policy-index-0-in-vocabulary)
  (let ((i (car (car self-play-replay-fix-policy))))
    (cond ((>= i 0) (< i 1968)) (t (quote ())))))

(replay-assert (quote policy-index-1-in-vocabulary)
  (let ((i (car (second self-play-replay-fix-policy))))
    (cond ((>= i 0) (< i 1968)) (t (quote ())))))

(print (quote SELF-PLAY-REPLAY-VERIFY-PASS))