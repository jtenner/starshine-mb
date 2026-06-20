---
kind: entity
status: supported
last_reviewed: 2026-06-20
sources:
  - ../../../raw/research/0801-2026-06-20-heap-store-optimization-table-grow-swap.md
  - ../../../raw/research/0800-2026-06-20-heap-store-optimization-table-size-swap.md
  - ../../../raw/research/0799-2026-06-20-heap-store-optimization-final-root-no-swap.md
  - ../../../raw/research/0798-2026-06-20-heap-store-optimization-active-catch-throw-negative.md
  - ../../../raw/research/0797-2026-06-20-heap-store-optimization-external-exits.md
  - ../../../raw/research/0796-2026-06-20-heap-store-optimization-disappearing-bad-get.md
  - ../../../raw/research/0795-2026-06-20-heap-store-optimization-nested-control-sequence.md
  - ../../../raw/research/0794-2026-06-20-heap-store-optimization-in-function-catch-control.md
  - ../../../raw/research/0793-2026-06-20-heap-store-optimization-function-return-control.md
  - ../../../raw/research/0790-2026-06-20-heap-store-optimization-explicit-non-goals.md
  - ../../../raw/research/0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ../../../raw/research/0788-2026-06-20-heap-store-optimization-descriptor-loop-outer-branch.md
  - ../../../raw/research/0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md
  - ../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md
  - ../../../raw/research/0246-2026-04-22-heap-store-optimization-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../src/passes/heap_store_optimization_test.mbt
  - ../../../../../src/passes/perf_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/CHANGELOG.md
  - ../late-pipeline-dispatch.md
  - https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html
  - https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./swap-safety-and-control-flow.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../raw/research/0530-2026-05-06-heap-store-optimization-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md
  - ../tracker.md
  - ../../no-dwarf-default-optimize-path.md
  - ../optimize-instructions/index.md
  - ../precompute/index.md
  - ../heap2local/index.md
  - ../late-pipeline-dispatch.md
---

# `heap-store-optimization`

## Role

- `heap-store-optimization` is an active implemented **hot pass** in Starshine.
- In upstream Binaryen `version_129`, the public `pass.cpp` description is simply:
  - `optimize heap (GC) stores`

That summary is technically true, but it is too broad.

A better beginner summary is:

- Binaryen looks for a `struct.set` that writes into a **freshly created struct**,
- checks whether the stored value can be moved earlier safely,
- folds that value back into the matching `struct.new` field,
- and deletes or nops the now-redundant `struct.set`.

So this is **not** a general heap dead-store elimination pass.
It is a narrow GC constructor/store cleanup pass.

## Why this pass matters

- When this thread started, `docs/wiki/binaryen/passes/tracker.md` named `heap-store-optimization` as the strongest remaining implemented landing-page target.
- The canonical no-DWARF `-O` / `-Os` scheduler uses it **twice** in the default function pipeline:
  - once early after `optimize-instructions`
  - once late after the late `optimize-instructions`
- The saved generated-artifact `-O4z` audit observed the same top-level Binaryen slots:
  - slot `17`
  - slot `45`
- The saved Binaryen debug log contains `36` `running pass: heap-store-optimization` lines in total, so nested reruns matter here too.
- The local docs needed one especially important correction:
  - explain that upstream Binaryen `heap-store-optimization` is mostly about folding `struct.set` into nearby `struct.new` forms, not about generic GC store elimination or load forwarding.

## Most important durable takeaways

- Binaryen `heap-store-optimization` currently handles **`struct.set`**, not all heap stores.
- The source file itself still says:
  - `TODO: Add dead store elimination / load forwarding here.`
- The pass is built around a small number of ingredients:
  1. a CFG walk that records only `struct.set` and `block` action sites
  2. a direct tee-wrapped fold for `(struct.set (local.tee ... (struct.new ...)) VALUE)`
  3. a block-local chain scan for `(local.set X (struct.new ...))` followed by later matching `struct.set`s
  4. effect-order checks that prove the moved value can cross later constructor operands and the constructor wrapper itself
  5. a `LazyLocalGraph` query for the hardest case: control flow inside the moved value that might skip the `local.set`
  6. side-effect preservation when replacing an old field value that still matters
- `struct.new_default` can be expanded into explicit default operands so the later store can still be absorbed.
- Function-external exits are mostly safe for this pass's current goal, but in-function exits and catches can block the rewrite.
- Current upstream `main` is unusually stable here.
  - A 2026-05-05 focused current-main source bridge found no teaching-relevant drift in `HeapStoreOptimization.cpp`, the dedicated `heap-store-optimization.wast` test file, and helper surfaces versus the `version_129` contract.

## Beginner warning: what the name hides

The easy wrong mental model is:

- `heap-store-optimization` is a broad heap optimizer for GC code

The safer mental model is:

