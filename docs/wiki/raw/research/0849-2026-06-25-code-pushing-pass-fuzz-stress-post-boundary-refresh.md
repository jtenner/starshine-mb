---
kind: research
status: supported
created: 2026-06-25
sources:
  - ./0848-2026-06-25-code-pushing-multilabel-br-table-boundary.md
  - ./0847-2026-06-25-code-pushing-all-post-boundary-refresh.md
  - ../../../binaryen/passes/code-pushing/fuzzing.md
  - ../../../binaryen/passes/code-pushing/starshine-port-readiness-and-validation.md
---

# Code Pushing `pass-fuzz-stress` Post-Boundary Refresh

## Question

After the multi-label `br_table` boundary slice, is the broad named GenValid lane for direct `code-pushing` still green with the current native Starshine binary?

## Command

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 10000 \
  --seed 0x5555 \
  --pass code-pushing \
  --gen-valid-profile pass-fuzz-stress \
  --normalize local-cleanup-debris \
  --out-dir .tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-ww \
  --jobs auto \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

Output directory: `.tmp/pass-fuzz-code-pushing-pass-fuzz-stress-10000-20260625-post-ww`.

- requested cases: `10000`
- compared cases: `10000/10000`
- normalized matches: `10000`
- cleanup-normalized matches: `0`
- raw mismatches: `0`
- validation failures: `0`
- generator failures: `0`
- property failures: `0`
- command failures: `0`
- jobs: `16`
- cache: `wasm-smith 0 hits/0 misses`; Binaryen `10000 hits/0 misses`; Binaryen failures `0 hits/0 misses`
- selected profile counts from the GenValid manifest: `pass-fuzz-stress: 10000`

## Classification

This is broad named-profile closeout-progress evidence for `[O4Z-AUDIT-CP]`, refreshed after the multi-label `br_table` boundary test/docs slice. It is not final closeout by itself: source-backed gaps or accepted boundaries, the explicit wasm-smith lane, the regular 100000 lane, the dedicated `code-pushing-all` lane, and an explicit stop condition must all be then-current before closure.

No behavior/profile change landed in the preceding `[O4Z-AUDIT-CP-WW]` slice, so the earlier regular GenValid 100000 and dedicated `code-pushing-all` 10000 lanes remain relevant. If future behavior or profile changes land, rerun affected lanes before final closeout.
