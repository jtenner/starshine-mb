---
title: Code-pushing regular GenValid 100000 current evidence
status: supported
date: 2026-06-25
tags:
  - code-pushing
  - fuzzing
  - o4z-audit
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../scripts/pass-fuzz-compare.ts
  - ../../../../src/passes/code_pushing.mbt
---

# Code-pushing regular GenValid 100000 current evidence

## Slice

`[O4Z-AUDIT-CP-TT]` refreshes the required large regular GenValid closeout-progress lane for direct `code-pushing` after the latest boundary-only slices. No behavior or profile implementation changed in this slice.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 100000 \
  --seed 0x5eed \
  --pass code-pushing \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-regular-100000-20260625 \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

The native binary path is the checkout-local release build path documented for this workspace. The run used the default in-repo GenValid generator, not the dedicated `code-pushing-all` profile and not `--wasm-smith`.

## Result

Out dir: `.tmp/pass-fuzz-code-pushing-regular-100000-20260625`.

From `result.json` and the command summary:

| Metric | Value |
| --- | --- |
| Requested count | `100000` |
| Compared count | `100000/100000` |
| Normalized matches | `100000` |
| Cleanup-normalized matches | `0` |
| Raw mismatches | `0` |
| Validation failures | `0` |
| Generator failures | `0` |
| Property failures | `0` |
| Command failures | `0` |
| Jobs | `16` (`--jobs auto`) |
| Seed | `0x5eed` |
| Generator | `gen-valid` |
| GenValid profile | none / regular |
| Selected profile counts | `binaryen-oracle-portable: 100000` |
| Cache | wasm-smith `0 hits/0 misses`; Binaryen `10356 hits/89644 misses`; Binaryen failures `0 hits/0 misses` |
| Normalizers | `local-cleanup-debris` |

## Classification

Agent classification: green regular GenValid closeout-progress evidence. There were no mismatches, no Starshine validation failures, and no command-failure classes to triage.

This is not final `[O4Z-AUDIT-CP]` closeout by itself. The final closeout still needs source-backed gap resolution or explicitly narrow accepted boundaries, then-current focused tests/docs/backlog, the explicit wasm-smith lane, the dedicated `code-pushing-all` lane, the broad named-profile lane, and an explicit stop condition. The existing same-day 10000 wasm-smith, 10000 dedicated `code-pushing-all`, and 10000 broad `pass-fuzz-stress` lanes remain closeout-progress evidence but should be rerun if future behavior/profile changes land before final closeout.
