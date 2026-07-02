---
kind: workflow
status: working
last_reviewed: 2026-07-02
sources:
  - ../../../tooling/pass-fuzz-compare.md
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ../../../raw/research/1402-2026-07-02-heap2local-genvalid-profile-start.md
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_tests.mbt
---

# `heap2local` Fuzzing Profile

Regular direct lane:

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --out-dir .tmp/pass-fuzz-heap2local --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Dedicated GenValid aggregate: `heap2local-all`.

```sh
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --gen-valid-profile heap2local-all --out-dir .tmp/pass-fuzz-heap2local-genvalid-all-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
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

Current agent judgment for the scaled generated lanes: **Starshine output-shape/local-debris wins after H2L traffic removal**, not active generated H2L misses. The full dedicated profile is now documented at the required `10000` scale, but H2L remains short of final closeout until the normalizer/alignment decision, the other three signoff lanes, pass-local timing, and any H2L slot/neighborhood evidence are complete.

## Known exclusions

The first dedicated profile intentionally focuses on validator-accepted H2L opportunities. It does not yet force nondefaultable-local repair, broad descriptor-cast traffic, escapes through calls/returns, mixed branch/select provenance, dynamic array sizes, dynamic array indexes, or atomic/RMW/cmpxchg corner cases. Those are audit targets only after focused source review and validator-surface proof.

## Required signoff use

For ordinary H2L audit signoff, use `heap2local-all` as the pass-specific GenValid lane in addition to regular GenValid, explicit wasm-smith, and the broad random-all-profiles lane.