- Binaryen is mostly trying to **fold a later `struct.set` back into the constructor that made the same struct**,
- and the real work is proving that moving the stored value earlier does not reorder effects or skip the local assignment that keeps the new ref visible.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- general GC heap store cleanup

What it actually is in `version_129`:

- a function-parallel CFG-based pass that only records `struct.set` and `block` action points,
- folds immediate tee or subsequent local-set patterns into `struct.new`,
- can swap a fresh `local.set(struct.new ...)` downward across safe blockers,
- materializes defaults for `with_default` constructors,
- preserves old field side effects when needed,
- and uses `LazyLocalGraph` only when control flow in the moved value might skip the moved `local.set`.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation structure, helper dependencies, scheduler placement, and the exact safety checks that make the pass much narrower than its name suggests.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Source-confirmed owner-file, helper, lit-test, registry, dispatcher, raw fast-skip, focused-test, perf-test, and CLI-replay map for upstream Binaryen and current Starshine.
- [`./swap-safety-and-control-flow.md`](./swap-safety-and-control-flow.md)
  - Focused guide to the easiest part of the pass to misunderstand: swap legality, field/descriptor reordering, target-local hazards, and the `LazyLocalGraph` rule that distinguishes safe exits from dangerous in-function skips.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly shape catalog covering tee folds, subsequent local-set chains, default-materialization positives, safe and unsafe control-flow families, and the main bailout shapes.
- [`./starshine-hot-ir-strategy.md`](./starshine-hot-ir-strategy.md)
  - Current in-tree Starshine strategy and the major ways the HOT-region implementation differs from upstream Binaryen's CFG-based source while still pursuing the same core optimization; the refreshed page now also points readers to the exact MoonBit registry / dispatcher / helper-cluster / reduced-test / CLI-replay code map.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Compact validation bridge for the active local implementation, with the exact unit, perf, CLI replay, source-spotcheck, and refreshed direct `pass-fuzz-compare` parity surfaces.
- [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md)
  - Focused current-main source bridge plus exact Starshine code-map refresh for this dossier on 2026-05-05.
