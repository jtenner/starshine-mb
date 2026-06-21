# Heap store optimization memory-store old-field boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh `struct.new` when the overwritten old constructor field is a value-producing block that performs an `i32.store`, and an unrelated mutable `global.set` root appears before the later `struct.set`?

This probes a broader HSO-D/G old-field side-effect family after the related `memory.grow`, `table.grow`, and mutable-global old-field positives.

## Probe

Temporary probe file: `.tmp/hso-probe-memory-store-old-field.wat`.

Shape:

- `struct.new $pair` initializes field `0` from a `(block (result i32) (i32.store ...) (i32.const 2))` old-field expression.
- The fresh struct is assigned to local `$p`.
- A root `(global.set $g0 (i32.const 9))` follows.
- A later `(struct.set $pair 0 (local.get $p) (i32.const 42))` overwrites field `0`.
- The function returns `(struct.get $pair 0 (local.get $p))`.

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-memory-store-old-field.wat --heap-store-optimization -S -o .tmp/hso-probe-memory-store-old-field.opt.wat
```

Observed Binaryen `version_130` output:

- Preserved the original `struct.new` old-field `block` with `i32.store`.
- Preserved the intervening `global.set`.
- Preserved the later `struct.set`.

## Classification

Binaryen behavior-parity boundary: HSO does **not** fold this memory-store old-field shape, even though the memory store itself occurs before the unrelated global write in the original order.

This is not a Starshine-win claim. It is a source-backed/oracle-backed negative boundary for the old-field side-effect matrix. Starshine already matched the boundary: the focused test added in this slice passed on the first run.

## Starshine coverage

Added focused test:

- `heap-store-optimization keeps memory-store old fields before unrelated global.set`

The test asserts that Starshine preserves:

- `i32.store`
- `global.set`
- `struct.set`

Command:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `258/258` passed.

No implementation change was needed, so no native rebuild or direct 10000-case compare was required for this coverage-only slice.

## Durable conclusion

Old-field side-effect preservation is not uniformly fold-positive. Binaryen folds side-effectful `memory.grow`, `table.grow`, and unrelated mutable-global-write old fields when the exact resource/global ordering proof allows it, but preserves the later `struct.set` for a memory-store old field in this probed shape.

Keep HSO-D/G open for additional old-field side-effect/resource families until either implemented, covered as Binaryen-matching boundaries, or documented as narrow Starshine wins/non-goals with reopening criteria.

## Reopening criteria

Reopen this boundary if:

- Binaryen moves memory-store old-field folding into HSO,
- Starshine begins folding this shape and needs a measured Starshine-win argument, or
- a narrower same-memory/different-memory/resource-index proof is added that distinguishes memory stores by exact memory and aliasing information.
