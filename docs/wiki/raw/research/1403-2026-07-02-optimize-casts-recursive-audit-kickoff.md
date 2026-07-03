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

## Slice 12 unary pure-root early-motion result

The twelfth recursive slice widened the strict early-motion subset by one more source-backed pure/no-effect tree. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by `i32.const; i32.eqz; drop` still stayed uncast. A paired trapping numeric-root negative keeps trap-timing boundaries closed: `i32.const 1; i32.const 0; i32.div_s; drop` must still clear the pending early-motion candidate so a cast trap is not introduced before the division trap.

`src/passes/optimize_casts.mbt` now keeps the pending early-motion candidate alive across `nop` roots, dropped constants, and the very narrow dropped `i32.eqz`-of-constant tree. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto the earlier dropped same-local `local.get` across that tiny unary pure window. Calls, same-local writes, structured control, loads, trapping numeric operators, other unary/binary pure expression trees, and effectful roots still clear the candidate until each has red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across a dropped unary pure root` before implementation (`29/30` passed), then passed `30/30` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3845/3845`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-unary-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-unary-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other binary/unary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 13 binary pure-root early-motion result

The thirteenth recursive slice widened the strict early-motion subset by one constant binary pure/no-effect tree. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by `i32.const; i32.const; i32.add; drop` still stayed uncast. A paired same-local `local.tee` write negative keeps the local-write boundary closed in the same binary-pure-root neighborhood.

`src/passes/optimize_casts.mbt` now keeps the pending early-motion candidate alive across `nop` roots, dropped constants, the narrow dropped `i32.eqz`-of-constant tree, and the narrow dropped `i32.add`-of-constants tree. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto the earlier dropped same-local `local.get` across that tiny binary pure window. Calls, same-local writes, structured control, loads, trapping numeric operators, non-constant pure expression trees, and other binary/unary trees still clear the candidate until each has red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across a dropped binary pure root` before implementation (`31/32` passed), then passed `32/32` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3847/3847`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-binary-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-binary-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other binary/unary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 14 multiplication pure-root early-motion result

The fourteenth recursive slice widened the strict early-motion subset by one more constant binary pure/no-effect tree. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by `i32.const; i32.const; i32.mul; drop` still stayed uncast. A paired same-local `local.set` write negative keeps the local-write boundary closed in the same multiplication-root neighborhood.

At that point, `src/passes/optimize_casts.mbt` kept the pending early-motion candidate alive across `nop` roots, dropped constants, the narrow dropped `i32.eqz`-of-constant tree, and narrow dropped `i32.add`/`i32.mul`-of-constants trees. A later dropped `ref.cast` or nullable-source `ref.as_non_null` could therefore be duplicated onto the earlier dropped same-local `local.get` across those tiny constant pure windows. Calls, same-local writes, structured control, loads, trapping numeric operators, non-constant pure expression trees, and other binary/unary trees still cleared the candidate until each had red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across a dropped multiplication pure root` before implementation (`33/34` passed), then passed `34/34` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3849/3849`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-mul-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-mul-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other binary/unary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 15 bitwise pure-root early-motion result

The fifteenth recursive slice widened the strict early-motion subset by a paired constant bitwise pure/no-effect window. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by `i32.const; i32.const; i32.and; drop` and `i32.const; i32.const; i32.or; drop` still stayed uncast. A paired same-local `local.set` write negative keeps the local-write boundary closed in the same bitwise-root neighborhood.

`src/passes/optimize_casts.mbt` now keeps the pending early-motion candidate alive across `nop` roots, dropped constants, the narrow dropped `i32.eqz`-of-constant tree, and narrow dropped `i32.add`/`i32.mul`/`i32.and`/`i32.or`-of-constants trees. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto the earlier dropped same-local `local.get` across those tiny constant pure windows. Calls, same-local writes, structured control, loads, trapping numeric operators, non-constant pure expression trees, and other binary/unary trees still clear the candidate until each has red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across dropped bitwise pure roots` before implementation (`35/36` passed), then passed `36/36` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3851/3851`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-bitwise-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-bitwise-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other unary/binary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 16 xor/shift pure-root early-motion result

The sixteenth recursive slice widened the strict early-motion subset by two more constant binary pure/no-effect trees. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by `i32.const; i32.const; i32.xor; drop` and `i32.const; i32.const; i32.shl; drop` still stayed uncast. A paired memory-load negative keeps potentially trapping/effectful roots closed: a dropped `i32.load` between the earlier get and later cast must still clear the pending early-motion candidate so a cast trap is not introduced before a load trap.

At that point, `src/passes/optimize_casts.mbt` kept the pending early-motion candidate alive across `nop` roots, dropped constants, the narrow dropped `i32.eqz`-of-constant tree, and narrow dropped `i32.add`/`i32.mul`/`i32.and`/`i32.or`/`i32.xor`/`i32.shl`-of-constants trees. A later dropped `ref.cast` or nullable-source `ref.as_non_null` could therefore be duplicated onto the earlier dropped same-local `local.get` across those tiny constant pure windows. Calls, same-local writes, structured control, loads, trapping numeric operators, non-constant pure expression trees, and other binary/unary trees still cleared the candidate until each had red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across dropped xor and shift pure roots` before implementation (`37/38` passed), then passed `38/38` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3853/3853`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-xor-shift-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-xor-shift-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other unary/binary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 17 sub/shift/rotate pure-root early-motion result

