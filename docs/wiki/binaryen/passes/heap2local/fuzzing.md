---
kind: workflow
status: supported
last_reviewed: 2026-07-19
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./index.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `heap2local` Fuzzing Profile

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe
```

Dedicated GenValid aggregate: `heap2local-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-genvalid-all-10000 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Aliases accepted by GenValid profile lookup: `heap2local`, `heap-to-local`, `h2l`, `heap2local-closeout`, and `heap2local-all-profiles`.

## Profile leaves

- `heap2local-struct`: local-held fresh struct candidates with `struct.new` / `struct.new_default`, `struct.set`, `struct.get`, owner locals, and local-copy-shaped traffic.
- `heap2local-array`: constant-size local-held array candidates with `array.new_default`, `array.new_fixed`, constant-index `array.get`, and `array.set`.
- `heap2local-ref`: direct fresh-reference folds with `ref.as_non_null`, `ref.eq`, and `ref.test` over fresh struct allocations.

The aggregate samples all three leaves and records the selected leaf through the normal composite-profile manifest `selected_profile` field. Use that field when triaging generated mismatches so struct scalarization, array lowering, and ref-fold families stay separated.

## Current smoke status

A 2026-07-02 first aggregate smoke after profile config fixes, `.tmp/pass-fuzz-heap2local-genvalid-all-1000-aggregate-config-fix`, compared `278/1000` before hitting the mismatch cap: `67` normalized matches, `211` mismatches, zero command/validation/generator/property failures, selected profiles `heap2local-struct=131`, `heap2local-array=75`, and `heap2local-ref=72` before cap. Treat these as open behavior-parity gaps; do not use the profile as a green signoff lane until the mismatch families are reduced or fixed.

A follow-up slice reduced `case-000001` (`selected_profile=heap2local-struct`) to repeated same-owner fresh struct allocations with a self-copy write. Starshine now scalarizes that generated family and removes residual `struct.new`, `struct.new_default`, `struct.get`, and `struct.set` traffic. Replay `.tmp/pass-fuzz-heap2local-case000001-after-sequential-owner` still reports a raw mismatch (`1/1`, zero failures) because Binaryen preserves extra local/default-value/drop debris while Starshine emits a smaller scalarized form. Agent classification: **behavior-parity improvement plus residual output-shape/local-debris drift**, not the original true GC-scalarization parity gap. A 100-case struct leaf smoke, `.tmp/pass-fuzz-heap2local-struct-100-after-sequential-owner`, compared `100/100`: `18` normalized and `82` mismatches, zero failures; every saved Starshine mismatch had no residual `struct.new`, `struct.get`, or `struct.set`. A classifier over the `82` saved struct residuals found `82/82` with no residual GC ops and `82/82` with smaller Starshine canonical wasm, so this sampled struct residual family is currently agent-classified as Starshine output-shape/local-debris wins pending a H2L-specific normalizer or larger-lane confirmation.

A third slice reduced aggregate `case-000015` (`heap2local-array`) to repeated same-owner fixed array allocation epochs and aggregate `case-000004` (`heap2local-ref`) to direct fresh `struct.new_default` `ref.test`. Starshine now scalarizes straight-line repeated same-owner array epochs and folds direct fresh-struct `ref.test` to `i32.const 1`. Replays `.tmp/pass-fuzz-heap2local-case000015-after-sequential-array` and `.tmp/pass-fuzz-heap2local-case000004-after-direct-struct-reftest` still mismatch raw compare but have no residual array/struct/ref-test traffic; the residual is Binaryen's preserved scalar local/default/drop scaffolding. The post-fix aggregate smoke `.tmp/pass-fuzz-heap2local-all-100-after-sequential-array-reftest` compared `100/100`: `22` normalized, `78` mismatches, zero command/validation/generator/property failures, Binaryen cache `100/0`, selected profiles `heap2local-struct=49`, `heap2local-array=22`, and `heap2local-ref=29`. Agent classifier over all `78` saved mismatches found no residual generated H2L operations in Starshine output (`struct`/`array`/`ref.eq`/`ref.test` tokens absent) and `78/78` smaller Starshine canonical wasm.

