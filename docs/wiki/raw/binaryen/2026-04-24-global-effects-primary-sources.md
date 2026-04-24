---
kind: source-capture
status: supported
last_reviewed: 2026-04-24
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_129
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast
related:
  - ../research/0168-2026-04-21-global-effects-binaryen-research.md
  - ../research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../binaryen/passes/global-effects/index.md
---

# Binaryen `global-effects` / `generate-global-effects` primary-source capture

Captured: 2026-04-24

## Source set

- Official Binaryen `version_129` release: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Reviewed release page reports `version_129` as released on **2026-04-01 14:31** and points at commit `d0e2be9`.
- `src/passes/GlobalEffects.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalEffects.cpp>
  - Key reviewed locations: owner file comments and implementation around the `GenerateGlobalEffects` pass, `FuncInfo`, shallow `EffectAnalyzer` construction, direct-call scan, unknown-effects handling for indirect calls, transitive-call propagation, recursive-cycle trap marking, `Function.effects` writeback, and `DiscardGlobalEffects` cleanup.
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Key reviewed location: pass registration for `generate-global-effects` and `discard-global-effects`; `generate-global-effects` is described as generating global effect info for later passes.
- `src/ir/effects.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - Key reviewed location: direct-call effect analysis can consume a callee function's stored summary when it exists.
- `src/wasm.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - Key reviewed location: `Function` owns optional `effects` metadata, which is the pass output.
- `test/lit/passes/vacuum-global-effects.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
  - Key reviewed location: run line composes `--generate-global-effects --vacuum`; comments explain that once global effects show a call has no effects, `vacuum` can remove it and then remove now-unused contents.
- `test/lit/passes/global-effects_simplify-locals.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-effects_simplify-locals.wast>
  - Key reviewed location: run lines compare plain `--simplify-locals` with `--generate-global-effects --simplify-locals`, proving a direct downstream consumer family beyond `vacuum`.

## Durable facts captured

- Upstream Binaryen publishes the producer pass as `generate-global-effects`; Starshine currently tracks the local compatibility name `global-effects`.
- The pass is metadata-producing. It does not directly rewrite printed WAT in ordinary cases; it writes per-function effect summaries for later consumers.
- `version_129` first computes shallow per-function effects for defined functions, clears ordinary call effects while it scans direct calls, treats unknown / indirect-call surfaces conservatively, computes transitive static-call reachability, marks potentially recursive functions as trapping, merges callee summaries into callers, then writes the result into each `Function.effects` field.
- Imported functions remain conservative because Binaryen cannot inspect their bodies; unknown callee effects poison callers rather than optimistically assuming purity.
- The sibling `discard-global-effects` pass clears stored summaries, which makes effect metadata lifecycle part of the contract.
- The `vacuum-global-effects.wast` and `global-effects_simplify-locals.wast` tests prove the value of the metadata through later passes, not through the producer pass itself.

## Current-`main` drift note

A 2026-04-24 spot check of `main` found teaching-relevant implementation drift in `GlobalEffects.cpp` compared with `version_129`:

- `version_129` computes transitive call reachability with `UniqueDeferredQueue` and then merges callee summaries into callers.
- current `main` refactors the propagation through an explicit call graph, SCC traversal, reverse topological processing, and component-level effect aggregation.

This drift changes the implementation shape future readers should expect on current `main`, but the high-level contract stayed aligned in the reviewed surfaces: shallow direct-call/effect scan, conservative unknown effects, recursive-cycle trap marking, per-function `Function.effects` writeback, and a `discard-global-effects` cleanup sibling remain the durable teaching story.

## Uncertainty and contradiction notes

- The owner-file header comment still says the effects are stored on `PassOptions`, but both the reviewed `GlobalEffects.cpp` writeback and the `wasm.h` data model point to per-function `Function.effects` storage. The wiki should teach `Function.effects` as the observed implementation contract and treat the `PassOptions` phrase as stale wording unless later upstream documentation says otherwise.
- `generate-global-effects` is a real public pass, but the reviewed default-pipeline materials and existing Starshine no-DWARF page do not place it in the canonical no-DWARF default optimize path. Keep that distinction explicit.
- The `global-effects_simplify-locals.wast` test proves a simplify-locals consumer family, but the exact local Starshine `simplify_locals.mbt` effect model is not a port of Binaryen's stored `Function.effects` metadata.

## Local Starshine status captured with this ingest

- `src/passes/optimize.mbt` lists `global-effects` in `pass_registry_boundary_only_names()`.
- Request expansion rejects boundary-only passes with the message that the pass is not implemented in the hot pipeline.
- `src/cli/cli_test.mbt` only proves that `--global-effects` parses to the pass flag.
- `src/ir/effects.mbt`, `src/ir/analysis_cache.mbt`, and `src/passes/pass_common.mbt` provide function-local HOT effect masks and cache plumbing, not a module-level interprocedural `Function.effects` equivalent.
- No dedicated `src/passes/global_effects.mbt` owner file, module dispatcher case, active preset slot, or `agent-todo.md` backlog slice was found in the 2026-04-24 local recheck.