The seventeenth recursive slice widened the strict early-motion subset by the remaining obvious constant nontrapping integer binary roots in this family. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from the later dropped `ref.cast` by constant `i32.sub`, `i32.shr_u`, `i32.shr_s`, `i32.rotl`, and `i32.rotr` roots still stayed uncast. A paired same-local write negative keeps the local-write boundary closed in the same sub/shift/rotate-root neighborhood.

`src/passes/optimize_casts.mbt` now keeps the pending early-motion candidate alive across `nop` roots, dropped constants, the narrow dropped `i32.eqz`-of-constant tree, and narrow dropped `i32.add`/`i32.sub`/`i32.mul`/`i32.and`/`i32.or`/`i32.xor`/`i32.shl`/`i32.shr_s`/`i32.shr_u`/`i32.rotl`/`i32.rotr`-of-constants trees. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto the earlier dropped same-local `local.get` across those constant pure windows. Calls, same-local writes, structured control, loads, trapping numeric operators, non-constant pure expression trees, and other binary/unary trees still clear the candidate until each has red-first source-backed positive and barrier coverage.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across dropped sub shift and rotate pure roots` before implementation (`39/40` passed), then passed `40/40` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3855/3855`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-sub-shift-rotate-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-sub-shift-rotate-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and other unary/binary operations, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 18 separate-index local early-motion result

The eighteenth recursive slice widened strict early motion from constant-only pure roots to the first local-neighborhood window around a separate-index local write. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from a later dropped `ref.as_non_null` by a nontrapping `i32.const; local.set` to a different local still stayed uncast. A paired same-local write negative keeps the ref.as_non_null motion behind writes to the source local.

`src/passes/optimize_casts.mbt` now preserves pending early-motion candidates across dropped `local.get` roots and admits only constant-fed `local.set` roots by clearing the pending fact for the written local while preserving other locals. A later dropped `ref.cast` or nullable-source `ref.as_non_null` may therefore be duplicated onto an earlier dropped same-local `local.get` across `nop`, dropped constants, dropped `i32.eqz`-of-constant, dropped nontrapping constant `i32` binary roots, dropped local reads, and constant writes to separate locals. Same-local writes still clear the corresponding pending get. Effectful/trapping local-set payloads, calls, loads, structured control, trapping operators, and broader local-write trees still clear candidates until each has source-backed positives and paired barriers.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.as_non_null across separate-index local writes` before implementation (`41/42` passed), then passed `42/42` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3857/3857`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-separate-index-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-separate-index-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader early-motion windows across non-constant pure expression trees and effect-free local writes beyond constant `local.set`, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 19 implementation result

The nineteenth recursive slice widened the strict early-motion pure-root subset from constant-only i32 trees to nontrapping dropped i32 expression trees with `const` and `local.get` leaves:

- a dropped same-local `local.get` followed by a dropped separate-local-fed pure root such as `local.get 1; i32.const 7; i32.add; drop` may keep the pending earlier-get candidate alive for a later dropped `ref.cast`;
- a local-fed trapping numeric root such as `local.get 1; i32.const 0; i32.div_s; drop` remains a trap-timing barrier and must not move the later cast earlier.

Before implementation, the positive still produced only one `ref.cast` because the early-motion scanner cleared pending candidates at a non-constant pure i32 tree. `src/passes/optimize_casts.mbt` now uses a bounded nontrapping i32 pure-tree recognizer for dropped roots. It admits `const` and `local.get` leaves, `i32.eqz`, and the previously covered nontrapping i32 binary operators (`add`, `sub`, `mul`, `and`, `or`, `xor`, `shl`, `shr_s`, `shr_u`, `rotl`, `rotr`) over those leaves/trees. It still rejects trapping numeric operators, calls, loads, structured control, local writes, and other effectful roots, so same-local write and trap/effect barriers remain closed.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across dropped local-fed pure roots` before implementation (`43/44` passed), then passed `44/44` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3859/3859`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-local-fed-pure-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-local-fed-pure-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: effect-free local writes beyond constant `local.set`, call/effect/trap/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 20 pure local-set early-motion result

The twentieth recursive slice widened the strict early-motion local-write subset from constant-fed separate-index `local.set` roots to separate-index `local.set` roots whose payload is the same bounded nontrapping pure tree used for dropped roots. Red-first `src/passes/optimize_casts_test.mbt` coverage first failed because a dropped same-local `local.get` separated from a later dropped `ref.cast` by `local.get 1; i32.const 7; i32.add; local.set 2` still stayed uncast. A paired negative proves `local.get 1; i32.const 0; i32.div_s; local.set 2` remains a trap-timing barrier.

