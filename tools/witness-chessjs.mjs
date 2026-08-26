// chess.js witness for CHESS-LISP-ZERO-CHESSJS-DIFFERENTIAL.
//
// Runs OUT-OF-TREE against the vendored BSD-2-Clause chess.js copy from
// chess-tauri-zero. Nothing here copies vendor code into this repository;
// we only record computed results plus tool identity in the evidence
// output. chess.js is a WITNESS, not a semantic authority.
//
// Usage:
//   node tools/witness-chessjs.mjs <fixtures-in.json> <witness-out.json>
//
// Input:  { "cases": [ { "id": ..., "fen": "..." }, ... ] }
// Output: { "witness": {...provenance...},
//           "results": [ { "id", "fen",
//                          "moves": ["1234"-style none — see below],
//                          "perft1" } ] }
//
// Move normalization: every legal move is emitted as a pair [from,to]
// of 0..63 square indices with a1=0, b1=1, ..., h8=63 — identical to
// lib/chess.my indexing (chess-square: file + rank*8).

import { createRequire } from "node:module";
import { readFileSync, writeFileSync } from "node:fs";

const VENDOR_CHESS_JS =
  "/home/agents/GitHub/chess-tauri-zero/app/web/vendor/chess.js";

const require = createRequire(import.meta.url);
const chessjs = await import(VENDOR_CHESS_JS);
const Chess = chessjs.Chess;

function sq(name) {
  // "a1" -> 0 ; "h8" -> 63
  const file = name.charCodeAt(0) - 97; // a..h -> 0..7
  const rank = Number(name[1]) - 1;     // 1..8 -> 0..7
  return rank * 8 + file;
}

function sha256Hex(buf) {
  return createRequire(import.meta.url)("node:crypto")
    .createHash("sha256").update(buf).digest("hex");
}

const [inPath, outPath] = process.argv.slice(2);
if (!inPath || !outPath) {
  console.error("usage: witness-chessjs.mjs <in.json> <out.json>");
  process.exit(2);
}

const input = JSON.parse(readFileSync(inPath, "utf8"));
let version = "unknown";
try {
  const pkgUri = new URL("../../chess-tauri-zero/app/web/vendor/chess.js", import.meta.url);
  void pkgUri;
} catch {}

const results = [];
for (const c of input.cases) {
  const game = new Chess();
  let ok = true;
  try {
    game.load(c.fen, { skipValidation: false });
  } catch {
    results.push({ id: c.id, fen: c.fen, error: "invalid-fen-per-witness" });
    continue;
  }
  // Normalized moves: sorted [from,to] numeric pairs, deduped.
  const pairs = new Set();
  for (const m of game.moves({ verbose: true })) {
    pairs.add(JSON.stringify([sq(m.from), sq(m.to)]));
  }
  const moves = [...pairs].map((s) => JSON.parse(s)).sort(
    (a, b) => a[0] * 64 + a[1] - (b[0] * 64 + b[1])
  );
  const rec = { id: c.id, fen: c.fen, moves, perft1: moves.length };
  // Witness-side perft up to requested depth (cheap in JS).
  if (c.perft_depth && c.perft_depth >= 2) {
    rec.perft = {};
    for (let d = 1; d <= c.perft_depth; d++) {
      rec.perft[d] = game.perft(d);
    }
  }
  results.push(rec);
}

const vendorBuf = readFileSync(VENDOR_CHESS_JS);
const output = {
  witness: {
    name: "chess.js (vendored from chess-tauri-zero)",
    vendor_path: VENDOR_CHESS_JS,
    vendor_sha256: sha256Hex(vendorBuf),
    license: "BSD-2-Clause (Jeff Hlywa) — witness use only, not copied into repo",
    role: "WITNESS-NOT-AUTHORITY",
    node_version: process.version,
    generated_at: new Date().toISOString(),
  },
  results,
};

writeFileSync(outPath, JSON.stringify(output, null, 2));
console.log(`witness done: ${results.length} cases -> ${outPath}`);
