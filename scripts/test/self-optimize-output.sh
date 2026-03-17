#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

mkdir -p \
  "$tmpdir/bin" \
  "$tmpdir/scripts" \
  "$tmpdir/_build/native/release/build/cmd"

cp "$repo_root/scripts/self-optimize.sh" "$tmpdir/scripts/self-optimize.sh"
chmod +x "$tmpdir/scripts/self-optimize.sh"

cat >"$tmpdir/bin/moon" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$tmpdir/bin/moon"

cat >"$tmpdir/_build/native/release/build/cmd/cmd" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'optimizer trace\n'
printf 'repro: starshine --dead-code-elimination --vacuum before.wasm\n' >&2
exit 0
EOF
chmod +x "$tmpdir/_build/native/release/build/cmd/cmd"

output="$(
  cd "$tmpdir" &&
    PATH="$tmpdir/bin:$PATH" \
    MOON_BIN="$tmpdir/bin/moon" \
    SELF_OPT_OUTPUT_LOG="$tmpdir/output.log" \
    bash scripts/self-optimize.sh 2>&1
)"

if [[ "$output" != *"repro: starshine --dead-code-elimination --vacuum before.wasm"* ]]; then
  printf 'expected terminal output to include repro command, got:\n%s\n' "$output" >&2
  exit 1
fi

if [[ ! -f "$tmpdir/output.log" ]]; then
  printf 'expected output log to be written\n' >&2
  exit 1
fi

log_output="$(<"$tmpdir/output.log")"
if [[ "$log_output" != *"repro: starshine --dead-code-elimination --vacuum before.wasm"* ]]; then
  printf 'expected log output to include repro command, got:\n%s\n' "$log_output" >&2
  exit 1
fi