`src/passes/optimize_casts.mbt` now admits only `local.set` roots whose single child is accepted by `oc_i32_nontrapping_pure_tree`: `const` and `local.get` leaves, `i32.eqz`, and nontrapping i32 binary operators (`add`, `sub`, `mul`, `and`, `or`, `xor`, `shl`, `shr_s`, `shr_u`, `rotl`, `rotr`) within the bounded fuel limit. The scan still clears the pending fact for the written local, so same-local `local.set` writes remain barriers; `local.tee`, calls, loads, trapping numeric operators, structured control, and other effectful roots remain excluded.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates later ref.cast across nonconstant pure separate-index local writes` before implementation (`45/46` passed), then passed `46/46` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3861/3861`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-early-pure-local-set-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-early-pure-local-set-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: local-write windows beyond nontrapping pure separate-index `local.set`, `local.tee` and same-local writes, calls/effects/traps/control barriers, broader adjacent-block/control reuse, broader multi-cast/best-cast coverage, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 21 fallthrough source and nonlinear barrier result

The twenty-first recursive slice shifted back to later-reuse/local-flow coverage and implemented a Binaryen-lit-style fallthrough source subset plus a missing basic-block barrier:

- a `ref.cast` whose source is a branch-free value block returning the same local can seed the remembered best-cast fact and retarget a following same-local read through a fresh local;
- a nonlinear control root such as `if (return)` between a remembered cast and a later local read clears remembered later-reuse facts, matching the source-backed `past-basic-block` boundary instead of leaking a fresh local across the basic-block split.

Before implementation, the fallthrough-source positive did not create a `local.tee` or later fresh-local read, and the nonlinear-control negative still reused the cast past the `if` barrier. `src/passes/optimize_casts.mbt` now recognizes only a plain fallthrough `block` child with exactly one `local.get` body root as a refinement source for `ref.cast` / nullable-source `ref.as_non_null`. It also clears the later-reuse best-cast/fresh-local tables at roots with linear-control barriers, while still allowing that narrow block-source root to seed a new fact after clearing older facts. Branches, nested control, multi-root blocks, block-local writes, and non-fallthrough source blocks remain excluded.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new tests before implementation (`46/48` passed), then passed `48/48` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3863/3863`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-fallthrough-source-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-fallthrough-source-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader adjacent-block reuse beyond branch-free roots/value-block sources, multi-root/value-producing source blocks, broader multi-cast/best-cast coverage, local-write windows beyond nontrapping pure separate-index `local.set`, `local.tee` and same-local writes, calls/effects/traps/control barriers, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 22 multi-root source-block result

The twenty-second recursive slice broadened the later-reuse source-block subset from exactly-one-root value blocks to a still-conservative pure-prefix source-block shape:

- a `ref.cast` whose source is a plain fallthrough value block with dropped nontrapping pure prefix roots and a final same-local `local.get` can seed the remembered best-cast fact and retarget a following same-local read through a fresh local;
- a source block with branch traffic remains excluded, so branch-skipped or multi-path source blocks do not seed reuse facts.

Before implementation, the positive `i32.const; drop; local.get` source block failed because Starshine did not materialize a `local.tee` or later fresh-local read. `src/passes/optimize_casts.mbt` now lets `oc_plain_block_source_local` accept one or more roots when every prefix root is accepted by the existing dropped nontrapping pure-root recognizer and the final root is the source `local.get` that satisfies the nullable-source rule. Branches, nested control, effectful/trapping prefix roots, local writes, non-local-get tails, and non-fallthrough blocks remain excluded.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the new multi-root source-block positive before implementation (`49/50` passed), then passed `50/50` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3865/3865`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-multiroot-source-smoke-100` compared/normalized `100/100` with zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-multiroot-source-smoke-20` compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: broader adjacent-block reuse beyond branch-free roots/value-block sources, effectful or local-writing source blocks, broader multi-cast/best-cast coverage, local-write windows beyond nontrapping pure separate-index `local.set`, `local.tee` and same-local writes, calls/effects/traps/control barriers, dedicated-profile compare/classification, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 23 nested ref.as/cast early-motion result

The twenty-third recursive slice added the first source-backed nested cast/as-non-null early-motion subset from the Binaryen lit `move-ref.as-and-ref.cast` family:

- a later dropped `ref.as_non_null(ref.cast (ref null T) (local.get x))` can be duplicated onto an earlier dropped same-local `local.get`, preserving both nested operations in the duplicated stack;
- the unsupported sibling `ref.cast T(ref.as_non_null(local.get x))` remains excluded, matching the lit `unoptimizable-nested-casts` boundary rather than over-widening nested-cast motion.

Before implementation, the nested positive still had only one `ref.cast` / `ref.as_non_null` pair because `oc_refinement_source_local` only recognized direct local/block sources and `oc_duplicate_refinement_at_get` cloned only the outer refinement node. `src/passes/optimize_casts.mbt` now recognizes exactly the nullable inner `ref.cast` under outer `ref.as_non_null` shape, clones that nested refinement stack onto the earlier pending get, and leaves outer-ref.cast-over-ref.as forms out of the new helper. Later reuse may also observe this nested refinement as one outer best-cast value, but the subset still does not implement all nested mixed cast ordering from the Binaryen lit family.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates nested nullable cast and ref.as_non_null` before implementation (`51/52` passed), then passed `52/52` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3867/3867`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-nested-ref-as-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-nested-ref-as-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: the remaining nested mixed `ref.cast`/`ref.as_non_null` lit variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, local-write windows beyond nontrapping pure separate-index `local.set`, `local.tee` and same-local writes, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 24 separate-root ref.as/cast early-motion result

