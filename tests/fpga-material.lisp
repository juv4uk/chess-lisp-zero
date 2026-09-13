; tests/fpga-material.my — pure material evaluation for FPGA kernel
; Extracted from lib/evaluation.wsm with zero dependencies.
; Run: my-lisp tests/fpga-material.my

(load "/home/agents/GitHub/my-lisp/lib/core.my")
(load "/home/agents/GitHub/chess-lisp-zero/lib/chess.my")

; Piece material values (centipawns). King = 0 per evaluation.wsm convention.
(def piece-material
  (lambda (piece)
    (cond ((eq piece (quote wp)) 100)
          ((eq piece (quote wn)) 320)
          ((eq piece (quote wb)) 330)
          ((eq piece (quote wr)) 500)
          ((eq piece (quote wq)) 900)
          ((eq piece (quote wk)) 0)
          ((eq piece (quote bp)) -100)
          ((eq piece (quote bn)) -320)
          ((eq piece (quote bb)) -330)
          ((eq piece (quote br)) -500)
          ((eq piece (quote bq)) -900)
          ((eq piece (quote bk)) 0)
          (t 0))))

; Sum material over 64 squares (board is a vector of 64)
(def board-material-from
  (lambda (board square total)
    (cond ((eq square 64) total)
          (t (board-material-from
               board
               (+ square 1)
               (+ total (piece-material (vector-ref board square))))))))

(def board-material
  (lambda (board)
    (board-material-from board 0 0)))

; --- Board construction helpers (single-expression) ---

(def make-empty-board (lambda () (make-vector 64)))

(def make-initial-board
  (lambda ()
    (chess-board-from-list
      (quote (wr wn wb wq wk wb wn wr
              wp wp wp wp wp wp wp wp
              () () () () () () () ()
              () () () () () () () ()
              () () () () () () () ()
              () () () () () () () ()
              bp bp bp bp bp bp bp bp
              br bn bb bq bk bb bn br)))))

(def make-white-pawn-board
  (lambda ()
    ((lambda (b) (vector-set! b 28 (quote wp)) b) (make-vector 64))))

(def make-black-knight-board
  (lambda ()
    ((lambda (b) (vector-set! b 36 (quote bn)) b) (make-vector 64))))

(def make-complex-board
  (lambda ()
    (chess-board-from-list
      (quote (br bn bb bq bk bb bn br
              bp bp bp bp bp bp bp bp
              () () () () () () () ()
              () () () () () () () ()
              () () () () () () () ()
              () () () () () () () ()
              wp wp wp wp wp wp wp wp
              wr wn wb wq wk wb wn wr)))))

(def make-endgame-board
  (lambda ()
    ((lambda (b)
         (vector-set! b 4 (quote wk))
         (vector-set! b 12 (quote wp))
         (vector-set! b 60 (quote bk))
         b)
     (make-vector 64))))

; --- Verification ---

(def verify
  (lambda (name board expected)
    (let ((actual (board-material board)))
      (print (list (quote fixture-material)
                   (quote name) name
                   (quote expected) expected
                   (quote actual) actual
                   (quote ok) (equal? actual expected))))))

; Run all fixtures
(verify (quote mat-empty) (make-empty-board) 0)
(verify (quote mat-initial) (make-initial-board) 0)
(verify (quote mat-white-up-pawn) (make-white-pawn-board) 100)
(verify (quote mat-black-up-knight) (make-black-knight-board) -320)
(verify (quote mat-complex) (make-complex-board) 0)
(verify (quote mat-endgame) (make-endgame-board) 100)

(print (quote FPGA-MATERIAL-OK))