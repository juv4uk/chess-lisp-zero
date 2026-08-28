const PURE_LISP_MODE = "lisp";

function decodeJsonString(evaluation) {
  if (!evaluation || typeof evaluation.value !== "string") {
    throw new TypeError("my-lisp WASM evaluation must contain a string value");
  }
  const json = JSON.parse(evaluation.value);
  if (typeof json !== "string") {
    throw new TypeError("chess WSM API must return a JSON string");
  }
  return JSON.parse(json);
}

function square(value, field) {
  if (!Number.isInteger(value) || value < 0 || value > 63) {
    throw new RangeError(`${field} must be an integer in 0..63`);
  }
  return value;
}

function promotion(value) {
  if (value == null) return "(quote ())";
  if (!["q", "r", "b", "n"].includes(value)) {
    throw new RangeError("promotion must be q, r, b, n, or null");
  }
  return `(quote ${value})`;
}

/** Thin typed facade; all chess rules execute inside the persistent WSM session. */
export class ChessApi {
  constructor(wasm, sources) {
    if (typeof wasm?.evaluate !== "function" || typeof wasm?.reset_session !== "function") {
      throw new TypeError("wasm must expose evaluate() and reset_session()");
    }
    this.wasm = wasm;
    this.sources = sources;
    this.initialized = false;
  }

  init() {
    this.wasm.reset_session();
    for (const source of [this.sources.chess, this.sources.fen, this.sources.api]) {
      this.wasm.evaluate(source, PURE_LISP_MODE);
    }
    this.initialized = true;
    return this.initialPosition();
  }

  evaluateJson(source) {
    if (!this.initialized) throw new Error("ChessApi.init() must be called first");
    return decodeJsonString(this.wasm.evaluate(source, PURE_LISP_MODE));
  }

  initialPosition() {
    return this.evaluateJson("(chess-api-reset)");
  }

  legalMoves() {
    return this.evaluateJson("(chess-api-legal-moves-json)");
  }

  applyMove(move) {
    const from = square(move?.from, "from");
    const to = square(move?.to, "to");
    const result = this.evaluateJson(
      `(chess-api-apply-move ${from} ${to} ${promotion(move?.promotion)})`,
    );
    if (result?.error) throw new Error(result.error);
    return result;
  }

  terminalStatus() {
    return this.evaluateJson("(chess-api-terminal-json)");
  }
}
