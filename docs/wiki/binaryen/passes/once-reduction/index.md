---
kind: entity
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md
  - ../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md
  - ../../../raw/research/0238-2026-04-21-once-reduction-starshine-strategy-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/once_reduction.mbt
  - ../../../../../src/passes/once_reduction_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./parity.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../memory-packing/index.md
  - ../global-refining/index.md
---

# `once-reduction`

## Role

- `once-reduction` is an active implemented **module pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is basically:
  - reduce calls to code that only runs once

That description is true, but too small.

A better beginner summary is:

- Binaryen first proves that a private integer global behaves like a monotonic once-bit,
- then proves that a no-param/no-result function really starts with the exact `if (global.get) return; global.set nonzero` guard shape,
- then propagates “this once-bit is definitely already set here” facts through dominated control-flow and direct-call summaries,
- nops redundant direct calls and redundant writes,
- and finally strips a tiny family of trivial once-function wrappers and empty once bodies.

The 2026-04-21 follow-up makes one additional source-confirmed point explicit:

- the real `version_129` implementation has four distinct owners that a future port must keep separate: `Scanner`, `OnceReduction::run(...)`, `Optimizer`, and `optimizeOnceBodies(...)`

So this is **not** generic repeated-call elimination.
It is a narrow whole-module once-bit plus direct-call optimization pass.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `once-reduction` as the strongest remaining implemented landing-page target.
- In the canonical no-DWARF `-O` / `-Os` scheduler it sits early in the module-prepass cluster:
  - `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing -> once-reduction -> global-refining -> ...`
- That placement is meaningful:
  - `memory-packing` shrinks data-segment and segment-op baggage first
  - `once-reduction` then deletes redundant run-once scaffolding
  - later module passes see a cleaner module before GC refinement and the main function pipeline
- In the saved generated-artifact `-O4z` audit, slot `4` (`once-reduction`) was already green:
  - exact wasm equal: `yes`
  - normalized WAT equal: `yes`
  - Starshine wall/runtime: `421.087 ms`
  - Binaryen wall/runtime: `206.659 ms`
  - Starshine in-pass time: `12.455 ms`
  - Binaryen in-pass time: `13.674 ms`
- The saved Binaryen debug log shows one top-level `running pass: once-reduction` line, followed by `running nested passes`.
  - That nested-pass note is an internal implementation detail of `OnceReduction.cpp` itself, not a later optimize-after-inlining scheduler rerun.

## Most important durable takeaways

- Upstream `once-reduction` is not a general “repeated pure call elimination” pass.
- The real safety story depends on three narrow facts:
  - the once-bit global is only written with nonzero integer constants
  - the guard read appears only in the recognized top-of-function once pattern
  - the redundant call or write is reached on a path where that bit is definitely already set
- Actual Binaryen `version_129` does **not** require the once-global initializer to be zero.
  - The shipped lit file has a nonzero-initializer case and still expects optimization.
- The pass is dominance-driven and deliberately conservative at merges.
  - after-`if` and cycle-heavy shapes often stay untouched even when they look morally redundant
- Upstream also supports a narrow `@binaryen.idempotent` path by giving such functions fake once-global names.
  - the local Starshine implementation does not model that official source feature today
- Final body cleanup is tiny on purpose.
  - Binaryen only strips empty once bodies and single-call once wrappers with cycle protection

## Biggest beginner correction

The easy wrong mental model is:

- once a once-function has been entered, Binaryen can treat all of its downstream once-callees as fully completed too

The safer mental model is:

- Binaryen mainly tracks that a specific once-bit is definitely already nonzero on the current dominated path
- that is enough to remove a later guarded direct call or a later redundant write to the same bit
- but it is **not** enough to assume every once-callee in a cycle or call nest has already finished its whole payload

That difference is why the official lit file keeps after-merge and dangerous triple-loop cases conservative.

## What the pass sounds like versus what it actually does

What it sounds like:

- remove repeated calls to run-once code

What it actually is in `version_129`:

- a whole-module pass with a parallel scan phase,
- an exact once-function shape matcher,
- a narrow idempotent-annotation fast path,
- a fixed-point direct-call summary propagation loop,
- a CFG plus immediate-dominator local optimizer,
- and a final trivial once-body cleanup step with explicit cycle protection.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the real `OnceReduction.cpp` structure, helper dependencies, scheduler placement, fixed-point iteration, and the actual algorithm.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact file/test map for the exact `version_129` pass ownership split: what `Scanner`, `Optimizer`, `OnceReduction::run(...)`, `optimizeOnceBodies(...)`, `pass.cpp`, `intrinsics.h`, and the shipped lit file each prove.
- [`./dominance-propagation-and-cycle-safety.md`](./dominance-propagation-and-cycle-safety.md)
  - Focused guide to the hardest part to misunderstand: what once facts really propagate, why after-merge cases stay conservative, what the triple-loop lit family is guarding, and how wrapper cleanup avoids infinite cycles.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering classic positive once patterns, call-chain propagation, wrapper positives, nonzero-init / nonzero-write nuances, and the main bailout families.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine module-pass strategy: exact MoonBit code map, recursive once-bit analysis/rewrite flow, and the main ways the local implementation is narrower than upstream Binaryen's CFG/dominator engine.
- [`./parity.md`](./parity.md)
  - Current in-tree parity state, saved generated-artifact evidence, and the honest remaining gap between the local implementation and the full official `OnceReduction.cpp` surface.

## Freshness note

The dossier now has an immutable raw provenance capture at:

- [`../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md`](../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md)

That 2026-04-22 capture rechecked the official Binaryen GitHub release page for `version_129`, where GitHub showed publish date **2026-04-01**, and also rechecked the core pass/test surfaces on `version_129` and `main`.

The narrow current-`main` spot check did **not** surface a new teaching-relevant contract drift beyond the dossier's existing claims.

So the durable rule is:

- treat Binaryen `version_129` as the released oracle for this dossier
- keep the current-main note explicit only to say there is no visible source or dedicated-lit drift on the reviewed surfaces right now

## Current maintenance rule

- Treat this folder as the canonical home for future `once-reduction` parity and scheduler research.
- Keep the main beginner correction explicit:
  - upstream `once-reduction` is a narrow dominance-and-direct-call once-bit pass, not generic idempotent-call removal
- Keep the idempotent-annotation special case, the conservative after-merge story, the triple-loop ordering caveat, and the wrapper-cycle guard explicit whenever future docs or code changes touch this pass.

## Sources

- [`../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md`](../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md)
- [`../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md`](../../../raw/research/0138-2026-04-20-once-reduction-binaryen-research.md)
- [`../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md`](../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md)
- [`../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md`](../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md)
- [`../../../../../src/passes/once_reduction.mbt`](../../../../../src/passes/once_reduction.mbt)
- [`../../../../../src/passes/once_reduction_test.mbt`](../../../../../src/passes/once_reduction_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.md)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
- Narrow freshness-check surface:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/OnceReduction.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/once-reduction.wast>
