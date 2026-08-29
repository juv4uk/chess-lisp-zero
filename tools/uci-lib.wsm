; Shared UCI adapter core for the my-lisp chess engine (chess-lisp-zero).
; Pure definitions — loading this file performs no I/O loop. Two entry
; points use it:
;   - tools/uci-adapter.wsm  batch/transcript UCI: (uci-loop) reads commands
;     from stdin, output lands in the host transcript, flushed at EOF.
;   - tools/uci-differential.py  live UCI over a private `my-lisp --tcp`
;     REPL: one (uci-eval-line ...) request per command, output streams
;     back per request (see docs/UCI-ADAPTER.md).
; Dialect mirrors the chess-tauri-zero UCI engine (uci_torch.py) so an
; identical dialogue can be replayed against both engines.

(load "lib/chess.my")
(load "lib/fen.wsm")
(load "lib/evaluation.wsm")
(load "lib/search.wsm")

(def uci-position-cell (make-vector 1))
(def uci-startpos-fen
  "rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1")
(vector-set! uci-position-cell 0 (chess-position-from-fen uci-startpos-fen))

;; ---- string helpers ------------------------------------------------

(def uci-string-length
  (lambda (s)
    (cond ((string-empty? s) 0)
          (t (+ 1 (uci-string-length (string-rest s)))))))

(def uci-string=
  (lambda (a b)
    (cond ((string-empty? a) (string-empty? b))
          ((string-empty? b) (quote ()))
          ((eq (string-first a) (string-first b))
           (uci-string= (string-rest a) (string-rest b)))
          (t (quote ())))))

(def uci-string-nth
  (lambda (n s)
    (cond ((string-empty? s) "")
          ((eq n 0) (string-first s))
          (t (uci-string-nth (- n 1) (string-rest s))))))

;; ---- tokenization ---------------------------------------------------

(def uci-tokenize
  (lambda (line)
    (uci-tokenize-walk line "" (quote ()))))

(def uci-tokenize-walk
  (lambda (line token acc)
    (cond ((string-empty? line)
           (reverse
             (cond ((string-empty? token) acc)
                   (t (cons (string->symbol token) acc)))))
          ((eq (string-first line) " ")
           (uci-tokenize-walk (string-rest line) ""
             (cond ((string-empty? token) acc)
                   (t (cons (string->symbol token) acc)))))
          (t (uci-tokenize-walk (string-rest line)
               (string-append token (string-first line)) acc)))))

;; ---- list / number helpers -----------------------------------------

(def uci-list-take
  (lambda (n xs)
    (cond ((eq n 0) (quote ()))
          ((atom xs) (quote ()))
          (t (cons (car xs) (uci-list-take (- n 1) (cdr xs)))))))

(def uci-list-drop
  (lambda (n xs)
    (cond ((eq n 0) xs)
          ((atom xs) (quote ()))
          (t (uci-list-drop (- n 1) (cdr xs))))))

(def uci-list-length
  (lambda (xs)
    (cond ((atom xs) 0)
          (t (+ 1 (uci-list-length (cdr xs)))))))

(def uci-all-digits?
  (lambda (s)
    (cond ((string-empty? s) t)
          ((eq (chess-fen-digit (string-first s)) -1) (quote ()))
          (t (uci-all-digits? (string-rest s))))))

(def uci-parse-depth
  (lambda (sym)
    (let ((s (symbol->string sym)))
      (cond ((or (string-empty? s) (not (uci-all-digits? s))) -1)
            (t (chess-fen-parse-uint s 0))))))

(def uci-join-words
  (lambda (words)
    (uci-join-words-walk words "" (quote ()))))

(def uci-join-words-walk
  (lambda (words acc seen)
    (cond ((atom words) acc)
          (t (uci-join-words-walk (cdr words)
               (string-append acc
                 (string-append (cond (seen " ") (t ""))
                   (symbol->string (car words))))
               t)))))

