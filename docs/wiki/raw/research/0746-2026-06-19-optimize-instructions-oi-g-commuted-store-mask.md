# Optimize-instructions OI-G commuted narrow store mask slice

Date: 2026-06-19

## Question

Can Starshine complete the local narrow-store redundant-mask cleanup for the commuted `and` spelling where the constant mask is the left operand?

## Classification

This is the fifteenth `[O4Z-AUDIT-OI-G]` sub-slice. It widens the existing `optimizeStoredValue` narrow-store mask cleanup from right-hand constant masks to either operand order:

- `i32.store8` / `i32.store16` now drop `(i32.and value mask)` and `(i32.and mask value)` when the mask preserves all low bits written by the store.
- `i64.store8` / `i64.store16` / `i64.store32` now drop `(i64.and value mask)` and `(i64.and mask value)` under the same low-bit preservation rule.

For the `i32` cases this matches Binaryen `version_130` observable behavior. For the `i64` cases this remains the earlier documented Starshine-win generalization: Binaryen keeps the equivalent `i64.and` masks today, but removing a mask that preserves every written low bit is behavior-preserving for narrow stores.

This is not pointer-add offset folding, zero-size bulk-memory cleanup, or any `load-call-optimize-instructions-noop` relaxation. Those OI-G items remain open.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryAccess(...)` / `optimizeStoredValue(...)` load-store cleanup as `[O4Z-AUDIT-OI-G]` work.
- Prior slices [`0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md`](0741-2026-06-19-optimize-instructions-oi-g-narrow-store-mask.md) and [`0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md`](0742-2026-06-19-optimize-instructions-oi-g-i64-narrow-store-mask.md) implemented right-hand-mask cleanup and kept broader stored-value spellings open.
- A local Binaryen oracle probe with `.tmp/oi-g-store-mask-lhs.wat` showed `wasm-opt --optimize-instructions` removes the commuted `i32.const 255; local.get; i32.and; i32.store8` and `i32.const 65535; local.get; i32.and; i32.store16` masks.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions drops commuted masks before narrow stores`.
  - The fixture covers commuted-mask `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, and `i64.store32` forms.
  - It asserts all redundant `i32.and` / `i64.and` operations disappear and that store operands become the original address/value order.

Changed `src/passes/optimize_instructions.mbt`:

- Updated `optimize_instructions_try_drop_narrow_store_value_mask(...)` to recognize the constant mask on either child of the `and`.
- The helper now rewrites the store value to the nonconstant child after proving the mask preserves the store-observed low bits.
- Existing value-changing mask boundaries remain protected by the previous negative tests.

## Red-first evidence

Before implementation, the new focused filter failed exactly the new positive test:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*commuted masks*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1528 ("optimize-instructions drops commuted masks before narrow stores") failed: ... body_raw: ... i32.and ... i32.store8 ... i32.and ... i32.store16 ... i64.and ... i64.store8 ... i64.and ... i64.store16 ... i64.and ... i64.store32 ...
Total tests: 1, passed: 0, failed: 1.
```

## Focused evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*commuted masks*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 1, passed: 1, failed: 0.
Total tests: 5, passed: 5, failed: 0.
Total tests: 21, passed: 21, failed: 0.
Total tests: 127, passed: 127, failed: 0.
```

## Broader validation

```sh
moon fmt
moon test src/passes
moon build --target native --release src/cmd
moon info
```

Results:

- `moon fmt`: passed.
- `moon test src/passes`: passed, `Total tests: 2639, passed: 2639, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-commuted-store-mask-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Requested: 10000
Compared: 51/10000
Normalized matches: 25
Cleanup-normalized matches: 0
Raw mismatches: 26
Validation failures: 0
Property failures: 0
Generator failures: 0
Command failures: 1
Jobs: 16
Cache: wasm-smith 26 hits/0 misses; Binaryen 51 hits/0 misses; Binaryen failures 1 hits/0 misses
```

Command failure classification: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).

Agent mismatch classification: the `26` raw mismatches are known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI slices, not new narrow-store semantic failures. A grep of failure artifacts found no `store8`, `store16`, `store32`, `i32.store8`, `i32.store16`, `i64.store8`, `i64.store16`, or `i64.store32` occurrences.

## Remaining OI-G work

`[O4Z-AUDIT-OI-G]` remains active after this sub-slice for:

- broader load/store canonicalization, especially nonconstant pointer-offset forms if source-backed safety proof and ownership are established;
- any other `optimizeStoredValue` shapes with clear proof;
- any further useful effect/trap negatives around memory lowering;
- any broader source-backed decision on whether a class of shapes should escape `load-call-optimize-instructions-noop`;
- zero-size bulk-memory cleanup only if local ignore-traps/TNH/IIT-equivalent support is added.
