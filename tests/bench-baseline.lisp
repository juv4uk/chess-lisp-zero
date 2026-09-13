(load "lib/chess.my")
(load "lib/fen.wsm")
(load "lib/evaluation.wsm")
(load "lib/search.wsm")

; ============================================================================
; CPU-BASELINE-PROFILE — vector-based my-lisp baseline measurement.
; Purpose (task CHESS-LISP-ZERO-CPU-BASELINE-PROFILE): measure the perft/
; search baseline with mono-ms, report correctness SEPARATELY from elapsed,
; identify the dominant operation before proposing bitboards or new
; primitives. This file only MEASURES; it changes no engine code and
; proposes nothing. Timing lines are REPORT data, not assertions — nothing
; here fails on a slow machine.
; Run: my-lisp tests/bench-baseline.my   (bounded; a few minutes)
; Report goes to docs/CPU-BASELINE-PROFILE.md.
; ============================================================================

(def timed-n
  (lambda (n thunk t0)
    (cond ((eq n 0) (- (mono-ms) t0))
          (t ((lambda ()
                (thunk)
                (timed-n (- n 1) thunk t0)))))))

(def time-it
  (lambda (n thunk)
    (timed-n n thunk (mono-ms))))

(def perft-bench
  (lambda (name fen depth published reps)
    (let ((pos (chess-position-from-fen fen)))
      ((lambda ()
        (let ((actual (chess-perft pos depth)))
          (let ((el-ms (time-it reps (lambda () (chess-perft pos depth)))))
            (cond ((equal? actual published)
                   ((lambda (mean-ms)
                      (print (list (quote bench-perft) name
                                   (quote depth) depth
                                   (quote nodes) actual
                                   (quote ok) t
                                   (quote mean-ms) mean-ms
                                   (quote per-node-ms)
                                   (/ mean-ms published))))
                    (/ el-ms (cond ((eq reps 0) 1) (t reps)))))
                  (t (print (list (quote bench-perft) name
                                  (quote depth) depth
                                  (quote nodes) actual
                                  (quote expected) published
                                  (quote ok) (quote no))))))))))))

(def legal-moves-bench
  (lambda (name fen reps)
    (let ((pos (chess-position-from-fen fen)))
      (let ((first (chess-legal-moves pos)))
        (let ((el-ms (time-it reps (lambda () (chess-legal-moves pos)))))
          (print (list (quote bench-legal-moves) name
                       (quote moves) (length first)
                       (quote mean-ms) (/ el-ms reps)
                       (quote calls) reps)))))))

(def apply-bench
  (lambda (name fen reps)
    (let ((pos (chess-position-from-fen fen)))
      (let ((move (car (chess-legal-moves pos))))
        (let ((el-ms (time-it reps (lambda () (chess-apply-move pos move)))))
          (print (list (quote bench-apply) name
                       (quote mean-ms) (/ el-ms reps)
                       (quote calls) reps)))))))

(def search-bench
  (lambda (reps)
    (let ((board (make-vector 64)))
      ((lambda ()
        (vector-set! board 4 (quote wk))
        (vector-set! board 60 (quote bk))
        (vector-set! board 8 (quote wr))
        (vector-set! board 16 (quote bq))
        (let ((pos (chess-position board (quote white) () () 0 1)))
          (let ((first (chess-best-move pos 1)))
            (let ((el-ms (time-it reps
                                  (lambda () (chess-best-move pos 1)))))
              (print (list (quote bench-search)
                           (quote best-move) (car first)
                           (quote score) (second first)
                           (quote mean-ms) (/ el-ms reps)
                           (quote calls) reps))))))))))

(perft-bench (quote initial)
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 1 20 3)
(perft-bench (quote initial)
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 2 400 1)
(perft-bench (quote kiwipete)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" 1 48 3)
(perft-bench (quote kiwipete)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" 2 2039 1)
(perft-bench (quote position-6)
  "r4rk1/1pp1qppp/p1np1n2/2b1p1B1/2B1P1b1/P1NP1N2/1PP1QPPP/R4RK1 w - - 0 10" 2 2079 1)

(legal-moves-bench (quote kiwipete-root)
  "r3k2r/p1ppqpb1/bn2pnp1/3PN3/1p2P3/2N2Q1p/PPPBBPPP/R3K2R w KQkq - 0 1" 30)
(apply-bench (quote initial-root)
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1" 50)
(search-bench 5)

(print (quote CPU-BASELINE-PROFILE-OK))