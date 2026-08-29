; UCI adapter for the my-lisp chess engine (chess-lisp-zero) — batch mode.
; Reads UCI commands from stdin (one line each via (read)), dispatches over
; the shared UCI core (tools/uci-lib.wsm), appends UCI response lines to the
; session transcript. The host my-lisp CLI flushes the transcript to stdout
; at end of run — this mode is transcript/EOF-buffered, not live-sreaming;
; for live per-command streaming use tools/uci-differential.py against a
; private `my-lisp --tcp` REPL (docs/UCI-ADAPTER.md).
;
; Usage from the repo root:
;   printf 'uci\nisready\nposition startpos\ngo depth 1\nquit\n' \
;     | my-lisp tools/uci-adapter.wsm

(load "tools/uci-lib.wsm")

(uci-loop)
