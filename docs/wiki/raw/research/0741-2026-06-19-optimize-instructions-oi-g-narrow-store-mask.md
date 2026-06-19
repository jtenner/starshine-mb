# Optimize-instructions OI-G narrow store mask slice

## Question

Can Starshine cover a source-backed, OI-owned load/store canonicalization case without conflating it with `optimize-added-constants`?

## Classification

This is the tenth `[O4Z-AUDIT-OI-G]` sub-slice. It covers the upstream `optimizeMemoryAccess(...)` / `optimizeStoredValue(...)` narrow-store value cleanup family for a deliberately small, safe subset: remove an `i32.and` mask before `i32.store8` or `i32.store16` when the mask preserves all bits that the narrow store can observe.

This is not pointer-offset folding, zero-size bulk-memory cleanup, or any `load-call-optimize-instructions-noop` relaxation. It leaves those OI-G items open.

Source anchors:

- Binaryen `version_130` source-refresh matrix records `optimizeMemoryAccess(...)` / load/store offset and stored-value cleanup as `[O4Z-AUDIT-OI-G]` work.
- Binaryen `OptimizeInstructions.cpp` `optimizeStoredValue(...)` handles narrow-store stored-value canonicalization: if a store writes fewer bytes than its value type, an `and` whose `maxBits` fit within the written bytes can be stripped before the store.
- The focused local proof uses Binaryen-observable text fixtures: `wasm-opt --optimize-instructions` removes `(i32.and value 255)` before `i32.store8` and `(i32.and value 65535)` before `i32.store16`, but keeps value-changing masks such as `127` and `32767`.

## Test and implementation changes

Changed `src/passes/optimize_instructions_test.mbt`:

- Added `optimize-instructions drops masked low bits before narrow stores`.
  - The fixture stores `(value & 255)` with `i32.store8` and `(value & 65535)` with `i32.store16`.
  - It asserts both redundant `i32.and` operations disappear and that the store operands remain the original address/value order.
- Added `optimize-instructions keeps value-changing masks before narrow stores`.
  - The fixture keeps `(value & 127)` before `i32.store8` and `(value & 32767)` before `i32.store16`.
  - This is an intentional fail-closed boundary: those masks change bits that the corresponding store can observe.

Changed `src/passes/optimize_instructions.mbt`:

- Added `optimize_instructions_store_value_bits(...)` for the current i32 narrow-store subset.
- Added `optimize_instructions_try_drop_narrow_store_value_mask(...)` and wired it into the `HotOp::Store` visitor.
- The rewrite only fires for direct `i32.and` stored values whose constant mask has every stored low bit set:
  - `i32.store8`: `(mask & 0xff) == 0xff`
  - `i32.store16`: `(mask & 0xffff) == 0xffff`
- The rewrite preserves the original store instruction and address child, and only replaces the stored value child with the unmasked value.

## Red-first evidence

Before the implementation, the new focused filter failed exactly the positive test while the intentional boundary test passed:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'
```

Result excerpt:

```text
[jtenner/starshine] test passes/optimize_instructions_test.mbt:1384 ("optimize-instructions drops masked low bits before narrow stores") failed: ... body_raw: ... i32.and ... i32.store8 ... i32.and ... i32.store16 ...
Total tests: 2, passed: 1, failed: 1.
```

## Focused evidence

After implementation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*narrow stores*'
```

Result:

```text
Total tests: 2, passed: 2, failed: 0.
```

Broader focused pass filters:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory*'
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*optimize-instructions*'
```

Results:

```text
Total tests: 15, passed: 15, failed: 0.
Total tests: 118, passed: 118, failed: 0.
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
- `moon test src/passes`: passed, `Total tests: 2630, passed: 2630, failed: 0.`
- `moon build --target native --release src/cmd`: passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `moon info`: passed with existing warnings in `src/validate/gen_valid.mbt` and `src/validate/gen_valid_ssa.mbt`.

## Direct compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --count 10000 --seed 0x5eed --out-dir .tmp/pass-fuzz-optimize-instructions-oi-g-narrow-store-mask-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

Result:

```text
Requested: 10000
Compared: 52/10000
Normalized matches: 26
Cleanup-normalized matches: 0
Raw mismatches: 26
Validation failures: 0
Property failures: 0
Generator failures: 0
Command failures: 1
Jobs: 16
Cache: wasm-smith 27 hits/0 misses; Binaryen 52 hits/0 misses; Binaryen failures 1 hits/0 misses
```

`result.json` classifies the command failure as `binaryen-rec-group-zero`.

Agent classification:

- Command failure: known **tool/Binaryen failure** (`binaryen-rec-group-zero`).
- Raw mismatches: known **Starshine-win** constant-if and redundant-sign-extension output-shape families from earlier OI-E/OI-F work, not new narrow-store semantic failures.
- A grep of failure artifacts found no `store8` or `store16` occurrences, so the direct lane did not surface a narrow-store regression family.
- Sample canonical wasm sizes remain the familiar Starshine-smaller family:
  - `case-000002-gen-valid`: Binaryen `4161` bytes vs Starshine `4120`
  - `case-000004-gen-valid`: Binaryen `5539` bytes vs Starshine `5481`
  - `case-000006-gen-valid`: Binaryen `5559` bytes vs Starshine `5496`

## Remaining OI-G work

This sub-slice does not close `[O4Z-AUDIT-OI-G]`. Remaining OI-G work includes:

- broader load/store canonicalization, including pointer-offset forms and wider `i64.store8` / `i64.store16` / `i64.store32` stored-value cleanup if chosen;
- any further useful effect/trap negatives around memory/fill/copy/load/store shapes;
- a decision on whether any memory/load/call shapes should escape the current `load-call-optimize-instructions-noop` raw gate.

Zero-size `memory.copy` and `memory.fill` cleanup remains blocked unless Starshine grows explicit local ignore-traps / TNH / IIT-equivalent mode support or the user accepts a different trap-mode policy with focused tests.
