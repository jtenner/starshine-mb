---
kind: entity
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../docs/0065-2026-03-24-ir2-execution-plan.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `loop-invariant-code-motion`

## Role

- `loop-invariant-code-motion` is a real Binaryen pass, but the upstream public pass name is the shorter alias **`licm`**.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **removed** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The refreshed IR2 registry docs now list it in the current removed-name migration gap rather than beside active `local-subtyping`; see [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md) and [`../../../../../docs/0065-2026-03-24-ir2-execution-plan.md`](../../../../../docs/0065-2026-03-24-ir2-execution-plan.md).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.

## Why this pass matters

- The folder previously had an important stale overread: it taught LICM as arbitrary value-expression caching through fresh temp locals.
- The reviewed Binaryen `version_129` source says the narrower contract is **whole none-typed loop-entry statement motion**.
- That correction matters for a future Starshine port because the implementation should start from loop-entry statement motion and local/effect dependency proofs, not from a generic CSE-like helper-local cache.
- The local full name still hides the upstream public `licm` alias, so source and test searches should use both spellings.

## Beginner summary

A good beginner mental model is:

- if the first statements in a loop always run when the loop is entered,
- and one of those statements has no result value of its own,
- and running it just before the loop would not change global state, mutable state, exceptions, traps, or local dependencies,
- Binaryen may move that whole statement before the loop and leave a `nop` in the original loop slot.

So this pass is best taught as:

- **conservative loop-preheader statement motion**,
- not generic code motion,
- not arbitrary expression hoisting,
- not local CSE,
- and not temp-local caching of every invariant subtree.

## Corrected durable takeaways

- Upstream public name: `licm`; local removed-registry name: `loop-invariant-code-motion`.
- The main implementation lives in upstream `src/passes/LoopInvariantCodeMotion.cpp`.
- The core loop visitor walks each loop body's **unconditional entrance** statements and stops when control-transfer effects appear.
- `interestingToMove(...)` only considers **none-typed** expressions and rejects several structural / store-like cases.
- Moving a statement is explicit: Binaryen records the statement, replaces its old loop-body slot with `nop`, and later emits a block containing moved statements followed by the loop.
- It uses effect analysis to reject global-state, exception, control-transfer, trap, and mutable-state hazards.
- It uses `LazyLocalGraph` plus local-set counting to reject statements that read locals changed by the loop or set locals that still have another in-loop set.
- Flattening can expose more independent none-typed statements, but LICM itself is not `flatten`.
- Current Starshine has no active LICM pass, owner file, or dedicated backlog slice.
- A 2026-04-25 current-main / port-readiness bridge found no teaching-relevant upstream drift and narrows the first Starshine slice to alias-policy, loop-entry candidate discovery, effect/local-dependency proof, cleanup-safe placeholders, reduced tests, and only then Binaryen oracle comparison.

## Explicit correction to older material

The archived 2026-04-21 research note remains useful history, but its temp-local phrasing is stale.
Use the 2026-04-24 raw source capture and follow-up as the corrected interpretation, plus the 2026-04-25 bridge as the current-main freshness and Starshine port-readiness source:

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md`](../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)

Do **not** teach Binaryen `version_129` LICM as creating fresh temps for arbitrary value expressions.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Source-backed Binaryen algorithm: loop discovery, entrance-statement scan, effect/local dependency guards, move emission, and 2026-04-25 current-main no-drift check.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./effects-loops-and-hoisting-rules.md`](./effects-loops-and-hoisting-rules.md)
  Focused guide to the real proof obligation: unconditional loop-entry placement, none-typed statement eligibility, effect safety, and local dependency guards.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing positive, mixed, and bailout WAT families with whole-statement moves.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future porting map, with exact local code and planning locations.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  First-slice and validation ladder for a future Starshine port: spelling/alias policy, loop-entry candidate discovery, safety summaries, rewrite repair, registry tests, and Binaryen `--licm` oracle comparison.

## Current maintenance rule

- Treat this folder as the canonical home for future `loop-invariant-code-motion` / `licm` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real active pass for it.
- Keep the scheduler fact explicit too: this is a real public Binaryen pass, but it is outside the current no-DWARF default optimize path.
- Keep the correction visible: reviewed Binaryen `version_129` LICM moves eligible none-typed entrance statements, not arbitrary value subtrees through newly synthesized temps.

## Sources

- [`../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md)
- [`../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md`](../../../raw/research/0378-2026-04-25-loop-invariant-code-motion-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md`](../../../raw/binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md)
- [`../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md`](../../../raw/research/0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md)
- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
- [`../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md)
- [`../../../../../docs/0065-2026-03-24-ir2-execution-plan.md`](../../../../../docs/0065-2026-03-24-ir2-execution-plan.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen primary sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/LoopInvariantCodeMotion.cpp>