;; ---- UCI coordinate <-> square / move ------------------------------

(def uci-square->number
  (lambda (square)
    (let* ((file (chess-fen-file (uci-string-nth 0 square)))
           (rank (chess-fen-digit (uci-string-nth 1 square))))
      (cond ((or (eq file -1) (eq rank -1) (< rank 1) (> rank 8)) -1)
            (t (chess-square file (- rank 1)))))))

(def uci-number->square
  (lambda (square)
    (string-append (chess-fen-file-string (chess-file square))
      (number->string (+ 1 (chess-rank square))))))

(def uci-move-from-symbol
  (lambda (sym)
    (let ((text (symbol->string sym)))
      (cond ((eq (uci-string-length text) 4)
             (let ((from (uci-square->number (string-append (uci-string-nth 0 text)
                                           (uci-string-nth 1 text))))
                   (to (uci-square->number (string-append (uci-string-nth 2 text)
                                         (uci-string-nth 3 text)))))
               (cond ((or (eq from -1) (eq to -1)) (quote ()))
                     (t (chess-move from to)))))
            ((eq (uci-string-length text) 5)
             (let ((from (uci-square->number (string-append (uci-string-nth 0 text)
                                           (uci-string-nth 1 text))))
                   (to (uci-square->number (string-append (uci-string-nth 2 text)
                                         (uci-string-nth 3 text))))
                   (promo (string->symbol (uci-string-nth 4 text))))
               (cond ((or (eq from -1) (eq to -1)) (quote ()))
                     (t (chess-promotion-move from to promo)))))
            (t (quote ()))))))

(def uci-move->string
  (lambda (move)
    (let* ((from (uci-number->square (chess-move-from move)))
           (to (uci-number->square (chess-move-to move)))
           (promo (chess-move-promotion move)))
      (cond ((atom promo) (string-append from to))
            (t (string-append (string-append from to) (symbol->string promo)))))))

(def uci-move-equal?
  (lambda (a b)
    (and (eq (chess-move-from a) (chess-move-from b))
         (eq (chess-move-to a) (chess-move-to b))
         (eq (chess-move-promotion a) (chess-move-promotion b)))))

(def uci-move-member?
  (lambda (move moves)
    (cond ((atom moves) (quote ()))
          ((uci-move-equal? move (car moves)) t)
          (t (uci-move-member? move (cdr moves))))))

;; ---- engine state ---------------------------------------------------

(def uci-current-position
  (lambda ()
    (vector-ref uci-position-cell 0)))

(def uci-set-position
  (lambda (pos)
    (vector-set! uci-position-cell 0 pos)))

;; ---- output ---------------------------------------------------------

(def uci-ok
  (lambda ()
    (princ "uciok")))

(def uci-info-error
  (lambda (tag reason)
    (princ (string-append (string-append (string-append "info error [" tag) "] ") reason))))

(def uci-info-string
  (lambda (text)
    (princ (string-append "info string " text))))

;; ---- command: uci / ucinewgame / isready ---------------------------

(def uci-cmd-uci
  (lambda ()
    (princ "id name my-lisp-chess v0 (chess-lisp-zero)")
    (princ "id author vyasa (my-lisp)")
    (uci-ok)))

(def uci-cmd-newgame
  (lambda ()
    (uci-set-position (chess-position-from-fen uci-startpos-fen))))

(def uci-cmd-isready
  (lambda ()
    (princ "readyok")))

;; ---- command: position ---------------------------------------------

(def uci-cmd-position
  (lambda (tokens)
    (cond ((atom tokens)
           (uci-info-error "position"
             "missing board subcommand (startpos|fen)"))
          ((eq (car tokens) (quote startpos))
           (uci-position-startpos (cdr tokens)))
          ((eq (car tokens) (quote fen))
           (uci-position-fen (cdr tokens)))
          (t (uci-info-error "position"
               (string-append "unknown board subcommand "
                 (uci-symbol->string (car tokens))))))))

