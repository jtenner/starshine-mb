# 0830 - optimize-instructions OI-K array.len(array.new_default)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC default-array constructor/accessor sub-slice: `array.len` over a fresh `array.new_default` with a small non-negative constant length.

This slice covers only direct one-use `array.new_default` producers whose length operand is an `i32.const` in the O4z-observed non-trapping range. It deliberately does not cover dynamic lengths, negative `i32.const` lengths that represent huge unsigned allocations, huge non-negative constant lengths, repeated-value `array.new`, descriptor array forms, mutable updates, atomics, or effect-localizing rewrites.

## Binaryen oracle

Probe file: `.tmp/oi-k-array-new-default-len-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-default-len-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `array.len(array.new_default $a (i32.const 3))` folded to `i32.const 3` under the O4z-style `-O --optimize-instructions` oracle.
- The same dynamic-length shape using a parameter stayed as `array.len(array.new_default ...)`.
- Additional local probes found that Binaryen folds through `i32.const 44739241` but keeps `i32.const 44739242`, `i32.const 100000000`, and `i32.const 2147483647`, so Starshine uses that oracle-observed upper bound instead of treating every non-negative constant as non-trapping.
- A direct `--optimize-instructions`-only spot check kept the small constant and dynamic shapes, so this note treats the bounded constant-length fold as part of the O4z OI audit surface rather than broad direct-OI-only ownership.

Additional boundary probe file: `.tmp/oi-k-array-new-default-len-negative-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-default-len-negative-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed boundary behavior: Binaryen kept `array.len(array.new_default $a (i32.const -1))`, preserving the huge-allocation trap rather than replacing the expression with `i32.const -1`. A separate huge-positive probe likewise kept `i32.const 2147483647`.

## Starshine change

`src/passes/optimize_instructions.mbt` extends the existing `array.len(array.new_fixed(...))` helper to also recognize direct one-use `array.new_default` producers when the producer has exactly one child and that child is an `i32.const` in the Binaryen O4z-observed non-trapping range (`0..44739241`).

For that proven small constant allocation size, Starshine replaces `array.len(array.new_default(...))` with the length constant. Dynamic lengths, negative constants, and huge non-negative constants remain unchanged to preserve allocation-size trap behavior.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*new_default*'
```

Before implementation this failed for the new test because the optimized function still printed:

```text
(i32.const I32(3))(array.new_default (Type 0))array.len(end)
```

After implementation the same focused filter passed `1/1`.

Final validation:

- Binaryen O4z-style oracle command above folded the small non-negative constant length to `i32.const 3` and kept the dynamic-length shape.
- Binaryen negative-length and huge-positive boundary probes kept the original shapes to preserve allocation traps.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*new_default*'` passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.len*'` passed `2/2`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `214/214`.
- `moon fmt` passed.
- `moon test src/passes` passed `2744/2744`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-new-default-len-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping final failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not a general `array.new_default` analysis; only direct one-use producers with small non-negative constant length are folded.
- Dynamic lengths remain open because allocation can trap and the result cannot be replaced without preserving that trap.
- Negative `i32.const` lengths and huge non-negative lengths remain boundaries because they encode huge allocations and Binaryen keeps them under the O4z-style oracle.
- Repeated-value `array.new`, descriptor array forms, array writes/fill/copy, shared/atomic operations, and effect-localizing constructor/accessor rewrites remain open `[O4Z-AUDIT-OI-K]` work.
