# Heap Store Optimization Result `try_table` Global-Set Fold

## Summary

Binaryen `version_130` folds a later same-field `struct.set` through a result-typed, non-throwing `try_table` whose body only writes an unrelated mutable global and returns a dropped value. Starshine initially found the same fold opportunity, but its block-wrapper lifting peeled the `drop(try_table(result ...))` root out of the enclosing block and left the `try_table` catch label pointing at a removed wrapper, causing HOT lowering to abort. This slice fixes that wrapper legality gap by preserving block wrappers around any nested `try_table` root during swapped-root lifting.

## Binaryen oracle

Probe file: `.tmp/hso-try-result-global2.wat`.

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-try-result-global2.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-try-result-global2.opt.wat
```

Result:

- Local oracle: `wasm-opt version 130 (version_130)`.
- Binaryen preserves the result `try_table`, the unrelated `global.set`, and the constructor's still-live `memory.size` field.
- Binaryen folds `i32.const 9` into field `0` of the later `struct.new` and removes the later `struct.set`.

Observed optimized shape:

```text
(block $h
  (drop
    (try_table (result i32) (catch_all $h)
      (global.set $g (i32.const 3))
      (i32.const 4))))
(local.set $r
  (struct.new $s
    (i32.const 9)
    (memory.size)))
```

## Starshine gap and fix

Focused red-first regression:

- `heap-store-optimization folds memory.size constructors across result try_table global stores`

Initial failure: `moon test` aborted in HOT lowering (`hot_lower_impl_label_depth`) after HSO lifted the `drop(try_table(result ...))` root out of its block wrapper. The local catch still targeted that wrapper, so the transformed HOT graph could not lower to valid wasm.

Implementation change:

- `src/passes/heap_store_optimization.mbt`
  - Adds `hso_subtree_contains_try_table(...)` / `hso_region_contains_try_table(...)`.
  - Changes `hso_liftable_swapped_block_roots(...)` to reject block-wrapper peeling when any candidate root contains a `try_table`, not only when the candidate root itself is a direct `TryTable` op.
  - This keeps result-typed `drop(try_table(...))` wrappers valid while still allowing the whole wrapper to move as one root when the underlying effects are safe.

## Classification

This is an HSO-G behavior-parity fix with HSO-F surface implications:

- HSO-G because the bug was a `trySwap(...)`/wrapper-peeling legality gap.
- HSO-F because preserving `try_table` catch-label structure is required for valid control-flow lowering.

This is not a Starshine win: Binaryen performs the fold and emits valid wrapped control; Starshine needed to match the behavior without invalidating the catch target.

## Validation

Focused red/green command after the fix:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt \
  -p 'result try_table global stores'
```

Result:

```text
Total tests: 352, passed: 352, failed: 0.
```

Additional validation:

```sh
moon fmt
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
moon test src/passes
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-result-try-table-10000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Results:

- `moon fmt` passed.
- Focused HSO tests passed `352/352`.
- `moon test src/passes` passed `2980/2980`.
- Native `src/cmd` build passed with pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.
- Direct 10000-case `heap-store-optimization` compare matched `10000/10000` with `10000` normalized matches, `0` mismatches, `0` validation/property/generator failures, and `0` command failures.

## Reopening criteria

Reopen if Starshine changes HOT lowering label-depth rules, adds a safe way to retarget `try_table` catches when peeling wrappers, or if new result-typed `try_table` roots show a narrower wrapper-peeling rule can preserve labels while still matching Binaryen behavior.