The twenty-fourth recursive slice broadened the nested mixed-cast early-motion family from one same-root nested stack to the first separate-root Binaryen lit sibling:

- a later dropped nullable `ref.cast` root and adjacent dropped `ref.as_non_null` root over the same local can be combined and duplicated as `ref.as_non_null(ref.cast nullable local.get)` onto an earlier dropped same-local `local.get`;
- a same-local `local.tee` between the separate roots remains a write barrier, so the combined ref.as/cast stack is not synthesized across the write.

Before implementation, the positive produced the later-reuse shape `local.tee(ref.cast nullable local.get)` followed by a later `ref.as_non_null(local.get fresh)` but did not duplicate `ref.as_non_null` to the earlier get. `src/passes/optimize_casts.mbt` now recognizes only adjacent dropped nullable-cast / nullable-source `ref.as_non_null` root pairs with the same source local, builds the combined outer-`ref.as_non_null` / inner-nullable-`ref.cast` stack at the earlier pending get, and preserves the previous unsupported outer-ref.cast-over-ref.as exclusion. This is still narrower than all Binaryen `move-ref.as-and-ref.cast-2` / `-3` behavior because broader windows, local.tee pairing, effect/trap/control crossings, and richer mixed chains remain excluded.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts combines separate nullable cast and ref.as_non_null at earlier get` before implementation (`53/54` passed), then passed `54/54` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3869/3869`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-separate-ref-as-cast-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-separate-ref-as-cast-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: the remaining mixed `ref.cast`/`ref.as_non_null` lit variants and richer chains, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, local-write windows beyond nontrapping pure separate-index `local.set`, `local.tee` and same-local writes, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 25 narrower-cast source early-motion result

The twenty-fifth recursive slice broadened strict early motion to the first Binaryen `move-cast-*` sibling where the earlier candidate is itself a cast:

- a later dropped same-local `ref.cast` to a strictly narrower subtype can be duplicated into the direct `local.get` source of an earlier dropped broader `ref.cast`;
- repeated or broader same-local refinement roots still do not qualify because the duplication gate uses the same source-backed stricter subtype comparison as the later-reuse best-cast logic.

Before implementation, the positive had only the original two `ref.cast` roots. `src/passes/optimize_casts.mbt` now tracks a pending direct dropped refinement source in the strict early-motion scanner, clears it across the same barriers that clear pending earlier gets, and duplicates a later strictly narrower direct refinement at the pending source get. This is still narrower than the full Binaryen `move-cast-1` through `move-cast-6` family: it does not solve exact non-null fresh-local representation, broad refinalization of the enclosing cast, richer chains, nested control, calls/effects/traps, or non-direct source shapes.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts duplicates a later narrower cast into an earlier broader cast source` before implementation (`54/55` passed), then passed `55/55` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3870/3870`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-narrower-cast-source-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-narrower-cast-source-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, Binaryen cache `20/0`, and selected leaves `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` refinalization/chains, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 26 source-cast refinalization result

The twenty-sixth recursive slice tightened the direct source-cast early-motion subset toward the Binaryen `move-cast-1` / `move-cast-2` refinalization direction:

- when a later strictly narrower `ref.cast` is duplicated into the direct source of an earlier broader `ref.cast`, the earlier broader outer cast is immediately rechecked by the static cast folder;
- if the duplicated narrower cast already satisfies the broader target, Starshine removes the redundant broader outer cast instead of leaving nested broader-over-narrower debris.

Before implementation, the focused source-cast fixture produced three `ref.cast` operations and still printed the earlier broader `(HeapType Idx 0)` cast after the duplicated child `(HeapType Idx 1)` cast. `src/passes/optimize_casts.mbt` now factors the existing static cast/test folder into `oc_static_fold_run` and reruns it after strict early motion changes. This is Starshine's local equivalent of the narrow refinalization cleanup needed by the Binaryen lit `move-cast-*` comments, but it remains narrower than the full upstream family: it does not implement exact non-null fresh locals, broad multi-root refinalization, richer local.tee/write variants, nested control, calls/effects/traps, or non-direct source shapes.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts refinalizes a broader cast after duplicating a narrower source` before implementation (`54/55` passed), then passed `55/55` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3870/3870`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-source-cast-refinalize-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-source-cast-refinalize-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond this direct refinalization cleanup, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 27 best early-cast selection result

The twenty-seventh recursive slice broadened strict early motion from immediate/greedy source-cast duplication to a narrow Binaryen `move-cast-3`-style best-selection window:

- an earlier dropped same-local `local.get`, followed by a broader cast and then a later strictly narrower cast, now receives the best later cast at the earliest get;
- the broader cast between the earliest get and the best later cast is still refinalized by the post-early-motion static folder, so the narrow fixture no longer leaves the broader `(HeapType Idx 0)` cast in the moved output;
- unrelated cast behavior remains protected by the existing repeated/unrelated source tests, so the delayed best-selection state does not start a new pending earliest-get move after an already-seen unrelated refinement.

