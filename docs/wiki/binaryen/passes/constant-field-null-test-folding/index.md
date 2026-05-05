---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/research/0474-2026-05-05-constant-field-propagation-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md
  - ../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md
  - ../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md
  - ../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md
  - ../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../constant-field-propagation/index.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../constant-field-propagation/index.md
  - ../constant-field-propagation/starshine-strategy.md
  - ../constant-field-propagation/starshine-port-readiness-and-validation.md
  - ../tracker.md
---

# `constant-field-null-test-folding` / upstream `cfp-reftest`

## Role

- `constant-field-null-test-folding` is the local Starshine registry name for the upstream Binaryen pass published as `cfp-reftest`.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt); the sibling-specific Starshine status/code-map page is [`./starshine-strategy.md`](./starshine-strategy.md), and the parent CFP Starshine page remains useful for shared infrastructure context in [`../constant-field-propagation/starshine-strategy.md`](../constant-field-propagation/starshine-strategy.md) and [`../constant-field-propagation/starshine-port-readiness-and-validation.md`](../constant-field-propagation/starshine-port-readiness-and-validation.md).
- It is a real public upstream pass in Binaryen `version_129`, but it is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` default top-level path.
- It is best understood as the **`constant-field-propagation` variant that adds one narrow `ref.test`-driven two-value field-read rewrite family**.

## Why this pass matters

- The main parity queue and first expansion queue are already dossier-covered, so this folder is an explicit source-backed tracker expansion for another real local registry entry.
- `agent-todo.md` currently has **no dedicated `constant-field-null-test-folding` or `cfp-reftest` slice**.
- The local registry already names this pass separately, but without a dossier the name is easy to misread as a broad null-test optimizer.
- The neighboring `constant-field-propagation` folder already proved there is a real upstream sibling variant here, so a dedicated landing page now helps keep the local-vs-upstream naming and variant split explicit.

## Beginner summary

A good beginner mental model is:

- Binaryen first runs the normal closed-world CFP analysis over struct fields
- plain `cfp` can replace a read only when one value bucket wins
- `cfp-reftest` adds one more rescue case: if **exactly two** buckets remain and one `ref.test` can distinguish them, the read may become a `select`

So this pass is best taught as:

- **field-read two-bucket subtype splitting on top of CFP**
- not as a generic null-test folding pass

## Most important durable takeaways

- The official upstream public name is `cfp-reftest`.
- The local Starshine registry currently calls it `constant-field-null-test-folding`.
- Binaryen `version_129` implements it by running the same `ConstantFieldPropagation` engine as plain `cfp`, but with the `optimizeUsingRefTest` mode enabled.
- The pass keeps all normal CFP gates and boundaries:
  - GC-only
  - closed-world-only
  - exact-vs-inexact reference reasoning
  - copy fixed point
  - packed-field and atomic safety
- The extra rewrite surface is narrower than the local name suggests:
  - exactly two tracked value buckets
  - exactly one usable classifier bucket per side
  - one legal subtype discriminator
  - optional `ref.as_non_null` repair plus validation of the repaired nonnullable `ref.test` form
  - replacement with `select(..., ..., ref.test(...))`
- It belongs to Binaryen's **closed-world GC/type cluster**, not to the repo's open-world no-DWARF default optimize path.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation, scheduler placement, helper dependencies, and the variant-only rewrite contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md`](./two-bucket-subtype-partitions-and-nonnullable-ref-test-gates.md)
  Source-confirmed mechanics page for the exact matcher: two tracked value buckets, one classifier bucket per side, subtype partition proof, nullable-base `ref.as_non_null` repair, and validation of the repaired nonnullable `ref.test` form.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing which field-read families become `select(ref.test(...))`, which stay plain `cfp`, and which still bail out.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and port map: boundary-only local alias, active request rejection, no owner file, no preset role, no backlog slice, prerequisite GC/type/parser/validator/binary surfaces, and why the sibling must layer on a future parent CFP module analysis rather than a HOT peephole.

## Current maintenance rule

- Treat this folder as the canonical home for future `constant-field-null-test-folding` / `cfp-reftest` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real pass for it.
- Keep the naming split explicit:
  - local registry: `constant-field-null-test-folding`
  - upstream public pass: `cfp-reftest`
- Keep the variant split explicit too:
  - this is not a separate analysis engine
  - it is the ordinary CFP engine plus one narrow `ref.test`-based read rewrite family

## Sources

- [`../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md`](../../../raw/binaryen/2026-04-25-constant-field-null-test-folding-primary-sources.md)
- [`../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md`](../../../raw/research/0335-2026-04-25-constant-field-null-test-folding-source-bridge.md)
- [`../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md`](../../../raw/binaryen/2026-04-24-constant-field-propagation-primary-sources.md)
- [`../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md`](../../../raw/research/0301-2026-04-24-constant-field-propagation-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md`](../../../raw/research/0216-2026-04-21-constant-field-null-test-folding-source-confirmation-followup.md)
- [`../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md`](../../../raw/research/0169-2026-04-21-constant-field-null-test-folding-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../constant-field-propagation/index.md`](../constant-field-propagation/index.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../constant-field-propagation/starshine-strategy.md`](../constant-field-propagation/starshine-strategy.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ConstantFieldPropagation.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-constant.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/struct-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp-reftest.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/cfp.wast>
