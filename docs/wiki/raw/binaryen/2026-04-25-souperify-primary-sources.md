# Binaryen `souperify` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/souperify/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 `souperify` source bridge. Use the living dossier pages for explanation:

- `docs/wiki/binaryen/passes/souperify/index.md`
- `docs/wiki/binaryen/passes/souperify/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/souperify/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/souperify/flat-dataflow-traces-and-single-use-boundaries.md`
- `docs/wiki/binaryen/passes/souperify/wat-shapes.md`
- `docs/wiki/binaryen/passes/souperify/starshine-strategy.md`

## Provenance

### Official release page consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-25.
  - GitHub showed the release as published **2026-04-01 14:31** and still marked it `Latest` on the reviewed page.

### Official Binaryen source files consulted

- `Souperify.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Souperify.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Souperify.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Souperify.cpp>
  - Key reviewed locations in the tagged file:
    - top file comments: recommended `flatten` / `simplify-locals-nonesting` / `reorder-locals` preparation, differences from the LLVM Souper extractor, and current TODOs around path conditions outside `if` plus missing Souper RHS support.
    - `UseFinder`: value-use discovery through `LocalGraph`, copy-only local-set chains, and non-set external-use classification.
    - `DataFlow::Trace`: traceable-node filter, bounded recursive slice growth, `excludeAsChildren`, fresh `Var` fallback, path-condition addition, and trivial-trace rejection.
    - `Printer`: Souper-style opcode mapping, `var` / `block` / `phi` / `pc` / `blockpc` / `zext` output, type spelling, and `hasExternalUses` annotations.
    - `Souperify`: `Flat::verifyFlatness(func)`, `DataFlow::Graph` construction, `LocalGraph::computeInfluences()`, single-use child-exclusion scan, and trace emission.
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Key reviewed location: public registrations for `souperify` and `souperify-single-use`.
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: declarations for `createSouperifyPass()` and `createSouperifySingleUsePass()`.

### Supporting Binaryen helper context

These helper files were treated as source-backed context for the pass contract, not as separate pass owners:

- `src/dataflow/node.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/node.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/dataflow/node.h>
  - Key reviewed surface: DataFlow node vocabulary (`Var`, `Expr`, `Phi`, `Cond`, `Block`, `Zext`, `Bad`) and the reason `Zext` exists for Souper `i1` comparison values returning to wasm integer widths.
- `src/dataflow/graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/graph.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/dataflow/graph.h>
  - Key reviewed surface: graph construction from flat Binaryen IR, local-state merging, block/condition nodes, loop-phi avoidance, parent tracking, and merge-value handling.
- `src/dataflow/utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/dataflow/utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/dataflow/utils.h>
  - Key reviewed surface: shared DataFlow dump/utility context used by the Souper extractor.
- `src/ir/flat.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/flat.h>
  - Key reviewed surface: hard flatness contract that makes `souperify` a consumer of flat IR, not a flattening pass.
- `src/ir/local-graph.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/local-graph.h>
  - Key reviewed surface: local influence / use-discovery helper used by `UseFinder` and the single-use exclusion prepass.

### Official Binaryen test files consulted

- `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast>
  - Key reviewed surface: `wasm-opt` invocation with `--flatten --simplify-locals-nonesting --souperify --enable-threads`, straight-line examples, path conditions, `select`, phi/merge families, bad-phi/bad-type bailouts, unreachable robustness, deep-trace truncation, and loop boundaries.
- `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast>
  - Key reviewed surface: parallel proof for the public single-use sibling, especially multi-use-child truncation into `var`s rather than root filtering.

## Durable observations from the captured sources

- `souperify` and `souperify-single-use` are real public Binaryen `version_129` passes, not hidden debugging helpers.
- Both public names share one `Souperify.cpp` engine.
- The pass emits Souper-style text traces; it does not optimize or mutate the wasm module body like a normal Binaryen optimization pass.
- `Flat::verifyFlatness(func)` is a hard precondition. The official tests therefore use a preparation prefix (`--flatten --simplify-locals-nonesting`) before invoking the pass.
- The pass builds Binaryen DataFlow IR and then prints from that graph. Its node vocabulary (`Var`, `Expr`, `Phi`, `Cond`, `Block`, `Zext`, `Bad`) is part of the teaching contract.
- `LocalGraph` is used for influence/use discovery, external-use annotation, copy-chain following, and single-use child-exclusion decisions.
- Trace growth is intentionally bounded by default depth and total-node limits, with `BINARYEN_SOUPERIFY_DEPTH_LIMIT` and `BINARYEN_SOUPERIFY_TOTAL_LIMIT` overrides.
- When a dependency is too deep, too large, unsupported, or excluded in single-use mode, the pass replaces it with a fresh `Var` rather than failing the whole extraction.
- `souperify-single-use` means “do not expand reused nodes as child dependencies”; reused nodes can still be emitted as roots.
- Path conditions are real (`pc` / `blockpc`) but source-confirmed as `if`-derived in the reviewed implementation.
- Loop-carried values are intentionally cut off instead of building full loop phis.
- The official proof surface is the two flatten-plus-cleanup combo lit files; there is no standalone `souperify.wast` in the reviewed `version_129` tree.
- The reviewed current-`main` owner and lit surfaces did not show teaching-relevant drift from `version_129`; the only noted owner-file drift was a spelling cleanup in an unreachable-string literal, so future semantic changes should still be re-checked before updating the dossier.

## Starshine-local observations captured in this run

- `src/passes/optimize.mbt` does not list `souperify` or `souperify-single-use` in active, module, boundary-only, removed, or preset names.
- `src/passes/pass_manager.mbt` has no dispatcher case for a Souper trace-emission pass.
- `src/cmd/cmd.mbt` would surface an explicit request as an unknown pass, because the name is absent from the registry rather than boundary-only or removed.
- No `src/passes/*souper*` owner file exists.
- Starshine has useful prerequisites (`src/ir/use_def.mbt`, `src/ir/ssa_local.mbt`, `src/ir/ssa_policy.mbt`, `src/ir/hot_lift.mbt`, `src/lib/types.mbt`, and WAT/binary/validation surfaces), but it has no DataFlow trace IR, Souper printer, flatness verifier matching Binaryen's `Flat::verifyFlatness`, or trace-emission output channel today.
- `agent-todo.md` has no dedicated `souperify` slice on 2026-04-25.

## Uncertainty and caveats

- This capture records source-level mechanics and official lit coverage; it does not prove byte-for-byte identity for every current `main` helper implementation detail.
- Souper text output is an instrumentation/extraction surface. A future Starshine port would need a deliberate CLI/output design before claiming support; adding a normal `HotPassDescriptor` alone would not match Binaryen's pass behavior.
- The reviewed upstream sources themselves leave broader path-condition and RHS/Souper integration work as future TODOs. Do not silently upgrade the wiki to claim those surfaces without fresh source confirmation.
- Starshine's HOT SSA and use-def helpers are prerequisites, not a substitute for Binaryen's DataFlow graph and printed trace contract.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
