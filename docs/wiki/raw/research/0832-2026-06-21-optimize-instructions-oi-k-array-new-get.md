# 0832 - optimize-instructions OI-K array.get(array.new)

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC repeated-value array constructor/accessor sub-slice: constant-index `array.get`, `array.get_s`, and `array.get_u` over a fresh direct one-use `array.new` with a small non-negative constant length.

This slice covers direct one-use `array.new` producers with exactly two children, a matching accessor type, and an `i32.const` length in the O4z-observed non-trapping range (`0..44739241`). For in-bounds constant indexes, the repeated value is forwarded to the accessor result, preserving value evaluation, including effectful calls. Packed reads preserve signedness with the same constant/sign-extension/mask helper used by the `array.new_fixed` and `array.new_default` slices. Constant out-of-bounds indexes fold to `unreachable` only when the repeated value is side-effect-free; effectful out-of-bounds repeated values remain a localizing boundary.

Dynamic indexes, dynamic lengths, negative lengths, huge non-negative lengths, descriptor array forms, mutable updates, atomics, and effect-localizing out-of-bounds rewrites remain open.

## Binaryen oracle

Primary probe file: `.tmp/oi-k-array-new-get-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-get-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior under the O4z-style oracle:

- `array.get(array.new $a (i32.const 7) (i32.const 3), i32.const 1)` folded to `i32.const 7`.
- Constant out-of-bounds index `3` for length `3` folded to `unreachable`.
- Dynamic-index reads stayed as `array.get(array.new ...)`.
- Repeated-value reads with `local.get` or an imported call folded to the repeated value, preserving the selected value evaluation.
- Negative and huge-positive lengths such as `i32.const -1` and `i32.const 2147483647` stayed unchanged to preserve allocation-trap behavior.

Direct `--optimize-instructions`-only spot check kept these repeated-value `array.get(array.new ...)` forms, so this note treats the fold as part of the O4z OI audit surface rather than a broad direct-OI-only ownership claim.

Out-of-bounds effect probe file: `.tmp/oi-k-array-new-get-oob-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-new-get-oob-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed boundary behavior:

- Pure/local repeated-value out-of-bounds reads folded to `unreachable`.
- Effectful repeated-value out-of-bounds reads lowered to `drop(call $effect); unreachable`. Starshine keeps that shape unchanged until safe localizing lowering can preserve the call before the trap.

Packed probe file: `.tmp/oi-k-packed-array-new-get-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-packed-array-new-get-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed packed behavior: Binaryen folded `array.get_s` of repeated `i8.const 255` to `i32.const -1`, folded `array.get_u` of the same repeated value to `i32.const 255`, rewrote local repeated-value `array.get_s` over `i16` to `i32.extend16_s(local.get)`, and rewrote local repeated-value `array.get_u` over `i16` to `i32.and(local.get, 65535)`.

## Starshine change

`src/passes/optimize_instructions.mbt` extends the fresh-array `array.get` folding helper to recognize `ArrayNew` alongside the existing `ArrayNewFixed` and `ArrayNewDefault` cases. The helper now classifies the fresh producer kind, proves the constant length, and then:

- forwards the selected fixed element for `array.new_fixed` as before;
- forwards the default element for `array.new_default` as before;
- forwards the repeated-value child for `array.new` when the constant index is in bounds;
- applies packed signed/unsigned interpretation through `optimize_instructions_replace_with_packed_i32_value(...)` for packed array reads;
- folds out-of-bounds reads to `unreachable` only when the repeated value or all fixed elements that would be dropped are side-effect-free.

The `array.new` path uses `optimize_instructions_array_new_len_is_known_non_trapping(...)`, so negative and huge-positive allocation-trap lengths remain unchanged.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*array.new repeated*'
```

Before implementation this failed for the new positive because the optimized function still printed:

```text
(i32.const I32(7))(i32.const I32(3))(array.new (Type 0))(i32.const I32(1))(array.get (Type 0))(end)
```

After implementation the same focused filter passed `1/1`.

Final validation for this slice:

- Binaryen O4z-style primary oracle command above folded constant, local, and effectful in-bounds repeated-value reads, folded pure out-of-bounds reads, kept dynamic indexes, and kept negative/huge lengths.
- Binaryen out-of-bounds effect probe preserved the effectful repeated value with `drop(call $effect); unreachable`; Starshine keeps that boundary unchanged.
- Binaryen packed probe produced the expected constants, sign-extension, and mask forms for packed repeated-value reads.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*array.new repeated*'` failed before implementation and passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.get*'` passed `4/4`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `216/216`.
- `moon fmt` passed.
- `moon test src/passes` passed `2746/2746`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-new-get-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not general `array.new` analysis; it requires a direct one-use producer, matching accessor type, constant index, and small non-negative constant length.
- Dynamic indexes remain unchanged because no selected value or out-of-bounds trap can be proven locally.
- Dynamic, negative, and huge-positive lengths remain unchanged because removing the allocation could remove a trap.
- Effectful repeated-value in-bounds reads are safe because the repeated value itself is the replacement and its evaluation is preserved.
- Effectful repeated-value out-of-bounds reads remain open because Binaryen preserves the effect with an explicit drop before `unreachable`, and Starshine needs safe localizing lowering before it can remove the allocation in that shape.
- Descriptor array forms, array writes/fill/copy, shared/atomic operations, and broader localizing rewrites remain open `[O4Z-AUDIT-OI-K]` work.
