# Optimize-instructions OI-G memory64 constant offset slice

## Question

Can Starshine extend the `OptimizeInstructions.cpp::optimizeMemoryAccess(...)` constant-pointer static-offset fold to memory64 loads and stores using direct-core fixtures and Binaryen's unsigned address-overflow rule?

## Classification

This is the thirteenth `[O4Z-AUDIT-OI-G]` sub-slice. It extends the prior constant memory-offset implementation from memory32 `i32.const` address children to memory64 `i64.const` address children. Starshine now folds a nonzero static memarg offset into a constant `i64` memory address when unsigned `u64(address) + offset` does not wrap, then resets the memarg offset to zero.

This remains deliberately narrow. It does not implement general pointer-add canonicalization, does not rewrite `(i64.add base (i64.const k))` address expressions, and does not relax the `load-call-optimize-instructions-noop` raw gate.

Source anchors:

- Binaryen `version_130` `OptimizeInstructions.cpp::visitLoad(...)` and `visitStore(...)` call `optimizeMemoryAccess(curr->ptr, curr->offset, curr->memory)` for scalar memory accesses.
- The prior source-refresh matrix records memory64 address/offset cleanup as `[O4Z-AUDIT-OI-G]` work.
- Local Binaryen oracle evidence with `wasm-opt --enable-memory64 --optimize-instructions -S --print` confirms memory64 constant-address positives and the unsigned overflow boundary.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions folds constant memory64 access offset into i64 address`.
  - The direct-core fixture builds a memory64 module with `i64.const 8` plus `i32.load offset=4` and proves the optimized function prints `i64.const 12` with the nonzero offset removed.
- Added `optimize-instructions folds constant memory64 store offset into i64 address`.
  - The direct-core fixture builds a memory64 store with `i64.const 16` plus `i32.store offset=12` and proves the optimized function prints `i64.const 28` with the nonzero offset removed.
- Added `optimize-instructions keeps memory64 access offsets that would wrap u64 address`.
  - This intentional fail-closed boundary uses `i64.const -8` plus `offset=16`, which would wrap unsigned `u64` effective-address addition, so the original constant and offset remain.

Changed `src/passes/optimize_instructions.mbt`:

- Extended `optimize_instructions_try_fold_const_memory_access_offset(...)` to handle `I64Const` address children in addition to the existing memory32 `I32Const` path.
- Kept the memory32 guard unchanged: `address >= 0`, `offset <= INT32_MAX`, and `address + offset <= INT32_MAX`.
- Added the memory64 guard: reinterpret the signed `i64.const` payload as `u64` and fold only when `raw_u <= UINT64_MAX - offset`.

## Red-first evidence

Before implementation, the new focused memory64 offset positives failed while the optimizer left the original nonzero offsets in place:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory64*offset*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1563 ("optimize-instructions folds constant memory64 access offset into i64 address") failed: ... body_raw: (i64.const I64(8))(i32.load align=U32(2) offset=U64(4))(end)
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1603 ("optimize-instructions folds constant memory64 store offset into i64 address") failed: ... body_raw: (i64.const I64(16))(i32.const I32(99))(i32.store align=U32(2) offset=U64(12))(end)
Total tests: 2, passed: 0, failed: 2.
```

## Focused and broader evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory64*offset*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 3, passed: 3, failed: 0.
Total tests: 20, passed: 20, failed: 0.
Total tests: 125, passed: 125, failed: 0.
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
- `moon test src/passes`: passed, `Total tests: 2637, passed: 2637, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Binaryen oracle probe

```sh
wasm-opt .tmp/oi-g-memory64-offset.wat --enable-memory64 --optimize-instructions -S --print | grep -E 'i64\.const|i32\.load|i32\.store'
```

Result:

```text
  (i32.load
   (i64.const 12)
  (i32.store
   (i64.const 28)
  (i32.load offset=16
   (i64.const -8)
```

This confirms Binaryen `version_130` folds the non-wrapping memory64 constant-address load/store offsets and keeps the unsigned-overflow boundary unchanged.

## Direct compare evidence

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-memory64-const-offset-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Wrote pass fuzz compare artifacts to /home/jtenner/Projects/starshine-mb/.tmp/pass-fuzz-optimize-instructions-oi-g-memory64-const-offset-10000
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

Agent mismatch classification: the `27` raw mismatches are the already-known **Starshine-win** constant-if and redundant-sign-extension output-shape families from OI-E/OI-F, not new memory64 constant-offset semantic failures. A grep of failure artifacts found no `memory64`, `i64.load offset`, `i64.store offset`, `i32.load offset`, or `i32.store offset` evidence indicating a new memory-offset failure.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially nonconstant pointer-offset forms if source-backed safety proof and ownership are established;
- any other `optimizeStoredValue` shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- the explicit decision on whether any memory/load/call shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
