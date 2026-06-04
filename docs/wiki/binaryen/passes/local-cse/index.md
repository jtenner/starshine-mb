---
kind: entity
status: supported
last_reviewed: 2026-06-04
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/local_cse.mbt
  - ../../../../../src/passes/local_cse_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./basic-block-windows-and-barriers.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `local-cse`

## Role

- `local-cse` is an upstream Binaryen local-cleanup pass.
- It is now implemented in Starshine as an active direct pass in [`../../../../../src/passes/local_cse.mbt`](../../../../../src/passes/local_cse.mbt) and is registered under the active module-pass surface in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Despite the name, Binaryen `version_129` does **not** use it as a whole-function or CFG-wide common-subexpression pass.
- The real job is narrower: find repeated whole expression trees inside one local execution window, save the first result in a fresh temp local, and reuse that value later with `local.get`.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` function pipeline runs `local-cse` in the late local-cleanup cluster:
  - after `coalesce-locals`
  - before full `simplify-locals`
- The saved generated-artifact `-O4z` audit records two real skipped top-level upstream slots:
  - top-level slot `11`
  - top-level slot `31`
- Slot `11` matters because it captures the extra aggressive upstream prelude:
  - `flatten`
  - `simplify-locals-notee-nostructure`
  - `local-cse`
- The saved Binaryen debug log shows `36` `local-cse` executions in one full `-O4z` run, which means the pass is also part of the nested optimizing-rerun story, not just the obvious top-level slots.
- The repo backlog already treats it as a real parity blocker under slice `LCSE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It also sits between several already-documented neighbors whose behavior is easier to understand once `local-cse` is documented clearly:
  - `simplify-locals-notee-nostructure`
  - `coalesce-locals`
  - `simplify-locals`
  - late `rse`

## Beginner summary

A safe beginner mental model is:

- look for the **same whole tree** twice,
- keep the first computation,
- store it in a temp local,
- replace later repeats with `local.get`,
- but only when effects and nondeterminism say that reuse is still safe.

That is smaller and more local than “Binaryen does generic CSE here.”

## Current durable takeaways

