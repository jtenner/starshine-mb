# Optimize-instructions OI-G eight-byte memory.fill slice

_Date:_ 2026-06-19
_Status:_ implementation sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine extend the existing constant-value `memory.fill` lowering to the eight-byte case without taking on nonconstant value materialization, overlap-sensitive `memory.copy`, or trap-relaxed zero-size cleanup?

## Source classification

The 2026-06-19 `version_130` source/lit matrix assigns Binaryen `OptimizeInstructions.cpp` ownership for `optimizeMemoryFill(...)`. Earlier OI-G sub-slices covered size `1`, constant-value size `2`, and constant-value size `4` fills. This sub-slice adds only the no-mode, no-side-effect size-`8` case:

- `memory.fill dst (i32.const b) (i32.const 8)` lowers to `i64.store dst (repeat-byte b)`, where `repeat-byte b` repeats the low byte across all eight bytes.

The lowered value is built as an `i64.const`, so the generated store has the expected `i64` value operand. The transform remains bulk-memory shape cleanup owned by optimize-instructions; it does not claim general load/store canonicalization or address/value propagation.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- added `optimize_instructions_repeated_fill_i64(...)` to repeat the low byte of an `i32.const` fill value into all eight bytes of an `i64.const`;
- extended `optimize_instructions_try_expand_tiny_memory_fill(...)` so constant size `8` requires an `i32.const` fill value, materializes the repeated-byte `i64.const`, and replaces the bulk-memory node with exact `i64.store` while preserving the memory index through the existing zero-offset memarg helper.

Safety boundaries:

- The dropped size operand is a constant, so no side effects are removed.
- The dropped fill-value operand is also required to be a constant, so no value side effects are removed.
- Nonconstant wider fill values remain as `memory.fill` until Starshine has a source-backed local computation/reordering proof for materializing repeated bytes.
- Zero-size cleanup remains unsupported without explicit trap-relaxed mode plumbing.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands constant eight-byte memory.fill to store`

Red-first result after adding the test and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 6, passed: 5, failed: 1.
```

The new eight-byte positive failed with `memory.fill` still present; the existing size-1, size-2, size-4, zero-size, and nonconstant-boundary tests passed.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 6, passed: 6, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 7, passed: 7, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 108, passed: 108, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2620, passed: 2620, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory-fill-8-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested `10000`
- compared `53/10000`
- normalized matches `26`
- cleanup-normalized matches `0`
- raw mismatches `27`
- validation failures `0`
- property failures `0`
- generator failures `0`
- command failures `1`
- jobs `16`
- cache: wasm-smith `27` hits / `0` misses; Binaryen `53` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent classifications:

- command failure: known **tool/Binaryen failure** class `binaryen-rec-group-zero`.
- raw mismatches: known **Starshine-win** output-shape families already present after OI-E/OI-F and unchanged by this memory-fill sub-slice, dominated by Starshine's smaller constant-if and redundant-sign-extension cleanup shapes rather than new memory-fill semantic failures. The inspected sample failure WATs do not contain memory-fill or generated store differences.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This sub-slice still does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- wider `memory.copy` sizes and overlap-safe multi-byte semantics;
- nonconstant wider `memory.fill` materialization with explicit effect/trap/reorder proof;
- memory64-focused fixtures beyond accepting a constant `i64` size operand in the helper;
- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- general load/store offset and stored-value canonicalization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
