; Typed, JSON-safe adapter around the authoritative chess library.
; Chess rules remain in chess.my; this file only owns session state and
; serialization for WASM/Tauri consumers.

(def chess-api-state (vector (chess-initial-position)))

(def chess-api-position
  (lambda () (vector-ref chess-api-state 0)))

(def chess-api-reset
  (lambda ()
    ((lambda ()
       (vector-set! chess-api-state 0 (chess-initial-position))
       (chess-api-state-json)))))

(def chess-api-promotion-json
  (lambda (promotion)
    (cond ((eq promotion chess-empty) "null")
          (t (string-append "\""
               (string-append (symbol->string promotion) "\""))))))

(def chess-api-move-json
  (lambda (move)
    (string-append "{\"from\":"
      (string-append (number->string (chess-move-from move))
        (string-append ",\"to\":"
          (string-append (number->string (chess-move-to move))
            (string-append ",\"promotion\":"
              (string-append
                (chess-api-promotion-json (chess-move-promotion move))
                "}"))))))))

(def chess-api-moves-json-rest
  (lambda (moves first)
    (cond ((atom moves) "]")
          (t (string-append
               (cond (first "") (t ","))
               (string-append (chess-api-move-json (car moves))
                 (chess-api-moves-json-rest (cdr moves) (quote ()))))))))

(def chess-api-legal-moves-json
  (lambda ()
    (string-append "["
      (chess-api-moves-json-rest
        (chess-legal-moves (chess-api-position)) t))))

(def chess-api-move-member?
  (lambda (needle moves)
    (cond ((atom moves) (quote ()))
          ((equal? needle (car moves)) t)
          (t (chess-api-move-member? needle (cdr moves))))))

(def chess-api-state-json
  (lambda ()
    (let ((position (chess-api-position)))
      (string-append "{\"fen\":\""
        (string-append (chess-position-to-fen position)
          (string-append "\",\"side\":\""
            (string-append
              (symbol->string (chess-position-side position))
              (string-append "\",\"terminal\":\""
                (string-append
                  (symbol->string (chess-terminal-state position))
                  "\"}")))))))))

(def chess-api-apply-move
  (lambda (from to promotion)
    (let ((move
            (cond ((eq promotion chess-empty) (chess-move from to))
                  (t (chess-promotion-move from to promotion)))))
      (cond ((chess-api-move-member? move
               (chess-legal-moves (chess-api-position)))
             ((lambda ()
                (vector-set! chess-api-state 0
                  (chess-apply-move (chess-api-position) move))
                (chess-api-state-json))))
            (t "{\"error\":\"illegal-move\"}")))))

(def chess-api-terminal-json
  (lambda ()
    (string-append "{\"terminal\":\""
      (string-append
        (symbol->string (chess-terminal-state (chess-api-position)))
        "\"}"))))
