# 0825 - optimize-instructions OI-K array.len(array.new_fixed)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC array constructor/accessor sub-slice: `array.len` over a fresh `array.new_fixed` whose element operands are side-effect-free.

This slice deliberately does not cover `array.new`, `array.new_default`, `array.get`, packed array loads, `array.set`, `array.fill`, `array.copy`, descriptor array forms, shared/atomic array operations, or effectful element operands.

## Binaryen oracle

Probe file: `.tmp/oi-k-array-len-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-len-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `array.len(array.new_fixed $a 2 (i32.const 7) (i32.const 8))` folded to `i32.const 2`.
- `array.len(array.new $a (i32.const 9) (local.get $n))` stayed as `array.len(array.new ...)`.
- `array.len(array.new_default $a (local.get $n))` stayed as `array.len(array.new_default ...)`.
- `array.len(array.new_fixed $a 2 (call $x) (i32.const 8))` stayed as `array.len(array.new_fixed ...)` in this optimization mode, so this slice keeps the same effectful-element spelling.

## Starshine change

`src/passes/optimize_instructions.mbt` now folds `ArrayLen(ArrayNewFixed(type, len, elements...))` to `i32.const len` when:

- the `array.len` has exactly one child;
- the child is live and the fresh array has exactly one use;
- the child is exactly `array.new_fixed`;
- the encoded fixed length equals the constructor child count; and
- every element operand is locally side-effect-free.

Effectful element operands remain unchanged, matching the local Binaryen probe and preserving element evaluation effects without needing localizing/HOT lowering.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*'
```

Before implementation this failed because the pure function still printed:

```text
(i32.const I32(7))(i32.const I32(8))(array.new_fixed (Type 0) U32(2))array.len(end)
```

After implementation, the same focused filter passed `1/1`.

Final validation:

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*'` passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `208/208`.
- `moon fmt` passed.
- `moon test src/passes` passed `2738/2738`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-len-new-fixed-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general array length analysis; only direct one-use `array.new_fixed` producers are folded.
- Dynamic-length `array.new` and `array.new_default` remain open because the probed Binaryen `optimize-instructions` output kept those shapes.
- Effectful element operands remain unchanged; if a future source-backed Binaryen shape localizes or drops element effects, Starshine needs a separate safe proof before matching it.
