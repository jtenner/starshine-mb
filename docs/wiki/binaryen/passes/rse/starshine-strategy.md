---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-rse-source-correction.md
  - ../../../raw/research/0348-2026-04-25-rse-source-correction-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/liveness.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ../simplify-locals/index.md
  - ../vacuum/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine Strategy For `rse`

Use this page with the corrected primary-source capture in [`../../../raw/binaryen/2026-04-25-rse-source-correction.md`](../../../raw/binaryen/2026-04-25-rse-source-correction.md).
The most important 2026-04-25 change is that the future Starshine port should be **smaller** than the older dossier suggested.

## Honest current status

`rse` is still **unimplemented** in Starshine.
There is no `src/passes/rse.mbt` and no `src/passes/redundant_set_elimination.mbt` owner file today.

Current local behavior is registry/backlog tracking only:

- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_removed_names()` includes `"redundant-set-elimination"`.
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - the hot-pass dispatcher match has no `"rse"` or `"redundant-set-elimination"` arm.
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
  - backlog slice `RSE` exists and now describes source-faithful same-value local set/tee work.
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - documents the late no-DWARF slot before final cleanup.

## Corrected local strategy

A faithful first Starshine port should implement Binaryen's `version_129` contract:

1. track one current value identity per local while walking HOT expressions;
2. refine `local.get` value/type identity when the remembered expression is safely assignable;
3. remove a `local.set` only when its RHS has the same value identity as the remembered value for the target local;
4. remove a `local.tee` under the same condition while preserving the RHS result;
5. clear one local or all locals at conservative barriers;
6. run/compare the pass in the late `rse -> vacuum` cleanup context.

That is a local-value-number cleanup pass, not a generic dead-store pass.

## Exact code locations a future port must touch

### Registry

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - Move `"redundant-set-elimination"` out of `pass_registry_removed_names()` once implemented.
  - Add an active hot-pass registry entry and descriptor.
  - Decide whether to expose only the upstream spelling or also the short CLI alias `rse`.

### Dispatcher

- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
  - Add a hot-pass match arm beside the other local cleanup passes.
  - Reuse existing validation/writeback policy rather than adding pass-specific raw bypasses first.
  - Keep the pass near the final cleanup cluster in preset expansion only after direct parity is green.

### Likely new owner file

- Suggested: `src/passes/redundant_set_elimination.mbt`
  - Own the per-local current-value table.
  - Own the set/tee rewrite rules.
  - Own barrier invalidation policy.
  - Own focused tests in `src/passes/redundant_set_elimination_test.mbt`.

### Existing analysis surfaces to read, but not over-port

- [`src/ir/use_def.mbt`](../../../../../src/ir/use_def.mbt)
- [`src/ir/liveness.mbt`](../../../../../src/ir/liveness.mbt)
- [`src/ir/ssa_local.mbt`](../../../../../src/ir/ssa_local.mbt)

These are useful local infrastructure, but the corrected Binaryen source does not require a liveness or SSA fixed-point port for baseline parity.
Use them only if they make value identity or testing easier.
Do not let them turn the first port into a broader dead-store optimizer.

## Neighboring pass relationships

### `simplify-locals`

See [`../simplify-locals/index.md`](../simplify-locals/index.md).

`rse` should run after earlier local simplification because those passes expose repeated same-value local writes and tees.
The relationship is producer-consumer, not replacement.

### `vacuum`

See [`../vacuum/index.md`](../vacuum/index.md).

`rse` can leave `drop(value)` after removing a plain `local.set` shell.
`vacuum` is the intended cleanup consumer for pure unused values.
A Starshine port should compare both direct `--rse` and late `--rse --vacuum` shapes.

## What Starshine should not implement first

Do **not** make the initial parity slice cover:

- globals;
- memory stores;
- `struct.set` or `array.set`;
- LocalGraph predecessor merges;
- liveness-backed dead overwritten writes;
- same-block `local.get` rewriting;
- copied-local provenance inheritance;
- exact-vs-merged CFG lattices.

Those were older local-wiki overreads, not source-backed `version_129` requirements.
If the project wants them later, document them as separate Starshine-local extensions.

## Validation ladder

1. Focused WAT tests for same-value `local.set` and `local.tee`.
2. Negative WAT tests for different overwritten writes.
3. Barrier tests for calls, branches, loops, and other invalidation points.
4. GC/ref-type local-get refinement tests modeled on Binaryen `rse-gc.wast`.
5. Direct `bun fuzz compare-pass ... --pass redundant-set-elimination` once the harness accepts the name.
6. Late-cluster replay with `rse -> vacuum`.
7. Saved generated-artifact prefix replay around the historical slot 46 before declaring parity.

## Current uncertainty

The only remaining design uncertainty is local naming:

- upstream exposes the public long name `redundant-set-elimination` and the pipeline/debug logs often use `rse` shorthand;
- Starshine currently tracks only the long name as removed.

When implementing, choose whether the CLI accepts both names or only the canonical upstream registry spelling, and record that decision in this page.
