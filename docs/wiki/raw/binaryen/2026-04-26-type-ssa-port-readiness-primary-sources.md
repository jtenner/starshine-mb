# Binaryen `type-ssa` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable primary-source bridge for `docs/wiki/binaryen/passes/type-ssa/starshine-port-readiness-and-validation.md`

## Scope

This capture rechecks the corrected `type-ssa` contract specifically for Starshine port planning. The 2026-04-26 source-correction capture already superseded the stale created-type-propagation model. This bridge asks a narrower question: what would the first honest Starshine slice need to validate, and did upstream current `main` change any teaching-relevant details after the tagged `version_129` read?

## Official online sources consulted

- Binaryen `TypeSSA.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeSSA.cpp>
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeSSA.cpp>
- Binaryen registration and declaration surfaces
  - `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - current `main` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - `version_129` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - current `main` `passes.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Official lit proof surface
  - `version_129` `type-ssa.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-ssa.wast>
  - current `main` `type-ssa.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-ssa.wast>
- Refinalization and type-shape helpers
  - current `ReFinalize.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/ReFinalize.cpp>
  - current `wasm-type-shape.h`: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-type-shape.h>

## Source-backed port-readiness facts

The current `main` owner file still matches the corrected `version_129` teaching contract:

- `type-ssa` remains a public Binaryen pass name, but its core rewrite is still allocation-type splitting, not local/global flow retagging.
- Candidate discovery is explicit in visitors for `StructNew`, `ArrayNew`, `ArrayNewData`, `ArrayNewElem`, and `ArrayNewFixed`.
- The run phase still gates on GC, skips imported function bodies, scans module code, globals, and element segments, and still has a TODO for table initializers.
- The pass still merges exact-observation blockers into `disallowedTypes` before selecting candidates to rewrite.
- Candidate selection still requires both "not disallowed" and `isInteresting(...)`.
- The selected allocations are still rewritten together so the fresh heap types can live in one rec group rather than several independent singleton groups.
- The pass still runs `ReFinalize` on ordinary functions and module code after the type rewrites.
- The official `type-ssa.wast` fixture still covers both positive fresh-subtype allocation shapes and boring/uninteresting preservation shapes, including struct and array families.

## Starshine-specific code surfaces rechecked

Current Starshine still has no hidden partial `type-ssa` implementation:

- `src/passes/optimize.mbt` has no `type-ssa` entry in the boundary-only, removed, active, or preset registries.
- `agent-todo.md` has no dedicated `type-ssa` slice.
- Local prerequisite surfaces exist, but they are just prerequisites:
  - GC allocation instructions are represented in `src/lib/types.mbt`.
  - struct/array allocation text lowering lives in `src/wast/lower_to_lib.mbt`.
  - allocation validation lives in `src/validate/typecheck.mbt`.
  - nearby active type/value passes are `src/passes/global_refining.mbt`, `src/passes/global_struct_inference.mbt`, and `src/passes/ssa_nomerge.mbt`.

## Port-readiness implications

A future Starshine port should not start by rewriting instructions. The safe order is:

1. decide registry honesty first: keep unknown, add boundary-only rejection, or add an active experimental pass;
2. add a no-rewrite analyzer that can find the allocation candidate families and exact-observation blockers;
3. add reduced tests that compare the analyzer classification against the official Binaryen fixture families;
4. only then add type-section mutation for fresh private subtypes and allocation retagging;
5. finish with validation/refinalization proof before pass-fuzz comparison.

## Uncertainty and contradiction record

- No teaching-relevant drift was found between the corrected `version_129` contract and current `main` in the rechecked surfaces.
- The closed-world usefulness caveat remains a comment-level planning signal, not a hard option gate in the pass runner.
- The table-initializer TODO remains relevant. Do not claim full module-code allocation discovery until Starshine and Binaryen source both cover that surface.
- Starshine has enough syntax/IR/validation plumbing to parse and validate many relevant shapes, but it does not yet have the type-section mutation, rec-group construction, exact-observation analyzer, or refinalization infrastructure required for a faithful pass.

## Living pages updated from this bridge

- `docs/wiki/binaryen/passes/type-ssa/index.md`
- `docs/wiki/binaryen/passes/type-ssa/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-ssa/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/type-ssa/wat-shapes.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`
