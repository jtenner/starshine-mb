# 0831 - optimize-instructions OI-K array.len(array.new)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC repeated-value array constructor/accessor sub-slice: `array.len` over a fresh `array.new` with a constant repeated value and a small non-negative constant length.

This slice covers only direct one-use `array.new` producers with exactly two children, where the repeated value is an `i32.const` and the length is an `i32.const` in the O4z-observed non-trapping range. It deliberately does not cover nonconstant repeated values, effectful repeated values, dynamic lengths, negative `i32.const` lengths, huge non-negative constant lengths, descriptor array forms, mutable updates, atomics, or effect-localizing rewrites.

## Binaryen oracle

Primary probe file: `.tmp/oi-k-array-new-len-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-len-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior under the O4z-style oracle:

- `array.len(array.new $a (i32.const 7) (i32.const 3))` folded to `i32.const 3`.
- The dynamic-length shape stayed as `array.len(array.new ...)`.
- The effectful repeated-value shape using an imported call stayed as `array.len(array.new ...)`, preserving value evaluation.

Direct `--optimize-instructions`-only spot check kept the small constant shape, so this note treats the fold as part of the O4z OI audit surface rather than a broad direct-OI-only ownership claim.

Boundary probe file: `.tmp/oi-k-array-new-len-boundary-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-len-boundary-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed boundary behavior:

- Binaryen kept `array.len(array.new $a (local.get $x) (i32.const 3))`; Starshine therefore does not generalize this slice to all pure repeated values.
- Binaryen kept negative and huge-positive lengths such as `i32.const -1` and `i32.const 2147483647` to preserve allocation-trap behavior.

Threshold probe file: `.tmp/oi-k-array-new-len-threshold-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-len-threshold-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed threshold behavior: Binaryen folded `i32.const 44739241` to the length constant and kept `i32.const 44739242`, matching the earlier `array.new_default` O4z-observed allocation limit.

## Starshine change

`src/passes/optimize_instructions.mbt` extends the existing fresh-array length helper to also recognize direct one-use `ArrayNew` producers when:

- the producer has exactly two children;
- the repeated-value child is an `i32.const`;
- the length child is an `i32.const` in the Binaryen O4z-observed non-trapping range (`0..44739241`).

For that locally proven subset, Starshine replaces `array.len(array.new(...))` with the length constant. Nonconstant repeated values, effectful repeated values, dynamic lengths, negative constants, and huge non-negative constants remain unchanged.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*array.new*'
```

Before implementation this failed for the new positive because the optimized function still printed:

```text
(i32.const I32(7))(i32.const I32(3))(array.new (Type 0))array.len(end)
```

After implementation the same focused filter passed `3/3`.

Final validation for this slice:

- Binaryen O4z-style oracle command above folded the small constant repeated-value/length shape to `i32.const 3` and kept dynamic/effectful shapes.
- Binaryen boundary probes kept local repeated values, negative lengths, and huge-positive lengths.
- Binaryen threshold probe folded through `44739241` and kept `44739242`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*array.new*'` passed `3/3` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*'` passed `3/3`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `215/215`.
- `moon fmt` passed.
- `moon test src/passes` passed `2745/2745`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-new-len-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not general `array.new` analysis; only direct one-use producers with an `i32.const` repeated value and small non-negative constant length are folded.
- Nonconstant repeated values remain open because Binaryen kept even a pure `local.get` repeated-value shape in the local O4z-style probe.
- Effectful repeated values remain open because dropping the constructor would otherwise drop value evaluation.
- Dynamic lengths remain open because allocation can trap and the result cannot be replaced without preserving that trap.
- Negative `i32.const` lengths and huge non-negative lengths remain boundaries because they encode huge allocations and Binaryen keeps them under the O4z-style oracle.
- Descriptor array forms, array writes/fill/copy, shared/atomic operations, and effect-localizing constructor/accessor rewrites remain open `[O4Z-AUDIT-OI-K]` work.
