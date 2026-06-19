# Optimize-instructions OI-G byte bulk-memory slice

_Date:_ 2026-06-19  
_Status:_ implementation slice for `[O4Z-AUDIT-OI-G]`

## Question

Can Starshine cover the smallest Binaryen-owned bulk-memory `optimize-instructions` surface without conflating it with `optimize-added-constants` or trap-relaxed mode work?

## Source classification

The 2026-06-19 `version_130` source/lit matrix records `OptimizeInstructions.cpp` ownership for `optimizeMemoryCopy(...)` and `optimizeMemoryFill(...)`, while keeping general load/store offset and stored-value canonicalization separate enough to audit later. This slice therefore chose the smallest non-mode-dependent bulk-memory cases:

- `memory.copy` with constant size `1` lowers to `i32.load8_u` from the source address and `i32.store8` to the destination address.
- `memory.fill` with constant size `1` lowers to `i32.store8` of the original fill value.
- zero-size `memory.fill` is intentionally left unchanged because Starshine does not expose Binaryen TNH/IIT or ignore-traps style OI options in this pass surface.

This is an OI-owned bulk-memory transform, not an `optimize-added-constants` fold: the value being optimized is the bulk-memory instruction shape itself, not propagation of address/value constants into neighboring arithmetic.

## Implementation

Changed `src/passes/optimize_instructions.mbt`:

- added `optimize_instructions_const_memory_size(...)` accepting non-negative `i32.const` or small `i64.const` size operands;
- added memory-index to zero-offset memarg construction for HOT memory nodes;
- added `optimize_instructions_try_expand_tiny_memory_copy(...)` for size-1 `MemoryCopy`;
- added `optimize_instructions_try_expand_tiny_memory_fill(...)` for size-1 `MemoryFill`;
- wired `HotOp::MemoryCopy` and `HotOp::MemoryFill` into `optimize_instructions_visit_node(...)`.

The rewrite preserves argument/effect order for this byte-only subset: `memory.copy dst src 1` evaluates `dst`, then the generated value load evaluates `src`, then the generated store writes one byte. The original size operand is a constant, so dropping it cannot drop effects. The byte copy is overlap-safe because copying one byte has no multi-byte direction choice.

## Tests

Changed `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands one-byte memory.copy to load8/store8`
- `optimize-instructions expands tiny constant memory.fill to store`
- `optimize-instructions keeps zero-size memory.fill without trap mode support`

Red-first result after adding tests and before implementation:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 3, passed: 1, failed: 2.
```

The two positive byte-lowering tests failed with the original `memory.copy` / `memory.fill` still present. The zero-size boundary passed.

Final focused results:

```text
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
Total tests: 3, passed: 3, failed: 0.

moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
Total tests: 104, passed: 104, failed: 0.
```

## Broader validation

```text
moon fmt
Finished.

moon test src/passes
Total tests: 2616, passed: 2616, failed: 0.

moon build --target native --release src/cmd
Finished. Existing unused-function warnings in pass_manager.mbt remained.

moon info
Finished. Existing unused trait/function warnings in validate/gen_valid*.mbt remained.
```

## Direct compare smoke

Command:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory-byte-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
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
- raw mismatches: known **Starshine-win** output-shape families already present after OI-E/OI-F, dominated by Starshine's smaller constant-if and redundant sign-extension cleanup shapes rather than new memory-copy/fill failures.

Sample canonical wasm size checks stayed smaller for Starshine:

- `case-000002-gen-valid`: Binaryen `4161` bytes, Starshine `4120` bytes
- `case-000004-gen-valid`: Binaryen `5539` bytes, Starshine `5481` bytes
- `case-000006-gen-valid`: Binaryen `5559` bytes, Starshine `5496` bytes

## Boundaries kept open

This slice does not claim full `[O4Z-AUDIT-OI-G]` memory parity. Remaining OI-G work includes:

- wider tiny `memory.copy` sizes such as `2`, `4`, `8`, and safe multi-store sequences;
- wider `memory.fill` sizes and repeated-byte materialization;
- memory64-focused fixtures beyond accepting an `i64.const` size operand in the helper;
- zero-size `memory.copy` / `memory.fill` cleanup gated by explicit ignore-traps / TNH / IIT-equivalent mode support;
- general load/store offset and stored-value canonicalization;
- deciding whether any memory-plus-call cases can safely escape the existing `load-call-optimize-instructions-noop` raw gate.
