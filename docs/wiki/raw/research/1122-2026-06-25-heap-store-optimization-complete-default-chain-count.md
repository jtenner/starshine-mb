# Heap Store Optimization Complete Default Chain Field Count Fast Path

## Question

Can the pure-default chain fast path reduce HSO-I allocation-heavy runtime by avoiding defaultable field-type materialization when every struct field is explicitly overwritten?

## Change

`src/passes/heap_store_optimization.mbt` now separates struct field-count caching from defaultable field-type caching:

- `HsoTypeCache` has a `struct_field_counts` cache.
- `hso_type_struct_field_count(...)` resolves only the struct field count.
- `hso_try_fold_pure_default_struct_set_chain(...)` first uses that count to scan the consecutive `struct.set` chain and detect whether all fields have replacements.
- When all fields are replaced, it builds `struct.new` directly from those values without materializing default field types.
- Partial chains still fall back to the existing defaultable field-type path and build defaults only for missing fields.

This is safe for the targeted fast path because it only applies to an existing `struct.new_default` with the same exact type and still requires consecutive same-local/same-type `struct.set` roots with childless `Const`/`RefNull` values. The general safety path remains unchanged for non-simple chains.

## Evidence

Post-change validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `417/417` passed.

```sh
moon build --target-dir target --target native --release src/cmd
```

Result: passed with the pre-existing unused-function warnings in `src/passes/pass_manager.mbt`.

```sh
moon fmt
```

Result: passed.

```sh
bun scripts/pass-fuzz-compare.ts \
  --count 1000 \
  --seed 0x5eed \
  --pass heap-store-optimization \
  --out-dir .tmp/pass-fuzz-heap-store-optimization-complete-default-count-1000 \
  --jobs auto \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --max-failures 2000 \
  --keep-going-after-command-failures
```

Result: `1000/1000` compared, `1000` normalized matches, `0` mismatches, `0` validation/property/generator/command failures, Binaryen cache `1000` hits / `0` misses.

Post-change allocation-heavy timing:

| Fixture | Samples | Median |
|---|---:|---:|
| 1000-function Starshine HSO | `3.937ms`, `3.844ms`, `3.861ms` | `3.861ms` |
| 2000-function Starshine HSO | `7.640ms`, `7.710ms`, `7.867ms` | `7.710ms` |

Using the `1120` refreshed Binaryen 2000-function median (`1.28922ms`), this remains about `5.98x` Binaryen and above the `<= 2.57844ms` target. HSO-I remains open.

## Interpretation

The field-count fast path gives a modest improvement over `1121` (`7.985ms` to `7.710ms` at 2000 functions) by avoiding default field-type work on complete overwrite chains. It does not resolve HSO-I. The next likely owners are still region-root copying/splicing overhead and per-function pass scaffolding rather than value/defaultability checks alone.
