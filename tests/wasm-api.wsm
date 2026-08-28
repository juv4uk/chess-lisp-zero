(load "lib/chess.my")
(load "lib/fen.wsm")
(load "lib/wasm-api.wsm")

(def api-assert
  (lambda (name actual expected)
    (cond ((equal? actual expected) (print (list (quote pass) name actual)))
          (t ((lambda ()
                (print (list (quote fail) name actual expected))
                (chess-api-test-failure name)))))))

(api-assert (quote initial-state)
  (chess-api-reset)
  "{\"fen\":\"rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1\",\"side\":\"white\",\"terminal\":\"ongoing\"}")

(def initial-moves-json (chess-api-legal-moves-json))
(api-assert (quote initial-moves-open) (string-first initial-moves-json) "[")

(api-assert (quote apply-e2-e4)
  (chess-api-apply-move 12 28 (quote ()))
  "{\"fen\":\"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1\",\"side\":\"black\",\"terminal\":\"ongoing\"}")

(api-assert (quote terminal-after-e2-e4)
  (chess-api-terminal-json)
  "{\"terminal\":\"ongoing\"}")

(api-assert (quote illegal-move-rejected)
  (chess-api-apply-move 0 63 (quote ()))
  "{\"error\":\"illegal-move\"}")

(api-assert (quote illegal-move-preserves-position)
  (chess-api-state-json)
  "{\"fen\":\"rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1\",\"side\":\"black\",\"terminal\":\"ongoing\"}")

(print (quote CHESS-WASM-API-PASS))
