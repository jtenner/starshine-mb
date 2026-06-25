# 0883 - code-pushing-all post-0881 bounded smoke

Date: 2026-06-25

## Goal

After behavior changed in `0881`, run a bounded dedicated `code-pushing-all` direct-compare smoke before handing off. This is not final closeout evidence; it is a 1000-case aggregate regression check.

## Build

Command:

```sh
moon build --target native --release src/cmd
```

Result: passed with pre-existing pass-manager unused-function warnings. In this workspace the executable is `_build/native/release/build/cmd/cmd.exe`; `target/native/release/build/cmd/cmd.exe` remains absent.

## Compare lane

Command:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --out-dir .tmp/pass-fuzz-code-pushing-all-post-0881-smoke-1000-local-cleanup \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures \
  --normalize local-cleanup-debris
```

Result:

- compared: `1000/1000`
- normalized matches: `466`
- cleanup-/compare-normalized matches: `534`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- cache: wasm-smith `0 hits/0 misses`; Binaryen `1000 hits/0 misses`; Binaryen failures `0 hits/0 misses`

Selected profile details are in the generated manifest under `.tmp/pass-fuzz-code-pushing-all-post-0881-smoke-1000-local-cleanup`.

## Note

An initial exploratory run used `--normalize drop-consts --normalize unreachable-control-debris`, which is not the documented `code-pushing-all` cleanup normalizer. That run compared `1000/1000` with `466` normalized matches and `534` raw mismatches. The correct `--normalize local-cleanup-debris` rerun above classifies the same known local cleanup/lowering debris as cleanup-normalized matches and has zero raw mismatches.

## Closeout status

`[O4Z-AUDIT-CP]` is still active. Final closeout still needs the full post-`0881` matrix:

- regular GenValid `100000`, seed `0x5eed`;
- explicit `--wasm-smith` `10000`, seed `0x5eed`;
- dedicated `code-pushing-all` `10000`, seed `0x5eed`, with `--normalize local-cleanup-debris`;
- broad named `pass-fuzz-stress` `10000`, seed `0x5555`.

The remaining source-backed audit gaps listed in `agent-todo.md` remain open.
