# Optimize-instructions OI-G local eight-byte memory.fill slice

_Date:_ 2026-06-19
_Status:_ implementation sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine safely lower the remaining local.get-valued size-8 `memory.fill` subset without admitting arbitrary nonconstant values or broader memory-copy overlap risks?

## Source classification

The 2026-06-19 `version_130` source/lit matrix assigns Binaryen `OptimizeInstructions.cpp` ownership for `optimizeMemoryFill(...)`. Earlier OI-G sub-slices covered constant-size-1 copy/fill, constant-value size-2/4/8 fill, and local.get-value size-2/4 fill. This sub-slice extends only the analogous local.get-value size-8 fill shape:

- `memory.fill dst (local.get $value) (i32.const 8)` lowers to `i64.store dst (i64.extend_i32_u((local.get $value) & 255) * 72340172838076673)`.

The expression masks to the low byte before extension and multiplication, matching `memory.fill` byte semantics. The multiplier is `0x0101010101010101`, so the low byte is repeated across the eight stored bytes. The generated `i64.store` preserves the destination memory index through the existing memarg helper.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- added exact HOT construction helpers for `i64` binary nodes and typed unary nodes;
- added `optimize_instructions_repeated_fill_i64_for_local_get(...)` to build the low-byte mask, `i64.extend_i32_u`, and repeat multiply sequence from a fresh `local.get` clone;
- extended the size-8 arm in `optimize_instructions_try_expand_tiny_memory_fill(...)` so constants still fold to repeated-byte `i64.const`, while `local.get` values now lower to the repeated-byte `i64` expression.

Safety boundaries:

- the size operand is still required to be a constant, so dropping it does not remove effects;
- the nonconstant fill value is admitted only when it is `local.get`, so rebuilding it as a fresh local read has no side effects and does not duplicate a trap;
- effectful values such as calls remain as `memory.fill` under the existing explicit negative fixture;
- wider `memory.copy` remains open because multi-byte copy lowering is overlap-sensitive;
- zero-size cleanup remains unsupported without explicit trap-relaxed mode plumbing;
- memory64-focused fixtures and general load/store canonicalization remain separate OI-G deliverables.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands local eight-byte memory.fill to store`

Red-first result after adding the test and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 9, passed: 8, failed: 1.
```

The new local-value size-8 positive failed because `memory.fill` still remained. Existing constant fill positives, local size-2/4 positives, zero-size boundary, and effectful-value boundary passed.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 9, passed: 9, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 10, passed: 10, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 111, passed: 111, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2623, passed: 2623, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-local-eight-fill-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- raw mismatches: known **Starshine-win** output-shape families already present after OI-E/OI-F and unchanged by this local eight-byte fill sub-slice, dominated by Starshine's smaller constant-if and redundant-sign-extension cleanup shapes rather than new memory-fill semantic failures. A grep of failure WATs found no `memory.fill` occurrences.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This sub-slice still does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- wider `memory.copy` sizes and overlap-safe multi-byte semantics;
- memory64-focused fixtures beyond accepting constant `i64` size operands in the helper;
- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- general load/store offset and stored-value canonicalization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
