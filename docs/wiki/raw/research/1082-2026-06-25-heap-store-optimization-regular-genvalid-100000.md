---
kind: research
status: current
last_reviewed: 2026-06-25
sources:
  - ../../binaryen/passes/heap-store-optimization/fuzzing.md
  - ../../../raw/research/1071-2026-06-25-heap-store-optimization-direct-o4z-refresh.md
  - ../../../raw/research/1077-2026-06-25-heap-store-optimization-no-candidate-unreachable-cleanup.md
  - ../../../raw/research/1078-2026-06-25-heap-store-optimization-wasm-smith-rerun-after-cleanup.md
  - ../../../raw/research/1080-2026-06-25-heap-store-optimization-random-all-profiles-lane.md
  - ../../../../scripts/pass-fuzz-compare.ts
---

# HSO regular GenValid 100000 lane

## Question

Refresh the required regular GenValid closeout lane for direct `heap-store-optimization` after the current native Starshine binary was rebuilt explicitly into `target/native/release/build/cmd/cmd.exe`.

## Commands

Native compare binary refresh:

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

Regular GenValid lane:

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 100000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-genvalid-20260625-100000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

## Result

`result.json` summary:

- requested count: `100000`
- compared count: `100000/100000`
- normalized matches: `100000`
- cleanup-normalized matches: `0`
- mismatches: `0`
- validation failures: `0`
- property failures: `0`
- generator failures: `0`
- command failures: `0`
- jobs: `16`
- seed: `0x5eed`
- generator: `gen-valid`
- GenValid profile: default (`null`), selected profile `binaryen-oracle-portable=100000`
- normalizers: none
- cache: wasm-smith `0/0`; Binaryen `10332` hits / `89668` misses; Binaryen failures `0/0`
- failure dirs: none

## Classification

Agent classification: green direct regular GenValid evidence for the current HSO implementation. This lane had no output-shape drift, cleanup-normalized cases, command failures, validation failures, or semantic mismatches.

This is final-closeout evidence for the required regular GenValid matrix lane, but it is not by itself HSO behavior-parity completion. HSO remains open for the source-backed family review, exact descriptor `ref.cast` surface blocker, allocation-heavy pass-local performance disposition, full Moon validation, and final backlog/docs cleanup.