Before implementation, the new move-cast-3-style fixture produced three `ref.cast` operations but still contained a broader `(HeapType Idx 0)` cast at the earliest moved location. `src/passes/optimize_casts.mbt` now keeps a pending earliest get plus its best pending refinement, updates that pending best when a later direct dropped same-local refinement is strictly narrower, and flushes the chosen refinement only at a barrier, same-local pure `local.set`, or the end of the scan window. This is still narrower than full Binaryen `EarlyCastFinder` behavior: it does not widen across calls, loads, nonlinear control, `local.tee`, same-local writes, or exact non-null fresh-local representation.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts moves the best later cast to the earliest get` before implementation (`55/56` passed), then passed `56/56` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3871/3871`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-best-early-selection-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-best-early-selection-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization subset, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 28 move-cast-4 broader-source refinalization result

The twenty-eighth recursive slice broadened the strict early-motion source-cast/refinalization subset to the Binaryen `move-cast-4` ordering:

- an earlier dropped same-local `local.get`, followed by a narrower cast and then a later broader cast, now keeps the earliest get at the best narrower cast;
- the later broader cast's direct source is rewritten through the earlier narrower refinement before the post-early-motion static folder runs, so the broader outer cast is refinalized away instead of surviving as nullable-fresh-local debris;
- the existing narrower-then-broader source fixture was tightened to require the broader `HeapType Idx 0` cast to disappear, making this a source-backed Starshine win over the earlier nullable-local later-reuse shape.

Before implementation, the new move-cast-4-style fixture produced a validating output that still contained a later broader `(HeapType Idx 0)` cast. `src/passes/optimize_casts.mbt` now handles both directions in the direct source-cast window: a later narrower cast can still be duplicated into an earlier broader cast source, and an earlier narrower cast can now be duplicated into a later broader cast source when the pending refinement is strictly more refined. Same-local write/local.tee, trap/effect/control, unrelated-cast, unsupported outer-ref.cast-over-ref.as, and nullable-fresh-local blocker boundaries remain unchanged.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts keeps the best earlier cast before a later broader cast` before implementation (`56/57` passed), then passed `57/57` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3872/3872`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-move-cast-4-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-4-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization subsets, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 29 move-cast-6 materialized-reuse result

The twenty-ninth recursive slice broadened the Binaryen `move-cast-*` coverage to a narrow `move-cast-6`-style later-reuse window:

- when the first root already computes the best/narrowest cast, no earlier motion is needed;
- once a later plain same-local read has materialized the best cast into a fresh local, a following same-local cast with the same effective refinement type may also read from that fresh local;
- repeated identical casts still do not create fresh locals on their own, preserving the earlier repeated-cast source protection.

Before implementation, the new `move-cast-6`-style fixture refinalized the later broader cast from `HeapType Idx 0` to the best `HeapType Idx 1`, but that later cast still read `Local 0` instead of the fresh `Local 1`. `src/passes/optimize_casts.mbt` now permits equal-type refinement roots to reuse an already-materialized fresh best-cast local, while keeping the stricter gate that blocks repeated identical casts before any fresh local exists. The existing earlier-narrower/later-broader fixture was tightened accordingly: after one plain later read materializes the fresh local, both the later refinalized cast source and the final read use it.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses the best first cast before a later broader cast` before implementation (`57/58` passed), then passed `58/58` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3873/3873`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-move-cast-6-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-6-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse subsets, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 30 move-cast-5 refinalized-source reuse result

The thirtieth recursive slice broadened the Binaryen `move-cast-*` materialized-reuse coverage to the `move-cast-5` ordering:

- when the first root already computes the best/narrowest cast, a following broader same-local cast can be refinalized to that best type and also read from the same fresh local;
- unlike the previous `move-cast-6` slice, no plain read appears between the first best cast and the later broader/refinalized cast, so Starshine must distinguish a refinalized source-moved equal cast from an ordinary repeated identical cast;
- repeated identical casts remain protected because equal-type source retargeting without an existing fresh local is only allowed for roots that strict early motion marked as having had a narrower cast inserted into their broader source.

Before implementation, the new `move-cast-5`-style fixture refinalized the later broader cast from `HeapType Idx 0` to `HeapType Idx 1`, and the final plain read used the materialized fresh local, but the later refinalized cast source still read `Local 0`. `src/passes/optimize_casts.mbt` now threads a small intra-pass set of source-refinalized refinement roots from strict early motion into later reuse. Later reuse can materialize the remembered best cast for those marked equal-type roots before any plain read has done so, while ordinary equal repeated casts still cannot create a fresh local on their own. The exact non-null body-local blocker and nullable-fresh-local workaround remain unchanged.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses the best first cast through a later broader cast` before implementation (`58/59` passed), then passed `59/59` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3874/3874`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-move-cast-5-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-5-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse subsets, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 31 implementation result

The thirty-first recursive slice added red-first source-backed coverage for Binaryen's `move-over-tee` / `no-move-over-self-tee` local.tee boundary:

- a later `ref.cast(local.tee y (local.get x))` may be duplicated to an earlier dropped `local.get x` when `y` is a separate local, after which later reuse can materialize the best cast and retarget the tee source through the fresh local;
- the same shape must not move when the `local.tee` writes the same local index being read, because the tee is a write barrier for early motion.

Before implementation, the separate-local tee fixture emitted only the original cast and no fresh-local source reuse, while the self-tee fixture incorrectly duplicated the cast. `src/passes/optimize_casts.mbt` now separates ordinary later-reuse refinement-source recognition from strict early-motion source recognition. Early motion accepts direct `local.get` sources as before and accepts `local.tee` sources only when the tee's child is a same-source `local.get` and the tee destination is a different local. Self-tees stay blocked as same-index writes. The nullable-fresh-local workaround and exact non-null body-local blocker remain unchanged.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new local.tee tests before implementation (`59/61` passed), then passed `61/61` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3876/3876`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-tee-motion-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-tee-motion-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse and separate-local-tee subsets, remaining mixed `ref.cast`/`ref.as_non_null` variants, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 32 mixed tee pair result

The thirty-second recursive slice broadened the mixed nullable-cast / `ref.as_non_null` separate-root family to the first local.tee-shaped source subset:

- an adjacent dropped nullable `ref.cast(local.tee y (local.get x))` plus dropped `ref.as_non_null(local.get x)` pair can now combine as `ref.as_non_null(ref.cast nullable local.get x)` at the earlier pending dropped `local.get x` when `y` is a separate local;
- the same shape remains blocked when the cast source is `local.tee x (local.get x)`, preserving the Binaryen `no-move-over-self-tee` same-index write barrier for mixed-pair synthesis.

