# Optimize-instructions OI-G wide constant memory.fill slice

_Date:_ 2026-06-19
_Status:_ implementation sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine cover a narrow wider `memory.fill` subset without taking on the harder general bulk-memory and trap-mode surfaces?

## Source classification

The 2026-06-19 `version_130` source/lit matrix assigns Binaryen `OptimizeInstructions.cpp` ownership for `optimizeMemoryFill(...)`. The prior OI-G byte slice covered constant-size `1`. This sub-slice extends only the no-mode, no-side-effect wider constant-value surface:

- `memory.fill dst (i32.const b) (i32.const 2)` lowers to `i32.store16 dst (repeat-byte b)`, where `repeat-byte b` is `b | b << 8` after truncating `b` to the low byte.
- `memory.fill dst (i32.const b) (i32.const 4)` lowers to `i32.store dst (repeat-byte b)`, where the repeated value fills all four bytes.
- wider nonconstant fill values remain as `memory.fill`, because lowering them correctly would require introducing value computation such as multiply/shift/or operations while preserving local effect, trap, and use semantics.

This remains OI-owned bulk-memory shape cleanup. It does not claim general load/store canonicalization and does not depend on Binaryen ignore-traps/TNH/IIT-like zero-size cleanup modes.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- generalized the one-byte store replacement helper into `optimize_instructions_replace_with_store_exact(...)` so fill rewrites can choose `i32.store8`, `i32.store16`, or `i32.store` while preserving the memory index through the existing zero-offset HOT memarg helper;
- kept `optimize_instructions_replace_with_store8(...)` as a small wrapper for the existing size-1 copy/fill paths;
- added `optimize_instructions_repeated_fill_i32(...)` for repeated low-byte constants at sizes `2` and `4`;
- extended `optimize_instructions_try_expand_tiny_memory_fill(...)` so size `1` still reuses the original value operand, while sizes `2` and `4` require an `i32.const` fill value and materialize the repeated constant before replacing the node with the exact store.

Safety boundaries:

- The dropped size operand is a constant, so no side effects are removed.
- For the wider cases, the dropped fill-value operand is also a constant, so no side effects are removed.
- Nonconstant wider values stay as `memory.fill` until Starshine has a source-backed local computation/reordering proof for materializing repeated bytes.
- Zero-size cleanup remains unsupported without explicit trap-relaxed mode plumbing.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands constant two-byte memory.fill to store16`
- `optimize-instructions expands constant four-byte memory.fill to store`
- `optimize-instructions keeps wider nonconstant memory.fill values`

Red-first result after adding tests and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 5, passed: 3, failed: 2.
```

The two positive wider constant-fill tests failed with `memory.fill` still present. The existing size-1 positive, zero-size boundary, and new nonconstant wider boundary passed.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 5, passed: 5, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 6, passed: 6, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 107, passed: 107, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2619, passed: 2619, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory-fill-wide-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested `10000`
- compared `54/10000`
- normalized matches `27`
- cleanup-normalized matches `0`
- raw mismatches `27`
- validation failures `0`
- property failures `0`
- generator failures `0`
- command failures `1`
- jobs `16`
- cache: wasm-smith `28` hits / `0` misses; Binaryen `54` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent classifications:

- command failure: known **tool/Binaryen failure** class `binaryen-rec-group-zero`.
- raw mismatches: known **Starshine-win** output-shape families already present after OI-E/OI-F and unchanged by this memory-fill sub-slice, dominated by Starshine's smaller constant-if and redundant sign-extension cleanup shapes rather than new memory-fill semantic failures.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This sub-slice still does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- wider `memory.copy` sizes and overlap-safe multi-byte semantics;
- nonconstant wider `memory.fill` materialization with explicit effect/trap/reorder proof;
- size-8 fill lowering, likely through an `i64.store` constant or another source-backed small sequence;
- memory64-focused fixtures beyond accepting a constant `i64` size operand in the helper;
- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- general load/store offset and stored-value canonicalization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
