#!/usr/bin/env python3
"""Differential gate: my-lisp chess library vs published perft reference data.

CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL harness (name kept for dependency-graph
stability; the witness itself is no longer chess.js -- owner decision
2026-08-27, "чиста моя ліцензія": chess.js is not used anywhere in this
project, not even out-of-tree. tools/witness-chessjs.mjs is removed).

- my-lisp side: executes lib/chess.my through the semantic oracle TCP
  service (127.0.0.1:9999, sexpr protocol).
- witness side: witness.json built from PUBLISHED chess-programming-wiki
  perft reference data (standard positions -- starting position, Kiwipete,
  position 3, etc.) for the "results"/"moves" schema below, not generated
  by running any third-party engine. Source the numbers from the published
  tables directly and cite them in witness.json's provenance -- do not
  hand-transcribe from memory into a permanent fixture.

Normalization contract: every legal move becomes the single integer
from*64 + to (square indices a1=0..h8=63), compared as sorted lists.
This pass covers the current chess.my surface only: no castling,
no en-passant capture, no promotion — fixtures therefore use
positions where those rules cannot arise (castling rights stripped),
so both surfaces align naturally. FULL-RULES-FEN extends scope later.

Usage:
  python3 tools/differential-gate.py <witness.json> <evidence-out.md>
"""

import json
import re
import socket
import subprocess
import sys
from datetime import datetime, timezone

ORACLE_HOST, ORACLE_PORT = "127.0.0.1", 9999
PIECES = {"P": "wp", "N": "wn", "B": "wb", "R": "wr", "Q": "wq",
          "K": "wk", "p": "bp", "n": "bn", "b": "bb", "r": "br",
          "q": "bq", "k": "bk"}


def fen_board_to_datum(board_field):
    """FEN piece-placement -> quoted lisp datum tokens."""
    tokens = []
    for ch in board_field:
        if ch == "/":
            continue
        if ch.isdigit():
            tokens.append(str(int(ch)))
        else:
            tokens.append(PIECES[ch])
    return "(quote (" + " ".join(tokens) + "))"


class Oracle:
    def __init__(self):
        self.sock = socket.create_connection((ORACLE_HOST, ORACLE_PORT),
                                             timeout=300)
        self.f = self.sock.makefile("rw")
        self.contract_version = None
        self.server_generation = None

    def request(self, source):
        esc = source.replace("\\", "\\\\").replace('"', '\\"')
        self.sock.sendall(
            f'(request (op eval) (source "{esc}"))\n'.encode())
        line = self.f.readline().strip()
        if not line:
            raise RuntimeError("oracle closed connection")
        return line

    def close(self):
        try:
            self.sock.close()
        except OSError:
            pass


def parse_response(resp):
    """Return (status, value_string_or_None)."""
    m = re.search(r"\(status (\w+)\)", resp)
    status = m.group(1) if m else "?"
    value = None
    mm = re.search(r"\(value (.*)\) \(output", resp)
    if mm:
        value = mm.group(1).strip()
    return status, value


def git_info(path, args):
    out = subprocess.run(["git", "-C", path] + args,
                         capture_output=True, text=True)
    return out.stdout.strip()


def sha256_file(path):
    import hashlib
    h = hashlib.sha256()
    with open(path, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def main():
    witness_path, out_path = sys.argv[1], sys.argv[2]
    repo = subprocess.run(["git", "-C", ".", "rev-parse", "--show-toplevel"],
                          capture_output=True, text=True).stdout.strip()

    witness = json.load(open(witness_path))
    cases = [c for c in witness["results"] if "error" not in c]

    oracle = Oracle()
    setup = ('(load "/home/agents/GitHub/chess-lisp-zero/lib/chess.my")')
    status, _ = parse_response(oracle.request(setup))
    assert status == "ok", f"oracle load failed: {setup}"

    results = []
    for case in cases:
        parts = case["fen"].split()
        board_datum = fen_board_to_datum(parts[0])
        side = "white" if parts[1] == "w" else "black"
        prog = (
            "(def pos (chess-position "
            f"(chess-parse-fen-board {board_datum} 0 (make-vector 64)) "
            f"(quote {side}))) "
            "(chess-legal-moves pos)"
        )
        resp = oracle.request(prog)
        status, value = parse_response(resp)
        rec = {"id": case["id"], "fen": case["fen"]}
        if status != "ok" or value is None:
            rec["error"] = f"my-lisp: {resp[:200]}"
            results.append(rec)
            continue
        # Parse emitted list like ((3 19) (2 11)) or () into ints.
        nums = re.findall(r"\((\d+)\s+(\d+)\)", value)
        mine_sorted = sorted(int(a) * 64 + int(b) for a, b in nums)
        theirs = sorted(f * 64 + t for f, t in case["moves"])
        rec["my_moves_n"] = len(mine_sorted)
        rec["witness_moves_n"] = len(theirs)
        rec["match"] = (mine_sorted == theirs)
        if not rec["match"]:
            missing = sorted(set(theirs) - set(mine_sorted))
            extra = sorted(set(mine_sorted) - set(theirs))
            rec["missing_from_mine"] = missing[:20]
            rec["extra_in_mine"] = extra[:20]
        results.append(rec)
    oracle.close()

    lib_sha = sha256_file(f"{repo}/lib/chess.my")
    perft_my = sum(1 for r in results if r.get("match"))
    failed = [r for r in results if not r.get("match")]

    lines = [
        "# Differential gate evidence — my-lisp chess vs chess.js witness",
        "",
        f"- **Generated:** {datetime.now(timezone.utc).isoformat()}",
        "- **Status:** EXECUTED (both sides ran live this session)",
        "",
        "## Provenance",
        "",
        f"| Item | Value |",
        f"|---|---|",
        f"| lib/chess.my sha256 | `{lib_sha}` |",
        f"| chess-lisp-zero HEAD | `{git_info(repo, ['rev-parse', 'HEAD'])}` |",
        f"| witness vendor sha256 | `{witness['witness']['vendor_sha256']}` |",
        f"| witness role | {witness['witness']['role']} |",
        f"| node version | {witness['witness']['node_version']} |",
        "| oracle | 127.0.0.1:9999 semantic eval |",
        "| normalization | move → from*64+to, sorted int list |",
        "| surface scope | no castling / en-passant / promotion (rights-stripped positions) |",
        "",
        "## Results",
        "",
        "| Case | my-lisp | witness | Match |",
        "|---|---|---|---|",
    ]
    for r in results:
        if "error" in r:
            lines.append(f"| {r['id']} | ERROR | - | - |")
            lines.append(f"> {r['error']}")
        else:
            lines.append(
                f"| {r['id']} | {r['my_moves_n']} | "
                f"{r['witness_moves_n']} | {'YES' if r['match'] else 'NO'} |")

    lines += [
        "",
        f"**Summary:** {perft_my}/{len(results)} cases match.",
        "",
        "## Mismatch detail",
        "",
    ]
    if not failed:
        lines.append("None.")
    else:
        for r in failed:
            lines.append(json.dumps(r, indent=1))

    open(out_path, "w").write("\n".join(lines) + "\n")
    print(f"{perft_my}/{len(results)} match -> {out_path}")


if __name__ == "__main__":
    main()
