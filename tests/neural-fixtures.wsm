(load "lib/chess.my")
(load "lib/fen.wsm")
(load "lib/neural-contract.wsm")

; Compact semantic fixtures for the chess -> neural boundary.  These positions
; are repository-authored and deliberately asymmetric so that own/opponent,
; castling and en-passant normalization cannot pass by accidental symmetry.

(def neural-fixture-assert
  (lambda (name condition)
    (cond (condition (print (list name (quote PASS))))
          (t (error (string-append "neural fixture failed: "
                     (symbol->string name)))))))

(def neural-fixture-plane-sum-from
  (lambda (planes plane square total)
    (cond ((eq square 64) total)
          (t (neural-fixture-plane-sum-from planes plane (+ square 1)
               (+ total
                 (cond ((eq (vector-ref planes
                              (chess-neural-offset plane square)) 1) 1)
                       (t 0))))))))

(def neural-fixture-plane-sum
  (lambda (planes plane)
    (neural-fixture-plane-sum-from planes plane 0 0)))

; White to move: own pawn e5, opponent pawn d5, K/q rights and ep=d6.
(def white-state
  (chess-position-from-fen "4k3/8/8/3pP3/8/8/8/4K3 w Kq d6 17 42"))
(def white-planes (chess-neural-position-planes white-state))

(neural-fixture-assert (quote white-own-pawn-e5)
  (= (vector-ref white-planes (chess-neural-offset 0 36)) 1))
(neural-fixture-assert (quote white-opponent-pawn-d5)
  (= (vector-ref white-planes (chess-neural-offset 6 35)) 1))
(neural-fixture-assert (quote white-own-king-e1)
  (= (vector-ref white-planes (chess-neural-offset 5 4)) 1))
(neural-fixture-assert (quote white-opponent-king-e8)
  (= (vector-ref white-planes (chess-neural-offset 11 60)) 1))
(neural-fixture-assert (quote white-own-kingside-right)
  (= (neural-fixture-plane-sum white-planes 12) 64))
(neural-fixture-assert (quote white-no-own-queenside-right)
  (= (neural-fixture-plane-sum white-planes 13) 0))
(neural-fixture-assert (quote white-no-opponent-kingside-right)
  (= (neural-fixture-plane-sum white-planes 14) 0))
(neural-fixture-assert (quote white-opponent-queenside-right)
  (= (neural-fixture-plane-sum white-planes 15) 64))
(neural-fixture-assert (quote white-ep-d6-only)
  (and (= (vector-ref white-planes (chess-neural-offset 16 43)) 1)
       (= (neural-fixture-plane-sum white-planes 16) 1)))

; Black to move: normalization flips ranks into the same side-to-move frame.
; Own black pawn d4 becomes d5; ep=e3 becomes e6.
(def black-state
  (chess-position-from-fen "4k3/8/8/8/3pP3/8/8/4K3 b Qk e3 17 42"))
(def black-planes (chess-neural-position-planes black-state))

(neural-fixture-assert (quote black-own-pawn-normalized-d5)
  (= (vector-ref black-planes (chess-neural-offset 0 35)) 1))
(neural-fixture-assert (quote black-opponent-pawn-normalized-e5)
  (= (vector-ref black-planes (chess-neural-offset 6 36)) 1))
(neural-fixture-assert (quote black-own-king-normalized-e1)
  (= (vector-ref black-planes (chess-neural-offset 5 4)) 1))
(neural-fixture-assert (quote black-opponent-king-normalized-e8)
  (= (vector-ref black-planes (chess-neural-offset 11 60)) 1))
(neural-fixture-assert (quote black-own-kingside-right)
  (= (neural-fixture-plane-sum black-planes 12) 64))
(neural-fixture-assert (quote black-opponent-queenside-right)
  (= (neural-fixture-plane-sum black-planes 15) 64))
(neural-fixture-assert (quote black-ep-normalized-e6-only)
  (and (= (vector-ref black-planes (chess-neural-offset 16 44)) 1)
       (= (neural-fixture-plane-sum black-planes 16) 1)))
(neural-fixture-assert (quote black-side-plane-zero)
  (= (neural-fixture-plane-sum black-planes 17) 0))

; Mirrored moves must address the same policy output from either side's view.
(def fixture-policy-labels (chess-policy-labels))
(def white-promotion-index
  (chess-policy-move-index-in fixture-policy-labels white-state
    (chess-promotion-move 48 56 (quote q))))
(def black-promotion-index
  (chess-policy-move-index-in fixture-policy-labels black-state
    (chess-promotion-move 8 0 (quote q))))
(neural-fixture-assert (quote mirrored-promotion-policy-index)
  (and (= white-promotion-index black-promotion-index)
       (>= white-promotion-index 1792)
       (< white-promotion-index 1968)))

(def white-castle-index
  (chess-policy-move-index-in fixture-policy-labels white-state (chess-move 4 6)))
(def black-castle-index
  (chess-policy-move-index-in fixture-policy-labels black-state (chess-move 60 62)))
(neural-fixture-assert (quote mirrored-castle-policy-index)
  (= white-castle-index black-castle-index))

(print (quote CHESS-NEURAL-FIXTURES-PASS))
