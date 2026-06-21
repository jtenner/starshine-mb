# Heap store optimization table-store old-field boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when the overwritten old constructor field is a value-producing block that performs `table.set`, and an unrelated mutable `global.set` root appears before the later `struct.set`?

This probes the table-side counterpart to the `0900` memory-store old-field boundary, after the related `0897`/`0898` growth old-field positives and `0899` unrelated-global-write old-field positive.

## Probe

Temporary probe file: `.tmp/hso-probe-table-store-old-field.wat`.

Shape:

- `struct.new $s` initializes field `0` from a `(block (result funcref) (table.set 0 ...) (ref.null func))` old-field expression.
- The fresh struct is assigned to local `$sref`.
- A root `(global.set $g (i32.const 9))` follows.
- A later `(struct.set $s 0 (local.get $sref) (ref.null func))` overwrites field `0`.
- The function returns `(local.get $sref)`.

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-table-store-old-field.wat --heap-store-optimization -S -o .tmp/hso-probe-table-store-old-field.opt.wat
```

Observed Binaryen `version_130` output:

- Preserved the original `struct.new` old-field `block` with `table.set`.
- Preserved the intervening `global.set`.
- Preserved the later `struct.set`.

## Classification

Binaryen behavior-parity boundary: HSO does **not** fold this table-store old-field shape, even though the table store itself occurs before the unrelated global write in the original order.

This is not a Starshine-win claim. It is an oracle-backed negative boundary for the old-field side-effect matrix. Starshine already matched the boundary: the focused test added in this slice passed on the first run.

## Starshine coverage

Added focused test:

- `heap-store-optimization keeps table-store old fields before unrelated global.set`

The test asserts that Starshine preserves:

- `table.set`
- `global.set`
- `struct.set`

Command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `259/259` passed.

No implementation change was needed, so no native rebuild or direct 10000-case compare was required for this coverage-only slice.

## Durable conclusion

Old-field side-effect preservation remains resource-specific. Binaryen folds side-effectful `memory.grow`, `table.grow`, and unrelated mutable-global-write old fields when the exact resource/global ordering proof allows it, but preserves the later `struct.set` for both memory-store (`0900`) and table-store old fields in the probed unrelated-global-set shapes.

Keep HSO-D/G open for additional old-field side-effect/resource families until either implemented, covered as Binaryen-matching boundaries, or documented as narrow Starshine wins/non-goals with reopening criteria.

## Reopening criteria

Reopen this boundary if:

- Binaryen moves table-store old-field folding into HSO,
- Starshine begins folding this shape and needs a measured Starshine-win argument, or
- a narrower same-table/different-table/resource-index proof is added that distinguishes table stores by exact table and aliasing information.
