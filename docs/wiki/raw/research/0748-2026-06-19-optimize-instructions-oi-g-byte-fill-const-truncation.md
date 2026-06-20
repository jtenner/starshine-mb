# Optimize-instructions OI-G byte memory.fill constant truncation slice

Date: 2026-06-19

## Question

Can Starshine match Binaryen's `optimizeMemoryFill(...)` spelling for constant size-1 fills whose value has high bits that `i32.store8` will discard?

## Classification

This is the seventeenth `[O4Z-AUDIT-OI-G]` sub-slice. It tightens the existing size-1 `memory.fill` lowering so constant fill values are canonicalized to the low byte before materializing the replacement `i32.store8`.

This is source-backed by the OI-G memory/bulk-memory owner matrix for `optimizeMemoryFill(...)` and by the local Binaryen oracle probe: with bulk memory enabled, `memory.fill` of size `1` with `i32.const -1` becomes `i32.store8` with `i32.const 255`. The same probe also confirmed the already-covered size `2` / `4` / `8` repeated-byte constants for high-bit values.

This is not zero-size bulk-memory cleanup, arbitrary nonconstant fill materialization, a wider multi-store copy shape, recursive `maxBits` scanner parity, or a `load-call-optimize-instructions-noop` relaxation.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryCopy(...)` / `optimizeMemoryFill(...)` as `[O4Z-AUDIT-OI-G]` work.
- Prior OI-G fill slices [`0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md`](0732-2026-06-19-optimize-instructions-oi-g-byte-bulk-memory.md), [`0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md`](0733-2026-06-19-optimize-instructions-oi-g-wide-memory-fill.md), [`0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md`](0734-2026-06-19-optimize-instructions-oi-g-eight-byte-fill.md), [`0735-2026-06-19-optimize-instructions-oi-g-local-fill.md`](0735-2026-06-19-optimize-instructions-oi-g-local-fill.md), and [`0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md`](0736-2026-06-19-optimize-instructions-oi-g-local-eight-fill.md) established the exact tiny fill lowering and effectful/nonconstant boundaries.
- The local Binaryen oracle probe `.tmp/oi-g-fill-const-trunc.wat` with `wasm-opt --enable-bulk-memory --optimize-instructions -S --print` showed `i32.const -1; i32.const 1; memory.fill` lowering to `i32.const 255; i32.store8`.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions truncates constant byte memory.fill values before store8`.
- The fixture covers constant size-1 fills with `i32.const -1` and `i32.const 511`.
- The assertions verify `memory.fill`, `I32(-1)`, and `I32(511)` disappear and the lowered stores use `I32(255)` before each `i32.store8`.

Changed `src/passes/optimize_instructions.mbt`:

- Extended `optimize_instructions_repeated_fill_i32(...)` with a size-1 case returning the low byte.
- Updated `optimize_instructions_try_expand_tiny_memory_fill(...)` so size-1 fills replace constant values with the low-byte constant before building the `i32.store8`; nonconstant values still lower exactly as before and rely on store8 semantics.

## Red-first evidence

Before implementation, the new focused test failed as expected:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*constant byte memory.fill values*'
```

Result excerpt:

```text
body_raw:
  (local.get (Local 0))(i32.const I32(-1))(i32.store8 ...)
  (local.get (Local 0))(i32.const I32(511))(i32.store8 ...)
Total tests: 1, passed: 0, failed: 1.
```

## Focused evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*constant byte memory.fill values*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 1, passed: 1, failed: 0.
Total tests: 11, passed: 11, failed: 0.
Total tests: 22, passed: 22, failed: 0.
Total tests: 129, passed: 129, failed: 0.
```

## Broader validation

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
moon info
```

Results:

- `moon fmt`: passed.
- `moon test src/passes`: passed, `Total tests: 2641, passed: 2641, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

The first direct compare attempt timed out before writing `result.json`:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-byte-fill-const-truncation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

After removing the partial out dir, the rerun completed to the default failure ceiling:

```sh
rm -rf .tmp/pass-fuzz-optimize-instructions-oi-g-byte-fill-const-truncation-10000 && \
  bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-byte-fill-const-truncation-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Requested: 10000
Compared: 55/10000
Normalized matches: 27
Cleanup-normalized matches: 0
Compare-normalized matches: 0
Raw mismatches: 28
Validation failures: 0
Property failures: 0
Generator failures: 0
Command failures: 1
Jobs: 16
Cache: wasm-smith 28 hits/0 misses; Binaryen 55 hits/0 misses; Binaryen failures 1 hits/0 misses
```

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new memory-fill semantic failures. A grep of failure artifacts found no `memory.fill`, `store8`, `i32.store8`, or `i64.store8` occurrences.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially any source-backed nonconstant pointer-offset forms if ownership and HOT safety are established;
- any other `optimizeStoredValue` shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- any broader source-backed decision on whether a class of shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