A scaled generated lane, `.tmp/pass-fuzz-heap2local-all-1000-after-array-reftest`, compared `1000/1000`: `244` normalized, `756` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `1000/0`, selected profiles `heap2local-struct=423`, `heap2local-array=276`, and `heap2local-ref=301`. Saved residuals by selected leaf were `heap2local-struct=351`, `heap2local-array=146`, and `heap2local-ref=259`; inferred normalized-by-leaf counts were `struct=72`, `array=130`, and `ref=42`. A classifier over all `756` saved residuals found no Starshine residual generated H2L operations (`struct.new`, `struct.new_default`, `struct.get`, `struct.set`, `array.new`, `array.new_default`, `array.new_fixed`, `array.get`, `array.get_s`, `array.get_u`, `array.set`, `ref.eq`, or `ref.test`) and `756/756` smaller Starshine canonical wasm than Binaryen. Representative sampled diffs for `case-000001` (`struct`), `case-000015` (`array`), and `case-000004` (`ref`) show Binaryen preserving scalar temp/default/null drops while Starshine emits the shorter scalarized form. Existing normalizers did not classify this family: reruns with `--normalize ssa-local-allocation-debris --normalize local-cleanup-debris` and with `--normalize drop-consts --normalize ssa-local-allocation-debris --normalize local-cleanup-debris` both stayed at `244` normalized, `0` compare-normalized, and `756` mismatches.

The required dedicated `10000` lane first hit the mismatch cap with `.tmp/pass-fuzz-heap2local-all-10000-after-array-reftest`: `2689/10000` compared, `679` normalized, `2010` mismatches, zero failures, selected profiles `heap2local-struct=1159`, `heap2local-array=787`, and `heap2local-ref=743`. It was rerun with the cap raised so the profile could complete: `.tmp/pass-fuzz-heap2local-all-10000-full-residuals-after-array-reftest` compared `10000/10000`: `2474` normalized, `7526` residual mismatches, zero command/validation/generator/property failures, Binaryen cache `10000/0`, selected profiles `heap2local-struct=4290`, `heap2local-array=2885`, and `heap2local-ref=2825`. Saved residuals by selected leaf were `heap2local-struct=3600`, `heap2local-array=1437`, and `heap2local-ref=2489`; inferred normalized-by-leaf counts were `struct=690`, `array=1448`, and `ref=336`. A classifier over all `7526` saved residuals found no residual generated H2L operations in either Starshine or Binaryen WAT for the same scanned operation set, and found `7526/7526` Starshine canonical wasm outputs smaller than Binaryen. The byte deltas were stable by leaf: struct residuals were `79` bytes vs Binaryen `105` (`-26`), array residuals `83` vs `106` (`-23`), and ref residuals `76` vs `107` (`-31`). Late representative samples `case-001001` (`struct`), `case-001010` (`array`), and `case-001008` (`ref`) match the earlier pattern: both tools eliminate the generated H2L operations, while Binaryen preserves scalar temp/default/null drops that Starshine omits.

Current agent judgment for the scaled generated lanes: **Starshine output-shape/local-debris wins after H2L traffic removal**, not active generated H2L misses. The full dedicated profile is now documented at the required `10000` scale.

## Final-matrix refresh and normalizer decision

A later 2026-07-02 slice inspected the compare normalizer surface and chose **not** to add a H2L-specific normalizer yet. Existing generic normalizers are syntax/debris scoped (`drop-consts`, `unreachable-control-debris`, `local-cleanup-debris`, `ssa-local-allocation-debris`), and the H2L residual family would require semantic gating on generated H2L traffic plus paired Binaryen/Starshine output inspection. Rather than risk hiding future generated allocation/get/set/ref residuals behind cleanup normalization, the dedicated H2L family remains a raw-mismatch, agent-classified Starshine output-shape win with explicit reopening criteria: reopen if any dedicated or random-all residual contains generated H2L ops in either output, Starshine is not smaller, validation/property failures appear, or source-backed Binaryen transform families remain unimplemented.

Current signoff-lane refresh with `_build/native/release/build/cmd/cmd.exe`:

