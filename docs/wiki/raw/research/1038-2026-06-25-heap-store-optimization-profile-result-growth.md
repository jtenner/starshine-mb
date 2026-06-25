# Heap Store Optimization Profile Result Growth Coverage

Date: 2026-06-25

## Summary

Extended the dedicated `heap-store-optimization` GenValid profile with deterministic result-typed cross-family growth roots:

- `memory.size`-seeded `struct.new` followed by a result-typed `try_table` whose body performs `table.grow`, drops the wrapper result, and then reaches a later same-local `struct.set`.
- `table.size`-seeded `struct.new` followed by a result-typed `try_table` whose body performs `memory.grow`, drops the wrapper result, and then reaches a later same-local `struct.set`.

These roots make the generated profile cover the source-backed HSO-G cross-family growth positives from the focused `0989` family rather than relying only on hand-written coverage.

## TDD

Strengthened `src/fuzz/main_wbtest.mbt` first so the HSO profile artifact requires at least five `try_table I32 []` roots, at least seven total `try_table I32` roots, and a `table.grow` root. Before the generator update, the focused fuzz test failed with only three non-catch result `try_table I32 []` roots and no `table.grow` in the profile artifact.

## Implementation

Updated `src/validate/gen_valid.mbt` inside `gen_valid_append_heap_store_optimization_body_slice` to append the two result-typed growth-wrapper roots when the profile has memory and funcref table support.

## Validation

- `moon test --package jtenner/starshine/fuzz --file main_wbtest.mbt` failed before implementation on the strengthened artifact floor, then passed after implementation: `92/92`.
- `moon fmt` passed.
- `moon build --target-dir target --target native --release src/cmd` passed and refreshed `target/native/release/build/cmd/cmd.exe`; existing `src/passes/pass_manager.mbt` unused-function warnings remain.
- `bun scripts/pass-fuzz-compare.ts --count 20 --seed 0x5eed --pass heap-store-optimization --gen-valid-profile heap-store-optimization --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-heap-store-optimization-profile-result-growth-20 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 20 --keep-going-after-command-failures` compared `20/20`, with `0` normalized matches, `20` compare-normalized matches, and `0` validation, property, generator, command, or mismatch failures. Binaryen cache: `0` hits / `20` misses.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-result-growth-direct-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` compared `1000/1000`, with `1000` normalized matches and `0` failures/mismatches. Binaryen cache: `1000` hits / `0` misses.

## Remaining Work

Generated profile coverage still lacks table-side same-resource result `table.fill`, broader catchable generated call/ref-call wrappers, mutable descriptor result-wrapper old-field variants, generated call-valued result-wrapper old-field variants, descriptor branch-result / `br_on_non_null` surfaces, and broader descriptor/control variants. HSO-B/D/E/F/G/H/I/J remain open until final closeout evidence proves the full behavior matrix or records narrow approved deferrals.
