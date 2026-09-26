#!/usr/bin/env bash
set -euo pipefail

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
my_lisp_dir="${MY_LISP_DIR:-$repo_dir/../sens}"
generated_dir="$repo_dir/src/generated"

if [[ ! -f "$my_lisp_dir/crates/sens-wasm/Cargo.toml" ]]; then
  echo "canonical SENS checkout not found: $my_lisp_dir" >&2
  echo "set MY_LISP_DIR to a SENS checkout" >&2
  exit 1
fi

mkdir -p "$generated_dir/wasm" "$generated_dir/lisp"
wasm-pack build "$my_lisp_dir/crates/sens-wasm" --target web --out-name my_lisp_wasm --out-dir "$generated_dir/wasm"
install -m 0644 "$repo_dir/lib/chess.my" "$generated_dir/lisp/chess.my"
install -m 0644 "$repo_dir/lib/fen.wsm" "$generated_dir/lisp/fen.wsm"
install -m 0644 "$repo_dir/lib/wasm-api.wsm" "$generated_dir/lisp/wasm-api.wsm"
echo "WASM chess assets ready: $generated_dir"
