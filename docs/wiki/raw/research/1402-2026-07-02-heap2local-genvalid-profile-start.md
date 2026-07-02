---
kind: research
status: working
created: 2026-07-02
sources:
  - ../../binaryen/passes/heap2local/fuzzing.md
  - ../../binaryen/passes/heap2local/parity.md
  - ../../binaryen/passes/heap2local/index.md
  - ../../../../src/validate/gen_valid.mbt
  - ../../../../src/validate/gen_valid_tests.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/Heap2Local.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap2local.wast
---

# `heap2local` GenValid profile start

## Goal

Start `[O4Z-AUDIT-H2L]` by adding a pass-specific GenValid surface that intentionally emits `heap2local` candidates instead of relying only on ordinary mixed GenValid traffic.

## Source-backed transformation families

The current audit target remains Binaryen `version_130` `Heap2Local.cpp` plus the dedicated `heap2local.wast` lit surface. The pass families to keep sampled are:

1. Exclusive nonescaping struct allocation scalarization: fresh `struct.new` / `struct.new_default` values stored in locals and used only by compatible `struct.get` / `struct.set` traffic.
2. Local-owner flow-through: owner locals, exclusive copy chains, direct `local.tee`, and simple structured result carriers are eligible when provenance stays exact.
3. Fresh-reference folds: operations whose result follows from the fresh allocation identity, including `ref.as_non_null`, null/equality/test/cast cases, and descriptor reads where the descriptor-bearing allocation is exact.
4. Small fixed-size array lowering: constant-size arrays with constant indexed `array.get` / `array.set` traffic can be lowered through the array-to-struct path before scalarization.
5. Bailout families: escapes through returns/calls, mixed provenance, ambiguous branch/select joins, nonconstant array sizes/indexes, and validator-surface repair cases that Starshine still cannot accept before the pass runs.

## Changes made in this slice

- Added GenValid leaves:
  - `heap2local-struct`
  - `heap2local-array`
  - `heap2local-ref`
- Added aggregate profile:
  - `heap2local-all`
  - Aliases: `heap2local`, `heap-to-local`, `h2l`, `heap2local-closeout`, `heap2local-all-profiles`.
- Added a dedicated body generator toggle and slice for H2L candidates:
  - struct owner/set/get and copy-chain-like local traffic
  - constant-size array new/default/fixed with local-held get/set traffic
  - direct fresh-reference folds via `ref.as_non_null`, `ref.eq`, and `ref.test`
- Added GenValid tests that check profile resolution, aggregate leaf sampling, validation of generated modules, and presence of the intended struct/array/ref candidate families.

## Validation status

Commands run after shell access was restored:

- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` initially failed because `heap2local-array` and `heap2local-ref` configs compared equal to `heap2local-struct`; fixed by making profile configs distinct and by making `Heap2LocalAllProfile` use its own aggregate config.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt` passed (`116/116`).
- `moon info` passed with pre-existing warnings.
- `moon test src/validate` passed (`1652/1652`).
- `moon build --target native --release src/cmd` passed with pre-existing warnings; the usable binary path is `_build/native/release/build/cmd/cmd.exe` in this worktree.

Profile smoke results:

- Incorrect binary-path probe: `.tmp/pass-fuzz-heap2local-genvalid-all-1000` used `target/native/release/build/cmd/cmd.exe` and produced `1000` Starshine command failures (`ENOENT`), so it is tooling/path noise only.
- Aggregate after config fix: `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix` compared `278/1000`, normalized `67`, mismatches `211`, command/validation/generator/property failures `0`, Binaryen cache `267/11`, and hit the mismatch cap. Selected profiles: `heap2local-struct=131`, `heap2local-array=75`, `heap2local-ref=72` before cap.
- Leaf probes, `30` cases each:
  - `.tmp/pass-fuzz-heap2local-struct-30`: `30/30` compared, `5` normalized, `25` mismatches.
  - `.tmp/pass-fuzz-heap2local-array-30`: `30/30` compared, `17` normalized, `13` mismatches.
  - `.tmp/pass-fuzz-heap2local-ref-30`: `30/30` compared, `2` normalized, `28` mismatches.

Agent classification: these are **open H2L behavior-parity gaps**, not accepted safe drift. The first inspected struct case shows Binaryen scalarizing repeated fresh struct/default allocations through the same owner local plus fresh-reference folds, while Starshine leaves most of that traffic as GC operations. The dedicated profile is therefore doing its job by exposing under-sampled H2L families, but the pass is not closeout-ready.

## Follow-up: repeated same-owner struct allocations

A second 2026-07-02 slice reduced the first aggregate mismatch, `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix/failures/case-000001-gen-valid`, to repeated writes of fresh `struct.new` / `struct.new_default` into the same owner local, including a `local.set $owner (local.get $owner)` self-copy. Binaryen scalarizes both allocation epochs. Starshine previously required exactly one write to the owner local, so it left all GC operations in place.