- Regular GenValid `.tmp/pass-fuzz-heap2local-genvalid-100000-20260702`: `100000/100000` compared, `100000` normalized, zero cleanup-normalized matches, zero mismatches, zero validation/generator/property/command failures, Binaryen cache `314/99686`, selected profile `binaryen-oracle-portable=100000`.
- Explicit wasm-smith `.tmp/pass-fuzz-heap2local-wasm-smith-10000-20260702`: `9956/10000` compared, `9955` normalized, one raw mismatch, and `44` Binaryen/oracle command failures. The single mismatch, `case-009332-wasm-smith`, is unrelated to H2L and is the known unreachable-control-debris shape (`drop(unreachable)` before `unreachable`). Replay `.tmp/pass-fuzz-heap2local-wasm-smith-case9332-normalized` with `--normalize unreachable-control-debris` compared `1/1` with one compare-normalized match and zero failures. Full rerun `.tmp/pass-fuzz-heap2local-wasm-smith-10000-unreachable-normalized-20260702` compared `9956/10000` with `9955` normalized, `1` compare-normalized, `0` mismatches, and the same `44` command failures (`39` rec-group-zero plus invalid-tag/table-index/bad-section parser classes as recorded in `cases.jsonl`).
- Broad random-all-profiles `.tmp/pass-fuzz-heap2local-genvalid-random-all-profiles-10000-20260702`: `10000/10000` compared, `8772` normalized, `1228` raw mismatches, zero validation/generator/property/command failures, Binaryen cache `2183/7817`. Selected profiles were `ssa-nomerge-smoke=1699`, `heap2local-array=454`, `coverage-forced-portable=1610`, `ssa-nomerge-parity=1644`, `heap2local-struct=715`, `binaryen-oracle-portable=1703`, `pass-fuzz-stress=1691`, and `heap2local-ref=484`. All mismatches came from the H2L leaves: `struct=587`, `array=221`, `ref=420`; classifier found no residual generated H2L ops in either output, `1228/1228` smaller Starshine canonical wasm, and the same stable deltas (`struct -26`, `array -23`, `ref -31` bytes).

## Binaryen v131 refresh

Final explicit-v131 lanes use `_build/native/release/build/cmd/cmd.exe`, `.tmp/binaryen-version-131-bin/bin/wasm-opt`, and `.tmp/h2l-v131-cache`:

- Regular `.tmp/h2l-v131-regular-10000-final`: `10000/10000` normalized, zero failures or mismatches.
- Wasm-smith `.tmp/h2l-v131-wasm-smith-10000-final`: `9956/10000` compared, `9955` normalized, one `unreachable-control-debris` compare-normalized match, zero mismatches, and `44` Binaryen command failures.
- Dedicated `.tmp/h2l-v131-all-10000-final`: `2474` normalized plus `7526` raw residuals. Both outputs contain no generated H2L operations in every residual; Starshine is smaller in `7526/7526`, with stable deltas `struct -26`, `array -23`, and `ref -31`, saving `203810` canonical bytes in aggregate.
- Random `.tmp/h2l-v131-random-all-10000-final`: `8517` normalized plus `1483` raw residuals, zero failures. The residual profiles are `local-subtyping-straight-line=712`, `heap2local-struct=297`, `heap2local-ref=206`, `heap2local-array=131`, `precompute-gc-values=72`, and `precompute-gc-atomic-boundary=65`; no scanned H2L operation has presence drift between outputs, Starshine is smaller in `1483/1483`, and aggregate savings are `37178` bytes.

The random lane exposed and now locks additional direct behavior: nullable GC-supertype drop-only struct owners, direct fresh nonpacked and packed struct/array reads, and fixed-array OOB trapping. The official shared reference-valued `acqrel` cmpxchg fixture is not classified as green: Starshine decodes it but rejects it during validation because reference-valued aggregate atomic RMW/cmpxchg is not represented by the current validator/atomic semantics.

## Pass-local timing and O4z slot evidence

