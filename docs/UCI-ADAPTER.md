# Optional UCI adapter

`tools/uci-lib.wsm` wraps the typed my-lisp chess API with an external UCI
protocol boundary. It does not replace the in-process Tauri API and is not a
language or chess-semantics authority.

## Entry points

- `tools/uci-adapter.wsm` reads batch input. The native CLI flushes its
  transcript at EOF, so this path is useful for scripted batches, not a live
  GUI engine connection.
- `tools/uci-differential.py` starts a private `my-lisp --tcp` session and
  evaluates one framed UCI command per request. State persists inside that
  connection and responses arrive command by command.

Run the live gate from the repository root:

```sh
python3 tools/uci-differential.py
```

The host binary defaults to
`/home/agents/GitHub/my-lisp/target/release/my-lisp`; override it with
`MY_LISP=/path/to/my-lisp`.

## Verified boundary

On 2026-08-29 the live gate passed 26/26 checks. Coverage includes UCI
handshake, readiness, malformed and unknown command survival, new-game reset,
start-position moves, full FEN input, bounded `go` variants, stop/setoption
acknowledgement, quit framing, and published perft anchors:

| Position | d1 | d2 |
|---|---:|---:|
| Kiwipete | 48 | 2039 |
| CPW position 3 | 14 | 191 |
| CPW position 6 | 46 | 2079 |

The adapter is synchronous. `stop` acknowledges that the current search cannot
be interrupted. Time-control fields are accepted but currently select the
bounded depth-1 search rather than implementing clock management.

`--theirs` is an optional environment-dependent comparison hook. It does not
claim byte-for-byte live parity unless the sibling Python engine and its
dependencies are actually available and executed.
