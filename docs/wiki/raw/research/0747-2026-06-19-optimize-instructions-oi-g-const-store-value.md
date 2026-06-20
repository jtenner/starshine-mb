# Optimize-instructions OI-G constant narrow store value slice

Date: 2026-06-19

## Question

Can Starshine cover Binaryen's `optimizeStoredValue(...)` behavior for constant values stored through narrow stores by truncating the constant to the bits the store actually writes?

## Classification

This is the sixteenth `[O4Z-AUDIT-OI-G]` sub-slice. It adds a source-backed, behavior-preserving `optimizeStoredValue` shape for narrow stores:

- `i32.store8` now truncates constant stored values to 8 bits.
- `i32.store16` now truncates constant stored values to 16 bits.
- `i64.store8`, `i64.store16`, and `i64.store32` now truncate constant stored values to the written low bits.

This matches Binaryen `version_130` observable behavior for the local probe: `i32.const -1; i32.store8` becomes `i32.const 255; i32.store8`, `i32.const 65537; i32.store16` becomes `i32.const 1; i32.store16`, and `i64.const 4294967296; i64.store32` becomes `i64.const 0; i64.store32`.

This is not recursive `maxBits` scanning, nonconstant pointer-offset folding, zero-size bulk-memory cleanup, or a `load-call-optimize-instructions-noop` relaxation.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryAccess(...)` / `optimizeStoredValue(...)` load-store cleanup as `[O4Z-AUDIT-OI-G]` work.
- Prior OI-G stored-value slices [`0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md`](0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md), [`0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md`](0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md), and [`0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md`](0746-2026-06-19-optimize-instructions-oi-g-commuted-store-mask.md) covered redundant mask removal; this slice adds the constant truncation branch.
- Local Binaryen oracle probe `.tmp/oi-g-store-const.wat` with `wasm-opt --optimize-instructions -S --print` confirmed constant truncation before `i32.store8`, `i32.store16`, and `i64.store32`.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions truncates constant narrow store values`.
- The fixture covers `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, and `i64.store32` constants whose high bits are discarded by the store.
- The assertions verify the original oversized constants disappear and the replacement constants match the written low bits.

Changed `src/passes/optimize_instructions.mbt`:

- Added `optimize_instructions_try_truncate_narrow_store_const_value(...)`.
- The helper recognizes narrow store instructions, checks whether the stored value is a constant of the correct value width, computes the low-bit mask from the store width, and rewrites the stored value to the truncated constant only when the constant actually changes.
- The store rewrite runs before redundant-mask cleanup in the existing `Store` pass dispatcher.

## Red-first evidence

Before implementation, the new focused test failed as expected:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*constant narrow store values*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1580 ("optimize-instructions truncates constant narrow store values") failed: ... body_raw: ... i32.const I32(-1) ... i32.store8 ... i32.const I32(65537) ... i32.store16 ... i64.const I64(511) ... i64.store8 ... i64.const I64(65537) ... i64.store16 ... i64.const I64(4294967296) ... i64.store32 ...
Total tests: 1, passed: 0, failed: 1.
```

## Focused evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*constant narrow store values*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 1, passed: 1, failed: 0.
Total tests: 5, passed: 5, failed: 0.
Total tests: 21, passed: 21, failed: 0.
Total tests: 128, passed: 128, failed: 0.
```

Note: the `*narrow stores*` filter covers the earlier plural-named narrow-store tests; the new singular `*constant narrow store values*` test is reported separately.

## Broader validation

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
moon info
```

Results:

- `moon fmt`: passed.
- `moon test src/passes`: passed, `Total tests: 2640, passed: 2640, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

First direct compare attempt timed out before writing `result.json`:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-const-store-value-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

A rerun against the same out dir failed during GenValid batch generation with `Error: Command exited without a return code`; no durable result was produced. After removing the partial out dir, the final rerun completed to the default failure ceiling:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-const-store-value-10000 && \
  bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-const-store-value-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Requested: 10000
Compared: 54/10000
Normalized matches: 27
Cleanup-normalized matches: 0
Raw mismatches: 27
Validation failures: 0
Property failures: 0
Generator failures: 0
Command failures: 1
Jobs: 16
Cache: wasm-smith 28 hits/0 misses; Binaryen 54 hits/0 misses; Binaryen failures 1 hits/0 misses
```

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `27` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new narrow-store semantic failures. A grep of failure artifacts found no `store8`, `store16`, `store32`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, or `i64.store32` occurrences.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially nonconstant pointer-offset forms if source-backed safety proof and ownership are established;
- any other `optimizeStoredValue` shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- any broader source-backed decision on whether a class of shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
