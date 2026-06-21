# Optimize-instructions OI-K struct.get of struct.new

Date: 2026-06-20

## Summary

First `[O4Z-AUDIT-OI-K]` GC constructor/field/default sub-slice.

This implementation slice covers the narrow, locally representable `struct.get(struct.new(...))` field-forwarding family when all non-selected `struct.new` field operands are side-effect-free:

```wat
i32.const 7
i64.const 9
struct.new $s
struct.get $s 0
```

Binaryen `version_130` removes the fresh allocation and forwards the selected field value. Starshine now matches that pure-sibling subset through HOT `Heap` nodes while keeping effectful sibling fields unchanged until a safe localizing/lowering path can preserve their evaluation effects.

## Binaryen oracle

Pure probe file: `.tmp/oi-k-struct-get-new-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-k-struct-get-new-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- `struct.get $s 0` over `struct.new $s` with constant `i32` / `i64` fields became `i32.const 7`;
- `struct.get $s 1` over the same constructor became `i64.const 9`;
- the fresh `struct.new` allocations were removed.

Effectful sibling probe file: `.tmp/oi-k-struct-get-new-effects-probe.wat`

Command:

```sh
wasm-opt .tmp/oi-k-struct-get-new-effects-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -
```

Observed Binaryen `version_130` behavior:

- for `struct.get $s 0`, Binaryen localized the selected `call $a`, preserved `call $b` as a dropped effect, then returned the localized `$a` result;
- for `struct.get $s 1`, Binaryen dropped `call $a` for its effect and returned `call $b` directly.

That effectful sibling shape requires localizing already-evaluated field operands and explicitly preserving dropped sibling effects. Starshine keeps that shape unchanged for now.

## Starshine change

Added `optimize_instructions_try_fold_struct_get_struct_new(...)` in `src/passes/optimize_instructions.mbt` and wired it into the `HotOp::Heap` optimize-instructions dispatcher.

The helper is intentionally narrow:

- it only handles exact `StructGet(type, field)` over exact `StructNew(type)`;
- it requires the `struct.new` node to have exactly one live use;
- it requires the selected field index to be in range;
- it requires every non-selected field operand to be pure;
- it replaces the `struct.get` node with the selected field child and leaves broader dead-node cleanup to existing traversal/lowering behavior.

Added focused public-pipeline tests in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds pure struct.get of struct.new field values`
- `optimize-instructions intentionally keeps struct.get of struct.new with effectful sibling fields`

## Red-first evidence

Before implementation, the focused filter failed the positive test because Starshine still printed the original `struct.new` / `struct.get` chain. The effectful boundary test also initially pointed at the wrong function index because imported functions occupy indices `0` and `1`; after correcting the assertion to inspect exported function index `2`, it remained a valid fail-closed boundary check.

Command:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.get of struct.new*'
```

Initial result: failed before implementation with the positive fixture still containing `(struct.new (Type 0))(struct.get (Type 0) U32(0))`.

Final focused result: `Total tests: 2, passed: 2, failed: 0.`

## Evidence

- Binaryen oracle:
  - `wasm-opt .tmp/oi-k-struct-get-new-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - removed the pure `struct.get(struct.new)` allocations and returned the selected constants.
  - `wasm-opt .tmp/oi-k-struct-get-new-effects-probe.wat --enable-gc --enable-reference-types -S -O --optimize-instructions -o -`
  - preserved effectful field evaluation through locals/drops while removing the allocation.
- Focused coverage:
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*struct.get of struct.new*'` passed: `Total tests: 2, passed: 2, failed: 0.`
  - `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'` passed: `Total tests: 206, passed: 206, failed: 0.`
- Broader validation:
  - `moon fmt` passed.
  - `moon test src/passes` passed: `Total tests: 2736, passed: 2736, failed: 0.`
  - `moon build --target native --release src/cmd` passed with existing unused-function warnings.
  - `moon info` passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.
- Direct compare smoke:
  - First count-1 smoke attempt timed out after 180 seconds before writing `result.json`; only partial `cases.jsonl` and input artifacts existed in `.tmp/pass-fuzz-optimize-instructions-oi-k-struct-get-new-1`.
  - Rerun command:
    - `rm -rf .tmp/pass-fuzz-optimize-instructions-oi-k-struct-get-new-1-rerun && bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 1 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-k-struct-get-new-1-rerun --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`
  - Requested `1`, compared `1/1`.
  - Normalized matches: `0`.
  - Cleanup/compare-normalized matches: `0`.
  - Raw mismatches: `1`.
  - Validation failures: `0`.
  - Property failures: `0`.
  - Generator failures: `0`.
  - Command failures: `0`.
  - Cache: wasm-smith `0` hits / `0` misses; Binaryen `1` hit / `0` misses; Binaryen failures `0` hits / `0` misses.
  - Agent classification: the single raw mismatch is not this slice. Grepping final failure artifacts found no `struct.`, `array.`, `call_ref`, `memory.copy`, `memory.fill`, `store8`, `store16`, or `store32` occurrences.

## Boundaries

This slice does not add:

- localizing rewrites for effectful `struct.new` field operands;
- `struct.new_default` forwarding;
- `struct.get_s` / `struct.get_u` signedness-specific forwarding;
- `array.new`, `array.new_fixed`, `array.get`, `array.len`, or array default rewrites;
- descriptor/custom-descriptor constructor support;
- GC atomic/RMW/cmpxchg lowering.

The effectful sibling boundary is deliberate: Binaryen can preserve already-evaluated sibling fields with locals and drops, but Starshine should not drop or reorder those effects without a safe localizing HOT lowering.

## Remaining work

`[O4Z-AUDIT-OI-K]` remains active for further source-backed GC constructor/field/array/default rewrites beyond the pure `struct.get(struct.new)` subset. `[O4Z-AUDIT-OI-G]`, `[O4Z-AUDIT-OI-H]`, `[O4Z-AUDIT-OI-I]`, `[O4Z-AUDIT-OI-J]`, and later OI slices also remain open.