(def uci-position-startpos
  (lambda (tokens)
    (let ((base (chess-position-from-fen uci-startpos-fen)))
      (uci-set-position (uci-position-moves base tokens)))))

(def uci-position-fen
  (lambda (tokens)
    (cond ((< (uci-list-length tokens) 6)
           (uci-info-error "position" "fen requires 6 fields"))
          (t (let ((fen (uci-join-words (uci-list-take 6 tokens))))
               (cond ((not (uci-fen-valid? fen))
                      (uci-info-error "position" "malformed fen"))
                     (t (uci-set-position
                          (uci-position-moves
                            (chess-position-from-fen fen)
                            (uci-list-drop 6 tokens))))))))))

(def uci-fen-valid?
  (lambda (fen)
    (let ((pos (chess-position-from-fen fen)))
      (and (uci-pieces-balance? (chess-position-board pos))
           (uci-string= (chess-position-to-fen pos) fen)))))

(def uci-pieces-balance?
  (lambda (board)
    (let ((counts (uci-count-pieces board 0 0 0)))
      (and (> (car counts) 0) (> (cdr counts) 0)))))

(def uci-count-pieces
  (lambda (board index white black)
    (cond ((eq index 64) (cons white black))
          (t (let ((piece (vector-ref board index)))
               (cond ((eq piece chess-empty)
                      (uci-count-pieces board (+ index 1) white black))
                     ((chess-white-piece? piece)
                      (uci-count-pieces board (+ index 1) (+ white 1) black))
                     (t (uci-count-pieces board (+ index 1) white
                          (+ black 1)))))))))

(def uci-position-moves
  (lambda (pos tokens)
    (cond ((atom tokens) pos)
          ((eq (car tokens) (quote moves))
           (uci-apply-moves pos (cdr tokens)))
          (t ((lambda ()
                (uci-info-error "position"
                  (string-append "unexpected token after board: "
                    (uci-symbol->string (car tokens))))
                pos))))))

(def uci-apply-moves
  (lambda (pos moves)
    (cond ((atom moves) pos)
          (t (let ((move (uci-move-from-symbol (car moves))))
               (cond ((atom move)
                      ((lambda ()
                        (uci-info-error "position"
                          (string-append "illegal move "
                            (uci-symbol->string (car moves))))
                        pos)))
                     ((uci-move-member? move (chess-legal-moves pos))
                      (uci-apply-moves (chess-apply-move pos move) (cdr moves)))
                     (t
                      ((lambda ()
                        (uci-info-error "position"
                          (string-append "illegal move "
                            (uci-symbol->string (car moves))))
                        pos)))))))))

;; ---- command: go ----------------------------------------------------

(def uci-go-known-token
  (lambda (tok)
    (and (not (eq tok (quote perft)))
         (not (eq tok (quote depth)))
         (uci-go-known-token-walk tok
           (quote (ponder wtime btime winc binc movetime nodes
                  infinite searchmoves mate movestogo))))))

(def uci-go-known-token-walk
  (lambda (tok list)
    (cond ((atom list) (quote ()))
          ((eq tok (car list)) t)
          (t (uci-go-known-token-walk tok (cdr list))))))

(def uci-go-skip-argument
  (lambda (tok tokens)
    (cond ((eq tok (quote ponder)) tokens)
          ((eq tok (quote infinite)) tokens)
          ((eq tok (quote searchmoves)) (uci-go-skip-searchmoves tokens))
          (t (cond ((atom tokens) tokens)
                   ((eq (uci-parse-depth (car tokens)) -1) tokens)
                   (t (cdr tokens)))))))

