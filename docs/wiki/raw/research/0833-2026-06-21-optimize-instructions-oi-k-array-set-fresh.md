# 0833 - optimize-instructions OI-K array.set fresh arrays

## Scope

Continue `[O4Z-AUDIT-OI-K]` with one narrow GC array-write sub-slice: remove `array.set` operations that target a fresh direct one-use array whose allocation and set value are side-effect-free and whose index is an `i32.const`.

This slice covers only:

- `array.set` over matching-type `array.new_fixed` when the encoded length equals the element child count and every constructor element is side-effect-free;
- `array.set` over matching-type `array.new_default` when the length is an `i32.const` in the O4z-observed non-trapping range (`0..44739241`);
- pure set values;
- constant indexes.

In-bounds writes are removed as `nop`; out-of-bounds writes fold to `unreachable`. Dynamic indexes, effectful set values, effectful constructor siblings, dynamic/negative/huge default lengths, `array.new` repeated-value writes, descriptor forms, `array.fill`/`array.copy`, shared/atomic array operations, and broader localizing rewrites remain open.

## Binaryen oracle

Primary probe file: `.tmp/oi-k-array-set-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-set-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior under the O4z-style oracle:

- `array.set(array.new_fixed $a 2 ..., i32.const 1, i32.const 9)` folded to `nop` for the pure in-bounds case.
- The same fixed array with out-of-bounds index `2` folded to `unreachable`.
- `array.set(array.new_default $a (i32.const 2), i32.const 1, i32.const 9)` folded to `nop`.
- An effectful set value was preserved as `drop(call $effect)` when in bounds.

Direct `--optimize-instructions`-only spot check kept the probed `array.set` shapes, so this note treats the removal as part of the O4z OI audit surface rather than a broad direct-OI-only ownership claim.

Effect boundary probe file: `.tmp/oi-k-array-set-oob-effect-probe.wat`.

Command:

```sh
wasm-opt .tmp/oi-k-array-set-oob-effect-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed boundary behavior: Binaryen localized both effectful set values and effectful constructor siblings before the out-of-bounds trap as `drop(call $effect); unreachable`. Starshine keeps those effectful shapes unchanged until a broader localizing proof is added.

## Starshine change

`src/passes/optimize_instructions.mbt` now recognizes the pure direct one-use `ArraySet` subset with fresh `ArrayNewFixed` and `ArrayNewDefault` producers. The helper proves:

- the `array.set` has exactly three operands;
- the fresh producer's type matches the set type;
- the fresh producer has one use;
- the index is an `i32.const`;
- the set value is side-effect-free;
- fixed-array constructor elements are side-effect-free, or default-array length is a small non-negative non-trapping constant.

When the constant index is in bounds, the set is replaced with `nop`. When it is out of bounds, the set is replaced with `unreachable`, preserving the array allocation trap boundary by refusing negative or huge `array.new_default` lengths.

## Tests and validation

Red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.set*fresh pure arrays*'
```

Before implementation this failed for the new positive because the optimized function still printed:

```text
(i32.const I32(1))(i32.const I32(2))(array.new_fixed (Type 0) U32(2))(i32.const I32(1))(i32.const I32(9))(array.set (Type 0))(end)
```

After implementation the same focused filter passed `1/1`.

Final validation for this slice:

- Binaryen O4z-style primary oracle command above removed pure in-bounds `array.set` operations, folded pure out-of-bounds fixed-array writes to `unreachable`, removed pure in-bounds default-array writes, and localized an effectful set value with `drop(call)`.
- Binaryen effect boundary probe preserved effectful values/siblings before the trap with `drop(call); unreachable`; Starshine keeps those localizing boundaries unchanged.
- Direct `--optimize-instructions`-only spot check kept the probed `array.set` shapes.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.set*fresh pure arrays*'` failed before implementation and passed `1/1` after implementation.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*array.set*'` passed `1/1`.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed `217/217`.
- `moon fmt` passed.
- `moon test src/passes` passed `2747/2747`.
- `moon build --target native --release src/cmd` passed with existing unused-function warnings.
- `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- `git diff --check && git diff --cached --check` passed.
- Direct compare smoke `bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-array-set-1 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `1/1`, with normalized matches `0`, compare-normalized matches `0`, raw mismatches `1`, validation/property/generator/command failures `0`, cache counters wasm-smith `0` hits / `0` misses, Binaryen `1` hit / `0` misses, Binaryen failures `0` hits / `0` misses. Agent classification: the single raw mismatch was unrelated to this slice; grepping failure artifacts found no `array.`, `struct.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

- This is not general `array.set` elimination. It requires a direct one-use fresh producer, matching set type, constant index, pure set value, and either pure fixed elements or a small constant default-array length.
- Dynamic indexes remain unchanged because Starshine cannot prove whether the operation traps.
- Effectful set values and effectful constructor siblings remain unchanged because Binaryen preserves those effects with explicit drops and Starshine does not yet have a general localizing lowering for this family.
- Dynamic, negative, and huge-positive `array.new_default` lengths remain unchanged to preserve allocation-trap behavior.
- `array.new` repeated-value writes, descriptor arrays, `array.fill`/`array.copy`, shared/atomic operations, and broader ordering rewrites remain open `[O4Z-AUDIT-OI-K]` work.
