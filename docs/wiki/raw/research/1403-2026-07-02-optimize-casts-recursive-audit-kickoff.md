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

## Slice 1 implementation result

The first recursive slice added red-first public-pipeline coverage for later reuse of an already-computed `ref.cast(local.get x)` and for the same-index `local.set` barrier. The tests failed before implementation because Starshine did not create a `local.tee` or retarget later gets.

`src/passes/optimize_casts.mbt` now has a conservative root-linear later-reuse subset:

- remembers direct `ref.cast(local.get x)` refinements after a root statement;
- when a later root reads the same local, appends a fresh body local, wraps the original cast in `local.tee`, and retargets that later `local.get` to the fresh local;
- clears the remembered fact after same-local `local.set` / `local.tee` writes so later reads past the write remain on the original local;
- chooses nullable fresh locals for now because the current Starshine validator/local model does not accept Binaryen's non-null body-local shape in this path.

Validation for this slice:

- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` passed `10/10` after failing red-first before implementation.
- `moon test src/passes` passed `3825/3825`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-later-reuse-smoke-100-nativepath --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This is forward progress, not OC closeout. Open local-flow gaps remain: `ref.as_non_null` later reuse, nested/fallthrough cast recognition, best-cast selection breadth, adjacent-block/nonlinear behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, O4z slot evidence, and pass-local timing.

## Slice 2 implementation result

The second recursive slice added red-first public-pipeline coverage for later reuse of an already-computed `ref.as_non_null(local.get x)` and for the non-nullable-source negative that must not materialize a fresh local when the original local is already non-null. The positive failed before implementation because Starshine did not create a `local.tee` or retarget the later read.

`src/passes/optimize_casts.mbt` now recognizes direct nullable-source `ref.as_non_null(local.get x)` as another conservative root-linear later-reuse refinement and routes it through the same fresh-local/local.tee path as the first `ref.cast` subset. The nullable-fresh-local workaround remains unchanged. Non-nullable `ref.as_non_null` sources are intentionally excluded from this reuse path because the local is already refined enough and materializing a fresh local would only add traffic.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first at `optimize-casts reuses an already computed ref.as_non_null for later local gets` before implementation, then passed `12/12` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3827/3827`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-ref-as-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: fallthrough/tee/repeated-cast recognition, best-cast subtype selection breadth, adjacent-block/nonlinear behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 3 implementation result

The third recursive slice added red-first public-pipeline coverage for two `local.tee` later-reuse edges:

- a direct `ref.cast(local.tee x ...)` should seed the same-local later-reuse fact and retarget a later same-local root read through the fresh refined local;
- a later same-local `local.tee` write must be a write barrier, so the pass must not retarget that root's own reads through the fresh refined local or carry the fact to following reads.

Both new tests failed before implementation: the first still lacked a fresh-local retarget, and the second exposed the existing unsafe/invalid reuse through a same-local `local.tee` write.

`src/passes/optimize_casts.mbt` now recognizes direct `LocalTee` children as later-reuse refinement sources for `ref.cast` and nullable-source `ref.as_non_null`, and pre-scans each root for local writes before retargeting. When a root writes the remembered local, the pass skips retargeting that root for the same local, then clears the remembered cast fact and fresh-local mapping before collecting new refinements from the root. This preserves the same conservative root-linear subset while covering the Binaryen-lit-style `local-tee` source shape and tightening the write barrier.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new `local.tee` tests before implementation, then passed `14/14` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3829/3829`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-tee-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: fallthrough/repeated-cast recognition, best-cast subtype selection breadth, adjacent-block/nonlinear behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 4 implementation result

The fourth recursive slice added red-first public-pipeline coverage for the first repeated/best-cast source families:

- a repeated identical `ref.cast(local.get x)` should not have its source read retargeted through the previously materialized fresh local;
- a later narrower subtype cast should remain available as the remembered best cast for following same-local reads instead of being rewritten through an earlier, less-refined fresh local.

Before implementation, the repeated-cast case produced two `local.get (Local 1)` uses instead of one, and the subtype-chain fixture exposed invalid/stale best-cast behavior. The implementation now pre-collects each root's refinement candidates before later-reuse retargeting and skips retargeting reads of a local inside roots that themselves compute a refinement for that local. This lets repeated casts keep their original source, lets the later subtype cast replace the remembered best-cast fact, and still preserves the prior same-local `local.set` / `local.tee` write-barrier pre-scan. The focused test helper now includes a child struct subtype in void fixtures so the subtype-chain case exercises a real base-to-child cast.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new repeated/best-cast tests before implementation, then passed `16/16` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3831/3831`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-bestcast-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: fallthrough/adjacent-block recognition, broader best-cast/subtype selection, nonlinear behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 5 implementation result

The fifth recursive slice added red-first public-pipeline coverage for the first structured fallthrough later-reuse family:

- a cast and a later same-local read inside the same void, branch-free block should be treated as one fallthrough later-reuse window;
- a cast that is skipped by a branch to the end of a block must not seed a fresh-local fact for following roots.

Before implementation, the fallthrough-block case lacked `local.tee` / fresh-local reuse, while the branch-skipped case incorrectly carried a nullable fresh local out of the block. The implementation now scans branch-free void block bodies with the same later-reuse state as the surrounding root sequence, and stops collecting refinement facts through structured-control roots unless a block is admitted by that branch-free fallthrough scanner. The admitted subset deliberately rejects value blocks, nested control, branches, returns, throws, `unreachable`, and EH/control barriers; those remain open until they have source-backed tests and safety rules.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new fallthrough/block-barrier tests before implementation, then passed `18/18` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3833/3833`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-block-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: adjacent-block reuse beyond branch-free void blocks, broader best-cast/subtype selection, nonlinear/control behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Recommended next implementation slices

1. Broaden best-cast/subtype coverage with source-backed unrelated-cast and multi-related-cast negatives/positives, or add a minimal adjacent-dominated-block later-reuse case only after proving the control-flow safety boundary red-first. Keep early-motion out of the next slice unless it starts with trap/effect/nonlinear barrier tests.
2. Add early-motion tests separately only after the later-reuse local/refinalization path is stable.
3. Add dedicated GenValid profiles once the target implementation families are known enough to generate meaningful positives rather than no-op valid modules.
4. Keep the non-null body-local blocker visible until Starshine can either model Binaryen's exact fresh-local type or document a measured, accepted representation win.
