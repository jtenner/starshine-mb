---
kind: concept
status: supported
last_reviewed: 2026-07-03
sources:
  - ../../../raw/research/1403-2026-07-02-optimize-casts-recursive-audit-kickoff.md
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

`optimize-casts` now has an active HOT implementation in Starshine and has completed the v0.1.0 source/docs review for the reasonable Binaryen `version_130` local-flow surface. The pass removes provably redundant GC casts, folds statically known `ref.test` / descriptor-test outcomes, removes redundant descriptor casts, rewrites guaranteed-success/fail `br_on_cast` / `br_on_cast_fail`, implements strict early motion for source-backed linear windows, and implements later reuse through fresh exact refined carrier locals. It is covered by focused tests, a closeout-sized direct GenValid lane, a closeout-sized `optimize-casts-all` dedicated lane, broad/random evidence with one accepted measured Starshine static-fold win, explicit wasm-smith evidence accepted with `--normalize unreachable-control-debris`, O4z timing, and ordered neighborhood owner localization.

## Upstream-aligned closeout questions

The final source/docs review answers the upstream-aligned questions as follows:

- Can a cast be duplicated earlier only inside a strict linear window? **Yes**, for the source-backed root/nested-region windows Starshine implements; broader EffectAnalyzer generality is a non-goal until reduced evidence needs it.
- Can a later get reuse an already-computed cast through a refined carrier local? **Yes**, including direct get/tee/fallthrough-block/value-block cases and exact non-null carrier locals.
- Does a same-index `local.set` kill remembered facts immediately? **Yes**, and same-index `local.tee` has the same barrier treatment.
- Do side effects, calls, and non-linear control still block earlier motion? **Yes** for calls, call_ref-class exits, memory loads, trapping numeric roots, branches, and nonlinear control; later reuse may cross side-effect/call roots because the cast point does not move.
- Does `ref.as_non_null` only help when the target local is nullable? **Yes**, with explicit non-nullable-source negatives.

## Exact Starshine code surfaces

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize_casts.mbt` | active HOT implementation for redundant GC casts, statically known `ref.test` outcomes, descriptor casts/tests, guaranteed branch casts, strict earlier motion, later reuse, exact fresh carrier locals, and barrier handling. |
| `src/passes/optimize_casts_test.mbt` | direct behavior coverage for redundant `ref.cast`, guaranteed-true `ref.test`, descriptor casts/tests, branch casts, nullable-to-nonnull trap preservation, local-flow positives, barriers, source-backed move-cast families, and the exact `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` neighborhood order. |
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

Future widening after the v0.1.0 closeout should validate in this order:

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

Do not widen the active pass into a generic cast optimizer without a separate design and measurement. The reviewed `version_130` upstream oracle still does **not** own the following families even though Starshine's local direct pass intentionally keeps conservative direct-only rewrites for the first three:

- `ref.test`
- `br_on_cast` / `br_on_cast_fail`
- descriptor-cast rewrites
- extern-conversion simplification
- whole-CFG cast propagation, including Binaryen's own `past-basic-block` TODO
- immediate deletion of every redundant cast produced by the rewrite

Future work may still choose a local extension, but only with focused tests, direct/broad fuzz evidence, size or semantic benefit, and explicit reopening criteria.

## Related pages

- [`./index.md`](./index.md) - folder overview
- [`./binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and source-backed scope
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - owner and test surface map
- [`./two-phase-dataflow.md`](./two-phase-dataflow.md) - strict vs loose safety split
- [`./wat-shapes.md`](./wat-shapes.md) - concrete shapes and bailouts
- [`./starshine-strategy.md`](./starshine-strategy.md) - current active-pass status, direct parity evidence, and remaining neighborhood map
