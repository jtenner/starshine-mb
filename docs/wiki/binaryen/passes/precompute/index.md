---
kind: entity
status: supported
last_reviewed: 2026-05-08
sources:
  - ../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md
  - ../../../raw/research/0400-2026-04-26-precompute-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md
  - ../../../raw/research/0229-2026-04-21-precompute-implementation-followup.md
  - ../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../scripts/lib/self-optimize-compare-task.ts
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - ../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md
  - ../../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/8f85446ee05b32726979a38284a48b1c3719208a
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/
  - https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/86f0d65bcf87c2491698b7cfd526f2f0614a75dd%5E%21/
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../optimize-instructions/index.md
  - ../heap-store-optimization/index.md
  - ../vacuum/index.md
---

# `precompute`

## Role

- `precompute` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the real pass family has **two public names**:
  - `precompute`
  - `precompute-propagate`
- The public summary in `pass.cpp` is small:
  - `precompute`: computes compile-time evaluatable expressions
  - `precompute-propagate`: computes compile-time evaluatable expressions and propagates them through locals

That summary is accurate, but too small.

A better beginner summary is:

- Binaryen tries to **execute** some expressions at compile time,
- keeps the result only when it can safely re-emit it as valid IR,
- preserves important local/global writes when needed,
- optionally propagates constant knowledge through locals,
- and at higher optimize levels can partially push parent computations into `select` arms.

So this pass is not just “integer constant folding.”

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `precompute` as the strongest remaining implemented-landing target after the `optimize-instructions` dossier landed.
- The canonical no-DWARF `-O` / `-Os` scheduler uses the precompute family **twice** in the default function pipeline:
  - once early
  - once late
- In Binaryen `version_129`, those top-level no-DWARF `-O` / `-Os` slots use **plain `precompute`**, not `precompute-propagate`, because that preset is only `optimizeLevel=2`, `shrinkLevel=1`.
- The saved generated-artifact `-O4z` audit saw the more aggressive variant instead:
  - slot `19`: `precompute-propagate`
  - slot `43`: `precompute-propagate`
- The saved Binaryen debug log contains `53` `running pass: precompute-propagate` lines in total, so nested optimizing reruns matter a lot more than the two visible top-level `-O4z` slots suggest.
- The local backlog already has dedicated `PC` slices, so a deeper dossier here directly helps future implementation work:
  - `[PC]001 - Runtime And Representation Drift`

## Most important durable takeaways

- Binaryen `precompute` is **not** just `1 + 2 -> 3`.
- Binaryen `precompute` is **not** just a peephole pass.
- Binaryen `precompute` is built around five linked ideas:
  1. use a bounded compile-time interpreter to see what an expression really does
  2. only replace the expression if the result is concrete **and** safely re-emittable
  3. preserve required local/global writes when speculative evaluation walked through them
  4. optionally push parent computation into `select` arms when that reduces the whole shape
  5. in the propagate variant, use `LazyLocalGraph` to move constant knowledge through locals and then rerun the main walk once
- The pass depends heavily on helper utilities such as:
  - `ConstantExpressionRunner`
  - `Flow`
  - `Literals`
  - `Properties`
  - `LazyLocalGraph`
  - `EffectAnalyzer`
  - `ExpressionStackWalker`
  - `ExpressionManipulator::nop`
  - `ReFinalize`
- GC identity is part of the real contract.
  - The pass keeps a heap-value cache so `ref.eq`, immutable field reads, and nested immutable-object reasoning do not accidentally confuse “same contents” with “same allocation.”
- Emitability is also part of the contract.
  - Binaryen may know a result value precisely, but still refuse to replace the expression if it cannot emit that value as a valid constant expression.