- [`../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md)
  - Immutable capture of the official Binaryen release, source, and lit-test URLs re-checked for this dossier on 2026-04-22.

## Freshness and naming note

The earlier landing page mostly existed to track naming evidence, so the richer dossier should keep those durable facts visible without letting them dominate the page.

Current durable answer:

- The current local release oracle is `wasm-opt version 130 (version_130)`.
- Binaryen `pass.cpp` still registers `heap-store-optimization` in `version_130`.
- The official Binaryen GitHub `version_129` release page re-checked on 2026-04-22 showed publish date **2026-04-01**.
- The current upstream changelog still records `Add a new --heap-store-optimization pass. (#6882)` under `v119`.
- A 2026-05-05 focused current-main source bridge preserved the no-teaching-drift result for `main` `HeapStoreOptimization.cpp`, the dedicated lit file, and helper surfaces, while refreshing the exact local code map.
- A 2026-06-20 `version_130` source refresh found byte-identical dedicated lit but a small source drift from `invalidates(...)` to directional `orderedBefore(...)` in swap, later-field, descriptor, and shallow-constructor movement checks. Follow-ups fixed plain-constructor shallow-effect overblocking for old-field call preservation plus moved-call folding, later-field trap/local-state overblocking where Binaryen moves a local-only value before a trapping field operand, descriptor global/call movement where an immutable descriptor `global.get` can be crossed but a mutable descriptor global cannot, one `trySwap(...)` underblocking gap where a constructor operand `global.get` cannot cross a later mutable `global.set`, and one `trySwap(...)` overblocking gap where an immutable descriptor `global.get` can cross an unrelated mutable `global.set`. A later coverage slice added source-backed `trySwap(...)` tests for `memory.size` constructor operands crossing unrelated `global.set`, trapping `i32.load` constructor operands not crossing `global.set`, and the constructor-local-set ping-pong no-fold boundary. Follow-up `0784` fixed descriptor-expression overblocking for block-wrapped immutable descriptor globals and descriptor `local.get`; follow-up `0785` fixed pure descriptor-`if` operands while preserving a call-condition negative; follow-up `0786` fixed descriptor block self-branch overblocking; follow-up `0787` fixed branchless descriptor-loop overblocking while locking a self-branching descriptor-loop negative; follow-up `0788` fixed descriptor-loop outer-branch overblocking by tracking the active loop label and then passed native-build plus direct 10000-case compare signoff. Follow-up `0789` added coverage-only repeated-store last-value and wrong-target-local tests; it also recorded exact descriptor `ref.cast` as blocked by local exact-cast/decode surface rather than accepted as an HSO non-goal. Follow-up `0790` added explicit boundary coverage for array stores remaining out of scope, but its ordinary-memory-store blocker claim was superseded by follow-up `0791`: Binaryen `version_130` crosses ordinary memory/table store blockers to reach a later fresh-struct `struct.set`, and Starshine now matches that behavior while preserving the stores themselves. Follow-up `0792` added focused unreachable constructor/set-value no-fold boundary coverage while recording a local direct-root unreachable fixture limitation. Follow-up `0793` fixed the `LazyLocalGraph`-style function-external `return` case: plain `Return` inside the moved set value is safe to fold because the taken return exits the function rather than skipping a later in-function read. Follow-up `0794` fixed the complementary in-function caught-call negative: a moved call/throw/return-call value is blocked while traversing a catchable `try`/`try_table` body because a caught throw could skip the delayed local assignment. Follow-up `0795` fixed nested expression traversal for `drop(block(result ...))` control-flow sequences so Starshine now reaches the nested local-set chain, folds the safe first store, and preserves unsafe escaping branch-valued stores when the target local is read after the block. Follow-up `0796` fixed Binaryen's exact one-disappearing-bad-get exception by allowing a branch-only root to move before the delayed constructor local assignment only when the target local is not read after the owner expression, which lets the following branch-valued store fold while keeping the `0795` outside-read negative blocked. Follow-up `0797` fixed safe external-exit classification for conditional `throw` and `return_call` set values, including Binaryen's observed `return_call` fold inside active `try_table`, while keeping ordinary caught-call behavior blocked. Follow-up `0798` promoted the active-catch conditional `throw` negative into focused coverage, confirming Starshine keeps `struct.set` there like Binaryen. Follow-up `0799` added source-backed final-root no-swap coverage for Binaryen's `trySwap(...)` last-element boundary. Follow-up `0800` added source/probe-backed coverage for swapping a `table.size` constructor operand across an unrelated mutable `global.set`, matching Binaryen's fold while preserving the table/global side effects. Follow-up `0801` added matching coverage for a table-growing constructor operand crossing an unrelated mutable `global.set`; Starshine already matched Binaryen by preserving `table.grow` / `global.set`, folding the later value into `struct.new`, and removing `struct.set`. Broader arbitrary descriptor expressions, remaining later-field shapes, broader in-function branch/catch negatives, final non-goal wording, and broader swap directionality remain active audit work until focused tests and compare evidence classify them.
- A 2026-05-06 direct revalidation ran `pass-fuzz-compare` at `--count 10000 --seed 0x5eed`, producing 6759 compared normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures.
- The Debian experimental `wasm-opt` manpage still lists `--heap-store-optimization`.
- The published docs.rs `wasm_opt::Pass` enum still omits `HeapStoreOptimization`, so that surface is still wrapper lag, not rename pressure.

## Current maintenance rule

- Treat this folder as the canonical home for future `heap-store-optimization` parity and scheduler research.
- Use Binaryen `version_130` as the current release source oracle.
- Keep the narrow-scope correction explicit:
  - this pass is mainly about folding `struct.set` into nearby `struct.new` families
  - it is not yet generic GC heap dead-store elimination or load forwarding
- Keep the older current-main no-drift note explicit as historical stability evidence, but do not use it to hide the `version_130` directional `orderedBefore(...)` movement-check drift.
- Keep [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) in sync with local owner/test line ranges when the active HOT implementation moves.

## Validation quick links

- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Compact local validation bridge for unit, perf, CLI replay, and source-spotcheck checks.

## Sources

- [`../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md`](../../../raw/binaryen/2026-04-22-heap-store-optimization-primary-sources.md)
- [`../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md`](../../../raw/research/0448-2026-05-05-heap-store-optimization-current-main-recheck.md)
- [`../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md`](../../../raw/research/0511-2026-05-06-heap-store-optimization-validation-bridge.md)
- [`../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md`](../../../raw/research/0133-2026-04-20-heap-store-optimization-binaryen-research.md)
- [`../../../../../src/passes/heap_store_optimization.mbt`](../../../../../src/passes/heap_store_optimization.mbt)
- [`../../../../../src/passes/heap_store_optimization_test.mbt`](../../../../../src/passes/heap_store_optimization_test.mbt)
- [`../../../../../src/passes/perf_test.mbt`](../../../../../src/passes/perf_test.mbt)
- [`../../../../../src/cmd/cmd_wbtest.mbt`](../../../../../src/cmd/cmd_wbtest.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md`](../../../raw/research/0093-2026-04-18-generated-o4z-pass-audit-summary.md) preserves the saved generated-artifact `-O4z` slot, summary, and Binaryen debug-log facts; older `.artifacts` paths are replay identifiers, not durable wiki source links.
- Binaryen `version_130` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/cfg/cfg-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/local-graph.h>
- Binaryen `version_130` dedicated lit test:
  - <https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast>
- Historical Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/heap-store-optimization.wast>
- Narrow freshness and naming sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/HeapStoreOptimization.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/heap-store-optimization.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/refs/heads/main/CHANGELOG.md>
  - <https://manpages.debian.org/experimental/binaryen/wasm-opt.1.en.html>
  - <https://docs.rs/wasm-opt/latest/wasm_opt/enum.Pass.html>
