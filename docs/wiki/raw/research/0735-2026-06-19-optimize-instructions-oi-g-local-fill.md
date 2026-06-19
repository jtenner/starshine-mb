# Optimize-instructions OI-G local wider memory.fill slice

_Date:_ 2026-06-19
_Status:_ implementation sub-slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine safely lower a nonconstant wider `memory.fill` subset without taking on arbitrary effectful value materialization or overlap-sensitive `memory.copy` work?

## Source classification

The 2026-06-19 `version_130` source/lit matrix assigns Binaryen `OptimizeInstructions.cpp` ownership for `optimizeMemoryFill(...)`. Earlier OI-G sub-slices covered size `1` fills, constant-value size `2`/`4` fills, and constant-value size `8` fills. This sub-slice extends only a locally safe nonconstant value shape:

- `memory.fill dst (local.get $value) (i32.const 2)` lowers to `i32.store16 dst ((local.get $value & 255) * 257)`.
- `memory.fill dst (local.get $value) (i32.const 4)` lowers to `i32.store dst ((local.get $value & 255) * 16843009)`.
- effectful values such as calls remain as `memory.fill` because duplicating or moving them into repeated-byte materialization would change evaluation and trap/effect behavior.

The repeated-byte expression masks to the low byte first, matching `memory.fill` semantics. It then multiplies by the byte-repeat constant for the target store width. The generated store preserves the destination memory index through the existing zero-offset memarg helper.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- added `optimize_instructions_build_i32_binary(...)` for exact HOT `i32` helper construction;
- added `optimize_instructions_repeated_fill_i32_for_local_get(...)` to build the low-byte mask and multiply sequence from a fresh `local.get` clone;
- extended the existing size `2` / `4` arm in `optimize_instructions_try_expand_tiny_memory_fill(...)` so constants still fold to constants, while `local.get` fill values lower to a repeated-byte expression.

Safety boundaries:

- the size operand is still required to be a constant, so dropping it does not remove effects;
- the nonconstant fill value is admitted only when it is a `local.get`, so rebuilding it as a fresh `local.get` has no side effects and does not duplicate a trap;
- effectful values remain unchanged and are covered by an explicit negative fixture;
- size `8` nonconstant values remain open until Starshine has a similarly narrow i64 expression construction and validation proof;
- zero-size cleanup remains unsupported without explicit trap-relaxed mode plumbing.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands local two-byte memory.fill to store16`
- `optimize-instructions expands local four-byte memory.fill to store`
- `optimize-instructions keeps wider effectful memory.fill values`

Red-first result after adding tests and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 8, passed: 6, failed: 2.
```

The two new local-value positives failed with `memory.fill` still present. The existing size-1/2/4/8 constant positives, zero-size boundary, and new effectful-value boundary passed.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'
Total tests: 8, passed: 8, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 9, passed: 9, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 110, passed: 110, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2622, passed: 2622, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Initial attempt:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-local-fill-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

The first attempt timed out after 600 seconds before `result.json` was written. No stale compare or Moon processes remained. The partial out dir was removed and the same lane was rerun with a longer command timeout.

Final command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-local-fill-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

- requested `10000`
- compared `56/10000`
- normalized matches `28`
- cleanup-normalized matches `0`
- raw mismatches `28`
- validation failures `0`
- property failures `0`
- generator failures `0`
- command failures `1`
- jobs `16`
- cache: wasm-smith `29` hits / `0` misses; Binaryen `56` hits / `0` misses; Binaryen failures `1` hit / `0` misses

Agent classifications:

- command failure: known **tool/Binaryen failure** class `binaryen-rec-group-zero`.
- raw mismatches: known **Starshine-win** output-shape families already present after OI-E/OI-F and unchanged by this local-fill sub-slice, dominated by Starshine's smaller constant-if and redundant-sign-extension cleanup shapes rather than new memory-fill semantic failures. A grep of failure WATs found no `memory.fill` occurrences.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This sub-slice still does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- wider `memory.copy` sizes and overlap-safe multi-byte semantics;
- size-8 nonconstant `memory.fill` materialization with an explicit i64 expression construction proof;
- memory64-focused fixtures beyond accepting a constant `i64` size operand in the helper;
- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- general load/store offset and stored-value canonicalization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