A bounded pass-local probe over nine representative dedicated-profile inputs from `.tmp/pass-fuzz-heap2local-all-10000-full-residuals-after-array-reftest/inputs/gen-valid/` recorded Starshine H2L pass-local times between `0.031ms` and `0.044ms` (median `0.033ms`) versus Binaryen `0.061245ms` to `0.074439ms` (median `0.068469ms`). Every sampled case was inside the repo pass-local floor and kept the same smaller Starshine residual sizes (`79/105`, `83/106`, or `76/107` bytes depending on leaf).

Current generated `-O4z` slot evidence used `_build/wasm/debug/build/cmd/cmd.wasm` rebuilt in this checkout and a Binaryen-produced predecessor after the current Starshine/Binaryen no-DWARF prefix through the pass immediately before H2L:

```sh
wasm-opt _build/wasm/debug/build/cmd/cmd.wasm --all-features \
  --once-reduction --global-refining --gsi --ssa-nomerge --dce \
  --remove-unused-names --remove-unused-brs --remove-unused-names --vacuum \
  --remove-unused-brs --optimize-instructions --heap-store-optimization \
  --pick-load-signs --precompute --code-pushing --tuple-optimization \
  --simplify-locals-nostructure --vacuum --reorder-locals --remove-unused-brs \
  -o .tmp/h2l-o4z-slot-evidence-20260702/prefix-before-h2l.wasm
bun scripts/self-optimize-compare.ts .tmp/h2l-o4z-slot-evidence-20260702/prefix-before-h2l.wasm \
  --starshine-bin _build/native/release/build/cmd/cmd.exe \
  --out-dir .tmp/h2l-o4z-slot-evidence-20260702/slot-h2l-compare \
  --timing-only --heap2local
```

The direct H2L slot was an exact canonical match: Starshine and Binaryen outputs were both `3,015,145` bytes, `wasmEqual=true`, and selected outputs validated. The measured pass-local time was inside the repo floor (`67.539ms` Starshine vs `153.397ms` Binaryen in the standalone slot run; a repeated prefix table recorded `60.175ms` vs `116.222ms`). Whole-command Starshine time stayed slower (`1907.600ms` vs `522.067ms`) because traced non-pass decode/validation/command work dominated; classify that under `[WALL]001`, not as an H2L pass-local blocker.

The adjacent GC/local-cleanup neighborhood was replayed incrementally from the same predecessor. `heap2local`, `heap2local + optimize-casts`, and `heap2local + optimize-casts + local-subtyping` were exact canonical matches. Adding `coalesce-locals` introduced a broader neighborhood output-size gap (`3,012,858` Starshine bytes vs `2,860,415` Binaryen), and adding `local-cse` kept that gap (`3,012,790` vs `2,858,855`). Because the H2L-only, H2L+OC, and H2L+OC+LS prefixes are exact and validated, the current neighborhood gap is classified as neighbor-owned ordered-pipeline evidence rather than an H2L blocker.

## Closeout status

H2L is audit-complete for the representable Binaryen v131 direct-pass/O4z scope. The required four-lane matrix is current; sequential branch-target and unreachable-flow behavior is focused and green; dedicated and random residuals have equal H2L-operation presence and strictly smaller Starshine output; wasm-smith's sole residual is generic unreachable-control debris; and the rebuilt v131 O4z H2L slot is an exact `4180576`-byte canonical match with pass-local `101.912ms` Starshine versus `160.650ms` Binaryen. Reopen for validation/property failures, H2L-operation drift, a size-losing residual, or when shared reference-valued ordered atomic RMW/cmpxchg becomes representable.

## Known exclusions

The dedicated profile intentionally focuses on validator-accepted H2L opportunities. It does not force nondefaultable-local repair, broad descriptor-cast traffic, escapes through calls/returns, mixed branch/select provenance, dynamic array sizes/indexes, or the full atomic/RMW/cmpxchg surface. In particular, the v131 shared reference-valued `acqrel` cmpxchg scratch-local fixture is a recorded validator/atomic-semantics blocker, not an accepted parity difference.

## Required signoff use

For ordinary H2L audit signoff, use `heap2local-all` as the pass-specific GenValid lane in addition to regular GenValid, explicit wasm-smith, and the broad random-all-profiles lane.
