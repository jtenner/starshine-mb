# `optimize-casts` Starshine port-readiness source check

_Date:_ 2026-05-06  
_Status:_ filed-back research note  
_Related living pages:_ `docs/wiki/binaryen/passes/optimize-casts/`

## Question

What is the narrowest faithful first Starshine slice for Binaryen `optimize-casts`, and what current source surfaces should the living wiki keep pointing at?

## Findings

- Current Binaryen `main` still matches the reviewed `version_129` contract on the checked surfaces.
- The upstream pass is still a GC-gated, function-parallel rewrite over **`ref.cast`** and **`ref.as_non_null`** only.
- The strict half still relies on linear-execution/effect barriers so earlier motion does not change trap timing.
- The looser half still reuses an already-computed cast through a fresh refined local and later `local.get`s.
- `ref.test` remains outside the reviewed upstream contract, so the backlog wording should not be widened silently.

## Source anchors checked

- Binaryen current-main `OptimizeCasts.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp#L1479-L1523>
  - early-cast motion setup and linear-window tracking
- Binaryen current-main `OptimizeCasts.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp#L1798-L1816>
  - later-reuse setup with adjacent-block connectivity
- Binaryen current-main `OptimizeCasts.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp#L1919-L1938>
  - `ref.as_non_null` handling and the non-nullable-target guard
- Binaryen current-main `OptimizeCasts.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OptimizeCasts.cpp#L2009-L2040>
  - `ref.cast` candidate selection and most-refined-cast preference
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L2879-L2884>
  - public registration and default no-DWARF cluster placement
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp#L3533-L3542>
  - nested rerun placement after inlining-oriented changes
- Binaryen current-main `optimize-casts.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast#L4028-L4032>
  - `ref.as_non_null` positive coverage
- Binaryen current-main `optimize-casts.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/optimize-casts.wast#L3713-L3908>
  - motion barriers, same-index write invalidation, and unsupported-family coverage

## Filed-back changes

- Planned a dedicated Starshine port-readiness / validation page for `optimize-casts`.
- Kept the living `optimize-casts` dossier scoped to the reviewed upstream contract instead of the broader backlog wording.
- Added the current-main source anchors above so future readers can verify the exact pass behavior without re-deriving the file map.

## Blocker

The run started with unrelated local changes in `agent-todo.md`, validation proof files, and untracked temp commit notes. Those were left untouched.
