# Optimize-instructions OI-G i64 narrow store mask slice

## Question

Can Starshine safely extend the existing narrow-store stored-value cleanup to `i64.store8`, `i64.store16`, and `i64.store32` while keeping Binaryen drift explicit?

## Classification

This is the eleventh `[O4Z-AUDIT-OI-G]` sub-slice. It extends the local stored-value cleanup added in the prior slice from `i32.store8` / `i32.store16` to the `i64` narrow-store family: remove an `i64.and` mask before `i64.store8`, `i64.store16`, or `i64.store32` when the mask preserves every low bit that the store can observe.

Important source/drift caveat: local `wasm-opt --optimize-instructions -S --print` evidence for Binaryen `version_130` keeps the equivalent `i64.and` masks before `i64.store8` / `i64.store16` / `i64.store32`, even though the same oracle removes the `i32.and` masks before `i32.store8` / `i32.store16`. This slice is therefore recorded as a Starshine-win generalization of the OI-owned stored-value rule, not as literal Binaryen output-shape parity. The transform is behavior-preserving because a narrow store only writes its low 8/16/32 value bits; removing a mask that has all those low bits set leaves the stored bytes unchanged and removes one pure operation.

This is not pointer-offset folding, zero-size bulk-memory cleanup, or any `load-call-optimize-instructions-noop` relaxation. Those OI-G items remain open.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryAccess(...)` / load-store offset and stored-value cleanup as `[O4Z-AUDIT-OI-G]` work.
- Prior slice [`0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md`](0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md) implemented the source-backed `i32` subset and kept broader stored-value cleanup open.
- Local Binaryen oracle probe: `wasm-opt .tmp/oi-g-i64-narrow-store-mask.wat --optimize-instructions -S --print | grep -E 'i64\.and|i64\.store'` still prints the `i64.and` operands, while the analogous `i32` probe removes `i32.and`.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions drops masked low bits before i64 narrow stores`.
  - The fixture stores `(value & 255)` with `i64.store8`, `(value & 65535)` with `i64.store16`, and `(value & 4294967295)` with `i64.store32`.
  - It asserts all redundant `i64.and` operations disappear and that the store operands remain original address/value order.
- Added `optimize-instructions keeps value-changing masks before i64 narrow stores`.
  - The fixture keeps `(value & 127)` before `i64.store8`, `(value & 32767)` before `i64.store16`, and `(value & 2147483647)` before `i64.store32`.
  - This is an intentional fail-closed boundary: those masks change bits that the corresponding store can observe.

Changed `src/passes/optimize_instructions.mbt`:

- Extended `optimize_instructions_store_value_bits(...)` to recognize `i64.store8`, `i64.store16`, and `i64.store32`.
- Added `optimize_instructions_store_value_is_i64(...)` so the stored-mask rewrite matches `i64.and` plus an `i64.const` mask for i64 stores and keeps the existing `i32.and` / `i32.const` path for i32 stores.
- The rewrite preserves the original store instruction and address child, and only replaces the stored value child with the unmasked value.

## Red-first evidence

Before the implementation, the new focused filter failed exactly the new positive test while the boundary test passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64 narrow stores*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1448 ("optimize-instructions drops masked low bits before i64 narrow stores") failed: ... body_raw: ... i64.and ... i64.store8 ... i64.and ... i64.store16 ... i64.and ... i64.store32 ...
Total tests: 2, passed: 1, failed: 1.
```

## Focused evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64 narrow stores*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 2, passed: 2, failed: 0.
Total tests: 4, passed: 4, failed: 0.
Total tests: 15, passed: 15, failed: 0.
Total tests: 120, passed: 120, failed: 0.
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
- `moon test src/passes`: passed, `Total tests: 2632, passed: 2632, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

The first direct compare invocation timed out after 600 seconds before writing `result.json`:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-i64-narrow-store-mask-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

A rerun with a longer tool timeout completed:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-i64-narrow-store-mask-10000-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Requested: 10000
Compared: 55/10000
Normalized matches: 27
Cleanup-normalized matches: 0
Raw mismatches: 28
Validation failures: 0
Property failures: 0
Generator failures: 0
Command failures: 1
Jobs: 16
Cache: wasm-smith 28 hits/0 misses; Binaryen 55 hits/0 misses; Binaryen failures 1 hits/0 misses
```

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `28` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from OI-E/OI-F, not new i64 narrow-store semantic failures. A grep of failure artifacts found no `store8`, `store16`, `store32`, `i64.store8`, `i64.store16`, or `i64.store32` occurrences. Sample canonical wasm sizes stayed smaller for Starshine: `case-000002-gen-valid` Binaryen `4161` bytes vs Starshine `4120`, `case-000004-gen-valid` `5539` vs `5481`, and `case-000006-gen-valid` `5559` vs `5496`.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially source-backed pointer-offset forms and any other stored-value shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- the explicit decision on whether any memory/load/call shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
