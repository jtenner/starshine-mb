---
kind: research
status: supported
last_reviewed: 2026-04-25
sources:
  - ../binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md
  - ../binaryen/2026-04-24-loop-invariant-code-motion-primary-sources.md
  - ./0282-2026-04-24-loop-invariant-code-motion-primary-sources-and-source-correction-followup.md
  - ./0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - ../../binaryen/passes/loop-invariant-code-motion/index.md
  - ../../binaryen/passes/loop-invariant-code-motion/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/registry_test.mbt
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - 0065-2026-03-24-ir2-execution-plan.md
---

# `loop-invariant-code-motion` port-readiness bridge

## Why this follow-up exists

The `loop-invariant-code-motion` dossier already corrected the main Binaryen overread on 2026-04-24: upstream `licm` moves eligible none-typed unconditional loop-entry statements, not arbitrary value expressions through synthesized temp locals.

The remaining gap was more local and practical: future Starshine implementers still had to infer the first safe local slice, the alias decision, and the validation ladder from the strategy and shape pages.

This follow-up keeps the existing folder as the canonical home and adds one port-readiness bridge rather than creating a duplicate pass dossier.

## Primary source added

New raw source bridge:

- `docs/wiki/raw/binaryen/2026-04-25-loop-invariant-code-motion-current-main-port-readiness.md`

It records the official Binaryen current-`main` URLs checked for:

- `src/passes/LoopInvariantCodeMotion.cpp`
- `src/passes/pass.cpp`
- `src/passes/pass.h`
- `src/ir/effects.h`
- `src/ir/find_all.h`
- `src/ir/local-graph.h`
- `src/wasm-builder.h`
- `test/lit/passes/licm.wast`

## Durable findings

### 1. No teaching-relevant current-main drift

The current-main bridge found no evidence to change the corrected `version_129` contract.
`licm` remains:

- function-parallel;
- loop-local;
- prefix-scoped to the unconditional loop-entry surface;
- none-typed and whole-statement based;
- guarded by effect hazards, local-set counts, and `LazyLocalGraph` local dependency checks;
- implemented as moved statements plus a `nop` placeholder at the original loop-body slot.

### 2. Starshine needs an alias decision before implementation exposure

The local registry preserves only the long name `loop-invariant-code-motion` as removed bookkeeping.
Upstream users request `licm`.

A future implementation should decide explicitly whether to expose:

- only the upstream alias `licm`,
- only the existing local long name,
- or both names with one canonical implementation descriptor.

The docs should not imply that either spelling is active today.

### 3. The first local slice should be smaller than a generic code-motion pass

The source-backed first slice is:

- identify loop-entry statement prefixes;
- move only none-typed statements already present in that prefix;
- reject all effect, trap, exception, global-state, mutable-state, and local-dependency hazards;
- insert a cleanup-safe placeholder or equivalent deletion shape;
- validate reduced WAT shapes against Binaryen before trying flattened or deeply nested families.

That is intentionally smaller than value-expression hoisting, CSE, `precompute`-style folding, or `code-pushing`.

### 4. Local code anchors are now explicit

The refreshed living pages now point to the exact current local status surfaces:

- `src/passes/optimize.mbt:98-106` for removed-entry construction;
- `src/passes/optimize.mbt:144-151` for the removed-name list containing `loop-invariant-code-motion`;
- `src/passes/optimize.mbt:469-472` for request rejection;
- `src/passes/registry_test.mbt:171-179` for the generic removed-name rejection test;
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:49-52` for Batch 3 planning;
- `docs/0065-2026-03-24-ir2-execution-plan.md:37-43` for migration order.

## Living pages refreshed

- `docs/wiki/binaryen/passes/loop-invariant-code-motion/index.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-strategy.md`
- `docs/wiki/binaryen/passes/loop-invariant-code-motion/starshine-port-readiness-and-validation.md`
- `docs/wiki/index.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/log.md`

## Follow-up rule

Future LICM work should start from the existing dossier plus this readiness page.
Only rewrite the Binaryen strategy if later primary sources change loop-entry scanning, none-typed eligibility, effect/local dependency checks, or moved-statement emission.
