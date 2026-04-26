# Binaryen `type-ssa` source correction and current-main check

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source correction for the `docs/wiki/binaryen/passes/type-ssa/` dossier

## Scope

This capture corrects the 2026-04-23 `type-ssa` dossier. The older living pages described `type-ssa` as if it tracked a `createdTypes` map through local/global/control-value SSA-like flows and retagged call operands and returns. A fresh read of the official Binaryen `version_129` sources shows that is not the current public contract.

The real `version_129` pass is a module-level GC type-creation pass: it finds selected `struct.new` and array allocation instructions, creates fresh private subtypes for interesting allocations, rewrites those allocation result types to the fresh exact non-null subtypes, copies type names when available, and refinalizes the module and module-code afterward.

## Official sources consulted

- `TypeSSA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- `type-ssa.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>
- `ReFinalize.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>
- `wasm-type-shape.*`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-type-shape.h>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-shape.h>

## Source-backed correction

### What changed in the local wiki understanding

The older dossier claims about a `createdTypes` map, `getTargetType(...)`, `getValue(...)`, control-value propagation, direct call operand retagging, and return-value retagging should now be treated as stale for the current `version_129` pass contract.

The source-backed contract is instead:

- `type-ssa` is registered as a public pass in `pass.cpp` under the name `type-ssa`.
- `TypeSSA.cpp` says the pass adds a new type for each selected `struct.new` / array allocation, by analogy with SSA creating a new register per value.
- The analyzer records allocation sites in `news`, not a general expression-created-type map.
- Allocation candidates include `struct.new`, `array.new`, `array.new_data`, `array.new_elem`, and `array.new_fixed`.
- The analyzer also records `disallowedTypes` where allocation exactness may be observed, including exact casts/tests, exact function results, exact global types, exact element-segment types, and exact child constraints discovered through `ChildTyper`.
- The pass is GC-gated and skips imported functions for function-body analysis.
- It also walks module code, globals, and element segments, with a TODO for table initializers.
- It processes candidates in deterministic function/module order.
- `isInteresting(...)` filters candidates: unreachable allocations, final/open-disabled types, and descriptor/describee types are rejected; default constructors, constants/globals, more-refined operand types, data/elem arrays, and all-interesting fixed arrays are positive families.
- `modifyNews(...)` builds one large rec group for all selected candidates, creates private open subtypes of the original struct/array heap types, preserves sharing, makes the rec group unique, rewrites each allocation type to exact non-null fresh type, and copies a friendly old type name with a numeric suffix when possible.
- After rewriting, Binaryen runs `ReFinalize` over ordinary functions and module code.

## Current-main check

A 2026-04-26 current-main spot check found no teaching-relevant drift from the corrected `version_129` contract above. Current main still exposes `type-ssa` as a real pass, keeps the allocation-subtype creation model, and retains the closed-world usefulness caveat in the owner file comments.

## Uncertainty and contradiction record

- This correction contradicts the 2026-04-23 raw capture and the living pages that described `type-ssa` as a created-type propagation / retagging pass. Those claims should be superseded rather than blended into the corrected story.
- The pass comments say it is likely most useful in closed-world scenarios because fresh rec-group collisions outside the module are possible. The pass itself is GC-gated but does not require the Binaryen `--closed-world` option in the same hard-gate style as some other GC/type passes. Treat that as a source-backed usefulness caveat, not a scheduler gate.
- The source has TODOs around table initializers, multiple-inheritance/phi-like merges, descriptor/describee support, segment immutability inspection, and possible broader interestingness criteria after future type-based optimizations.

## Living pages updated from this capture

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-ssa/created-exact-types-control-values-and-signature-rewrites.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
