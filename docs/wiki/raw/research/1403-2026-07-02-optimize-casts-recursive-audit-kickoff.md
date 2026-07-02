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

Before implementation, the fallthrough-block case lacked `local.tee` / fresh-local reuse, while the branch-skipped case incorrectly carried a nullable fresh local out of the block. The implementation initially scanned branch-free void block bodies with the same later-reuse state as the surrounding root sequence and stopped collecting refinement facts through structured-control roots unless a block was admitted by that branch-free fallthrough scanner. Slice 7 below later broadened this admitted subset to dropped branch-free value blocks. Nested control, branches, returns, throws, `unreachable`, and EH/control barriers remain rejected until they have source-backed tests and safety rules.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new fallthrough/block-barrier tests before implementation, then passed `18/18` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3833/3833`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-block-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: adjacent-block reuse beyond branch-free void blocks, broader best-cast/subtype selection, nonlinear/control behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 6 implementation result

The sixth recursive slice broadened the source-backed best-cast subset from "later narrower cast wins for following root reads" to the Binaryen `best-2`-style case where an earlier narrower cast may also feed a later broader cast's source read:

- a `ref.cast` to a narrower subtype, followed by a later broader `ref.cast` of the same original local, may retarget the later broader cast's source through the remembered narrower fresh local;
- an unrelated later cast, such as struct-vs-array, must remain conservative and must not have its cast source retargeted through the remembered fresh local.

Before implementation, the narrower-then-broader positive only produced two fresh-local reads instead of the expected three, proving that the later broader cast source was still reading the original local. The implementation now distinguishes the semantic refinement type of a wrapped cast/as-non-null from the nullable fresh-local tee type used by the current Starshine workaround. A root that computes a same-local refinement is still normally protected from retargeting, but it can retarget its source reads when the remembered best cast is strictly more refined than every refinement computed in that root. Repeated identical casts and unrelated casts remain blocked by the same stricter comparison.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the new narrower-then-broader source-retargeting test before implementation (`2 != 3` fresh-local reads), then passed `20/20` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3835/3835`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-bestcast-source-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: adjacent-block reuse beyond branch-free block subsets, broader multi-cast/best-cast coverage, nonlinear/control behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 7 implementation result

The seventh recursive slice widened the branch-free block scanner from void block roots to a small dropped value-block fallthrough subset:

- a branch-free value-producing block whose result is immediately dropped may carry an already-computed cast fact out to following same-local reads;
- a value block with a branch to its end remains a control-flow barrier, so a branch-skipped cast inside the block must not seed a fresh-local fact outside the block.

Before implementation, the positive produced no fresh-local read after the value block. The implementation now treats block roots and single-child `drop(block ...)` roots as admissible only when the enclosed block body has no linear-control barrier. It reuses the same later-reuse state inside the block and carries the fact to following roots. The dropped value-block form may lower the original dropped cast as `local.set` rather than preserving a visible `local.tee`; the tested behavior is the fresh-local read after the block, not exact tee spelling. Branches, nested control, returns, throws, `unreachable`, and EH/control barriers still reject the block and prevent skipped facts from leaking.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the new branch-free value-block positive before implementation, then passed `22/22` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3837/3837`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-value-block-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: broader adjacent-block reuse beyond the branch-free block subsets, broader multi-cast/best-cast coverage, nonlinear/control behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 8 implementation result

The eighth recursive slice widened the mixed `ref.cast` / `ref.as_non_null` best-cast subset:

- a remembered nullable subtype `ref.cast` may feed a later same-local `ref.as_non_null` source when making that remembered type non-null is more refined than the `ref.as_non_null` result;
- a same-local write between the nullable cast and the later `ref.as_non_null` remains a barrier and prevents stale fresh-local reuse.

Before implementation, the positive produced only two fresh-local reads instead of three because the later `ref.as_non_null` source still read the original local. The implementation now has a narrow source-retarget gate for this mixed family: it compares the remembered nullable best-cast type after non-nullification against the later `ref.as_non_null` result type, while preserving the existing stricter comparisons for repeated identical casts, unrelated casts, and same-local refinement roots. This is still a nullable-fresh-local representation; the slice does not solve the exact Binaryen non-null body-local shape blocker.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the new mixed nullable-cast/ref.as source positive before implementation (`2 != 3` fresh-local reads), then passed `24/24` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3839/3839`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-mixed-ref-as-smoke-100 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `100/100`, normalized `100`, and had zero validation/generator/property/command failures.

