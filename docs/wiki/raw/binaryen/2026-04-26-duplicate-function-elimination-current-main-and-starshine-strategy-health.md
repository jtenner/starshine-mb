---
kind: raw-source
status: supported
last_reviewed: 2026-04-26
source_type: primary-source-manifest
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/tree/main/test/lit/passes
  - ../../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Duplicate function elimination current-main and Starshine strategy health

## Capture purpose

This raw-source manifest records a 2026-04-26 recheck of official Binaryen current `main` for `duplicate-function-elimination` and a local Starshine documentation-health cleanup.

The main local health issue was not a semantic strategy error. It was that the Starshine strategy page still used the stale filename `starshine-hot-ir-strategy.md` even though the page itself correctly says DFE is a module pass, not a HOT-IR pass.

## Primary sources checked

Official Binaryen current-main primary sources:

- `src/passes/DuplicateFunctionElimination.cpp`
- `src/passes/pass.cpp`
- `src/ir/function-utils.h`
- `src/ir/hashed.h`
- `test/lit/passes/` for the existing DFE lit fixtures

Local Starshine sources checked:

- `src/passes/duplicate_function_elimination.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/optimize.mbt`
- `src/passes/duplicate_function_elimination_test.mbt`

## Source-backed findings

- Current Binaryen still presents DFE as the small whole-module duplicate-function pass documented in the existing dossier: candidate hashing, exact equality checks within hash buckets, earliest survivor selection, reference rewrites, and an optimization-level-dependent repeat budget.
- No source-backed reason was found to call upstream DFE a HOT/function-local pass. It remains a whole-module pass because it compares functions against other functions and rewrites module-wide function references.
- Starshine's implementation remains module-dispatched: the registry registers `duplicate-function-elimination` as a module pass, and `pass_manager.mbt` dispatches it through the module-pass path.
- Starshine still intentionally differs from upstream by bundling extra cleanup around the core duplicate-function rewrite: compactable element-segment canonicalization, name-section stripping, duplicate simple function-type compaction, type-index rewrite, and function-annotation/type-name repair.
- The remaining local parity caveat is still the iteration/scheduler gap: Starshine runs one explicit DFE iteration, while Binaryen can repeat according to optimization/shrink settings.

## Documentation-health decision

Rename the living Starshine strategy page to `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-strategy.md` and update local links. Keep older raw/research references to the historical filename unchanged because raw sources are immutable audit records.

## Uncertainties and caveats

- This was a focused current-main recheck, not a full semantic diff of every DFE helper dependency.
- Current-main drift can still happen after 2026-04-26; implementation work should re-open the official owner file before changing parity claims.
- The local extra cleanup bundle may remain pragmatic even though it is broader than upstream DFE proper, but docs should continue to mark that split explicitly.
