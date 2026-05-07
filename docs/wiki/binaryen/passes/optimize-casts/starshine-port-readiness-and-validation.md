---
kind: concept
status: supported
last_reviewed: 2026-05-08
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md
  - ../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md
  - ../../../raw/research/0551-2026-05-08-optimize-casts-ordered-slot-replay.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../heap2local/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine Port-Readiness And Validation For `optimize-casts`

Use this bridge with:

- [`./starshine-strategy.md`](./starshine-strategy.md) for the current local status;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for exact owner/test surfaces;
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md) for the strict-vs-loose safety split;
- [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after families.

## Current local reality

`optimize-casts` now has an active narrow HOT implementation in Starshine. The current pass removes provably redundant GC casts, folds statically known `ref.test` / descriptor-test outcomes, removes redundant descriptor casts, and rewrites guaranteed-success `br_on_cast` / `br_on_cast_fail`; it is direct-pass revalidated, the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood is debug-artifact proven, and public `optimize` / `shrink` now schedule that slot.

## Remaining upstream-aligned widening

The active Starshine pass is direct-parity green for its current narrow rewrite. A future upstream-aligned widening should still start from the reviewed Binaryen oracle exactly as it exists today:

1. `ref.cast`
2. `ref.as_non_null`

Keep upstream-aligned widening small enough to prove the safety boundaries before widening anything else.
That means the next upstream-aligned landing should be able to answer these questions:

- Can a cast be duplicated earlier only inside a strict linear window?
- Can a later get reuse an already-computed cast through a refined carrier local?
- Does a same-index `local.set` kill remembered facts immediately?
- Do side effects, calls, and non-linear control still block earlier motion?
- Does `ref.as_non_null` only help when the target local is nullable?

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize_casts.mbt` | active narrow HOT implementation for redundant GC casts, statically known `ref.test` outcomes, descriptor casts/tests, and guaranteed-success branch casts. |
| `src/passes/optimize_casts_test.mbt` | direct behavior coverage for redundant `ref.cast`, guaranteed-true `ref.test`, descriptor casts/tests, guaranteed-success `br_on_cast` / `br_on_cast_fail`, nullable-to-nonnull trap preservation, and the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood order. |
| `src/passes/optimize.mbt` | active registry coverage for `optimize-casts` plus the public `optimize` / `shrink` slot immediately after `heap2local`. |
| `src/passes/pass_manager.mbt` | dispatcher routes `optimize-casts` to `optimize_casts_run(...)`. |
| `agent-todo.md` | the standalone `OC` preset-readiness gate is closed; remaining broader GC/local follow-up now lives under neighboring backlog slices. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | canonical scheduler slot: after `heap2local`, before `local-subtyping -> coalesce-locals -> local-cse`. |
| `docs/wiki/binaryen/passes/heap2local/index.md` | upstream feeder for stronger local cast facts. |
| `docs/wiki/binaryen/passes/local-subtyping/index.md` | immediate left neighbor and later type-narrowing consumer. |
| `docs/wiki/binaryen/passes/coalesce-locals/index.md` | cleanup neighbor that should consume narrower traffic. |
| `docs/wiki/binaryen/passes/local-cse/index.md` | later local-value-flow consumer. |
| `src/lib/types.mbt:723-764` | ref-cast / ref-test / br_on_cast surface already exists locally. |
| `src/lib/types.mbt:3995-3996` | `Instruction::ref_as_non_null()` constructor. |
| `src/lib/types.mbt:4170-4171` | `Instruction::ref_cast(...)` constructor. |
| `src/wast/lower_to_lib.mbt:1297-1298` | WAT lowering for `ref.as_non_null`. |
| `src/binary/encode.mbt:2580` | binary opcode emission for `ref.as_non_null`. |
| `src/binary/encode.mbt:2897-2912` | binary opcode emission for nullable and non-nullable `ref.cast`. |
| `src/binary/decode.mbt:3116-3124` | binary decode surface for `ref.cast`. |
| `src/validate/typecheck.mbt:3228` | validation dispatch for `ref.as_non_null`. |
| `src/validate/typecheck.mbt:3265` | validation dispatch for `ref.cast`. |
| `src/ir/hot_core.mbt:70-73` | HOT op variants for cast/test families. |
| `src/ir/hot_flags.mbt:81` | HOT trap flag for `RefCast` / descriptor cast. |
| `src/ir/hot_lift.mbt:612-625` | HOT arity/classification surface for unary/ref cast/test families. |
| `src/ir/hot_lift.mbt:764-818` | instruction-to-HOT classification for ref test/cast and unary `ref.as_non_null`. |
| `src/ir/hot_lower.mbt:1080-1084` | HOT-to-lib lowering family for ref test/cast operations. |

## Validation ladder

Future widening should validate in this order:

1. strict earlier-motion positives
   - `ref.cast` duplicated only when the path stays linear
   - `ref.as_non_null` duplicated only when the target local is nullable
2. same-index and barrier negatives
   - `local.set` invalidation
   - side-effect and call barriers
   - non-linear-window bailouts
3. later-reuse positives
   - fresh refined carrier locals
   - redirected later gets
   - refinalized types after the rewrite
4. neighbor interactions
   - `heap2local -> optimize-casts`
   - `optimize-casts -> local-subtyping`
   - `local-subtyping -> coalesce-locals`
   - `coalesce-locals -> local-cse`
5. oracle comparison
   - compare the implemented slice directly against Binaryen
   - keep any broader post-`OC` GC/local follow-up honest about the narrower upstream scope

## Non-goals to preserve

Do not widen the active pass into a generic cast optimizer.
The reviewed upstream oracle still does **not** own the following families even though Starshine's local direct pass now has conservative direct-only rewrites for the first three:

- `ref.test`
- `br_on_cast` / `br_on_cast_fail`
- descriptor-cast rewrites
- extern-conversion simplification
- whole-CFG cast propagation
- immediate deletion of every redundant cast produced by the rewrite

Those may be future work, but they are not the reviewed contract.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and source-backed scope
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md) - strict vs loose safety split
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes and bailouts
- [`./starshine-strategy.md`](./starshine-strategy.md) - current active-pass status, direct parity evidence, and remaining neighborhood map