Before implementation, the separate-local tee positive duplicated/materialized only the nullable cast and left a single `ref.as_non_null`, while the self-tee negative incorrectly synthesized/materialized the mixed pair through the same-local tee. `src/passes/optimize_casts.mbt` now routes adjacent separate-root pair recognition through the strict early-motion source recognizer for both the nullable cast and the `ref.as_non_null`: direct `local.get` sources still qualify, separate-local tees qualify when they read the pending source local, and self-tees return no source local. The later-reuse recognizer remains broader for ordinary reuse, but mixed early-motion pair synthesis now shares the self-tee discriminator added for direct cast motion.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on the two new mixed-tee tests before implementation (`61/63` passed), then passed `63/63` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3878/3878`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-mixed-tee-pair-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-mixed-tee-pair-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse and separate-local-tee subsets, richer mixed `ref.cast`/`ref.as_non_null` chains beyond adjacent direct/separate-tee pairs, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 33 best-cast source-feed result

The thirty-third recursive slice broadened the Binaryen `best` later-reuse/source-feed subset:

- an earlier broader cast that has already been materialized through a fresh local can now feed both a following plain same-local read and the source of a later narrower cast;
- intervening `global.set` roots remain in place, matching the source-backed shape where effects prevent moving casts backward but do not prevent later reads from using an already-computed cast value;
- unrelated casts remain protected: the source-feed gate requires the remembered best-cast type to be a valid subtype of the original cast source and not provably disjoint from the later cast target.

Before implementation, the new `best`-style fixture materialized the first broader cast for the middle plain read but left the later narrower `ref.cast` source reading `Local 0` instead of the broader fresh local. A first implementation attempt also showed why the disjoint-target guard is necessary: the existing struct-vs-array unrelated negative would otherwise retarget an unrelated later cast source through the remembered struct value. `src/passes/optimize_casts.mbt` now allows source retargeting through an existing fresh best-cast local only when the source type and target-overlap checks pass. The exact non-null body-local blocker and nullable-fresh-local workaround remain unchanged.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts feeds later narrower casts from the current best broader cast` before implementation (`63/64` passed), then passed `64/64` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3879/3879`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-best-source-feed-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-best-source-feed-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee subsets, richer mixed `ref.cast`/`ref.as_non_null` chains beyond adjacent direct/separate-tee pairs, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 34 nested branch-local early-motion result

The thirty-fourth recursive slice broadened strict early motion from the root region into source-backed nested branch-local regions:

- a dropped `local.get` and following dropped `ref.as_non_null(local.get x)` inside the same block nested under an `if` arm now form their own early-motion window, matching the Binaryen `no-move-past-non-linear` lit shape where motion is allowed inside the branch-local block;
- the enclosing `if` remains a nonlinear boundary, so the implementation scans each structured-control child region with fresh pending state instead of carrying facts into or out of the branch.

Before implementation, the nested-block positive printed only the original `ref.as_non_null`; the earlier local read inside the branch-local block was not refined because Starshine only ran strict early motion over the root region. `src/passes/optimize_casts.mbt` now scans block, loop, if-arm, try/catch, and try_table catch-list regions independently, preserving existing same-local write barriers, effect/trap/control barriers, self-tee boundaries, unsupported outer-ref.cast-over-ref.as exclusion, best-cast gates, and the nullable-fresh-local workaround.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts moves casts inside nested branch-local blocks` before implementation (`64/65` passed), then passed `65/65` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3880/3880`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-nested-region-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-nested-region-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region subsets, richer mixed `ref.cast`/`ref.as_non_null` chains, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 35 tee-alias later-reuse result

The thirty-fifth recursive slice broadened the source-backed Binaryen `local-tee` later-reuse family:

- a `ref.cast(local.tee y (local.get x))` now records that the computed cast value can serve later reads of both the original source local `x` and the separate tee destination local `y`;
- when those alias facts materialize, they share one fresh refined carrier local instead of wrapping the same cast twice;
- the existing repeated-cast source protection, same-local write barriers, strict early-motion self-tee exclusions, and nullable-fresh-local workaround remain unchanged.

Before implementation, the new fixture retargeted only the later `local.get y` and left the later `local.get x` on the original local. `src/passes/optimize_casts.mbt` now pre-collects local.tee source aliases for later-reuse fact recording without treating that alias as a refinement-root blocker during same-root source retargeting. This keeps direct repeated casts conservative while allowing the source-backed `local-tee` shape to feed both locals. It also reuses an existing fresh local for the same best-cast node when multiple locals alias the same computed value.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses a tee-fed cast for source and destination locals` before implementation (`65/66` passed), then passed `66/66` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3881/3881`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-tee-alias-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-tee-alias-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader local.tee/write variants beyond the current same-root alias and separate-local early-motion subsets, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region subsets, richer mixed `ref.cast`/`ref.as_non_null` chains, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 36 repeated equal moved-cast result

The thirty-sixth recursive slice broadened Binaryen `move-identical-repeated-casts` coverage:

- an earliest dropped same-local `local.get`, followed by two equal same-local `ref.cast` roots, now receives one duplicated cast at the earliest get;
- both later equal cast sources then read the shared fresh carrier local materialized from that earliest moved cast, matching the source-backed lit expectation that only one equal cast is duplicated but later equal casts reuse the carrier;
- ordinary repeated identical casts without an earlier moved get remain protected and do not materialize a fresh local on their own.

Before implementation, the new fixture printed three `ref.cast` roots all reading `Local 0` and no `local.tee`/fresh-local reuse. `src/passes/optimize_casts.mbt` now marks early-motion-selected refinements, plus later equal refinements in the same earliest-get window, as source-refinalized for the later-reuse phase. Later reuse may therefore materialize one fresh carrier from the earliest moved cast and retarget the marked equal cast sources through it, while the existing repeated-cast protection still blocks equal repeated casts that were not part of an earlier-moved window. Same-local write/self-tee barriers, unrelated-cast guards, exact non-null body-local blocker, and nullable fresh-local workaround remain unchanged.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses earliest moved identical casts for equal later casts` before implementation (`66/67` passed), then passed `67/67` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3882/3882`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-repeated-equal-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-repeated-equal-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader local.tee/write variants, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region/repeated-equal subsets, richer mixed `ref.cast`/`ref.as_non_null` chains, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 37 mixed moved ref.as/cast refinalization result

The thirty-seventh recursive slice tightened the source-backed Binaryen `move-ref.as-and-ref.cast-3` mixed-root shape:

- an earliest dropped same-local `local.get`, followed by a dropped `ref.as_non_null(local.get x)` root and then a dropped nullable `ref.cast(local.get x)` root, still reuses the one mixed moved carrier for both later roots;
- the later nullable `ref.cast` is now refinalized to a non-null `ref.cast` once it reads the carrier produced by the moved `ref.as_non_null(ref.cast nullable ...)` stack, matching the lit expectation while keeping Starshine's fresh body local itself nullable;
- the marking is tied to the adjacent mixed ref.as/cast early-motion pair, so ordinary nullable casts are not broadly rewritten to non-null casts without that source-backed proof.

Before implementation, the new fixture already reused the carrier but left the final cast as `(ref.cast (RefType Null (HeapType Idx 0)))`. `src/passes/optimize_casts.mbt` now marks nullable cast roots that participate in a moved separate-root `ref.as_non_null` / nullable-`ref.cast` pair. When later reuse retargets such a marked root through the materialized carrier, the pass rewrites that root's cast target to the equivalent non-null `ref.cast` target. The exact non-null body-local blocker remains open: the carrier local is still nullable because Starshine's current local validation/model cannot yet represent Binaryen's initialized non-null body local shape.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses mixed moved ref.as then nullable cast roots` before implementation (`67/68` passed), then passed `68/68` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3883/3883`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-mixed-ref-as-refinalize-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-mixed-ref-as-refinalize-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader local.tee/write variants, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region/repeated-equal/mixed-refinalized subsets, richer mixed `ref.cast`/`ref.as_non_null` chains beyond adjacent direct/separate-tee/moved-root refinalization cases, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Slice 38 broad-then-narrow moved-carrier reuse result

The thirty-eighth recursive slice tightened another source-backed Binaryen `move-cast-*` follow-up, closest to the `move-cast-2` broad-then-narrow ordering:

- a first dropped broad cast of `x`, followed by a dropped narrower cast of `x`, and then a plain dropped read of `x`, should materialize one moved narrower carrier;
- after the narrower cast has been duplicated into the earlier broad cast source and the broad cast is refinalized away, the later narrower cast root and the following plain read should both read the same fresh carrier;
- the ordinary equal-cast protection remains narrow because this carrier reuse is only enabled when strict early motion marked the later narrower cast as refinalized/moved.

Before implementation, the new fixture failed red-first: the final plain read used the fresh `Local 1`, but the intervening narrower cast still read `Local 0`. `src/passes/optimize_casts.mbt` now marks the later stricter cast as a moved/refinalized refinement when early motion duplicates it into an earlier broader cast source. The later-reuse phase can then materialize the moved carrier at that marked cast root and retarget both the cast source and subsequent reads through the carrier. An existing focused expectation for the same broad-then-narrow follow-up was tightened from one fresh-local read to two.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts reuses moved narrower cast after broad then narrow roots` before implementation (`68/69` passed), then passed `69/69` after implementation and expectation tightening.
- `moon fmt` passed.
- `moon test src/passes` passed `3884/3884`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-move-cast-2-reuse-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-move-cast-2-reuse-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader local.tee/write variants, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region/repeated-equal/mixed-refinalized/broad-then-narrow moved-carrier subsets, richer mixed `ref.cast`/`ref.as_non_null` chains beyond adjacent direct/separate-tee/moved-root refinalization cases, broader best-cast/subtype coverage, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.


