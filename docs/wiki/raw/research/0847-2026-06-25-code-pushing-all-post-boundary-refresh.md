---
title: Code-pushing all-profile post-boundary 10000 refresh
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
  - ./0846-2026-06-25-code-pushing-br-on-null-prefix-boundary.md
---

# Code-pushing all-profile post-boundary 10000 refresh

## Slice

`[O4Z-AUDIT-CP-VV]` refreshes the dedicated `code-pushing-all` 10000-case lane after the docs-only `br_on_null` prefix-payload boundary probe. No Starshine behavior or GenValid profile implementation changed in this slice.

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5eed \
  --pass code-pushing \
  --gen-valid-profile code-pushing-all \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-all-10000-20260625-post-uu \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

- Requested: `10000`
- Compared: `10000/10000`
- Normalized matches: `4769`
- Cleanup-normalized matches: `5231`
- Raw mismatches: `0`
- Validation failures: `0`
- Generator failures: `0`
- Property failures: `0`
- Command failures: `0`
- Jobs: `16`
- Cache: wasm-smith `0 hits/0 misses`; Binaryen `10000 hits/0 misses`; Binaryen failures `0 hits/0 misses`

Selected profile counts:

| Leaf | Count |
| --- | ---: |
| `code-pushing-after-if` | 558 |
| `code-pushing-br-if` | 537 |
| `code-pushing-br-if-value` | 516 |
| `code-pushing-br-on-cast` | 565 |
| `code-pushing-br-on-cast-fail` | 526 |
| `code-pushing-br-on-non-null` | 555 |
| `code-pushing-br-on-non-null-prefix` | 513 |
| `code-pushing-br-on-null` | 524 |
| `code-pushing-dropped-if` | 510 |
| `code-pushing-if-arm` | 504 |
| `code-pushing-loop-br-if` | 511 |
| `code-pushing-multi-set` | 507 |
| `code-pushing-multi-set-br-if` | 511 |
| `code-pushing-multi-set-drop-window` | 504 |
| `code-pushing-multi-set-dropped-if` | 530 |
| `code-pushing-multi-set-global-get-window` | 554 |
| `code-pushing-multi-set-local-copy` | 520 |
| `code-pushing-multi-set-local-get-window` | 515 |
| `code-pushing-multi-set-nop-window` | 540 |

## Classification

Agent classification: current dedicated-profile closeout-progress lane remains green under the documented narrow `local-cleanup-debris` normalizer. The cleanup-normalized cases are local cleanup/lowering debris, not harness-proven semantic equivalence; their acceptance relies on the earlier inspected normalizer slices and targeted lane evidence.

This supersedes the same-day `.tmp/pass-fuzz-code-pushing-all-10000-20260625-current` dedicated lane only for freshness after `[O4Z-AUDIT-CP-UU]`. It does not close `[O4Z-AUDIT-CP]`: remaining source gaps/accepted boundaries and the final matrix/stop condition must still be then-current.
