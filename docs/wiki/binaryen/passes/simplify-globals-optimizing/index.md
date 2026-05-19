---
kind: entity
status: supported
last_reviewed: 2026-05-18
sources:
  - ../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md
  - ../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md
  - ../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./linear-traces-read-only-to-write-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-globals/index.md
  - ../propagate-globals-globally/index.md
  - ../inlining-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `simplify-globals-optimizing`

## Role

- `simplify-globals-optimizing` is an upstream Binaryen late global optimizing pass.
- It is currently **partially implemented** in Starshine as an active module pass in [`../../../../../src/passes/simplify_globals_optimizing.mbt`](../../../../../src/passes/simplify_globals_optimizing.mbt), with registry and dispatcher wiring in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) and [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt). The exact local status and remaining port map live in [`./starshine-strategy.md`](./starshine-strategy.md).
- Binaryen also exposes the related plain pass name `simplify-globals`.
- The `simplify-globals-optimizing` variant is the same core global pass **plus** a nested rerun of the default function optimization pipeline on changed functions.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `simplify-globals-optimizing` after `duplicate-import-elimination` and before `remove-unused-module-elements`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `52`
- The saved debug log also shows that this pass is bigger than one top-level name suggests. Between top-level `simplify-globals-optimizing` and the next top-level `remove-unused-module-elements`, repo-local counting over [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log) finds:
  - `3` nested pass batches
- The backlog already tracks this as slice `SGO` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is also the remaining late boundary/global cleanup dossier nearest the freshly documented late neighbors:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`

## Beginner summary

A safe beginner mental model is:

- scan the whole module to learn which globals are really observed,
- fold single-use globals into later global initializers when that is still one-time work,
- remove writes whose value never matters,
- canonicalize immutable copy chains,
- propagate known values through later global initializers and segment offsets,
- propagate known values through function code only when the current runtime trace is still simple,
- then rerun normal function cleanup on the functions that changed.

That is much closer to the real Binaryen pass than “replace constant `global.get`s.”

## Current durable takeaways

- The reviewed official Binaryen `version_129` release page on 2026-04-24 showed publish date **2026-04-01**, and the raw manifests in [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md) and [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md) record the exact source, lit-test, and current-main port-readiness URLs checked for this folder. The 2026-05-18 refresh in [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md) rechecked official Binaryen `main` at commit `d3029d2b975488acdf9253eb2994a3fc55bd3549` (committer date 2026-05-15) and found no SGO semantic drift from the `version_129` contract; the only `SimplifyGlobals.cpp` changes were comment typo fixes.
- `simplify-globals-optimizing` is a **module / boundary** pass, not a function-local peephole.
- The pass has several distinct algorithm families, not one:
  - practical-immutability discovery
  - single-use global-init folding
  - dead or redundant `global.set` removal
  - `read-only-to-write` elimination
  - immutable copy-chain canonicalization
  - startup-time constant propagation into later globals and offsets
  - runtime constant propagation into function code with a cheap linear-trace model
- The `optimizing` part really matters: Binaryen reruns the default function optimization pipeline on changed functions after constant replacement or removed writes.
- That nested rerun is **not** the same helper used by `dae-optimizing` and `inlining-optimizing`:
  - it does **not** prepend `precompute-propagate`
  - it reruns per changed function through a nested `PassRunner`
- Imports, exports, actual calls, nonlinear control flow, and type mismatches are major bailout or conservatism families.
- The active Starshine slice preserves both halves narrowly:
  - a first module-owned global rewrite algorithm for private never-written globals, single-use initializer folding into later globals, exact-type immutable copy-chain canonicalization, never-read, single-const same-as-init, and adjacent/eqz/bidirectional compare-const/simple-pure-condition (including i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares), transparent, nested, block-wrapped-pure-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, no-op-condition-prefix, and const-drop-body read-only-to-write and exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-wrapped-set/block-wrapped-condition+set `if return; set` dead writes, supported constant global reads, startup constants in table/global/offset module expressions, and straight-line runtime propagation for single-const private global writes
  - a touched-function nested default cleanup lane without the `precompute-propagate` prefix
- Current Starshine no longer rejects direct `simplify-globals-optimizing` requests, but it remains incomplete: broader same-as-init expression matching, broader `read-only-to-write` conditions beyond the current adjacent/eqz/bidirectional compare-const/simple-pure-condition (including i32 unary/bitwise/shift-rotate ops, i64 equality/compare and non-trapping value ops, plus f32/f64 compares), transparent, nested, block-wrapped-pure-condition, block-yielded-condition, block-yielded operators after pure block condition bodies, no-op-condition-prefix, and const-drop-body self-guard and exact/eqz/bidirectional compare/pure-condition/block-wrapped-condition/block-wrapped-pure-condition/nested-block-wrapped-condition/block-yielded-condition/block-yielded-condition+set/block-yielded operators after pure block condition bodies/block-wrapped-set/block-wrapped-condition+set `if return; set` matchers, value-flow-sensitive safe-side-effect condition positives from Binaryen's official test, broader copy-chain/type-refinalization cases, broader runtime linear-trace propagation, debug-artifact oracle parity, and public-preset scheduling are still open.
- The first active slice has generated-input oracle evidence: 10000/10000 `gen-valid` normalized matches against Binaryen and 9975/9975 compared mixed-generator matches, with only known Binaryen/tool command failures in the mixed lane.
- The 2026-04-25 port-readiness bridge and 2026-05-18 current-main refresh found no teaching-relevant Binaryen current-main drift; the 2026-05-16 through 2026-05-18 local implementation slices should be read as a partial port against that contract, not as full parity.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper dependencies, scheduler placement, safety rules, and nested-rerun behavior.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file, helper, and lit-test map for the shared `SimplifyGlobals.cpp` family and the optimizing-specific nested-rerun wrapper.
- [`./linear-traces-read-only-to-write-and-reruns.md`](./linear-traces-read-only-to-write-and-reruns.md)
  Focused guide to the easiest parts of the pass to misunderstand: startup versus runtime propagation, the exact `read-only-to-write` matcher, actual-node versus effect-summary conservatism, and the optimizing rerun contract.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and remaining port map: active partial module-pass wiring, implemented constant/dead-set/touched-cleanup subset, open `SGO` backlog work, and the exact neighboring late-tail pass dossiers to compose with.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge for a future port: minimum viable slice order, transformed-shape test plan, scheduler validation, Binaryen oracle comparison, and late-tail replay sequencing.

## Current maintenance rule

- Treat this folder as the canonical home for `simplify-globals-optimizing` research, implementation notes, and port planning.
- Keep it explicitly marked as **partial** until Starshine grows the remaining Binaryen global rewrite families plus debug-artifact oracle parity and preset scheduling.
- New `simplify-globals-optimizing` findings should update the strategy page, the linear-trace / read-only-to-write page, and the port-readiness page together so the global algorithm story, scheduler story, and Starshine validation plan stay aligned.

## Sources

- [`../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md`](../../../raw/research/0570-2026-05-18-simplify-globals-optimizing-current-main-refresh.md)
- [`../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-globals-optimizing-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md)
- [`../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md`](../../../raw/research/0376-2026-04-25-simplify-globals-optimizing-port-readiness.md)
- [`../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md`](../../../raw/research/0286-2026-04-24-simplify-globals-optimizing-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md`](../../../raw/research/0122-2026-04-20-simplify-globals-optimizing-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-dominance.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-nested.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-non-init.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-offsets.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-prefer_earlier.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-read_only_to_write.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals-single_use.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/simplify-globals_func-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
