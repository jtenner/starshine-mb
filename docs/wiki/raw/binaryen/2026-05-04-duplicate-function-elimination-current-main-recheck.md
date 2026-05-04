---
kind: raw-source
status: supported
last_reviewed: 2026-05-04
source_type: current-main-recheck
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_annotations.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level%3D1.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level%3D2.wast
  - ../../binaryen/passes/duplicate-function-elimination/index.md
  - ../../binaryen/passes/duplicate-function-elimination/binaryen-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/implementation-structure-and-tests.md
  - ../../binaryen/passes/duplicate-function-elimination/wat-shapes.md
  - ../../binaryen/passes/duplicate-function-elimination/starshine-strategy.md
  - ../../binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md
  - ../../binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md
  - ../../binaryen/passes/duplicate-function-elimination/parity.md
  - ../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/optimize.mbt
---

# Duplicate function elimination current-main recheck

## Capture purpose

This manifest records a focused 2026-05-04 recheck of official Binaryen current `main` and local Starshine code for `duplicate-function-elimination`.

The existing DFE dossier already explains the upstream algorithm, the current Starshine module implementation, the local extra cleanup bundle, and the scheduler/validation bridge. This recheck only verifies that the current-main upstream owner, scheduler, helper, and lit-test surfaces still match the existing source-backed contract.

## Primary sources checked

Official Binaryen current-main primary sources:

- `src/passes/DuplicateFunctionElimination.cpp:524-646`
- `src/passes/pass.cpp:3606-3625` and `:3710-3725`
- `src/ir/function-utils.h:413-482`
- `src/ir/hashed.h:499-519`
- `src/passes/opt-utils.h:603-638`
- `test/lit/passes/duplicate-function-elimination_all-features.wast`
- `test/lit/passes/duplicate-function-elimination_annotations.wast`
- `test/lit/passes/duplicate-function-elimination_branch-hints.wast`
- `test/lit/passes/duplicate-function-elimination_optimize-level=1.wast`
- `test/lit/passes/duplicate-function-elimination_optimize-level=2.wast`

Local Starshine sources checked:

- `src/passes/optimize.mbt:254`
- `src/passes/pass_manager.mbt:8701-8702`
- `src/passes/duplicate_function_elimination.mbt:3245-3535`
- `src/passes/duplicate_function_elimination_test.mbt:99-848`

## Source-backed findings

- Binaryen current `main` still presents DFE as the same small whole-module duplicate-function pass documented in the living dossier: candidate hashing, exact equality within hash buckets, earliest survivor selection, reference rewrites, and an optimization-level-dependent repeat budget.
- Binaryen current `main` still schedules DFE twice in the default no-DWARF optimization path: once at the start of global pre-passes and once in global post-passes after DAE/inlining can expose more duplicates.
- Binaryen current `main` still buckets only defined functions, exact-compares functions in hash groups with `FunctionUtils::equal`, removes later duplicates, and calls `OptUtils::replaceFunctions` for the module-wide function-reference rewrite.
- The only checked current-main drift remains non-semantic: the duplicate-name set changed from `std::set<Name>` to `std::unordered_set<Name>`.
- Starshine still registers and dispatches `duplicate-function-elimination` as an active module pass, but the public `optimize` and `shrink` presets still omit it.
- Starshine still performs one explicit duplicate-elimination iteration and then local extra cleanup: compactable element-segment canonicalization, name-section stripping, duplicate simple function-type compaction, broad type-index repair, and annotation/type-name repair.

## Documentation action

Use this recheck as the current-main freshness anchor for the living DFE folder, especially the overview, Binaryen strategy, implementation/test map, Starshine strategy, scheduler/validation bridge, type-compaction split, and parity pages.

## Uncertainties and caveats

- This recheck focused on DFE owner, scheduler, representative optimize-level lit behavior, and local code surfaces. It was not a full line-by-line diff of every helper transitively used by `FunctionUtils::equal` or `OptUtils::replaceFunctions`.
- The Starshine extra cleanup bundle may remain useful even though it is broader than upstream DFE. The validation page records it as a local policy and not as Binaryen behavior.
- Preset scheduling remains intentionally open until Starshine has a decision on multi-round DFE parity and ordered no-DWARF replay evidence.
