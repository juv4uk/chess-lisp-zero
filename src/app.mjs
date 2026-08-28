import initWasm, * as wasm from "./generated/wasm/my_lisp_wasm.js";
import { ChessApi } from "./chess-api.mjs";

const PIECES = { r: "♜", n: "♞", b: "♝", q: "♛", k: "♚", p: "♟", R: "♖", N: "♘", B: "♗", Q: "♕", K: "♔", P: "♙" };
const boardElement = document.querySelector("#board");
const statusElement = document.querySelector("#status");
const fenElement = document.querySelector("#fen");
const turnElement = document.querySelector("#turn");
const resetButton = document.querySelector("#reset");
let api;
let state;
let legalMoves = [];
let selected = null;

function squareFor(row, column) { return (7 - row) * 8 + column; }

function boardFromFen(fen) {
  const pieces = new Map();
  const rows = fen.split(" ", 1)[0].split("/");
  if (rows.length !== 8) throw new Error("invalid board field returned by chess API");
  rows.forEach((rank, row) => {
    let column = 0;
    for (const token of rank) {
      if (/^[1-8]$/.test(token)) column += Number(token);
      else { pieces.set(squareFor(row, column), token); column += 1; }
    }
    if (column !== 8) throw new Error("invalid rank returned by chess API");
  });
  return pieces;
}

function targetsFor(square) { return new Set(legalMoves.filter((move) => move.from === square).map((move) => move.to)); }

function render() {
  const pieces = boardFromFen(state.fen);
  const targets = selected == null ? new Set() : targetsFor(selected);
  boardElement.replaceChildren();
  for (let row = 0; row < 8; row += 1) {
    for (let column = 0; column < 8; column += 1) {
      const square = squareFor(row, column);
      const cell = document.createElement("button");
      cell.type = "button";
      cell.className = `cell ${(row + column) % 2 === 0 ? "light" : "dark"}`;
      if (square === selected) cell.classList.add("selected");
      if (targets.has(square)) cell.classList.add("target");
      cell.dataset.square = String(square);
      cell.setAttribute("aria-label", `square ${square}`);
      const piece = pieces.get(square);
      if (piece) cell.textContent = PIECES[piece] ?? "";
      cell.addEventListener("click", () => selectSquare(square));
      boardElement.appendChild(cell);
    }
  }
  fenElement.textContent = state.fen;
  turnElement.textContent = state.terminal === "ongoing" ? `Хід: ${state.side}` : state.terminal;
  statusElement.textContent = state.terminal === "ongoing" ? "Оберіть фігуру: зеленим позначаються ходи, обчислені my-lisp." : `Партія завершена: ${state.terminal}`;
  statusElement.classList.remove("error");
}

function selectSquare(square) {
  if (state.terminal !== "ongoing") return;
  if (selected == null) {
    if (legalMoves.some((move) => move.from === square)) selected = square;
    render();
    return;
  }
  const candidates = legalMoves.filter((move) => move.from === selected && move.to === square);
  if (candidates.length === 0) {
    selected = legalMoves.some((move) => move.from === square) ? square : null;
    render();
    return;
  }
  const move = candidates.find((candidate) => candidate.promotion === "q") ?? candidates[0];
  state = api.applyMove(move);
  legalMoves = state.terminal === "ongoing" ? api.legalMoves() : [];
  selected = null;
  render();
}

async function readSource(name) {
  const response = await fetch(`./generated/lisp/${name}`);
  if (!response.ok) throw new Error(`cannot load ${name}: HTTP ${response.status}`);
  return response.text();
}

async function start() {
  try {
    await initWasm();
    api = new ChessApi(wasm, { chess: await readSource("chess.my"), fen: await readSource("fen.wsm"), api: await readSource("wasm-api.wsm") });
    state = api.init();
    legalMoves = api.legalMoves();
    render();
  } catch (error) {
    statusElement.textContent = `Помилка запуску: ${error instanceof Error ? error.message : error}`;
    statusElement.classList.add("error");
  }
}

resetButton.addEventListener("click", () => {
  if (!api) return;
  state = api.initialPosition();
  legalMoves = api.legalMoves();
  selected = null;
  render();
});

await start();
