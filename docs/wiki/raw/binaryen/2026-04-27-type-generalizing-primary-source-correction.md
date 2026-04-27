# Binaryen `type-generalizing` primary-source correction

_Capture date:_ 2026-04-27  
_Status:_ immutable corrective source manifest for `docs/wiki/binaryen/passes/type-generalizing/`

## Scope

This file corrects the 2026-04-24 `type-generalizing` dossier. The older manifest and living pages said Binaryen `version_129` `experimental-type-generalizing` was a tiny local-set/local-tee retagging pass with no `ContentOracle`, no `call_ref`, no GC instruction visitors, no nested `dce`, and no refinalization. A fresh primary-source recheck of the official `version_129` and current `main` files shows that model was wrong.

Use this manifest, not the older 2026-04-24 manifest, as the current source anchor for the pass mechanics.

## Official sources consulted

### `version_129`

- Release anchor: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Owner source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeGeneralizing.cpp>
- Raw owner source: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeGeneralizing.cpp>
- Registration surface: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Raw registration surface: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-generalizing.wast>
- Raw dedicated lit test: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-generalizing.wast>

### Current `main`

- Owner source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeGeneralizing.cpp>
- Raw owner source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeGeneralizing.cpp>
- Registration surface: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Raw registration surface: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Dedicated lit test: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-generalizing.wast>
- Raw dedicated lit test: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-generalizing.wast>

## Corrected durable observations

- `pass.cpp` registers `experimental-type-generalizing` with `registerTestPass(...)` and labels it "generalize types (not yet sound)". It remains a hidden/internal test pass, not a normal public optimizer pass.
- `TypeGeneralizing.cpp` is a function-parallel pass, but it is not the tiny retagging-only pass described in the 2026-04-24 dossier.
- The owner file builds a function CFG and runs a backward `MonotoneCFGAnalyzer` over a lattice of local type requirements plus value-stack type requirements.
- The transfer function records local requirements, stack requirements, and dependent basic blocks so local requirement changes can trigger reanalysis.
- The pass first runs nested `dce` on each function before building the CFG. The source comment says unreachable code can otherwise become invalid because the analysis does not materialize or analyze unreachable blocks.
- Function exit constrains result types. Function entry constrains params to their original types, non-reference locals to their original types, and reference locals to their heap top type.
- Calls, locals, globals, select, drop, ref operations, tables, GC struct/array operations, and conversion operations each impose or relax type requirements in the backward transfer function.
- `call_ref` is explicitly handled. Bottom call targets keep a bottom function-reference requirement; otherwise the pass walks declared supertypes of the target signature while preserving result and parameter requirements.
- `struct.get`, `struct.set`, `array.get`, `array.set`, `array.copy`, `array.fill`, `array.init_*`, `array.len`, `ref.cast`, `ref.test`, and `ref.as_*` are explicitly part of the source surface.
- `br_if`, `br_on*`, EH, tuple, string, continuation, array atomic/load/store, struct atomic/RMW/cmpxchg/wait/notify, and `pop` paths still contain explicit `TODO` / unreachable markers in the reviewed source. This is part of why the pass remains a hidden "not yet sound" test pass.
- After analysis, the pass writes generalized local types back to non-param locals, then updates `local.get` and `local.tee` result types to match the new local declarations.
- If any local get or tee type was changed, the pass runs `ReFinalize` on the function.
- The dedicated lit file exercises top-type generalization for unconstrained refs, implicit-return constraints, local get/set/tee propagation, call and call_ref requirements, global/table boundaries, select/drop/ref operations, struct/array generalization, and multiple no-op or unsupported boundaries.
- The 2026-04-24 claims that the pass had no `call_ref`, no `struct.get`, no `struct.set`, no refinalization, and a `local.get` drop-plus-zero replacement are superseded by this manifest.

## Current Starshine status rechecked

- Starshine still has only a boundary-only local name, `type-generalizing`, in `src/passes/optimize.mbt`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names before execution.
- `optimize` and `shrink` preset expansion lists do not include `type-generalizing`.
- No `src/passes/type_generalizing.mbt` owner file exists in the current tree.
- No active backlog slice for this pass was found in `agent-todo.md` during this correction.

## Consumability rule

Cite this manifest together with `docs/wiki/raw/research/0421-2026-04-27-type-generalizing-source-correction-and-port-readiness.md` and the refreshed living pages. Treat `docs/wiki/raw/binaryen/2026-04-24-type-generalizing-primary-sources.md` and `docs/wiki/raw/research/0308-2026-04-24-type-generalizing-source-correction-and-starshine-followup.md` as superseded for pass mechanics, although they remain useful audit history.