The fix adds a bounded straight-line sequential-owner path in `src/passes/heap2local.mbt`: when all writes to a non-param owner local are root-level fresh struct allocation writes or no-op self-copy writes, each allocation epoch is analyzed separately and lowered with the existing scalar-field rewrite. The focused regression `heap2local scalarizes repeated same-owner fresh struct allocations` in `src/passes/heap2local_test.mbt` failed before the implementation and now passes.

Validation and smokes for this slice:

- `moon test --package jtenner/starshine/passes --file heap2local_test.mbt` passed (`15/15`).
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file heap2local_primary_test.mbt` passed (`16/16`).
- `moon test src/passes` passed (`3812/3812`).
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` compared `1/1` with one residual mismatch and zero failures. Agent classification: the original true GC-scalarization parity gap is fixed for this family; residual output differs because Binaryen preserves extra scalar local/default/drop debris while Starshine emits a smaller scalarized form after omitting pure/nontrapping unused initialization debris.
- `--normalize local-cleanup-debris` did not normalize that replay.
- Struct leaf smoke `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner` compared `100/100`: `18` normalized, `82` mismatches, zero command/validation/generator/property failures. Every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set`, so the remaining struct mismatches are now output-shape/local-debris classification work rather than the original missed scalarization family.
- Aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-owner` compared `100/100`: `22` normalized, `78` mismatches, zero failures, selected profiles `heap2local-struct=49`, `heap2local-array=22`, `heap2local-ref=29`.

## Follow-up: generated array and direct-ref families

A third 2026-07-02 slice classified the residual struct sample and reduced two aggregate mismatch leaves:

- Struct residual classifier over `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner/failures` found `82/82` saved mismatches with no residual `struct.new`, `struct.get`, or `struct.set` in Starshine output and `82/82` smaller Starshine canonical wasm than Binaryen. Agent classification for the sampled struct residual family: output-shape/local-debris wins, not missed scalarization.
- Aggregate `case-000015` (`heap2local-array`) reduced to repeated same-owner fixed-array allocation epochs. The red-first regression `heap2local lowers repeated same-owner fresh array allocations` failed before implementation and now passes. Starshine now applies the same bounded straight-line allocation-epoch analysis to array owners and lowers each epoch through existing scalar element locals.
- Aggregate `case-000004` (`heap2local-ref`) reduced to direct fresh `struct.new_default` `ref.test`. The red-first regression `heap2local folds fresh struct ref.test to a constant` failed before implementation and now passes. Starshine now folds exact direct fresh-struct `ref.test` to `i32.const 1` while dropping allocation children.

Validation and smokes for this slice:

- `moon test --package jtenner/starshine/passes --file heap2local_test.mbt` passed (`17/17`).
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file heap2local_primary_test.mbt` passed (`16/16`).
- `moon test src/passes` passed (`3814/3814`).
- `moon test` passed (`7212/7212`) with pre-existing warnings.
- `moon info` passed with pre-existing warnings.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Replay `.tmp/pass-fuzz-heap2local-case000015-after-sequential-array` compared `1/1` with one residual mismatch and zero failures; Starshine output had no residual array traffic and only differed by omitted Binaryen scalar local/default/drop scaffolding.
- Replay `.tmp/pass-fuzz-heap2local-case000004-after-direct-struct-reftest` compared `1/1` with one residual mismatch and zero failures; Starshine output had no residual `ref.test`, while Binaryen preserved extra scalar debris.
- Aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-array-reftest` compared `100/100`: `22` normalized, `78` mismatches, zero command/validation/generator/property failures, Binaryen cache `100/0`, selected profiles `heap2local-struct=49`, `heap2local-array=22`, and `heap2local-ref=29`. A classifier over all saved residuals found no Starshine residual `struct`/`array`/`ref.eq`/`ref.test` generated H2L operations and `78/78` smaller Starshine canonical wasm.

Current agent judgment: the small generated aggregate sample has shifted from true missed-H2L parity gaps to sampled output-shape/local-debris drift after Starshine performs the same H2L-relevant scalarization/fresh-reference folds. This is not a green closeout: the finding needs a larger dedicated lane, a normalizer/alignment decision for Binaryen's preserved local debris, and review for broader Binaryen families not yet forced by the initial generator.

## Follow-up: scaled generated-lane classification

