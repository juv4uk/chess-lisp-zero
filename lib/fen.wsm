; Deterministic Forsyth-Edwards Notation for chess-lisp-zero positions.
; Depends only on lib/chess.my + the canonical my-lisp core library.

(def chess-fen-digit
  (lambda (c)
    (cond ((eq c "0") 0) ((eq c "1") 1) ((eq c "2") 2)
          ((eq c "3") 3) ((eq c "4") 4) ((eq c "5") 5)
          ((eq c "6") 6) ((eq c "7") 7) ((eq c "8") 8)
          ((eq c "9") 9) (t -1))))

(def chess-fen-piece
  (lambda (c)
    (cond ((eq c "P") (quote wp)) ((eq c "p") (quote bp))
          ((eq c "N") (quote wn)) ((eq c "n") (quote bn))
          ((eq c "B") (quote wb)) ((eq c "b") (quote bb))
          ((eq c "R") (quote wr)) ((eq c "r") (quote br))
          ((eq c "Q") (quote wq)) ((eq c "q") (quote bq))
          ((eq c "K") (quote wk)) ((eq c "k") (quote bk))
          (t chess-empty))))

(def chess-fen-piece-string
  (lambda (piece)
    (cond ((eq piece (quote wp)) "P") ((eq piece (quote bp)) "p")
          ((eq piece (quote wn)) "N") ((eq piece (quote bn)) "n")
          ((eq piece (quote wb)) "B") ((eq piece (quote bb)) "b")
          ((eq piece (quote wr)) "R") ((eq piece (quote br)) "r")
          ((eq piece (quote wq)) "Q") ((eq piece (quote bq)) "q")
          ((eq piece (quote wk)) "K") ((eq piece (quote bk)) "k")
          (t ""))))

(def chess-fen-next-field
  (lambda (source acc)
    (cond ((string-empty? source) (cons acc ""))
          ((eq (string-first source) " ") (cons acc (string-rest source)))
          (t (chess-fen-next-field (string-rest source)
               (string-append acc (string-first source)))))))

(def chess-fen-parse-uint
  (lambda (source total)
    (cond ((string-empty? source) total)
          (t (let ((digit (chess-fen-digit (string-first source))))
               (cond ((< digit 0) total)
                     (t (chess-fen-parse-uint (string-rest source)
                          (+ (* total 10) digit)))))))))

(def chess-fen-parse-board-into
  (lambda (source index board)
    (cond ((string-empty? source) board)
          (t (let* ((c (string-first source))
                    (rest (string-rest source))
                    (digit (chess-fen-digit c)))
               (cond ((eq c "/") (chess-fen-parse-board-into rest (- index 16) board))
                     ((> digit 0) (chess-fen-parse-board-into rest (+ index digit) board))
                     (t ((lambda ()
                           (vector-set! board index (chess-fen-piece c))
                           (chess-fen-parse-board-into rest (+ index 1) board))))))))))

(def chess-fen-parse-castling
  (lambda (source accepted)
    (cond ((string-empty? source) (reverse accepted))
          ((eq source "-") (quote ()))
          (t (let ((c (string-first source)))
               (chess-fen-parse-castling (string-rest source)
                 (cons (string->symbol c) accepted)))))))

(def chess-fen-file
  (lambda (c)
    (cond ((eq c "a") 0) ((eq c "b") 1) ((eq c "c") 2)
          ((eq c "d") 3) ((eq c "e") 4) ((eq c "f") 5)
          ((eq c "g") 6) ((eq c "h") 7) (t -1))))

(def chess-fen-file-string
  (lambda (file)
    (nth file (quote ("a" "b" "c" "d" "e" "f" "g" "h")))))

(def chess-fen-parse-ep
  (lambda (source)
    (cond ((eq source "-") chess-empty)
          ((string-empty? source) chess-empty)
          (t (let* ((file (chess-fen-file (string-first source)))
                    (rank (chess-fen-digit (string-first (string-rest source)))))
               (cond ((or (< file 0) (< rank 1) (> rank 8)) chess-empty)
                     (t (chess-square file (- rank 1)))))))))

(def chess-position-from-fen
  (lambda (source)
    (let* ((board-field (chess-fen-next-field source ""))
           (side-field (chess-fen-next-field (cdr board-field) ""))
           (castle-field (chess-fen-next-field (cdr side-field) ""))
           (ep-field (chess-fen-next-field (cdr castle-field) ""))
           (half-field (chess-fen-next-field (cdr ep-field) ""))
           (full-field (chess-fen-next-field (cdr half-field) ""))
           (board (chess-fen-parse-board-into (car board-field) 56 (make-vector 64))))
      (chess-position board
        (cond ((eq (car side-field) "w") (quote white)) (t (quote black)))
        (chess-fen-parse-castling (car castle-field) (quote ()))
        (chess-fen-parse-ep (car ep-field))
        (chess-fen-parse-uint (car half-field) 0)
        (chess-fen-parse-uint (car full-field) 0)))))

(def chess-fen-flush-empty
  (lambda (count acc)
    (cond ((eq count 0) acc)
          (t (string-append acc (number->string count))))))

(def chess-fen-print-rank
  (lambda (board square file empty-count acc)
    (cond ((eq file 8) (chess-fen-flush-empty empty-count acc))
          (t (let ((piece (vector-ref board square)))
               (cond ((eq piece chess-empty)
                      (chess-fen-print-rank board (+ square 1) (+ file 1)
                        (+ empty-count 1) acc))
                     (t (chess-fen-print-rank board (+ square 1) (+ file 1) 0
                          (string-append (chess-fen-flush-empty empty-count acc)
                            (chess-fen-piece-string piece))))))))))

(def chess-fen-print-board
  (lambda (board rank acc)
    (let ((rank-text (chess-fen-print-rank board (* rank 8) 0 0 "")))
      (cond ((eq rank 0) (string-append acc rank-text))
            (t (chess-fen-print-board board (- rank 1)
                 (string-append (string-append acc rank-text) "/")))))))

(def chess-fen-print-castling
  (lambda (rights)
    (let ((text
            (string-append
              (cond ((chess-castling-king? rights (quote white)) "K") (t ""))
              (string-append
                (cond ((chess-castling-queen? rights (quote white)) "Q") (t ""))
                (string-append
                  (cond ((chess-castling-king? rights (quote black)) "k") (t ""))
                  (cond ((chess-castling-queen? rights (quote black)) "q") (t "")))))))
      (cond ((string-empty? text) "-") (t text)))))

(def chess-fen-print-ep
  (lambda (ep)
    (cond ((eq ep chess-empty) "-")
          (t (string-append (chess-fen-file-string (chess-file ep))
               (number->string (+ (chess-rank ep) 1)))))))

(def chess-position-to-fen
  (lambda (position)
    (string-append
      (chess-fen-print-board (chess-position-board position) 7 "")
      (string-append " "
        (string-append
          (cond ((eq (chess-position-side position) (quote white)) "w") (t "b"))
          (string-append " "
            (string-append (chess-fen-print-castling (chess-position-castling position))
              (string-append " "
                (string-append (chess-fen-print-ep (chess-position-ep position))
                  (string-append " "
                    (string-append (number->string (chess-position-halfmove position))
                      (string-append " "
                        (number->string (chess-position-fullmove position))))))))))))))
