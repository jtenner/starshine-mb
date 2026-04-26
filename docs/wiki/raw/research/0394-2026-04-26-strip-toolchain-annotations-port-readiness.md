---
kind: research
status: supported
last_reviewed: 2026-04-26
sources:
  - ../binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../binaryen/passes/strip-toolchain-annotations/index.md
  - ../../binaryen/passes/strip-toolchain-annotations/binaryen-strategy.md
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
  - ../../binaryen/passes/instrument-locals/index.md
  - ../../binaryen/passes/duplicate-function-elimination/index.md
---

# `strip-toolchain-annotations` port-readiness follow-up

## Question

The 2026-04-24 dossier correctly explained Binaryen's `strip-toolchain-annotations` pass, but it still left a future Starshine implementer to infer the safe first local slice, validation ladder, and exact gap between Starshine's current function-annotation surface and Binaryen's broader function-plus-expression annotation model.

## Sources reviewed

- Official Binaryen `main` and `version_129` `StripToolchainAnnotations.cpp`.
- Official Binaryen `main` `pass.cpp` registration.
- Official Binaryen `main` `strip-toolchain-annotations.wast`.
- Official Binaryen `main` `CHANGELOG.md` release-note trail for the toolchain annotation family.
- Local Starshine pass registry, WAT parser/lowering, `FuncAnnotationSec` model, annotation roundtrip tests, and annotation-remap code in DFE/DIE/RUME.

## Findings

- No teaching-relevant current-main drift was found from the 2026-04-24 source contract.
- Binaryen still strips exactly the reviewed toolchain annotation bits from functions and per-expression `codeAnnotations`: `removableIfUnused`, `jsCalled`, and `idempotent`.
- Binaryen's dedicated lit proof still focuses on `@binaryen.removable.if.unused`, `@binaryen.idempotent`, and `@metadata.code.inline` preservation, including mixed annotation order.
- Starshine still has no registry spelling for `strip-toolchain-annotations`; explicit requests remain unknown rather than boundary-only or removed.
- Starshine's local supported annotation storage is currently `FuncAnnotationSec` attached to function/import indices. That is enough for a useful first local slice, but not enough to claim full Binaryen parity over expression-level `codeAnnotations`.
- Local parser/lowering tests cover `binaryen.js.called`, `binaryen.idempotent`, and `metadata.code.inline`; this focused grep did not find a local `binaryen.removable.if.unused` test, so that should be added before or with any active pass.
- DFE, DIE, and RUME already remap or compare annotation entries when function/import indices change, so a future strip pass must be ordered and tested with those module passes in mind.

## Durable wiki updates made

- Added `docs/wiki/raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/strip-toolchain-annotations/starshine-port-readiness-and-validation.md`.
- Refreshed the overview, Binaryen strategy, WAT-shape catalog, implementation/test-map, and Starshine strategy pages so the first-slice module pass, full-parity blocker, exact local code surfaces, and validation ladder are explicit.
- Updated the pass catalog, top-level index, tracker, and wiki log to mark the dossier as deepened.

## Uncertainty

- Binary roundtrip support for Starshine's `FuncAnnotationSec` surface still needs a focused encoder/decoder audit before a port can promise binary parity.
- The local first slice would be useful but deliberately narrower than Binaryen until Starshine has a per-expression annotation representation or documents that it does not intend to support that surface.
- The upstream `jsCalled` strip remains source-backed but less directly lit-backed than the two other removed annotation families.
