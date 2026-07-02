# Optimize Casts Recursive Audit Kickoff

Date: 2026-07-02

## Goal

Audit and implement all reasonable transform families for Starshine `optimize-casts` under the v0.1.0 `-O4z` per-pass audit rules.

Original recursive goal:

- Make an inventory of all the reasonable GenValid fuzz generators that need to be created
- Look for blockers and risks that prevent OC from being implemented, and fix them
- Implement the fixes and bring OC to parity (or better!)
- Update docs to reflect the state of the OC pass.

## Source refresh

Local oracle/source inputs for this slice:

- `wasm-opt --version` should be treated as the local Binaryen oracle version for follow-up validation. This slice fetched the official `version_130` `src/passes/OptimizeCasts.cpp` and `test/lit/passes/optimize-casts.wast` into `.tmp/oc-audit/` for source inspection.
- `OptimizeCasts.cpp` remains a function-parallel, GC-gated pass with two source-backed phases:
  1. `EarlyCastFinder` / `EarlyCastApplier`: duplicate a later `ref.cast` or `ref.as_non_null` to an earlier `local.get` in a strict linear-execution window, using effect barriers and same-index local writes to preserve trap timing.
  2. `BestCastFinder` / `FindingApplier`: save an already-computed best cast in a fresh local via `local.tee`, then retarget later less-refined `local.get`s in connected adjacent blocks until same-index writes or nonlinear flow clear the fact.
- Official lit coverage enumerates the useful family names: `ref.as`, `ref.as-no`, `ref.cast`, `not-past-set`, `yes-past-call`, `not-past-call_ref`, `not-backwards-past-call`, `not-backwards-past-call_ref`, `best`, `best-2`, `fallthrough`, `past-basic-block`, `multiple`, `move-cast-1` through `move-cast-6`, `no-move-already-refined-local`, `no-move-ref.as-to-non-nullable-local`, `avoid-erroneous-cast-move`, `move-as-1` / `move-as-2`, `move-cast-side-effects`, `move-ref.as-for-separate-index`, `move-ref.as-and-ref.cast*`, nested/unoptimizable casts, tee barriers, repeated casts, nonlinear boundaries, and helper functions.

## Current Starshine implementation state

`src/passes/optimize_casts.mbt` is active but still only covers the local static-folding subset:

- redundant `ref.cast` / `ref.cast_desc_eq` when the source statically matches the target;
- guaranteed `ref.test` / `ref.test_desc` true/false folds;
- guaranteed-success/fail `br_on_cast` and `br_on_cast_fail` rewrites;
- nullable-to-non-null trap preservation.

It does **not** yet implement either upstream local-flow phase:

- earlier duplication of later `ref.cast` / `ref.as_non_null` to earlier `local.get`s;
- later reuse of an already-computed cast through a fresh refined local and retargeted less-refined gets.

## Reasonable dedicated GenValid generator inventory

The pass-specific aggregate should be named `optimize-casts-all`, with deterministic selected-profile metadata. Reasonable leaves:

1. `optimize-casts-later-reuse`: already-computed `ref.cast` and `ref.as_non_null` followed by one or more later same-local `local.get`s that should be retargeted through a fresh refined local.
2. `optimize-casts-early-motion`: earlier same-local `local.get`s followed by later safe `ref.cast` / `ref.as_non_null` candidates in a strict linear window.
3. `optimize-casts-barriers`: same-index `local.set`, possible-call/trap/control, `call_ref`, local.tee/self-tee, and nonlinear boundaries that must prevent unsafe motion or fact reuse.
4. `optimize-casts-best-cast`: multiple related casts where the narrowest subtype wins, repeated-identical casts are ignored, and unrelated casts remain conservative.
5. `optimize-casts-ref-as`: nullable-to-non-null `ref.as_non_null` positives plus non-nullable source negatives.
6. `optimize-casts-static-folds`: current Starshine-only/static families (`ref.test`, descriptor casts/tests, branch casts) so existing behavior remains fuzzed even though upstream `OptimizeCasts.cpp` is narrower.
7. `optimize-casts-neighborhood`: small `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse` cases where H2L exposes the cast traffic and later local cleanup consumes refined locals.

The aggregate should be documented in `docs/wiki/binaryen/passes/optimize-casts/fuzzing.md` before closeout and used as the pass-specific `10000` GenValid lane.

## Blockers and risks

- **Implementation gap:** the upstream two-phase local-flow algorithm is absent; green historical direct fuzz lanes only prove the current static-folding subset was stable.
- **Doc drift:** `starshine-strategy.md` still contains stale pre-port wording saying no MoonBit implementation file exists, contradicting the active pass and tests.
- **Trap timing:** early motion is stricter than later reuse. Moving `ref.cast` / `ref.as_non_null` earlier across calls, stores, or nonlinear control can create earlier traps and is unsafe.
- **Fresh locals/refinalization:** later reuse adds locals and retargets get types. Starshine must update local types and invalidate/refinalize enough for validation and later cleanup consumers.
- **Generator gap:** there is no `optimize-casts-*` GenValid profile today, so final matrix signoff lacks a dedicated pass trigger lane.

## Recommended first implementation slices

1. Add red-first tests for Binaryen later-reuse basics: `ref.cast(local.get x)` followed by later `local.get x`, same-index `local.set` barrier, and `ref.as_non_null` nullable local reuse.
2. Implement a conservative root/linear HOT later-reuse subset that wraps the original cast in `local.tee` only when at least one later get is actually retargeted.
3. Add early-motion tests separately only after the later-reuse local/refinalization path is stable.
4. Add dedicated GenValid profiles once the target implementation families are known enough to generate meaningful positives rather than no-op valid modules.
