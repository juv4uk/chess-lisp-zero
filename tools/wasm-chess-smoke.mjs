import fs from "node:fs";
import path from "node:path";
import { pathToFileURL } from "node:url";
import assert from "node:assert/strict";
import { ChessApi } from "../src/chess-api.mjs";

const packageDirectory = process.argv[2];
if (!packageDirectory) throw new Error("usage: node tools/wasm-chess-smoke.mjs <wasm-package>");

const wasm = await import(pathToFileURL(path.resolve(packageDirectory, "my_lisp_wasm.js")));
const api = new ChessApi(wasm, {
  chess: fs.readFileSync("lib/chess.my", "utf8"),
  fen: fs.readFileSync("lib/fen.wsm", "utf8"),
  api: fs.readFileSync("lib/wasm-api.wsm", "utf8"),
});

const initial = api.init();
assert.equal(initial.side, "white");
assert.equal(initial.terminal, "ongoing");
assert.equal(api.legalMoves().length, 20);

const afterE2E4 = api.applyMove({ from: 12, to: 28 });
assert.equal(afterE2E4.side, "black");
assert.equal(afterE2E4.fen, "rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq e3 0 1");
assert.deepEqual(api.terminalStatus(), { terminal: "ongoing" });
assert.throws(() => api.applyMove({ from: 0, to: 63 }), /illegal-move/);
assert.equal(api.terminalStatus().terminal, "ongoing");

console.log("CHESS-WASM-NODE-PASS");
