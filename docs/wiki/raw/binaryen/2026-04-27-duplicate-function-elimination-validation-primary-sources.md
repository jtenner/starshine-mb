---
kind: raw-source
status: supported
last_reviewed: 2026-04-27
source_type: primary-source-manifest
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level%3D1.wast
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Duplicate function elimination validation primary sources

## Capture purpose

This manifest records a focused 2026-04-27 recheck of official Binaryen current `main` and local Starshine code for the validation and scheduler gap in `duplicate-function-elimination`.

The existing dossier already explained the Binaryen algorithm and the Starshine module implementation. The missing teaching piece was a compact validation bridge that tells future implementers exactly which behavior is intentionally local, which behavior is upstream-required, and which parity gaps should be tested before DFE is scheduled inside Starshine presets.

## Primary sources checked

Official Binaryen current-main primary sources:

- `src/passes/DuplicateFunctionElimination.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/duplicate-function-elimination_optimize-level=1.wast`

Local Starshine sources checked:

- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/duplicate_function_elimination.mbt`
- `src/passes/duplicate_function_elimination_test.mbt`

## Source-backed findings

- Binaryen still runs DFE as a whole-module pass with an option-dependent repeat budget. Current `main` chooses an effectively unlimited budget for `-O3+` or `-Os+`, a 10-round budget for `-O2`, and one round otherwise.
- Binaryen still schedules DFE twice in the default no-DWARF optimization path: once at the start of global pre-passes and once in global post-passes after DAE/inlining can expose more duplicates.
- Binaryen still buckets only defined functions, exact-compares functions in hash groups with `FunctionUtils::equal`, removes later duplicates, and calls `OptUtils::replaceFunctions` for the module-wide function-reference rewrite.
- Starshine still registers and dispatches `duplicate-function-elimination` as an active module pass, but the public `optimize` and `shrink` presets still omit it.
- Starshine still performs one explicit duplicate-elimination iteration and then local extra cleanup: compactable element-segment canonicalization, name-section stripping, duplicate simple function-type compaction, broad type-index repair, and annotation/type-name repair.

## Documentation action

Add `docs/wiki/binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md` as a living bridge between the existing overview, Binaryen strategy, WAT-shape, Starshine strategy, type-compaction, and parity pages.

## Uncertainties and caveats

- This recheck focused on DFE owner, scheduler, representative optimize-level lit behavior, and local code surfaces. It was not a full line-by-line diff of every helper transitively used by `FunctionUtils::equal` or `OptUtils::replaceFunctions`.
- The Starshine extra cleanup bundle may remain useful even though it is broader than upstream DFE. The validation page records it as a local policy and not as Binaryen behavior.
- Preset scheduling remains intentionally open until Starshine has a decision on multi-round DFE parity and ordered no-DWARF replay evidence.
