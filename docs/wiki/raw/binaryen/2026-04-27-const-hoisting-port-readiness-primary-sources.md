# Binaryen `const-hoisting` port-readiness primary-source capture

_Capture date:_ 2026-04-27  
_Status:_ immutable current-main recheck and Starshine port-readiness source manifest for the `docs/wiki/binaryen/passes/const-hoisting/` dossier

## Scope

This capture refreshes the earlier `const-hoisting` manifests and records the exact local Starshine surfaces a future first implementation slice would use. It does not replace the tagged-release oracle in `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md` or the 2026-04-25 current-main recheck; it adds an implementation-readiness bridge.

Use this file together with:

- `docs/wiki/binaryen/passes/const-hoisting/index.md`
- `docs/wiki/binaryen/passes/const-hoisting/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/const-hoisting/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/const-hoisting/size-model-and-boundaries.md`
- `docs/wiki/binaryen/passes/const-hoisting/literal-bit-identity-zero-signs-and-nan-payloads.md`
- `docs/wiki/binaryen/passes/const-hoisting/wat-shapes.md`
- `docs/wiki/binaryen/passes/const-hoisting/starshine-strategy.md`
- `docs/wiki/binaryen/passes/const-hoisting/starshine-port-readiness-and-validation.md`

## Official online primary sources rechecked

### Binaryen current `main`

- `src/passes/ConstHoisting.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ConstHoisting.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/ConstHoisting.cpp>
  - Important source locations: file-level gzip/raw-size warning and zero TODOs; `MIN_USES`; `uses`; `isFunctionParallel`; `visitConst`; `worthHoisting`; `hoist`; `visitFunction`; `createConstHoistingPass`.
- `src/passes/pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Important source location: public registration string for `const-hoisting`.
- `src/literal.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/literal.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/literal.h>
  - Important source locations: `Literal` equality and hashing, especially typed bit identity for floats.
- `src/wasm-binary.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-binary.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-binary.h>
  - Important source locations: signed-LEB writer helpers used to measure integer literal payload size.
- `src/wasm-builder.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/wasm-builder.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/wasm-builder.h>
  - Important source location: builder helpers used by the pass to add locals and create `local.set`, `local.get`, and block/sequence wrappers.
- `test/lit/passes/const-hoisting.wast`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/const-hoisting.wast>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/const-hoisting.wast>
  - Important proof surface: integer and float threshold families, emitted prelude shape, deterministic local ordering, and current `v128` non-support.

### Stable release oracle retained

- Binaryen GitHub release `version_129`: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Earlier immutable source manifest retained as the release-tag oracle: `docs/wiki/raw/binaryen/2026-04-23-const-hoisting-primary-sources.md`
- Earlier focused current-main no-drift check retained: `docs/wiki/raw/binaryen/2026-04-25-const-hoisting-current-main-recheck.md`

## Local Starshine code surfaces rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_removed_names()` lists `const-hoisting`.
  - `run_hot_pipeline_expand_passes(...)` rejects removed pass names with `pass flag {name} is removed from the active hot pipeline registry`.
- `src/ir/hot_core.mbt`
  - `HotOp::Const`, `HotOp::LocalGet`, and `HotOp::LocalSet` are the relevant HOT node families.
  - `HotConstPayload` currently covers `I32Const`, `I64Const`, `F32Const`, and `F64Const`, matching the scalar numeric subset Binaryen hoists.
- `src/ir/hot_lift.mbt` / `src/ir/hot_lower.mbt`
  - lift and lower scalar numeric constants plus local get/set nodes through HOT.
- `src/ir/hot_builders.mbt`
  - builds typed scalar constants, `local.get`, and `local.set` nodes.
- `src/ir/hot_mutate.mbt`
  - `hot_append_body_local(...)` appends a fresh body local and bumps the HOT revision.
- `src/binary/encode.mbt`
  - signed-LEB emission helpers and scalar-const encoding provide the byte-size ingredients a faithful local pass would need to mirror Binaryen thresholds.
- `agent-todo.md`
  - no dedicated active `const-hoisting` slice exists today.

## Durable observations

- Binaryen current `main` still teaches the same contract captured from `version_129`: a function-parallel postwalk groups literal `Const` nodes, computes raw binary payload savings, rejects `v128`, and rewrites only profitable scalar-literal groups through one fresh local plus an entry prelude.
- No teaching-relevant drift was observed in the owner file, public registration, literal identity helper, signed-LEB helper, builder dependency, or dedicated lit proof surface.
- Starshine still has honest removed-registry behavior today: explicit `const-hoisting` requests are rejected instead of silently no-oping or pretending the pass is implemented.
- Starshine already has enough HOT scalar-constant and local-construction infrastructure for a narrow implementation, but it lacks the pass-specific pieces: literal bucket collection, Binaryen-compatible encoded-size helpers, deterministic prelude insertion, focused tests, dispatcher wiring, and pass-fuzz compare coverage.
- The first local implementation slice should be a HOT function pass, not a whole-module pass. It should scan one function, report/then rewrite profitable scalar literal buckets, and compare isolated `--pass const-hoisting` output against Binaryen before any preset scheduling decision.

## Uncertainties and contradictions

- The 2026-04-23, 2026-04-25, and 2026-04-27 source readings agree on the Binaryen contract. This file does not supersede them; it adds current-main freshness plus local implementation-readiness detail.
- Binaryen's source comments mention zero-special-case possibilities and raw-size-versus-gzip tradeoffs. Those are not implemented behavior today and should remain caveats in Starshine docs and tests.
- The upstream lit file proves many threshold and ordering cases, but `+0.0` versus `-0.0` and distinct NaN-payload grouping remain source-confirmed through `Literal` equality/hashing rather than separately isolated by a dedicated WAT fixture.
- The web-rendered raw GitHub view observed by the agent folded some C++ source into long records, so this manifest cites files and function / method names rather than depending on fragile rendered line numbers.
