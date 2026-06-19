# Optimize-instructions OI-G wider memory.copy slice

_Date:_ 2026-06-19  
_Status:_ implementation sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine widen the OI-owned tiny `memory.copy` lowering beyond the byte case without violating overlap / trap behavior or conflating the work with `optimize-added-constants`?

## Source classification

The 2026-06-19 `version_130` source/lit matrix records Binaryen `OptimizeInstructions.cpp` ownership for `optimizeMemoryCopy(...)` and `optimizeMemoryFill(...)`. The first OI-G byte slice already proved the size-1 `memory.copy` lowering to `i32.load8_u` + `i32.store8`.

This sub-slice covers constant sizes `2`, `4`, and `8` with a single exact load followed by a single exact store:

- size `2`: `i32.load16_u` + `i32.store16`;
- size `4`: `i32.load` + `i32.store`;
- size `8`: `i64.load` + `i64.store`.

This is safe for overlapping ranges because the whole source value is loaded before the destination store writes. It also preserves the relevant trap behavior for the admitted subset: the constant size operand has no effects, source range trapping happens at the generated load before any destination write, and destination range trapping happens at the generated store without partial stores. The rewrite keeps the original source and destination memory indices through exact memargs.

This remains an OI bulk-memory transform, not an `optimize-added-constants` fold: the instruction shape changes from `memory.copy` to an equivalent fixed-width load/store pair while address arithmetic is otherwise left alone.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- widened `optimize_instructions_try_expand_tiny_memory_copy(...)` from size `1` only to constant sizes `1`, `2`, `4`, and `8`;
- selected the exact load result type and load/store instruction pair by size;
- reused `optimize_instructions_replace_with_store_exact(...)` so destination memory index preservation stays shared with fill lowering;
- kept all other sizes as `memory.copy`.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- added `optimize-instructions expands wider tiny memory.copy to exact load/store`, covering sizes `2`, `4`, and `8` in one fixture and asserting the original `memory.copy` instructions disappear.

Red-first result after adding the test and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy*'
Total tests: 2, passed: 1, failed: 1.
```

The new wider-copy positive failed with the original `memory.copy` instructions still present.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.copy*'
Total tests: 2, passed: 2, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 11, passed: 11, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 112, passed: 112, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2624, passed: 2624, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-wider-memory-copy-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested `10000`
- compared `55/10000`
- normalized matches `27`
- cleanup-normalized matches `0`
- raw mismatches `28`
- validation failures `0`
- property failures `0`
- generator failures `0`
- command failures `1`
- jobs `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `55` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent classifications:

- command failure: known **tool/Binaryen failure** class `binaryen-rec-group-zero` (`case-000029-wasm-smith`).
- raw mismatches: known **Starshine-win** output-shape families from the preceding OI-E/OI-F work, dominated by Starshine's smaller constant-if and redundant sign-extension cleanup shapes. A grep of failure artifacts found no `memory.copy` or `memory.fill` occurrences, so this slice did not introduce a new bulk-memory mismatch family.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This sub-slice does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- memory64-focused fixtures beyond accepting constant `i64` size operands in the helper;
- general load/store offset and stored-value canonicalization;
- arbitrary or effectful nonconstant wider `memory.fill` value materialization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
