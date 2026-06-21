# Optimize-instructions OI-K packed struct.get_s/get_u of struct.new

Date: 2026-06-20

## Summary

Second `[O4Z-AUDIT-OI-K]` GC constructor/field/default sub-slice.

This implementation slice extends the prior pure `struct.get(struct.new(...))` forwarding to packed field reads:

```wat
local.get $x
struct.new $s
struct.get_s $s 1
```

For pure non-selected constructor fields, Binaryen `version_130` removes the fresh allocation and rewrites packed reads to the selected value with the correct signed or unsigned unpacking. Starshine now matches that locally representable subset for `struct.get_s` / `struct.get_u` over matching exact `struct.new` constructors.

## Binaryen oracle

Probe file: `.tmp/oi-k-struct-get-packed-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-k-struct-get-packed-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- constant `struct.get_s` over an `i8` field with `i32.const 255` became `i32.const -1`;
- constant `struct.get_u` over the same `i8` field became `i32.const 255`;
- constant `struct.get_s` over an `i16` field with `i32.const 65535` became `i32.const -1`;
- constant `struct.get_u` over the same `i16` field became `i32.const 65535`;
- nonconstant `struct.get_s` over an `i8` field became `i32.extend8_s(local.get)`;
- nonconstant `struct.get_u` over an `i16` field became `i32.and(local.get, i32.const 65535)`.

## Starshine change

Updated `optimize_instructions_try_fold_struct_get_struct_new(...)` in `src/passes/optimize_instructions.mbt`:

- recognizes `StructGetS(type, field)` and `StructGetU(type, field)` in addition to plain `StructGet`;
- resolves the struct field storage through `HotModuleContext` and only folds packed `i8` / `i16` fields;
- preserves the previous one-use matching-`StructNew` and pure non-selected sibling requirements;
- folds constant selected values with the correct signed or unsigned truncation;
- rewrites nonconstant signed reads to `i32.extend8s` / `i32.extend16s`;
- rewrites nonconstant unsigned reads to `i32.and` with `255` or `65535`.

Added focused public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds packed struct.get_s and struct.get_u of struct.new field values`

## Red-first evidence

Before implementation, the focused filter failed because Starshine still printed the original packed `struct.new` / `struct.get_s` chain:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*packed struct.get*'
```

Initial result: failed with the first function still containing `(struct.new (Type 0))(struct.get_s (Type 0) U32(1))`.

Final focused result: `Total tests: 1, passed: 1, failed: 0.`

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-k-struct-get-packed-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - removed fresh packed-field allocations and returned constants or extension/mask expressions matching the signedness of the packed read.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*packed struct.get*'` passed: `Total tests: 1, passed: 1, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.get*'` passed: `Total tests: 3, passed: 3, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 207, passed: 207, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2737, passed: 2737, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-k-packed-struct-get-new-1 && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-packed-struct-get-new-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is not this slice. Grepping final failure artifacts found no `struct.`, `array.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

This slice does not add:

- localizing rewrites for effectful constructor sibling fields;
- `struct.new_default` forwarding;
- plain `struct.get` changes beyond the prior pure-field subset;
- packed array `array.get_s` / `array.get_u` forwarding;
- descriptor/custom-descriptor constructor support;
- GC atomic/RMW/cmpxchg lowering.

The same effectful sibling boundary from `0823` remains: Starshine only removes the allocation when every non-selected constructor operand is pure.

## Remaining work

`[O4Z-AUDIT-OI-K]` remains active for further source-backed GC constructor/field/array/default rewrites beyond pure `struct.get` and packed `struct.get_s` / `struct.get_u` over matching `struct.new`. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later OI slices also remain open.