A fourth 2026-07-02 slice scaled the generated aggregate to `1000` requested cases using the current native binary:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-all-1000-after-array-reftest --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 1000 --keep-going-after-command-failures
```

Result: `1000/1000` compared, `244` normalized, `756` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `1000/0`, selected profiles `heap2local-struct=423`, `heap2local-array=276`, and `heap2local-ref=301`. Saved residuals by selected profile were `heap2local-struct=351`, `heap2local-array=146`, and `heap2local-ref=259`; inferred normalized-by-profile counts were `struct=72`, `array=130`, and `ref=42`.

A classifier over the saved residuals scanned Starshine WAT for generated H2L operations: `struct.new`, `struct.new_default`, `struct.get`, `struct.set`, `array.new`, `array.new_default`, `array.new_fixed`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `ref.eq`, and `ref.test`. It found no residual generated H2L operations in `756/756` saved Starshine outputs and found `756/756` Starshine canonical wasm outputs smaller than Binaryen. Representative samples:

- `case-000001` (`heap2local-struct`): both tools have removed struct operations; Binaryen keeps extra scalar temp/default/null drops while Starshine emits the shorter scalarized sequence (`79` bytes vs Binaryen `105`).
- `case-000015` (`heap2local-array`): both tools have removed array operations; Binaryen keeps extra scalar temp/null drops while Starshine emits the shorter scalarized sequence (`83` bytes vs Binaryen `106`).
- `case-000004` (`heap2local-ref`): both tools have removed direct `ref.test`; Binaryen keeps extra scalar/default/null drops while Starshine emits the shorter constant-folded sequence (`76` bytes vs Binaryen `107`).

Existing generic normalizers are insufficient for this family. The reruns

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --normalize ssa-local-allocation-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap2local-all-1000-after-array-reftest-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 1000 --keep-going-after-command-failures
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --normalize drop-consts --normalize ssa-local-allocation-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap2local-all-1000-after-array-reftest-drop-ssa-local-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 1000 --keep-going-after-command-failures
```

both stayed at `1000/1000` compared, `244` normalized, `0` compare-normalized, `756` mismatches, zero failures, and Binaryen cache `1000/0`.

Agent judgment: the scaled generated sample is currently **Starshine output-shape/local-debris wins after generated H2L traffic removal**, not active generated H2L misses. The supporting semantic argument is the H2L transform contract plus inspected representative diffs showing both outputs have eliminated the generated allocation/get/set/ref-test/ref-eq traffic; the size result is supporting evidence, not the sole reason for classification.

## Follow-up: required dedicated-profile scale

A fifth 2026-07-02 slice ran the required `10000` dedicated `heap2local-all` lane with seed `0x5eed`.

The first attempt used the ordinary mismatch cap:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-all-10000-after-array-reftest --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Result: `2689/10000` compared before the mismatch cap, `679` normalized, `2010` mismatches, zero command/validation/generator/property failures, Binaryen cache `2689/0`, selected profiles `heap2local-struct=1159`, `heap2local-array=787`, and `heap2local-ref=743`. Classifying the `2010` saved residuals found no residual generated H2L operations in Starshine WAT, no residual generated H2L operations in Binaryen WAT, and `2010/2010` smaller Starshine canonical wasm outputs. Saved residuals by selected profile were `struct=969`, `array=394`, and `ref=647`.

The lane was rerun with the mismatch cap raised high enough to complete:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-all-10000-full-residuals-after-array-reftest --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 10000 --keep-going-after-command-failures
```

Result: `10000/10000` compared, `2474` normalized, `7526` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `10000/0`, selected profiles `heap2local-struct=4290`, `heap2local-array=2885`, and `heap2local-ref=2825`. Saved residuals by selected profile were `heap2local-struct=3600`, `heap2local-array=1437`, and `heap2local-ref=2489`; inferred normalized-by-profile counts were `struct=690`, `array=1448`, and `ref=336`.

The classifier scanned both Starshine and Binaryen WAT for the generated H2L operation set used in the prior slice: `struct.new`, `struct.new_default`, `struct.get`, `struct.set`, `array.new`, `array.new_default`, `array.new_fixed`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `ref.eq`, and `ref.test`. It found no residual generated H2L operations in `7526/7526` saved Starshine outputs and no residual generated H2L operations in `7526/7526` saved Binaryen outputs. It also found `7526/7526` smaller Starshine canonical wasm outputs. The size deltas were uniform by selected profile: struct residuals were `79` bytes vs Binaryen `105` (`-26`), array residuals were `83` vs `106` (`-23`), and ref residuals were `76` vs `107` (`-31`). Late representative diffs `case-001001` (`heap2local-struct`), `case-001010` (`heap2local-array`), and `case-001008` (`heap2local-ref`) match the earlier samples: both tools have removed the generated allocation/get/set/ref-fold traffic, while Binaryen preserves scalar temp/default/null drops and Starshine emits the shorter scalarized/constant-folded sequence.

Agent judgment: the required dedicated profile at `10000` scale is **not exposing active generated H2L misses** after the latest fixes. The raw residual family is Starshine output-shape/local-debris wins after H2L traffic removal. This judgment still depends on the H2L transform contract and inspected diffs showing the generated operations are gone; smaller size is supporting evidence only.

## Next audit slice

1. Make the normalizer/alignment decision concrete. Preferred next step: inspect the compare normalizer surfaces and either add a narrow `heap2local-local-debris` normalizer that first refuses residual generated H2L traffic, or document why the raw mismatch family remains an accepted measured Starshine output-shape win without normalizer support. Any normalizer work must be test-first.
2. Refresh ordinary direct GenValid, explicit wasm-smith, and broad random-all-profile signoff lanes, and record pass-local timing. The required pass-specific `heap2local-all` lane is now run at `10000`, but it is raw-mismatch-heavy by design until the normalizer/alignment decision is complete.
3. Replay or document any H2L `-O4z` slot/neighborhood evidence required by the common audit checklist before closing `[O4Z-AUDIT-H2L]`.