- The reviewed official Binaryen `version_129` release page rechecked on 2026-04-22 showed publish date **2026-04-01**, and the dossier has an immutable raw primary-source manifest at [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md).
- A focused 2026-05-05 current-`main` recheck at [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md) refreshed `LocalCSE.cpp`, `pass.cpp`, `opt-utils.h`, and `local-cse.wast`; it found no teaching-relevant drift and kept the upstream/test plus Starshine code map current.
- A 2026-05-06 line-anchor refresh at [`../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md) pinned the exact current local code anchors now used in the Starshine pages and confirmed the same source-backed contract.
- A repo-authored 2026-05-05 correction note at [`../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md`](../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md) records that older Starshine-status wording in the raw upstream bridge is stale now that the direct Starshine pass has landed.
- A 2026-05-06 direct revalidation at [`../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md`](../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md) reran the refreshed harness with `--count 10000 --seed 0x5eed --pass local-cse`, reached 6759 compared cases, and found 6759 normalized matches, 0 mismatches, and 20 known Binaryen empty-recursion-group command failures.
- A 2026-06-04 `version_130` / current-main refresh at [`../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md`](../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md) found no teaching-relevant Binaryen drift from the 2026-05-06 source bridge.
- A 2026-06-04 O4z audit at [`../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md`](../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md) refreshed a 1000-case direct lane with 998 normalized matches, 2 known Binaryen empty-recursion-group command failures, and 0 mismatches; it found and then fixed Starshine missed optimizations for Binaryen's before-`if` into `then` reuse window and simple before-block into straight-line block reuse window. The then-arm post-fix 10000-case direct compare reached 6768 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches, while pass-local timing on `tests/node/dist/starshine-debug-wasi.wasm` stayed within the 2x Binaryen budget. The later return-boundary and `br_table` boundary coverage slices each reran the direct 10000-case lane with 6771 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches; the `unreachable` boundary slice reran it with 6765 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches; the `struct.new` generative-root slice reran it with 6769 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches; the named-block positive fix reran it with 6771 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches; the `struct.new_default` generative-root slice reran it with 6764 normalized matches, 20 Binaryen/tool command failures, and 0 mismatches.
- The pass really is a three-stage algorithm:
  - `scan`
  - `check`
  - `apply`
- It reuses only **whole repeated trees**, not arbitrary shared subtrees.
- Parent repeats can cancel child-level reuse requests, so the pass prefers to reuse the bigger matching tree when it can.
- It is mostly window-local, but the `LinearExecutionWalker` helper lets some cheap adjacent dominated cases count too, such as before-`if` into the `then` arm and before a straight-line block into that block body.
- Repeated loads may optimize even though loads can trap; ordinary repeated calls do not.
- Calls to functions annotated idempotent are a narrow source-level exception.
- Constants and tiny size-1 roots like `global.get` are intentionally left alone; Starshine now has direct regression coverage for the repeated-`global.get` no-op.
- Fresh/generative GC roots such as `struct.new` and `struct.new_default` must not be reused; Starshine now has direct regression coverage for those repeated roots remaining separate.
- The early `-O4` slot depends on `flatten` plus a little simplify-locals cleanup to expose more identical whole trees.
- The pass adds locals, so Binaryen marks it as DWARF-invalidating.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: data structures, scan/check/apply phases, helper dependencies, profitability rules, and scheduler placement.
- [`./basic-block-windows-and-barriers.md`](./basic-block-windows-and-barriers.md)
  Focused guide to the easiest parts of the pass to misunderstand: what “inside basic blocks” really means here, which control-flow boundaries reset the window, and why effects, traps, generativity, and idempotent calls matter.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed owner-file, helper, lit-test, scheduler, and Starshine status map for readers who need to follow the pass from upstream code into the local port plan.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, negative, bailout, and interaction families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Dedicated Starshine status/port map for this active direct pass: exact implementation, registry, dispatcher, scheduler, neighboring MoonBit files and test lanes, and the main honesty rule that preset placement should stay blocked until the missing Binaryen-neighbor equivalents land locally.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  Implementation-readiness bridge: the nearest local landing zone, conservative validation ladder, and the exact cluster-replay checks to defer until the missing neighbors exist.

## Current maintenance rule

- Treat this folder as the canonical home for `local-cse` behavior, parity, and slot-planning notes.
- Keep the active Starshine implementation status in sync with `src/passes/local_cse.mbt`, `src/passes/local_cse_test.mbt`, `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, `src/cmd/cmd_wbtest.mbt`, and `agent-todo.md`.
- New `local-cse` findings should update the strategy page, implementation/test-map page, and windows/barriers page together so the algorithm explanation, proof-surface map, and control-flow safety story stay aligned.
- The before-`if` into `then` and before-block into straight-line block missed optimizations are now covered test-first and implemented in the raw/module path, the before-loop into loop-body, `br_table`, return-boundary, and unreachable-boundary negatives are covered, the tiny-root repeated-`global.get` no-op is covered, and the repeated `struct.new` / `struct.new_default` generative-root no-ops are covered as durable direct tests; keep future O4z LCSE closure criteria focused on the remaining hard control-boundary, GC/generative, and idempotent-call shapes rather than reopening those fixed/covered families.

## Sources

- [`../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md`](../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md)
- [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md)
- [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md)
- [`../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md`](../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md)
- [`../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md`](../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md`](../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md)
- [`../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md`](../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md)
- [`../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md`](../../../raw/research/0491-2026-05-05-local-cse-starshine-active-direct-pass-correction.md)
- [`../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md`](../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md)
- [`../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md`](../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md)
- [`../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md`](../../../raw/research/0533-2026-05-06-local-cse-direct-revalidation.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LocalCSE.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
- Binaryen `version_129` lit tests: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/local-cse.wast>
