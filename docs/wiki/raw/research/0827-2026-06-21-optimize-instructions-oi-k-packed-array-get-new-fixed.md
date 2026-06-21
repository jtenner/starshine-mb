# 0827 - optimize-instructions OI-K packed array.get_s/array.get_u(array.new_fixed)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC packed-array constructor/accessor sub-slice: `array.get_s` / `array.get_u` over a fresh packed `array.new_fixed` with a constant index.

This slice covers only direct one-use matching `array.new_fixed` producers when the index is constant and every non-selected element operand is side-effect-free. It deliberately does not cover dynamic indexes, effectful sibling-element localization, `array.new`, `array.new_default`, descriptor array forms, shared/atomic array operations, or generalized array value analysis.

## Binaryen oracle

Probe file: `.tmp/oi-k-packed-array-get-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-packed-array-get-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `array.get_s` over an `i8` `array.new_fixed` selected from `i32.const 255` folded to `i32.const -1`.
- `array.get_u` over an `i8` `array.new_fixed` selected from `i32.const 255` folded to `i32.const 255`.
- `array.get_s` over an `i16` `array.new_fixed` selected from `i32.const 32768` folded to `i32.const -32768`.
- `array.get_u` over an `i16` `array.new_fixed` selected from `i32.const 32768` folded to `i32.const 32768`.
- Nonconstant selected values were rewritten to `i32.extend8_s` for signed `i8` and `i32.and 65535` for unsigned `i16`.
- Dynamic indexes stayed as `array.get_s(array.new_fixed ...)`.
- Constant out-of-bounds index `2` folded to `unreachable`.
- With an imported call in a non-selected element, Binaryen preserved the effect as `drop(call $x)` before forwarding the selected constant. Starshine keeps that stack form unchanged in this slice until a safe localizing lowering exists.

## Starshine change

`src/passes/optimize_instructions.mbt` now extends the direct one-use `ArrayGet(ArrayNewFixed(...))` helper to also accept `ArrayGetS` and `ArrayGetU` when the accessor type resolves to a packed `i8` or `i16` array field through the HOT module context.

For in-bounds constant indexes:

- signed constant selected values are truncated and sign-extended at compile time;
- unsigned constant selected values are truncated at compile time;
- signed nonconstant selected values become `i32.extend8s` or `i32.extend16s`; and
- unsigned nonconstant selected values become `i32.and 255` or `i32.and 65535`.

Constant out-of-bounds indexes still become `unreachable` after proving all elements and the constant index are side-effect-free. Effectful non-selected elements remain unchanged because Binaryen's matching output requires effect-preserving localization that this HOT slice does not provide.

The existing packed struct-field helper was factored into a storage-type helper plus a reusable packed-i32 replacement helper so packed struct forwarding and packed array forwarding share the same signedness-preserving constants/extensions/masks.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*packed array.get*'
```

Before implementation this failed because the first packed-array positive still printed:

```text
(i32.const I32(255))(i32.const I32(128))(array.new_fixed (Type 0) U32(2))(i32.const I32(0))(array.get_s (Type 0))(end)
```

After implementation and formatting, the same focused filter passed `1/1`.

Final validation:

- Binaryen oracle command above produced the packed constants/extensions/masks, kept dynamic indexes, folded out-of-bounds to `unreachable`, and localized the effectful sibling with `drop`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*packed array.get*'` passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*'` passed `2/2`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `210/210`.
- `moon fmt` passed.
- `moon test src/passes` passed `2740/2740`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-packed-array-get-new-fixed-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general packed-array analysis; only direct one-use `array.new_fixed` producers with constant indexes are folded.
- Dynamic indexes remain open because the probed Binaryen output kept that shape.
- Effectful non-selected elements remain unchanged until Starshine has a safe localizing/HOT lowering that can preserve element-evaluation effects before forwarding the selected value.
- Repeated-value constructors, default constructors, mutable array updates, descriptor forms, shared/atomic forms, and broader ordering relaxations remain open `[O4Z-AUDIT-OI-K]` work.
