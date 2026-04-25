# Binaryen `dae2` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/dae2/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `dae2` source bridge. Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/dae2/index.md`
- `docs/wiki/binaryen/passes/dae2/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/dae2/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/dae2/fixed-point-forwarding-type-trees-and-expression-removal.md`
- `docs/wiki/binaryen/passes/dae2/wat-shapes.md`
- `docs/wiki/binaryen/passes/dae2/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official Binaryen source files consulted

- `DeadArgumentElimination2.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination2.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeadArgumentElimination2.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/DeadArgumentElimination2.cpp>
  - Key reviewed locations in the tagged file:
    - top pass comment near the beginning of the file: scope, one analysis traversal, one optimize traversal, optional referenced-type global rewrite, and current non-goals around results/constants/type propagation.
    - `FunctionInfo`: per-function used-parameter bits, direct and indirect forwarded-parameter maps, reverse caller-param edges, removable parameter-get tracking, continuation-type usage, referenced status, intrinsic blocker, and replacement type.
    - `RootFuncTypeInfo`: tree-wide parameter facts for related function-type roots and reverse edges for indirect/reference callers.
    - `DAE2::run(...)`: `closedWorld && wasm->features.hasGC()` switch, `analyzeModule()`, `prepareReverseGraph()`, `computeFixedPoint()`, and `optimize()` ordering.
    - `GraphBuilder`: direct / indirect forwarding discovery, incoming-parameter reasoning, condition/effect blockers, references, continuations, and intrinsic blockers.
    - `DAE2::prepareReverseGraph()` and `DAE2::computeFixedPoint()`: reverse-graph construction and smallest-fixed-point use propagation.
    - `Optimizer`, `DAETypeUpdater`, and `makeUnreferencedFunctionTypes(...)`: body rewrite, referenced-function type repair, replacement-type generation, and expression removal.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Key reviewed location: public `registerPass("dae2", "Experimental reimplementation of DAE", createDAE2Pass)` registration next to `dae` / `dae-optimizing`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: pass constructor declaration for `createDAE2Pass()`.

### Official Binaryen test files consulted

- `dae2.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/dae2.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/dae2.wast>
  - Key reviewed surface: the file runs `wasm-opt -all --dae2 --closed-world -S`, and covers basic dead params, live params, recursive forwarding, `call_ref`, `call_indirect`, referenced-vs-unreferenced functions, public / continuation / tag / intrinsic boundaries, replacement-type regressions, effect/control preservation, tuple conservatism, and nondefaultable-local ordering.

### Supporting Binaryen helper context

These helper files were treated as context for the source map, not as separate pass owners:

- `src/ir/local-graph.h` - incoming-param value reasoning and slot-reuse safety.
- `src/ir/module-utils.h` - public heap-type discovery and module-level reference helpers.
- `src/ir/type-updating.h` - global type and holder repair after referenced signature changes.
- `src/ir/intrinsics.h` - `call.without.effects` and JS-called blockers.
- `src/ir/effects.h` - removable-expression and side-effect boundaries.
- `src/ir/eh-utils.h` - stack-switching / continuation-related type roots.
- `src/support/mixed_arena.h` and `src/wasm-type-shape.h` - replacement-type / rec-group helper context.

## Durable observations from the captured sources

- `dae2` is a real public Binaryen `version_129` pass and is separate from plain `dae` / `dae-optimizing`.
- The source explicitly calls it an experimental reimplementation and keeps its current scope narrower than plain DAE on result removal, constant propagation, and type propagation.
- The core proof is a backward smallest fixed point over used params and params forwarded through direct calls or root function-type trees.
- The analysis must distinguish true incoming-param use from local-slot reuse; Binaryen uses `LazyLocalGraph` for that safety boundary.
- The pass treats branch conditions, effectful parents, imports/exports, `ref.func`, public roots, continuations/tags, JS-called functions, and `call.without.effects` as conservative surfaces.
- The `closedWorld && GC` switch decides whether referenced function types and indirect/reference call surfaces can be rewritten.
- Referenced-function optimization requires global type repair and may require replacement types for unreferenced sibling functions before the global rewrite.
- The reviewed current-`main` source and lit file still present the same teaching-level contract as `version_129`; the top source comment and the primary `dae2.wast` run line matched the tagged file on 2026-04-25.

## Uncertainty and caveats

- This capture records source-level mechanics and the large official lit suite, but it does not prove that every current `main` internal helper detail is byte-for-byte identical to `version_129`.
- The source itself states that `dae2` is incomplete relative to its intended future power: result analysis, constant propagation, and type propagation should be source-confirmed again if upstream extends the pass.
- Starshine has prerequisite function type, call, `call_ref`, `call_indirect`, `ref.func`, closed-world option, and validator surfaces, but this capture found no local `dae2` registry entry, owner file, dispatcher case, or backlog slice on 2026-04-25.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