- Current Starshine models only a small scalar/control subset of the upstream behavior, with a conservative raw stack-level shortcut for scalar/no-candidate functions, branch-free constant-`if` arm picks, module-proven immutable `global.get` constants, mutable/global no-candidate reads, dropped flat nontrapping scalar/global/select expressions, safely voidable dropped result blocks, and preserved effectful/trapping dropped-tail no-candidate shapes to reduce direct-pass HOT lift/lower work.
- The direct debug-artifact representation drift is classified at `.tmp/pc-artifact-drift-classified` and rechecked at `.tmp/pc001-final-recheck`: after fixing the compare fallback to ignore parentheses inside WAT data strings, the first function-body drift is defined `4` / absolute `21`, where Binaryen emits temporary-local/block scaffolding plus dropped intermediate constants around `memory.size` / `local.tee` scalar folding while Starshine leaves the compact stack expression. Type-index ordering also differs across `1913 / 4671` defined functions because Binaryen's `precompute` output reorders the function types. The active `[PC]001` backlog slice is closed because direct semantic parity remains green and the remaining shape gap is not a small raw shortcut candidate; whole-command runtime belongs to `[WALL]001`.
- The earlier generated-artifact slot-19 hard failure is retired.
  - The durable explanation is that the saved failure was fixed by HOT-lowering / writeback guards and full-module validation, not by discovering that Binaryen `precompute` itself is a still-open structural rewrite hazard.
- The later rooted slot-43 continuation blocker is also retired.
  - The durable explanation is again HOT-lowering / writeback hardening rather than a new `precompute`-local algorithm bug: the remaining live witness was a wrapped carried-local branch-depth corruption in `hot_lower_impl_stackify_wrapped_struct_set_prefixes(...)`, fixed by refusing stackification when a doubly nested child exit still targets the carried-prefix block's own label.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `precompute` just folds exact constant arithmetic

The safer mental model is:

- Binaryen uses a small interpreter plus local-flow reasoning to compute what an expression would do,
- then only replaces it when both semantics and re-emission stay honest,
- and the propagate variant extends that by using local get/set flow information rather than just the syntax under one node.

That difference matters a lot for future parity work.

## What the pass sounds like versus what it actually does

What it sounds like:

- a small constant-folder

What it actually is in `version_129`:

- a function-parallel post-walk pass with:
  - bounded compile-time execution
  - result / break / return flow tracking
  - child-retention logic for local/global writes
  - a block-specific quadratic-work bailout
  - partial select-arm precompute at higher optimize levels
  - optional `LazyLocalGraph` constant propagation
  - GC identity caching
  - constant-emission restrictions for refs and strings
  - final refinalization

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the difference between the pass's small public name and its larger real scope.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Compact source-confirmed owner/test map for plain `precompute`, including the shared `Precompute.cpp` core, the public/scheduler split in `pass.cpp` and `opt-utils.h`, the helper ownership in `wasm-interpreter.h` / `properties.h` / `local-graph.h`, and the broad lit roster that proves the plain-pass contract instead of only the sibling `precompute-propagate` one.
- [`./propagation-partial-precompute-and-gc-identity.md`](./propagation-partial-precompute-and-gc-identity.md)
  - Focused guide to the easiest part of the pass to underestimate: the split between plain `precompute` and `precompute-propagate`, the upward partial-select algorithm, the `LazyLocalGraph` worklist, and the GC identity / emitability boundaries.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering scalar, control, `select`, tuple, string, GC, atomic, and bailout families.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy plus an exact MoonBit code map for the descriptor, fold helpers, region cleanup, pipeline writeback guards, preset placement, and focused proof lanes.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Implementation-readiness bridge for future Starshine work: safe next slices, validation ladder, Binaryen oracle comparison order, current-main drift handling, and exact local code locations for HOT rewrites plus pass-manager writeback guards.
- [`../precompute-propagate/index.md`](../precompute-propagate/index.md)
  - Dedicated dossier for the upstream aggressive / nested-rerun sibling, focused on the separate public pass name, the extra `LazyLocalGraph` propagation phase, and the `optimizeAfterInlining(...)` scheduler role.

## Newer-than-`version_129` drift already recorded on this page

The current dossier uses Binaryen `version_129` as the main source oracle, but this folder should not silently forget the newer upstream drift that the earlier landing page had already recorded.

