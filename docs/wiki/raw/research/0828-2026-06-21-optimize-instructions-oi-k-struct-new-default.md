# 0828 - optimize-instructions OI-K struct.get(struct.new_default)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC default-constructor/accessor sub-slice: plain and packed `struct.get` over a fresh `struct.new_default`.

This slice covers only direct one-use matching `struct.new_default` producers whose selected field type has a WebAssembly default value. It deliberately does not cover `struct.new_default_desc`, descriptor-bearing struct forms, arrays, mutable field updates, atomics, or broader ordering/localization rewrites.

## Binaryen oracle

Probe files:

- `.tmp/oi-k-struct-new-default-probe.wat`
- `.tmp/oi-k-struct-new-default-packed-probe.wat`

Commands:

```sh
wasm-opt .tmp/oi-k-struct-new-default-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
wasm-opt .tmp/oi-k-struct-new-default-packed-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `struct.get` over default `i32`, `i64`, `f32`, and `f64` fields folded to zero constants.
- `struct.get` over a nullable externref field folded to `ref.null noextern`.
- Packed `struct.get_s` / `struct.get_u` over default `i8` and `i16` fields folded to `i32.const 0`.
- Binaryen's whole-module optimizer merged the four identical packed exported functions after OI had made them equivalent; this slice only relies on the OI-observable field-default fold.

## Starshine change

`src/passes/optimize_instructions.mbt` now extends the existing `struct.get(struct.new(...))` helper to also fold direct one-use `struct.new_default` producers.

The helper resolves the selected field through the HOT module context and materializes the field's WebAssembly default value:

- `i32` and packed fields become `i32.const 0`;
- `i64` becomes `i64.const 0`;
- `f32` and `f64` become zero float constants;
- `v128` can be represented as a zero vector if encountered; and
- nullable references become `ref.null` of the field reference type.

Packed signedness is preserved through the existing packed-i32 replacement helper. For default packed fields, both signed and unsigned reads fold to `i32.const 0`.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.new_default*'
```

Before implementation this failed for both new tests because Starshine still printed the original default-constructor/accessor forms, for example:

```text
(struct.new_default (Type 0))(struct.get (Type 0) U32(0))(end)
(struct.new_default (Type 0))(struct.get_s (Type 0) U32(0))(end)
```

After implementation the same focused filter passed `2/2`.

Final validation:

- Binaryen oracle commands above folded plain numeric/reference defaults and packed signed/unsigned defaults to constants/nulls.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.new_default*'` passed `2/2` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.get*'` passed `5/5`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `212/212`.
- `moon fmt` passed.
- `moon test src/passes` passed `2742/2742`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-struct-new-default-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general default-constructor analysis; only direct one-use `struct.new_default` producers are folded.
- Descriptor-bearing `struct.new_default_desc` and official descriptor operands remain open until Starshine's HOT representation and validation/lowering surfaces can preserve the descriptor operand correctly.
- `array.new_default`, `array.new`, dynamic-index array reads, shared/atomic operations, mutable updates, and effect-localizing constructor/accessor rewrites remain open `[O4Z-AUDIT-OI-K]` work.