## Slice 39 three-level best-cast refinalization result

The thirty-ninth recursive slice tightened best-cast/subtype selection beyond the prior two-level source-backed chains:

- an earlier dropped same-local get followed by base, mid, and leaf `ref.cast` roots now carries the deepest leaf cast back to the earliest get;
- when the leaf cast is duplicated into the intermediate mid-cast source, the mid root is also marked as moved/refinalized so later reuse rewrites that broader intermediate cast target to the current best leaf target;
- the gate remains tied to strict early-motion moved/refinalized roots, so ordinary repeated equal casts and unrelated cast targets still do not get broadened materialization or retargeting.

Before implementation, the new fixture failed red-first: the optimized output materialized the leaf carrier but still kept an intermediate `(ref.cast (HeapType Idx 1))` reading that carrier. `src/passes/optimize_casts.mbt` now marks the earlier broader refinement when a stricter later cast is duplicated into its source, and generalizes marked `ref.cast` refinalization from nullable-only casts to the current best cast target.

Validation for this slice:

- `moon test --package jtenner/starshine/passes --file optimize_casts_test.mbt` failed red-first on `optimize-casts moves the deepest best cast across a three-level chain` before implementation (`69/70` passed), then passed `70/70` after implementation.
- `moon fmt` passed.
- `moon test src/passes` passed `3885/3885`.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings and produced `_build/native/release/build/cmd/cmd.exe`.
- Regular direct smoke `.tmp/pass-fuzz-optimize-casts-three-level-best-smoke-100`: compared/normalized `100/100`, zero validation/generator/property/command failures, zero mismatches, and Binaryen cache `100/0`.
- Tiny dedicated aggregate smoke `.tmp/pass-fuzz-optimize-casts-genvalid-all-after-three-level-best-smoke-20`: compared `20/20`, normalized `2`, left `18` raw mismatches, had zero validation/generator/property/command failures, and Binaryen cache `20/0`. Selected leaves were `best-cast=6`, `early-motion=5`, `barriers=3`, `later-reuse=3`, `static-folds=2`, and `neighborhood=1`. Agent classification remains expected open generated parity surface, not signoff.

This still is not OC closeout. Open transform/evidence gaps remain: exact non-null body locals, broader local.tee/write variants, broader nested/control early motion beyond independent same-region scans, broader `move-cast-*` chains beyond the current best-selection/refinalization/materialized-reuse/source-feed/separate-local-tee/nested-region/repeated-equal/mixed-refinalized/broad-then-narrow/three-level best-cast subsets, richer mixed `ref.cast`/`ref.as_non_null` chains beyond adjacent direct/separate-tee/moved-root refinalization cases, broader best-cast/subtype coverage in generated aggregate residuals, adjacent-block reuse beyond branch-free root/source subsets, calls/effects/traps/control barriers, dedicated-profile compare/classification at closeout scale, larger direct compare refresh, wasm-smith/random-all lanes, O4z slot evidence, and pass-local timing.

## Recommended next implementation slices

1. Broaden strict early motion one source-backed window at a time only with paired barriers: for example, investigate a narrow `ref.as_non_null` variant across nonconstant pure separate-index `local.set`, or switch to best-cast/adjacent-block local-flow coverage; keep calls/effects/traps/`call_ref`/same-local-write/`local.tee`/nonlinear-control negatives before any implementation.
2. Alternatively, broaden best-cast/subtype coverage with source-backed unrelated-cast and multi-related-cast negatives/positives, or add a minimal adjacent-dominated-block later-reuse case only after proving the control-flow safety boundary red-first.
3. Use the new `optimize-casts-all` aggregate for bounded generated compare/classification after each transform subset lands; do not expect the aggregate to be green while early-motion and broader local-flow families remain only partially implemented.
4. Keep the non-null body-local blocker visible until Starshine can either model Binaryen's exact fresh-local type or document a measured, accepted representation win.
