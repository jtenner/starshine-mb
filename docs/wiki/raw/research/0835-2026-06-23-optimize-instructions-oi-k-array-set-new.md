# 0835 - optimize-instructions OI-K array.set fresh array.new repeated-value arrays

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC array-write sub-slice: extend the fresh-array `array.set` removal from `0833` to the `array.new` repeated-value producer.

This slice covers only:

- `array.set` over a matching-type `array.new(value, len)` producer when the producer has one use, the repeated-value operand is side-effect-free, the set value is side-effect-free, the index is an `i32.const`, and the length is an `i32.const` in the O4z-observed non-trapping range (`0..44739241`).

In-bounds writes are removed as `nop`; out-of-bounds writes fold to `unreachable`. Dynamic indexes, effectful set values, effectful repeated-value operands, dynamic/negative/huge lengths, descriptor forms, `array.fill`/`array.copy`, shared/atomic array operations, and broader localizing rewrites remain open.

This mirrors the already-covered `array.new_fixed` and `array.new_default` arms of `optimize_instructions_try_remove_array_set_fresh_array` and the `array.new` arms already present in the sibling `array.len` and `array.get` helpers.

## Binaryen oracle

Primary probe file: `.tmp/oi-k-array-set-new-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-set-new-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior under the O4z-style oracle:

- `array.set(array.new $a (i32.const 7) (i32.const 2), i32.const 1, i32.const 9)` folded to `nop` for the pure in-bounds case.
- The same producer with out-of-bounds index `2` folded to `unreachable`.
- `array.set(array.new $a (call $effect) (i32.const 2), i32.const 1, i32.const 9)` localized the effectful repeated value as `drop(call $effect)`.
- `array.set(array.new $a (i32.const 7) (i32.const 2), i32.const 1, call $effect)` localized the effectful set value as `drop(call $effect)`.

Direct `--optimize-instructions`-only spot check kept all probed `array.set` shapes, so this note treats the removal as part of the O4z OI audit surface (consistent with `0833`) rather than a broad direct-OI-only ownership claim.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes the pure direct one-use `ArraySet` subset with a fresh `ArrayNew` repeated-value producer, alongside the existing `ArrayNewFixed` and `ArrayNewDefault` arms. For the `ArrayNew` arm the helper proves:

- the `array.set` has exactly three operands;
- the fresh producer's type matches the set type;
- the fresh producer has one use;
- the index is an `i32.const`;
- the set value is side-effect-free;
- the repeated-value operand (child 0) is side-effect-free;
- the length (child 1) is an `i32.const` in the O4z-observed non-trapping range.

When the constant index is in bounds, the set is replaced with `nop`. When it is out of bounds, the set is replaced with `unreachable`, preserving the allocation-trap boundary by refusing negative or huge `array.new` lengths.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.new repeated-value arrays*'
```

Before implementation this failed for the positive in-bounds case because the optimized function still printed:

```text
(i32.const I32(7))(i32.const I32(2))(array.new (Type 0))(i32.const I32(1))(i32.const I32(9))(array.set (Type 0))(end)
```

After implementation the same focused filter passed `1/1`. The test also locks boundaries: effectful set values, effectful repeated-value operands, dynamic lengths, and huge constant lengths are all kept unchanged.

Final validation for this slice:

- Binaryen O4z-style primary oracle command above removed the pure in-bounds `array.set` over `array.new`, folded the pure out-of-bounds write to `unreachable`, and localized effectful repeated-value and set-value operands with `drop(call)`.
- Direct `--optimize-instructions`-only spot check kept the probed `array.set` shapes.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.new repeated-value arrays*'` failed before implementation and passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `220/220`.
- `moon fmt` passed.
- `moon test src/passes` passed `2750/2750`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-set-new-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `0` hits / `1` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was the known scalar `i32.const` / `i64.const` drop-sequence output-shape family and was unrelated to this slice; grepping failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not general `array.set` elimination. It requires a direct one-use fresh `array.new` producer, matching set type, constant index, pure set value, pure repeated-value operand, and a small constant non-trapping length.
- Dynamic indexes remain unchanged because Starshine cannot prove whether the operation traps.
- Effectful set values and effectful repeated-value operands remain unchanged because Binaryen preserves those effects with explicit drops and Starshine does not yet have a general localizing lowering for this family.
- Dynamic, negative, and huge-positive `array.new` lengths remain unchanged to preserve allocation-trap behavior, matching the established `optimize_instructions_array_new_len_is_known_non_trapping` guard.
- Descriptor arrays, `array.fill`/`array.copy`, shared/atomic operations, and broader ordering rewrites remain open `[O4Z-AUDIT-OI-K]` work.
