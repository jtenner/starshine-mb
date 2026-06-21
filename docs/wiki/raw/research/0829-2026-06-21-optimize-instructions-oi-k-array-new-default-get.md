# 0829 - optimize-instructions OI-K array.get(array.new_default)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC default-array constructor/accessor sub-slice: plain and packed `array.get` over a fresh `array.new_default` with a constant length and constant index.

This slice covers only direct one-use matching `array.new_default` producers where the length operand and access index are both `i32.const`. It deliberately does not cover dynamic lengths, dynamic indexes, `array.len(array.new_default(...))`, repeated-value `array.new`, descriptor array forms, mutable updates, atomics, or effect-localizing rewrites.

## Binaryen oracle

Probe file: `.tmp/oi-k-array-new-default-get-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-default-get-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `array.get(array.new_default $a (i32.const 3), i32.const 1)` folded to `i32.const 0` for an `i32` element array.
- The same shape with constant out-of-bounds index `3` folded to `unreachable`.
- Packed `array.get_s` / `array.get_u` over default `i8` elements folded to `i32.const 0`.
- A direct `--optimize-instructions`-only spot check kept these shapes, while the O4z-style `-O --optimize-instructions` oracle folded them. This note treats the fold as part of the O4z OI audit surface and keeps the local implementation narrower than a general array-default analysis.

## Starshine change

`src/passes/optimize_instructions.mbt` extends the existing constant-index `array.get(array.new_fixed(...))` helper to also recognize matching one-use `array.new_default` producers when the length is an `i32.const`.

For in-bounds constant indexes, the helper materializes the array element WebAssembly default value through the HOT module context:

- unpacked `i32` elements become `i32.const 0`;
- packed `i8` / `i16` signed and unsigned reads become `i32.const 0` through the existing packed-i32 replacement helper; and
- other defaultable storage kinds reuse the existing default-storage materialization path when representable.

For constant out-of-bounds indexes, the helper replaces the accessor with `unreachable`. Dynamic-length arrays stay unchanged because this slice cannot prove the index relation.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.new_default*'
```

Before implementation this failed for the new test because the optimized function still printed the original default-array accessor form, for example:

```text
(i32.const I32(3))(array.new_default (Type 0))(i32.const I32(1))(array.get (Type 0))(end)
```

After implementation the same focused filter passed `1/1`.

Final validation:

- Binaryen oracle command above folded constant-length/default plain and packed reads and out-of-bounds indexes as described.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.new_default*'` passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*'` passed `3/3`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `213/213`.
- `moon fmt` passed.
- `moon test src/passes` passed `2743/2743`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-new-default-get-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general `array.new_default` analysis; only direct one-use producers with constant length and constant index are folded.
- Dynamic lengths and dynamic indexes remain open because Starshine cannot locally prove whether the access is in-bounds.
- `array.len(array.new_default(...))` remains a separate boundary from the earlier `0825` probe: direct OI-only Binaryen kept the dynamic-length shape, and this slice does not generalize length analysis.
- Repeated-value `array.new`, descriptor array forms, array writes/fill/copy, shared/atomic operations, and effect-localizing constructor/accessor rewrites remain open `[O4Z-AUDIT-OI-K]` work.
