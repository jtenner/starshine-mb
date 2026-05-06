---
kind: research
status: supported
last_reviewed: 2026-05-06
sources:
  - ../binaryen/2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../binaryen/passes/strip-toolchain-annotations/index.md
  - ../../binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md
  - ../../binaryen/passes/strip-toolchain-annotations/implementation-structure-and-tests.md
  - ../../binaryen/passes/strip-toolchain-annotations/wat-shapes.md
  - ../../binaryen/passes/strip-toolchain-annotations/starshine-strategy.md
  - ../../binaryen/passes/strip-toolchain-annotations/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/lib/types.mbt
  - ../../../../src/wast/parser.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../src/wast/module_wast_tests.mbt
related:
  - ../../binaryen/passes/strip-target-features/index.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/instrument-locals/index.md
---

# `strip-toolchain-annotations` current-main recheck and freshness refresh

## Why this follow-up exists

The `strip-toolchain-annotations` dossier was already source-correct, but its freshness layer still stopped at the 2026-04-26 port-readiness capture.
This follow-up records a 2026-05-06 current-main recheck so the living pages can carry a fresher provenance layer and keep the function-annotation subset / expression-annotation parity split explicit.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/StripToolchainAnnotations.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/strip-toolchain-annotations.wast`
  - `CHANGELOG.md`
- Comparison anchors on `version_129`:
  - the same owner, registration, lit, and changelog files
- Existing living dossier pages for the pass family

## Source-backed Binaryen conclusions

- Current `main` still matches the corrected `version_129` teaching contract on the reviewed surfaces.
- The pass remains a function-parallel metadata cleanup pass, not an expression optimizer.
- `removableIfUnused`, `jsCalled`, and `idempotent` are still the source-backed removed annotation bits.
- The lit file still proves removal for `@binaryen.removable.if.unused` and `@binaryen.idempotent`, plus preservation of `@metadata.code.inline`.
- No teaching-relevant current-main drift was found.

## Starshine local status

The local status is unchanged by this source refresh:

- `strip-toolchain-annotations` remains upstream-only in the registry;
- the current Starshine annotation surface is still `FuncAnnotationSec` plus WAT parsing/lowering for function and function-import annotations;
- the safest first implementation slice is still a module pass over that local function-annotation section;
- full Binaryen parity still needs a deliberate answer for per-expression annotation coverage.

## Living page updates from this follow-up

Updated or refreshed:

- `docs/wiki/raw/binaryen/2026-05-06-strip-toolchain-annotations-current-main-recheck.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/index.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/wat-shapes.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-strategy.md`
- `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the 2026-04-24 source capture and the 2026-04-26 port-readiness bridge.
It does not change the contract story; it only refreshes provenance and exact local code anchors while keeping the upstream-only status explicit.
