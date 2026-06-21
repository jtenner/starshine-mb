# Heap-store-optimization `try_table` / `global.set` fold

Date: 2026-06-21

## Question

Can Starshine close the `0922` HSO-G parity gap where Binaryen folds a fresh-constructor `struct.set` through a non-throwing `try_table` wrapper whose body only performs an unrelated mutable `global.set`?

## Binaryen oracle

Local oracle: `wasm-opt version 130 (version_130)`.

Probe fixture: a fresh `$pair` is stored in local `$x`; the constructor field uses `memory.size`; an intervening `block` contains `try_table (catch_all $done)` with a body that only executes `global.set $g`; a later `struct.set $pair 1` updates the fresh object.

Command:

```sh
wasm-opt --all-features --heap-store-optimization \
  .tmp/hso-probe-try-table-memory-size-global-set.wat \
  -S -o .tmp/hso-probe-try-table-memory-size-global-set.opt.wat
```

Observed shape: Binaryen preserves the `try_table` / `global.set` wrapper, moves the constructor `local.set` after the wrapper, folds the later field value into `struct.new`, and removes the later `struct.set`.

## Starshine change

Added failing-first focused coverage for both `memory.size` and `table.size` constructor operands crossing a block-wrapped, non-throwing `try_table` / `global.set` root. The first focused run failed with `hot_lower_impl_label_depth` after Starshine lifted the `try_table` root out of its block wrapper, invalidating the catch target.

The fix keeps `hso_liftable_swapped_block_roots(...)` from peeling a direct `try_table` root out of its containing block. The later fallback then treats the whole block wrapper as the swap root. This preserves catch-label validity while still allowing the non-throwing global-set wrapper to move before the constructor assignment.

Focused validation after the fix:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'try_table global stores'
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'try_table'
```

Both focused runs passed after the implementation change. Broader slice validation also passed:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt -p 'try_table'
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-try-table-global-set-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe
```

The direct compare requested `10000/10000` cases and compared `10000`; all `10000` were normalized matches, with `0` mismatches, `0` validation/property/generator failures, and `0` command failures. The native build passed with pre-existing `pass_manager.mbt` unused-function warnings.

## Classification

`0922` is fixed for the covered non-throwing block-wrapped `try_table` / unrelated mutable `global.set` shapes with `memory.size` and `table.size` constructor operands.

This does not generalize the prior `0910`-`0913` no-fold boundaries: ordinary memory/table stores, same-effect bulk roots, and cross-family growth roots inside `try_table` remain barriers. It also does not close arbitrary throwing `try_table` bodies or all catch/branch-bearing wrappers.

## Reopening criteria

Reopen if a future Binaryen source/oracle refresh shows additional non-throwing `try_table` body families that should fold, if Starshine again peels a `try_table` out of the block that owns its catch target, or if direct compare/artifact evidence exposes a catch-label validation failure or semantic mismatch in this family.
