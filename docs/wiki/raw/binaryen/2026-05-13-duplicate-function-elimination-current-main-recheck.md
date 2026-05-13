# Binaryen `duplicate-function-elimination` current-main recheck

_Status:_ immutable focused source recheck and code-map refresh for the `docs/wiki/binaryen/passes/duplicate-function-elimination/` dossier

This file captures a 2026-05-13 current-`main` recheck of the upstream `duplicate-function-elimination` surfaces. It narrows the earlier provenance to two questions:

- did current `main` drift in any teaching-relevant way from the existing Binaryen `version_129` contract?
- did the exact local Starshine code anchors used by the living dossier need a freshness refresh?

## Pages this manifest supports

- `docs/wiki/binaryen/passes/duplicate-function-elimination/index.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/wat-shapes.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/starshine-strategy.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/scheduler-validation-and-parity.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/type-compaction-and-metadata.md`
- `docs/wiki/binaryen/passes/duplicate-function-elimination/parity.md`

## Primary sources rechecked

Official Binaryen current-main primary sources:

- `src/passes/DuplicateFunctionElimination.cpp#L514-L638`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp>
- `src/passes/pass.cpp#L3612-L3733`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/ir/function-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/function-utils.h>
- `src/ir/hashed.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/hashed.h>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- dedicated lit tests:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_all-features.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_annotations.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_branch-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level%3D1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/duplicate-function-elimination_optimize-level%3D2.wast>

Local Starshine sources rechecked:

- `src/passes/optimize.mbt:241-242`
- `src/passes/pass_manager.mbt:8672-8673`
- `src/passes/duplicate_function_elimination.mbt:3245-3535`
- `src/passes/duplicate_function_elimination_test.mbt:99-848`

## Source-backed findings

- Binaryen current `main` still presents DFE as the same small whole-module duplicate-function pass documented in the living dossier: candidate hashing, exact equality within hash buckets, earliest survivor selection, reference rewrites, and an optimization-level-dependent repeat budget.
- Binaryen current `main` still schedules DFE twice in the default no-DWARF optimization path: once at the start of global pre-passes and once in global post-passes after DAE/inlining can expose more duplicates.
- Binaryen current `main` still buckets only defined functions, exact-compares functions in hash groups with `FunctionUtils::equal`, removes later duplicates, and calls `OptUtils::replaceFunctions` for the module-wide function-reference rewrite.
- The only reviewed current-main drift remains non-semantic: the duplicate-name set uses `std::unordered_set<Name>` instead of `std::set<Name>`.
- Starshine still registers and dispatches `duplicate-function-elimination` as an active module pass, but the public `optimize` and `shrink` presets still omit it.
- Starshine still performs one explicit duplicate-elimination iteration and then local extra cleanup: compactable element-segment canonicalization, name-section stripping, duplicate simple function-type compaction, broad type-index repair, and annotation/type-name repair.

## Documentation action

Use this recheck as the current-main freshness anchor for the living DFE folder, especially the overview, Binaryen strategy, implementation/test map, Starshine strategy, scheduler/validation bridge, type-compaction split, and parity pages.

## Uncertainties and caveats

- This recheck focused on DFE owner, scheduler, representative optimize-level lit behavior, and local code surfaces. It was not a full line-by-line diff of every helper transitively used by `FunctionUtils::equal` or `OptUtils::replaceFunctions`.
- The Starshine extra cleanup bundle may remain useful even though it is broader than upstream DFE. The validation page records it as a local policy and not as Binaryen behavior.
- Preset scheduling remains intentionally open until Starshine has a decision on multi-round DFE parity and ordered no-DWARF replay evidence.