Those newer facts remain useful, provided they stay labeled as newer than the tagged oracle:

- `2025-08-27`: a Chromium mirror `Precompute` rewrite reworked child-retention logic and removed the older dual-cache split
- `2026-03-23`: upstream fixed GC writes such as `ArrayStore` being treated too optimistically during precompute
- `2026-03-25`: upstream stopped folding GC `struct` / `array` atomic RMW and `cmpxchg` because those operations both read and write heap state
- `2026-03-26`: upstream kept multibyte `array.load` as `NONCONSTANT_FLOW` for now instead of folding it like a normal immutable read

Treat those as newer-trunk drift notes, not as silent edits to the `version_129` contract described in the strategy page.

## Current maintenance rule

- Treat this folder as the canonical home for future plain `precompute` parity work and family-level context.
- Treat [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md) as the immutable provenance anchor for the reviewed official release, source, and test URLs.
- Treat [`../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md) as the current-main / local-code-location bridge until the project deliberately bumps the Binaryen oracle baseline; the 2026-05-05 recheck in [`../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md) confirms no teaching-relevant drift on the reviewed surfaces.
- Treat [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) as the compact owner/test attribution page when future threads need to answer “which file proves what?” instead of reopening that same gap from scratch.
- Use [`../precompute-propagate/index.md`](../precompute-propagate/index.md) as the canonical home for the separate public aggressive / nested-rerun sibling.
- Use Binaryen `version_129` as the current source oracle for new conclusions.
- Keep the landing page honest about the mode split:
  - no-DWARF `-O` / `-Os` top-level slots use plain `precompute`
  - aggressive `-O4z`-style and nested optimizing reruns use `precompute-propagate`
- Keep the landing page honest about the artifact story:
  - the saved slot-19 `func 108` invalid-output witness is retired
  - the later rooted slot-43 continuation witness (`func 3867`, extracted as `func 15`) is also retired by HOT-lower carried-prefix label guarding rather than by a new pass-local `precompute` rewrite
  - the remaining work is documentation depth, parity breadth, and runtime honesty, not an open hard-corruption blocker
- Keep newer upstream drift notes labeled as newer-than-`version_129` facts instead of silently rewriting the `version_129` contract.

## Sources

- [`../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-precompute-current-main-recheck.md)
- [`../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md`](../../../raw/research/0468-2026-05-05-precompute-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md)
- [`../../../raw/research/0400-2026-04-26-precompute-port-readiness.md`](../../../raw/research/0400-2026-04-26-precompute-port-readiness.md)
- [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md)
- [`../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md`](../../../raw/research/0132-2026-04-20-precompute-binaryen-research.md)
- [`../../../raw/research/0229-2026-04-21-precompute-implementation-followup.md`](../../../raw/research/0229-2026-04-21-precompute-implementation-followup.md)
- [`../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md`](../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md)
- [`../../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md`](../../../raw/research/0268-2026-04-23-generated-o4z-precompute-slot43-retired-by-hot-lower-prefix-label-guard.md)
- [`../../../../../src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt)
- [`../../../../../src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- [`../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md`](../../../raw/research/0096-2026-04-18-generated-o4z-precompute-slot19-missing-i32-result.md)
- [`../../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md`](../../../raw/research/0105-2026-04-18-generated-o4z-precompute-slot19-retired-by-writeback-guards.md)
- Newer upstream drift notes already recorded on the old landing page:
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/9de4aca15b3125d54aabaf2913a0988ff500bdba>
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/8f85446ee05b32726979a38284a48b1c3719208a>
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/10c876d4d246a2e697a166879bcb6df0d7b7bbca%5E%21/>
  - <https://chromium.googlesource.com/external/github.com/WebAssembly/binaryen/+/86f0d65bcf87c2491698b7cfd526f2f0614a75dd%5E%21/>
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Precompute.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-interpreter.h>
- Representative Binaryen `version_129` tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-effects.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-partial.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-immutable.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-gc-atomics.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-strings.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-ref-func.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/precompute-relaxed.wast>
