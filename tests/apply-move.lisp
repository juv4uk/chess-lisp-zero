(load "lib/chess.my")

(def apply-assert
  (lambda (name actual expected)
    (cond ((equal? actual expected)
           (print (list (quote pass) name actual)))
          (t (print (list (quote fail) name actual expected))))))

; Moving the a1 rook removes only White's queen-side castling right.
(def rights-position (chess-initial-position))
(def rights-next (chess-apply-move rights-position (chess-move 0 8)))
(apply-assert (quote rook-rights)
  (chess-position-castling rights-next)
  (quote (K k q)))

; Direct apply-move castling semantics use the repository's a1=0 layout.
(def castle-board (make-vector 64))
(vector-set! castle-board 4 (quote wk))
(vector-set! castle-board 7 (quote wr))
(vector-set! castle-board 60 (quote bk))
(def castle-position
  (chess-position castle-board (quote white) (quote (K)) (quote ()) 0 1))
(def castle-next (chess-apply-move castle-position (chess-move 4 6)))
(apply-assert (quote castle-king)
  (vector-ref (chess-position-board castle-next) 6)
  (quote wk))
(apply-assert (quote castle-rook)
  (vector-ref (chess-position-board castle-next) 5)
  (quote wr))
(apply-assert (quote castle-origin-empty)
  (vector-ref (chess-position-board castle-next) 4)
  (quote ()))
(apply-assert (quote castle-rights-cleared)
  (chess-position-castling castle-next)
  (quote ()))

; Clocks: quiet non-pawn increments, pawn move resets.
(def quiet-board (make-vector 64))
(vector-set! quiet-board 4 (quote wk))
(vector-set! quiet-board 60 (quote bk))
(def quiet-position
  (chess-position quiet-board (quote white) (quote ()) (quote ()) 8 1))
(apply-assert (quote quiet-halfmove)
  (chess-position-halfmove
    (chess-apply-move quiet-position (chess-move 4 5)))
  9)

(def pawn-board (make-vector 64))
(vector-set! pawn-board 4 (quote wk))
(vector-set! pawn-board 60 (quote bk))
(vector-set! pawn-board 8 (quote wp))
(def pawn-position
  (chess-position pawn-board (quote white) (quote ()) (quote ()) 8 1))
(apply-assert (quote pawn-halfmove-reset)
  (chess-position-halfmove
    (chess-apply-move pawn-position (chess-move 8 16)))
  0)

(def move-member?
  (lambda (needle moves)
    (cond ((atom moves) (quote ()))
          ((equal? needle (car moves)) t)
          (t (move-member? needle (cdr moves))))))

; Castling generation requires rights, an unmoved rook, clear transit squares,
; and no attack on the king's origin/transit/destination.
(apply-assert (quote castle-generated)
  (move-member? (chess-move 4 6) (chess-legal-moves castle-position))
  t)

; En-passant is generated from the position target and removes the bypassed pawn.
(def ep-board (make-vector 64))
(vector-set! ep-board 4 (quote wk))
(vector-set! ep-board 60 (quote bk))
(vector-set! ep-board 36 (quote wp))
(vector-set! ep-board 35 (quote bp))
(def ep-position
  (chess-position ep-board (quote white) (quote ()) 43 0 1))
(apply-assert (quote en-passant-generated)
  (move-member? (chess-move 36 43) (chess-legal-moves ep-position))
  t)
(def ep-next (chess-apply-move ep-position (chess-move 36 43)))
(apply-assert (quote en-passant-lands)
  (vector-ref (chess-position-board ep-next) 43) (quote wp))
(apply-assert (quote en-passant-removes-pawn)
  (vector-ref (chess-position-board ep-next) 35) (quote ()))

; Promotion generation exposes all four choices; apply-move preserves the choice.
(def promotion-board (make-vector 64))
(vector-set! promotion-board 4 (quote wk))
(vector-set! promotion-board 63 (quote bk))
(vector-set! promotion-board 48 (quote wp))
(def promotion-position
  (chess-position promotion-board (quote white) (quote ()) (quote ()) 0 1))
(def promotion-moves (chess-legal-moves promotion-position))
(apply-assert (quote promote-queen-generated)
  (move-member? (chess-promotion-move 48 56 (quote q)) promotion-moves) t)
(apply-assert (quote promote-rook-generated)
  (move-member? (chess-promotion-move 48 56 (quote r)) promotion-moves) t)
(apply-assert (quote promote-bishop-generated)
  (move-member? (chess-promotion-move 48 56 (quote b)) promotion-moves) t)
(apply-assert (quote promote-knight-generated)
  (move-member? (chess-promotion-move 48 56 (quote n)) promotion-moves) t)
(apply-assert (quote promote-knight-applied)
  (vector-ref
    (chess-position-board
      (chess-apply-move promotion-position
        (chess-promotion-move 48 56 (quote n))))
    56)
  (quote wn))
