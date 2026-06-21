# Heap-store-optimization trapping old-field preservation

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh constructor when the overwritten constructor field is a trapping numeric expression and an unrelated mutable `global.set` sits between the constructor and later store?

## Binaryen probe

Probe fixture: `.tmp/hso-probe-div-s-swap.wat`.

Relevant shape:

```wat
(local.set $x
  (struct.new $pair
    (i32.div_s (i32.const 10) (i32.const 0))
    (i32.const 2)))
(global.set $g (i32.const 9))
(struct.set $pair 0 (local.get $x) (i32.const 42))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-div-s-swap.wat --heap-store-optimization -S -o .tmp/hso-probe-div-s-swap.opt.wat
```

Observed Binaryen `wasm-opt version 130 (version_130)` behavior:

- the constructor remains before the `global.set`;
- the trapping `i32.div_s` old field remains inside the constructor;
- the later `struct.set` remains after the `global.set`.

Classification: Binaryen preserves trapping old-field evaluation. Folding this field replacement away would delete a potential trap before the later global write and would not match HSO behavior parity.

## Starshine finding

A new focused test was added first:

- `heap-store-optimization keeps trapping constructor operands before unrelated global.set`

The first Starshine run failed. Starshine folded the later store into the constructor and dropped the old field's trapping `i32.div_s`, producing a body with `global.set`, `struct.new`, and `struct.get` but no preserved `i32.div_s` / `struct.set`.

Root cause: HSO's local effect mask path did not mark exact integer div/rem HOT binary nodes as trapping, and old-field preservation used the effect mask to decide whether the old constructor field could be discarded.

## Fix

`src/passes/heap_store_optimization.mbt` now has a local exact-instruction trap helper for integer div/rem nodes. HSO effect lookup ORs in `EFFECT_MASK_TRAP` for those exact instructions, and HSO's trapless readonly/reorderable predicates use the helper so old-field and movement legality checks do not treat trapping integer div/rem as pure.

This is a behavior fix, not a Starshine-win divergence. Starshine now matches the probed Binaryen boundary and preserves `struct.set` for the tested shape.

## Validation

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/hso-probe-div-s-swap.wat --heap-store-optimization -S -o .tmp/hso-probe-div-s-swap.opt.wat` — Binaryen preserved the trapping old field and the later `struct.set`.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — first run failed on the new test before the fix; final run passed `250/250` after the fix.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-trapping-old-field-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` — compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation/property/generator failures `0`, command failures `0`; Binaryen cache `10000` hits / `0` misses.

## Reopening criteria

Reopen this boundary if:

- Binaryen HSO changes to preserve the trap via a different folded shape;
- Starshine learns exact HOT trap flags for integer div/rem globally and the local HSO exact-trap workaround becomes redundant;
- a future HSO change folds this shape without preserving `i32.div_s` evaluation before the intervening `global.set`.
