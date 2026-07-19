---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/RemoveUnusedModuleElements.cpp
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./parity.md
---

# `remove-unused-module-elements` Fuzzing Profile

Use a freshly built native CLI and the explicit Binaryen v131 oracle.

## Current closeout lanes

For explicit v131 closeout, pin `--wasm-opt-bin` to an official `version_131` `wasm-opt`; the PATH oracle may be stale. Copyable guidance uses `bun fuzz compare-pass` so wrapper defaults stay centralized.

- Regular GenValid, seed `0x5eed`, `.tmp/rume-v131-regular-100000`: `100000/100000` normalized, zero failures.
- Explicit wasm-smith, seed `0x5eed`, `.tmp/rume-v131-wasm-smith-10000-final`: `9956/10000` compared, `9955` normalized, one classified smaller Starshine unused-memory cleanup, `44` Binaryen/tool command failures, zero Starshine command/validation/property failures.
- Random all-profiles, seed `0x5555`, `.tmp/rume-v131-random-all-10000`: `10000/10000` normalized, zero failures.

There is no dedicated RUME GenValid aggregate yet. Do **not** use `pass-cleanup` as a RUME-specific closeout lane: it floods with large-body local/`tee` expression-shape differences unrelated to module-element keep/drop. The pass-specific replacement is the focused matrix in `src/passes/remove_unused_module_elements_test.mbt`, covering callable table defaults, wrong-type/no-default removal, default trap preservation, TNH removal, overlapping null/wrong-type writes, trap-only body nullification, subtype matching, and recursive-group validity.

Exact upstream-shaped comparisons are preserved under `.tmp/rume-v131-*-compare*` and `.tmp/rume-v131-overlap-null-*`. The first and second early O4z neighborhoods under `.tmp/rume-v131-o4z-neighborhood/` are canonical/normalized equal. Earlier `case-004700` evidence also records a deliberate Starshine win: full-u64 memory64 bounds avoid Binaryen's `Index(initial << pageSizeLog2)` truncation false-positive.
