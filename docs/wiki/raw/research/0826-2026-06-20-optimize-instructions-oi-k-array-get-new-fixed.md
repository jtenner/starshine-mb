# 0826 - optimize-instructions OI-K array.get(array.new_fixed)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC array constructor/accessor sub-slice: `array.get` over a fresh `array.new_fixed` with a constant index.

This slice deliberately covers only direct plain `array.get` over a one-use matching `array.new_fixed` when every non-selected element operand is side-effect-free. It does not cover packed `array.get_s` / `array.get_u`, dynamic indexes, `array.new`, `array.new_default`, `array.set`, `array.fill`, `array.copy`, descriptor array forms, shared/atomic array operations, or effectful sibling-element localization.

## Binaryen oracle

Probe file: `.tmp/oi-k-array-get-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-get-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `array.get(array.new_fixed $a 2 (i32.const 7) (i32.const 8), i32.const 0)` folded to `i32.const 7`.
- The same shape with index `1` folded to `i32.const 8`.
- The same shape with dynamic `local.get` index stayed as `array.get(array.new_fixed ...)`.
- The same shape with constant out-of-bounds index `2` folded to `unreachable`.
- With an imported call in a non-selected element, Binaryen preserved the effect as `drop(call $x)` before forwarding the selected constant. Starshine keeps that stack form unchanged in this slice until a safe localizing lowering exists.

## Starshine change

`src/passes/optimize_instructions.mbt` now folds `ArrayGet(type, ArrayNewFixed(type, len, elements...), const-index)` when:

- the `array.get` has exactly two children;
- the fresh array child is live and has exactly one use;
- the array constructor type matches the `array.get` type;
- the encoded fixed length equals the constructor child count;
- the index is an `i32.const`; and
- every non-selected element operand is locally side-effect-free.

For in-bounds indexes, Starshine replaces the `array.get` with the selected element. For constant out-of-bounds indexes, Starshine replaces the operation with `unreachable` after proving all element operands are side-effect-free. Effectful non-selected element operands remain unchanged because Binaryen's matching output requires effect-preserving localization that this HOT slice does not provide.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*'
```

Before implementation this failed because the pure indexed function still printed:

```text
(i32.const I32(7))(i32.const I32(8))(array.new_fixed (Type 0) U32(2))(i32.const I32(0))(array.get (Type 0))(end)
```

After implementation and formatting, the same focused filter passed `1/1`.

Final validation:

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*'` passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `209/209`.
- `moon fmt` passed.
- `moon test src/passes` passed `2739/2739`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-get-new-fixed-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general array value analysis; only direct one-use `array.new_fixed` producers with constant indexes are folded.
- Dynamic indexes remain open because the probed Binaryen output kept that shape.
- Packed array loads remain open so signedness and storage-type facts can be handled in a separate proof.
- Effectful non-selected elements remain unchanged until Starshine has a safe localizing/HOT lowering that can preserve element-evaluation effects before forwarding the selected value.
