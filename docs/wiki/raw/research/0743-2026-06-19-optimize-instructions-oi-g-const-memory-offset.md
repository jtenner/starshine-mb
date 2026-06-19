# Optimize-instructions OI-G constant memory offset slice

## Question

Can Starshine cover the `OptimizeInstructions.cpp::optimizeMemoryAccess(...)` constant-pointer offset fold for ordinary memory32 loads and stores without conflating it with broader `optimize-added-constants` address arithmetic?

## Classification

This is the twelfth `[O4Z-AUDIT-OI-G]` sub-slice. It implements the narrow source-backed `optimizeMemoryAccess(...)` case where a load or store already has a constant address child and a nonzero static memarg offset. Starshine now folds the static offset into the constant address and resets the memarg offset to zero when the address, offset, and sum all stay in Binaryen's guarded nonnegative memory32 range.

This is deliberately not general pointer-add canonicalization. It does not rewrite `(i32.add base (i32.const k))` address expressions into memarg offsets, does not relax the `load-call-optimize-instructions-noop` raw gate, and does not cover memory64 constant offsets yet.

Source anchors:

- Binaryen `version_130` `OptimizeInstructions.cpp::visitLoad(...)` and `visitStore(...)` call `optimizeMemoryAccess(curr->ptr, curr->offset, curr->memory)`.
- Binaryen `version_130` `optimizeMemoryAccess(...)` folds only constant `ptr` plus existing static `offset`; for memory32, it refuses the fold unless the constant address, offset, and sum all fit in the nonnegative `int32_t` range.
- Local oracle probe on `.tmp/oi-g-const-offset.wat` confirmed `wasm-opt --optimize-instructions -S --print` rewrites `i32.load offset=4 (i32.const 8)` to `i32.load (i32.const 12)`, rewrites `i32.store offset=12 (i32.const 16) ...` to `i32.store (i32.const 28) ...`, and keeps `i32.load offset=16 (i32.const 2147483640)` unchanged.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions folds constant memory access offset into i32 address`.
  - The load fixture proves `i32.const 8` plus `i32.load offset=4` becomes address `12` with zero memarg offset.
  - The store fixture proves `i32.const 16` plus `i32.store offset=12` becomes address `28` with zero memarg offset.
- Added `optimize-instructions keeps memory access offsets that would escape i32 positive range`.
  - This is an intentional fail-closed boundary matching Binaryen's memory32 guard: `i32.const 2147483640` plus `offset=16` keeps the original address and offset because the sum would exceed `INT32_MAX`.

Changed `src/passes/optimize_instructions.mbt`:

- Added `optimize_instructions_memory_access_with_memarg(...)` for scalar load/store exact-instruction reconstruction with a replacement memarg.
- Added `optimize_instructions_try_fold_const_memory_access_offset(...)`.
  - It only runs on HOT `Load` and `Store` nodes with a constant `i32` address child and a nonzero memarg offset.
  - It requires `address >= 0`, `offset <= 2147483647`, and `address + offset <= 2147483647`.
  - It replaces the address child with a new folded `i32.const` and resets the exact load/store instruction memarg offset to zero.
- Wired the load visitor arm to this helper and made the store arm try it before the existing narrow stored-mask cleanup.

## Red-first evidence

Before implementation, the focused filter failed the new positive test while the boundary test passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory access offset*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1524 ("optimize-instructions folds constant memory access offset into i32 address") failed: ... `I32Const(I32(8)) != I32Const(I32(12))`
Total tests: 2, passed: 1, failed: 1.
```

## Focused and broader evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory access offset*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 2, passed: 2, failed: 0.
Total tests: 17, passed: 17, failed: 0.
Total tests: 122, passed: 122, failed: 0.
```

Broader local signoff:

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
moon info
```

Results:

- `moon fmt`: passed.
- `moon test src/passes`: passed, `Total tests: 2634, passed: 2634, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Binaryen oracle probe

```sh
wasm-opt .tmp/oi-g-const-offset.wat --optimize-instructions -S --print | grep -E 'i32\.const|i32\.load|i32\.store'
```

Result:

```text
  (i32.load
   (i32.const 12)
  (i32.store
   (i32.const 28)
   (i32.const 99)
  (i32.load offset=16
   (i32.const 2147483640)
```

This confirms the implemented positive and boundary shapes match Binaryen `version_130` for memory32 constant-pointer offset folding.

## Direct compare evidence

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-const-offset-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Wrote pass fuzz compare artifacts to /home/jtenner/Projects/starshine-mb/.tmp/pass-fuzz-optimize-instructions-oi-g-const-offset-10000-rerun
Jobs: 16
Compared cases: 54/10000
Normalized matches: 27
Compare-normalized matches: 0
Validation failures: 0
Property failures: 0
Cache: wasm-smith 28 hits/0 misses; Binaryen 54 hits/0 misses; Binaryen failures 1 hits/0 misses
Generator failures: 0
Command failures: 1
Mismatches: 27
```

`result.json` records `cleanupNormalizedMatchCount: 0`, `commandFailureClasses: { "binaryen-rec-group-zero": 1 }`, and default cache dir `.tmp/pass-fuzz-cache`.

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `27` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from OI-E/OI-F, not new constant-memory-offset semantic failures. A grep of failure artifacts found no `load offset`, `store offset`, `i32.load offset`, or `i32.store offset` occurrences. Sample canonical wasm sizes stayed smaller for Starshine: `case-000002-gen-valid` Binaryen `4161` bytes vs Starshine `4120`, `case-000004-gen-valid` `5539` vs `5481`, `case-000006-gen-valid` `5559` vs `5496`.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially nonconstant pointer-offset forms if source-backed safety proof and ownership are established;
- any other `optimizeStoredValue` shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- the explicit decision on whether any memory/load/call shapes should escape `load-call-optimize-instructions-noop`;
- memory64 constant-pointer offset folding if local fixtures can prove the memory64 address and overflow rules;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
