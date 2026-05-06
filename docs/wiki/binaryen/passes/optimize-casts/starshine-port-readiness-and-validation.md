---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0500-2026-05-06-optimize-casts-starshine-port-readiness.md
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

`optimize-casts` is still removed-registry only in Starshine.
There is no implementation file, no dispatcher case, and no pass-specific rewrite code yet.
So the first port should be a measured module-local implementation, not a HOT-only peephole.

## The narrow first slice

Start with the upstream oracle exactly as it exists today:

1. `ref.cast`
2. `ref.as_non_null`

Keep the first slice small enough to prove the safety boundaries before widening anything else.
That means the first landing should be able to answer these questions:

- Can a cast be duplicated earlier only inside a strict linear window?
- Can a later get reuse an already-computed cast through a refined carrier local?
- Does a same-index `local.set` kill remembered facts immediately?
- Do side effects, calls, and non-linear control still block earlier motion?
- Does `ref.as_non_null` only help when the target local is nullable?

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize.mbt:143-149` | `optimize-casts` is still in `pass_registry_removed_names()`. |
| `src/passes/pass_manager.mbt` | no `optimize-casts` dispatcher case exists today. |
| `agent-todo.md:355-364` | backlog slice `OC` is the current planning anchor. |
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

A future port should validate in this order:

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
   - keep the backlog's `OC` slice honest about the narrower upstream scope

## Non-goals to preserve

Do not widen the first port into a generic cast optimizer.
The reviewed upstream oracle still does **not** own:

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
- [`./starshine-strategy.md`](./starshine-strategy.md) - current removed-registry status and local port map
