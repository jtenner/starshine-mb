#!/usr/bin/env bash
set -euo pipefail

workflow_file=".github/workflows/examples-cli-native.yml"

if [[ ! -f "$workflow_file" ]]; then
  echo "Missing workflow file: $workflow_file" >&2
  exit 1
fi

require_pattern() {
  local pattern="$1"
  local description="$2"
  if ! rg -q --fixed-strings "$pattern" "$workflow_file"; then
    echo "Workflow contract violation: missing $description" >&2
    echo "Required pattern: $pattern" >&2
    exit 1
  fi
}

require_pattern "WASM_TOOLS_VERSION:" "WASM_TOOLS_VERSION env declaration"
require_pattern "name: Cache wasm-tools cargo install artifacts" "wasm-tools cache step name"
require_pattern "uses: actions/cache@v4" "actions/cache usage"
require_pattern "~/.cargo/bin/wasm-tools" "cached wasm-tools binary path"
require_pattern 'key: ${{ runner.os }}-cargo-wasm-tools-${{ env.WASM_TOOLS_VERSION }}' "cache key tied to WASM_TOOLS_VERSION"
require_pattern 'if [ ! -x "$HOME/.cargo/bin/wasm-tools" ]; then' "guarded install check"
require_pattern 'cargo install wasm-tools --locked --version "$WASM_TOOLS_VERSION"' "versioned wasm-tools install command"
require_pattern 'echo "$HOME/.cargo/bin" >> "$GITHUB_PATH"' "cargo bin path export"

echo "Workflow contract check passed: wasm-tools cache + guarded install wiring is present."
