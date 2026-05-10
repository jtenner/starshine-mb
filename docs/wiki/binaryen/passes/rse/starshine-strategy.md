---
kind: concept
status: supported
last_reviewed: 2026-05-10
sources:
  - ../../../raw/research/0538-2026-05-06-rse-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md
  - ../../../raw/research/0463-2026-05-05-rse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md
  - ../../../raw/research/0382-2026-04-26-rse-cfg-source-correction-and-port-readiness.md
  - ../../../../../src/passes/rse.mbt
  - ../../../../../src/passes/rse_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
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

Use this page with the current-main bridge in [`../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-rse-current-main-recheck.md) and the corrected primary-source capture in [`../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md`](../../../raw/binaryen/2026-04-26-rse-cfg-source-correction.md).
The most important teaching point remains the same: the future Starshine port needs a **small CFG/value-flow substrate**, not the stale straight-line-only plan from 2026-04-25.

## Honest current status

`rse` is now **implemented as an active direct pass** in Starshine under the long upstream spelling `redundant-set-elimination`.

Current local behavior:

- `src/passes/rse.mbt` owns the descriptor, summary, HOT same-value rewrite, raw lowered-function value tracker, default body-local identities, branch merge sentinels, and raw strict-subtype local-get retargeting.
- `src/passes/optimize.mbt` registers `"redundant-set-elimination"` as an active hot pass instead of a removed name.
- `src/passes/pass_manager.mbt` dispatches the hot pass, constructs the module validation environment needed for raw subtype checks, and runs the raw fast path before hot lift for lowered functions.
- `src/cmd/cmd_wbtest.mbt`, `src/passes/rse_test.mbt`, and `src/passes/registry_test.mbt` cover CLI, direct HOT behavior, raw branch-merge/default/refined-get behavior, and registry classification.
- The pass remains **direct-only**; the late no-DWARF preset slot is not scheduled yet.

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

## Exact code locations touched by the active port

### Registry

- `src/passes/optimize.mbt`
  - Keeps `"redundant-set-elimination"` as an active hot-pass registry entry near `merge-blocks`.
  - The short `rse` name is accepted by compare harnesses as a Binaryen/Starshine alias, not as a public CLI registry name.

### Dispatcher

- `src/passes/pass_manager.mbt`
  - Runs `rse_run_raw_func` before hot lift for `redundant-set-elimination`.
  - Keeps the normal hot-pass dispatcher arm for focused HOT tests and fallback behavior.
  - Keeps preset placement near the final cleanup cluster deferred until refined-get and late-tail proof are complete.

### Owner file

- `src/passes/rse.mbt:2-8`
  - Owns the active direct-pass descriptor.
- `src/passes/rse.mbt:12-16`
  - Owns the summary.
- `src/passes/rse.mbt:692-700`
  - Owns the raw lowered-function value tracker used to keep the debug-artifact lane fast.
- `src/passes/optimize.mbt:253-256`
  - Registers the active hot-pass name.
- `src/passes/pass_manager.mbt:7324-7334`
  - Runs `rse_run_raw_func` before hot lift for `redundant-set-elimination`.
- `src/passes/rse_test.mbt:41-71`
  - Owns the focused same-value set/tee tests.
  - Should own future fixed-point CFG merge and refined local-get retargeting work.

### 2026-05-10 RSE002 progress

- Added branch-disagreement merge identities so a later `local.set $x (local.get $x)` can fold even when predecessor values differ.
- Initialized raw body-local value facts to default values where the local type is defaultable, matching Binaryen's ability to remove redundant default writes.
- Added raw strict-subtype equivalent-local `local.get` retargeting using the module validation environment; the reduced fixture retargets an `anyref` local read to an equivalent `eqref` local.
- Added raw structured block/if label-exit merge tracking plus unreachable-tail skipping so branch exits like `block ... br_if 0 ... end; i32.const 1; local.set` no longer misfold the final const set.
- Refreshed direct compare-pass parity at `.tmp/pass-fuzz-rse-rse002-next-followup`: `6759/10000` compared, `6759` normalized matches, `0` mismatches, and `20` Binaryen/tool command failures.
- Replayed `--redundant-set-elimination --vacuum` at `.tmp/rse002-rse-vacuum`; it initially remained red at `defined=0 abs=17` because nested `drop(...)` / `nop` cleanup debris remained in Starshine's paired vacuum output while Binaryen removed it.
- Follow-up cleanup taught vacuum to recurse into nested value-expression control regions for small functions, added a raw no-candidate vacuum skip to avoid lifting unchanged functions, preserved raw RSE fallthrough facts after one-armed terminating `if`s, and added Binaryen-style vacuum inversion for empty-then/live-else void `if`s. The replay at `.tmp/rse002-rse-vacuum-final` moved past the `defined=29 abs=46` empty-then / double-`eqz` family to `defined=208 abs=225`.
- The current `rse -> vacuum` exact replay residual is classified as inherited direct-`vacuum` representation drift: `.tmp/rse002-vacuum-baseline` has the same first differing function, and Starshine's focused `func-defined208-abs225` WAT and pretty files are byte-identical with and without RSE.

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
2. CFG tests for branch-join agreement, branch-join disagreement, block-exit disagreement, and loop convergence/skip behavior.
3. Negative WAT tests for different overwritten writes.
4. RHS trap/effect preservation tests.
5. GC/ref-type local-get retargeting tests modeled on Binaryen `rse-gc.wast`.
6. Direct `bun fuzz compare-pass ... --pass redundant-set-elimination`; current evidence includes `.tmp/pass-fuzz-redundant-set-elimination` from 2026-05-06 with 6759 comparable matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group command failures.
7. Direct debug-artifact replay; current evidence is `.tmp/self-opt-rse-native-20260426b` with normalized WAT equality via fallback and canonical function equality.
8. Late-cluster replay with `rse -> vacuum`.
9. Saved generated-artifact prefix replay around the historical slot `46` before declaring preset parity.

## Current uncertainty

Two local design decisions remain open:

- **Name surface:** upstream exposes the public long name `redundant-set-elimination` and the shorthand `rse` appears in pipeline/debug contexts; Starshine exposes the long CLI/registry name and maps `--rse` inside compare harnesses.
- **CFG/value substrate:** Binaryen definitely has a fuller fixed-point CFG flow than the active Starshine slice; future work should carry the new raw block/if label-exit identities through the remaining HOT/control families and add loop fixed-point or explicit conservative loop contracts without widening into liveness-backed dead-store elimination.