This still is not OC closeout. Open local-flow gaps remain: broader adjacent-block reuse beyond the branch-free block subsets, broader multi-cast/best-cast coverage, nonlinear/control behavior, strict early-motion, dedicated GenValid profiles, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 9 generator result

The ninth recursive slice converted the generator inventory into repo-visible GenValid profiles. Red-first `src/validate/gen_valid_tests.mbt` coverage first failed because no `optimize-casts-*` profile names were registered. `src/validate/gen_valid.mbt` now registers the singleton leaves `optimize-casts-later-reuse`, `optimize-casts-early-motion`, `optimize-casts-barriers`, `optimize-casts-best-cast`, `optimize-casts-ref-as`, `optimize-casts-static-folds`, and `optimize-casts-neighborhood`, plus the `optimize-casts-all` aggregate and aliases `optimize-casts`, `optimize-casts-closeout`, `optimize-casts-all-profiles`, `oc`, and `oc-closeout`.

The generated bodies are deliberately small, validating GC/local cast trigger modules over a local `anyref` seeded from a generated struct value. The aggregate records selected leaves through the standard composite-profile `selected_profile` manifest field. The early-motion leaf is intentional even though Starshine does not implement that Binaryen phase yet; it should expose remaining parity gaps in the future dedicated lane rather than hiding them behind generic GenValid coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` failed red-first on the three new optimize-casts profile tests, then passed `119/119` after implementation.
- `moon fmt` passed.
- `moon test src/validate` passed `1655/1655`.
- `moon info` passed with pre-existing warnings.
- `moon test src/passes` passed `3839/3839`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-genprofile-slice-regular-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures and zero mismatches.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-profile-smoke-20` compared `20/20`, normalized `2`, had `18` raw mismatches, zero validation/generator/property/command failures, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, `neighborhood=1`. This is expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, strict early motion implementation beyond a tiny adjacent subset, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 10 adjacent early-motion result

The tenth recursive slice added the first intentionally tiny early-motion subset. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because an immediately previous dropped `local.get` was left uncast when the following root performed a same-local dropped `ref.cast`. The paired same-local write negative kept the motion window from crossing writes.

`src/passes/optimize_casts.mbt` now duplicates a following dropped `ref.cast` / nullable-source `ref.as_non_null` refinement onto an immediately previous dropped same-local `local.get` when there is no intervening root. The subset clears candidates across any other root, does not cross same-local writes, and avoids interacting with already-seen same-local refinement roots so repeated/unrelated best-cast source-protection tests remain stable. This is a strict adjacent early-motion slice only; it does not implement Binaryen's full earlier-cast finder across wider pure windows, calls/effects/traps, `call_ref`, or nonlinear control.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the new adjacent early-motion positive (`1 != 2` `ref.cast` count), then passed `26/26` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3841/3841`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-adjacent-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures and zero mismatches.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-adjacent-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, strict early motion beyond the immediate-adjacent/no-intervening-root subset, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 11 pure-root early-motion result

The eleventh recursive slice widened the strict early-motion subset by one source-backed pure/no-effect root. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by an intervening dropped `i32.const` still stayed uncast. A paired call-barrier negative keeps effect/trap-order boundaries closed, and the prior same-local write negative remains active.

`src/passes/optimize_casts.mbt` now keeps the pending early-motion candidate alive across only `nop` roots and dropped constant roots. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto the earlier dropped same-local `local.get` across that tiny pure window. Calls, same-local writes, structured control, trapping operations, loads, and broader pure expression trees still clear the candidate until each has red-first source-backed barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across a dropped const root` before implementation, then passed `28/28` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3843/3843`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-pure-root-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures and zero mismatches.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-pure-root-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across nontrapping pure expression trees, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Recommended next implementation slices

1. Broaden strict early motion one source-backed window at a time only with paired barriers: for example, a safe pure/no-effect intervening root beyond constants plus calls/effects/traps/`call_ref`/same-local-write/nonlinear-control negatives before any implementation.
2. Alternatively, broaden best-cast/subtype coverage with source-backed unrelated-cast and multi-related-cast negatives/positives, or add a minimal adjacent-dominated-block later-reuse case only after proving the control-flow safety boundary red-first.
3. Use the new `optimize-casts-all` aggregate for bounded generated compare/classification after each transform subset lands; do not expect the aggregate to be green while early-motion and broader local-flow families remain only partially implemented.
4. Keep the non-null body-local blocker visible until Starshine can either model Binaryen's exact fresh-local type or document a measured, accepted representation win.
