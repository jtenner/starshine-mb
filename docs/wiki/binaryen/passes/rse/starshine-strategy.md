---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/ir/use_def.mbt
  - ../../../../../src/ir/hot_module_context.mbt
  - ../../../../../src/ir/ssa_local.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals/index.md
  - ../local-cse/index.md
  - ../vacuum/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./cfg-and-value-tracking.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/index.md
  - ../local-cse/index.md
  - ../vacuum/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Starshine Strategy For `rse`

Use this page with the corrected primary-source capture in [`../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md`](../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md).
The most important 2026-04-26 change is that the future Starshine port needs a **small CFG/value-flow substrate**, not the stale straight-line-only plan from 2026-04-25.

## Honest current status

`rse` is still **unimplemented** in Starshine.
There is no `src/passes/rse.mbt` and no `src/passes/redundant_set_elimination.mbt` owner file today.

Current local behavior is registry/backlog tracking only:

- [`src/passes/optimize.mbt:144-152`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_removed_names()` includes `"redundant-set-elimination"`.
- [`src/passes/pass_manager.mbt:8685-8705`](../../../../../src/passes/pass_manager.mbt)
  - the hot-pass dispatcher match has no `"rse"` or `"redundant-set-elimination"` arm.
- [`agent-todo.md:481-491`](../../../../../agent-todo.md)
  - backlog slice `RSE` exists and now describes CFG-aware same-value local set/tee work plus refined local-get retargeting.
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - documents the late no-DWARF slot before final cleanup.

## Corrected local strategy

A faithful first Starshine port should implement Binaryen's `version_129` contract:

1. collect ordered local-get/local-set/local-tee sites per HOT/basic block;
2. compute per-local value identities at block starts and ends until CFG facts converge;
3. synthesize merge identities for predecessor disagreement instead of choosing one path;
4. remove a `local.set` only when its RHS has the same value identity as the current target-local identity;
5. remove a `local.tee` under the same condition while preserving the RHS result;
6. retarget a `local.get` to another local only when both locals hold the same identity and the replacement local's declared type is a strict subtype;
7. run/compare the pass in the late `rse -> vacuum` cleanup context.

That is a CFG-aware local-value cleanup pass, not a generic liveness dead-store pass.

## Exact code locations a future port must touch

### Registry

- [`src/passes/optimize.mbt:144-152`](../../../../../src/passes/optimize.mbt)
  - Move `"redundant-set-elimination"` out of `pass_registry_removed_names()` once implemented.
  - Add an active hot-pass registry entry and descriptor near the other local cleanup passes.
  - Decide whether to expose only the long upstream spelling or also the short `rse` alias.

### Dispatcher

- [`src/passes/pass_manager.mbt:8685-8705`](../../../../../src/passes/pass_manager.mbt)
  - Add a hot-pass match arm beside `simplify-locals`, `merge-blocks`, and other late cleanup passes.
  - Reuse existing validation/writeback policy rather than adding pass-specific raw bypasses first.
  - Keep preset placement near the final cleanup cluster only after direct parity is green.

### Likely new owner file

- Suggested: `src/passes/redundant_set_elimination.mbt`
  - Own the pass-local CFG/value-flow table.
  - Own value identity and merge identity assignment.
  - Own set/tee rewrite rules.
  - Own refined local-get retargeting and type gates.
  - Own focused tests in `src/passes/redundant_set_elimination_test.mbt`.

### Existing Starshine analysis surfaces to read

- [`src/ir/use_def.mbt:1-120`](../../../../../src/ir/use_def.mbt)
  - Local read/write collection exists, but it is not yet Binaryen-style value numbering or block merge flow.
- [`src/ir/hot_module_context.mbt:1-58`](../../../../../src/ir/hot_module_context.mbt)
  - Module subtype/function type context exists and is the likely source for refined-local type checks.
- [`src/ir/ssa_local.mbt`](../../../../../src/ir/ssa_local.mbt)
  - Useful local-SSA infrastructure to read before designing value identities, but not a mandate to port broad SSA/liveness behavior.

## Neighboring pass relationships

### `simplify-locals`

See [`../simplify-locals/index.md`](../simplify-locals/index.md).

`rse` should run after earlier local simplification because those passes expose repeated same-value local writes and tees.
The relationship is producer-consumer, not replacement.

### `local-cse`

See [`../local-cse/index.md`](../local-cse/index.md).

`local-cse` can create local reuse opportunities that later value-number equalities make visible to `rse`.
Do not collapse the two passes: `local-cse` introduces/reuses temporaries for repeated expressions, while `rse` removes redundant writes and retargets some gets.

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
- Binaryen `LocalGraph` or liveness-backed dead overwritten writes;
- expression cloning/substitution for arbitrary `local.get`s;
- value propagation outside the local get/set/tee surface.

Those are not source-backed `version_129` `rse` requirements.
If the project wants them later, document them as separate Starshine-local extensions.

## Validation ladder

1. Focused WAT tests for same-block same-value `local.set` and `local.tee`.
2. CFG tests for branch-join agreement, branch-join disagreement, and loop convergence/skip behavior.
3. Negative WAT tests for different overwritten writes.
4. RHS trap/effect preservation tests.
5. GC/ref-type local-get retargeting tests modeled on Binaryen `rse-gc.wast`.
6. Direct `bun fuzz compare-pass ... --pass redundant-set-elimination` once the harness accepts the name.
7. Late-cluster replay with `rse -> vacuum`.
8. Saved generated-artifact prefix replay around the historical slot `46` before declaring parity.

## Current uncertainty

Two local design decisions remain open:

- **Name surface:** upstream exposes the public long name `redundant-set-elimination` and the shorthand `rse` appears in pipeline/debug contexts; Starshine currently tracks only the long name as removed.
- **CFG/value substrate:** Binaryen definitely has a CFG flow here, but Starshine still needs to decide whether to build a pass-local value-flow helper or reuse broader HOT block/use-def/SSA infrastructure without widening semantics.
