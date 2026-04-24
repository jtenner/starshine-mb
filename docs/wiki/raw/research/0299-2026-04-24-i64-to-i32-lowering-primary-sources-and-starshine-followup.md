# 0299 - `i64-to-i32-lowering` primary sources and Starshine follow-up

Date: 2026-04-24  
Status: completed research ingest  
Pass: `i64-to-i32-lowering`  
Local registry status: boundary-only  
Upstream status: public Binaryen pass in `version_129`

## Why this pass was chosen

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/raw/research/`
- the existing `docs/wiki/binaryen/passes/i64-to-i32-lowering/` folder
- `src/passes/optimize.mbt`
- `src/passes/pass_manager.mbt`
- `src/passes/registry_test.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`

The tracker now says the obvious `none` / implemented-landing queues are clear, so this run needed a justified major-gap fallback inside an already-covered folder.
I chose `i64-to-i32-lowering` because the existing folder already had a strong overview, Binaryen strategy, implementation map, flatness/boundary page, ABI/opcode ledger, and WAT-shape catalog, but it still lacked two durable wiki-health pieces required by the current campaign instructions:

1. an immutable raw primary-source manifest under `docs/wiki/raw/binaryen/`
2. a dedicated Starshine status / port-strategy page that points readers to exact local code surfaces

That made the gap concrete without creating a near-duplicate pass page.

## Primary sources ingested

Added:

- `docs/wiki/raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`

The manifest captures these official Binaryen sources:

- `version_129` release page and releases index
- `src/passes/I64ToI32Lowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/pass.h`
- `src/abi/js.h`
- `src/asmjs/shared-constants.h`
- `src/ir/flat.h`
- `src/ir/iteration.h`
- `src/ir/memory-utils.h`
- `src/ir/module-utils.h`
- `src/ir/names.h`
- `test/lit/passes/flatten_i64-to-i32-lowering.wast`
- narrow current-`main` owner/test URLs for future freshness checks

## Main Binaryen facts preserved

The new raw manifest does not change the algorithmic summary already in the living dossier.
It anchors these durable facts:

- `i64-to-i32-lowering` is a real public pass, not a hidden test helper.
- It is whole-module and not function-parallel because function signatures and globals change.
- It requires flat function bodies in the reviewed implementation.
- It splits logical `i64` traffic into low/high `i32` halves.
- Most expression rewrites keep the low half visible and put the high half in temp-local side-channel state.
- Former `i64` returns use the synthetic mutable high-half global rather than multivalue.
- Reinterpret and selected atomic families rely on wasm2js helper imports and, for reinterpret, scratch-memory support.
- The pass still has explicit unsupported or assumed-gone families, so it must not be taught as a universal arbitrary-`i64` legalizer.

## Starshine follow-up

Added:

- `docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-strategy.md`

The current local truth is:

- `src/passes/optimize.mbt` lists `i64-to-i32-lowering` in `pass_registry_boundary_only_names()`.
- `run_hot_pipeline_expand_passes(...)` rejects boundary-only names before dispatch.
- `src/passes/pass_manager.mbt` dispatches only the active module-pass set; there is no `i64-to-i32-lowering` case.
- `src/passes/registry_test.mbt` checks category classes, but there is no pass-specific implementation or parity test for `i64-to-i32-lowering`.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` lists it under Batch 3 whole-module or layout transforms.
- `agent-todo.md` currently has no dedicated `i64-to-i32-lowering` slice.

The likely future local landing is a boundary/module pass, not a HOT-only pass, because a faithful port must rewrite types, globals, function signatures, code bodies, call targets, `ref.func` type uses, locals, memory operations, and helper imports together.

## Local code surfaces mapped for future work

The Starshine page points future readers at these concrete in-repo surfaces:

- `src/passes/optimize.mbt` for registry status and boundary-only rejection
- `src/passes/pass_manager.mbt` for active module-pass dispatch and validation policy
- `src/lib/types.mbt` for `ValType::i64`, `FuncType`, `FuncIdx`, `GlobalIdx`, `LocalIdx`, `Locals`, and the broad i64 instruction enum surface
- `src/lib/util.mbt` for local-run / `FunctionLocals` helpers that would need param/body-local rebuilding semantics
- `src/wast/keywords.mbt` and `src/wast/lower_to_lib.mbt` for the current WAT parser/lowering surface for i64 ops, calls, locals, globals, and memory ops
- `src/binary/decode.mbt` and `src/binary/encode.mbt` for binary codec support around value types, locals, globals, function/code sections, and i64 opcodes
- `src/validate/env.mbt` and `src/validate/typecheck.mbt` for final validation of rewritten module signatures, locals, globals, calls, and i64 memory/atomic families
- `src/ir/hot_lift.mbt` and `src/ir/hot_lower.mbt` as cautionary neighbors rather than the likely first implementation home, because this pass is larger than a function-local HOT rewrite

## Uncertainties and open questions

- The current dossier is still anchored to Binaryen `version_129` plus narrow current-`main` source URLs. Future source drift should update the raw manifest or add a new follow-up instead of silently changing the living pages.
- Starshine has no chosen backlog slice for the pass, so the future port shape is only a strategy map, not a committed implementation plan.
- The page intentionally does not decide whether a future Starshine port should run an in-tree flatten-equivalent first, require already-flat lowered bodies, or implement a different internal pair-lowering strategy. It only records that upstream `version_129` requires flat input and that a faithful local port must make that policy explicit.

## Living-doc updates made

Updated the existing `i64-to-i32-lowering` dossier to cite the raw manifest and Starshine page, then refreshed the pass catalogs so readers can navigate from overview -> transformed shapes -> Binaryen strategy -> local status without relying on the older research notes alone.

Touched living pages:

- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/flatness-helpers-and-boundaries.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/abi-surface-and-opcode-coverage.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Source URLs

- Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen `version_129` `I64ToI32Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
- Binaryen current `main` `I64ToI32Lowering.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp>
- Binaryen `version_129` dedicated lit file: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