(def uci-go-skip-searchmoves
  (lambda (tokens)
    (cond ((atom tokens) tokens)
          ((uci-go-known-token (car tokens)) tokens)
          ((eq (car tokens) (quote depth)) tokens)
          ((eq (car tokens) (quote perft)) tokens)
          (t (uci-go-skip-searchmoves (cdr tokens))))))

(def uci-cmd-go
  (lambda (tokens)
    (cond ((atom tokens) (uci-go-search 1))
          ((eq (car tokens) (quote perft)) (uci-go-perft (cdr tokens)))
          ((eq (car tokens) (quote depth)) (uci-go-depth (cdr tokens)))
          ((uci-go-known-token (car tokens))
           (uci-cmd-go (uci-go-skip-argument (car tokens) (cdr tokens))))
          (t (uci-info-error "go"
               (string-append "unrecognized token "
                 (uci-symbol->string (car tokens))))))))

(def uci-go-depth
  (lambda (tokens)
    (cond ((atom tokens)
           (uci-info-error "go" "depth requires a number"))
          (t (let ((n (uci-parse-depth (car tokens))))
               (cond ((< n 1)
                      (uci-info-error "go" "depth must be a positive integer"))
                     (t (uci-go-search n))))))))

(def uci-go-search
  (lambda (depth)
    (let* ((pos (uci-current-position))
           (moves (chess-legal-moves pos)))
      (cond ((atom moves)
             ((lambda ()
               (uci-info-string
                 (cond ((chess-in-check? (chess-position-board pos)
                                         (chess-position-side pos))
                        "checkmate")
                       (t "stalemate")))
               (princ "bestmove (none)"))))
            (t ((lambda ()
                 (uci-info-string (string-append "my-lisp minimax depth "
                                        (number->string depth)))
                 (let* ((result (chess-best-move pos depth))
                        (move (car result)))
(princ (string-append "bestmove "
                                   (uci-move->string move)))))))))))

(def uci-go-perft
  (lambda (tokens)
    (cond ((atom tokens)
           (uci-info-error "go" "perft requires a depth"))
          (t (let ((n (uci-parse-depth (car tokens))))
               (cond ((< n 0)
                      (uci-info-error "go"
                        "perft depth must be a non-negative integer"))
                     (t (princ (string-append "info perft "
                              (number->string
                                (chess-perft (uci-current-position) n)))))))))))

;; ---- command: dispatch ----------------------------------------------

(def uci-cmd-unknown
  (lambda (tok)
    (uci-info-error (uci-symbol->string tok)
      (string-append "unknown command: "
        (uci-symbol->string tok)))))

(def uci-dispatch
  (lambda (tokens)
    (cond ((atom tokens) (quote ok))
          ((eq (car tokens) (quote uci)) (uci-cmd-uci))
          ((eq (car tokens) (quote ucinewgame)) (uci-cmd-newgame))
          ((eq (car tokens) (quote isready)) (uci-cmd-isready))
          ((eq (car tokens) (quote position)) (uci-cmd-position (cdr tokens)))
          ((eq (car tokens) (quote go)) (uci-cmd-go (cdr tokens)))
          ((eq (car tokens) (quote stop))
           (uci-info-string
             "stop noted: synchronous adapter, bestmove arrives on completion"))
          ((eq (car tokens) (quote setoption))
           (uci-info-string "setoption ignored: no options supported"))
          ((eq (car tokens) (quote quit)) (quote quit))
          (t (uci-cmd-unknown (car tokens))))))

;; ---- entry points ---------------------------------------------------

(def uci-symbol->string
  (lambda (sym)
    (symbol->string sym)))

(def uci-eval-line
  (lambda (line)
    (cond ((string-empty? line) (quote ok))
          (t (uci-dispatch (uci-tokenize line))))))

(def uci-loop
  (lambda ()
    (let ((line (read)))
      (cond ((string-empty? line) (quote quit))
            (t (let ((result (uci-eval-line line)))
                 (cond ((eq result (quote quit)) result)
                       (t (uci-loop)))))))))
