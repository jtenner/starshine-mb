# Heap-store-optimization trapping trunc old-field preservation

## Question

Does Binaryen `version_130` fold a later `struct.set` into a fresh constructor when the overwritten constructor field is a trapping float-to-int truncation and an unrelated mutable `global.set` sits between the constructor and later store?

## Binaryen probe

Probe fixture: `.tmp/hso-probe-trunc-s-swap.wat`.

Relevant shape:

```wat
(local.set $x
  (struct.new $pair
    (i32.trunc_f32_s (f32.const nan))
    (i32.const 2)))
(global.set $g (i32.const 9))
(struct.set $pair 0 (local.get $x) (i32.const 42))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-trunc-s-swap.wat --heap-store-optimization -S -o .tmp/hso-probe-trunc-s-swap.opt.wat
```

Observed Binaryen `wasm-opt version 130 (version_130)` behavior:

- the constructor remains before the `global.set`;
- the trapping `i32.trunc_f32_s` old field remains inside the constructor;
- the later `struct.set` remains after the `global.set`.

Classification: Binaryen preserves trapping old-field evaluation for non-saturating float-to-int truncation, just as it does for the integer div/rem family in `0892`. Dropping the old field would delete a possible trap before the later global write and is a behavior parity bug, not a Starshine win.

## Starshine finding

A new focused test was added first:

- `heap-store-optimization keeps trapping trunc constructor operands before unrelated global.set`

The first Starshine run failed. Starshine folded the later store into the constructor and dropped the old field's trapping `i32.trunc_f32s`, producing a body with `global.set`, `struct.new`, and `struct.get` but no preserved truncation or `struct.set`.

Root cause: the local HSO exact-instruction trap helper added in `0892` covered exact integer div/rem nodes but not exact non-saturating float-to-int truncation nodes, so HSO still treated those old fields as trapless readonly values in old-field preservation and movement legality.

## Fix

`src/passes/heap_store_optimization.mbt` now marks exact non-saturating truncation instructions as trapping in the HSO exact-trap helper:

- `I32TruncF32S`, `I32TruncF32U`, `I32TruncF64S`, `I32TruncF64U`
- `I64TruncF32S`, `I64TruncF32U`, `I64TruncF64S`, `I64TruncF64U`

The existing HSO effect lookup and trapless-readonly predicates already consult that helper, so widening the helper preserves truncating old fields and blocks the unsafe fold for the tested shape.

This is a behavior fix, not a Starshine-win divergence. Starshine now matches the probed Binaryen boundary and preserves `struct.set` for the tested truncation shape.

## Validation

- `wasm-opt --version` — `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features .tmp/hso-probe-trunc-s-swap.wat --heap-store-optimization -S -o .tmp/hso-probe-trunc-s-swap.opt.wat` — Binaryen preserved the trapping old field and the later `struct.set`.
- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — first run failed on the new test before the fix; final post-fix run passed `251/251`.
- `moon fmt` — passed.
- `moon build --target native --release src/cmd` — passed with existing unused-function warnings in `src/passes/pass_manager.mbt`.
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap-store-optimization --out-dir .tmp/pass-fuzz-heap-store-optimization-trapping-trunc-old-field-10000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` — compared `10000/10000`, normalized matches `10000`, mismatches `0`, validation/property/generator failures `0`, command failures `0`; Binaryen cache `10000` hits / `0` misses.

## Reopening criteria

Reopen this boundary if:

- Binaryen HSO changes to preserve truncation traps via a different folded shape;
- Starshine learns exact HOT trap flags for non-saturating truncation globally and the local HSO exact-trap workaround becomes redundant;
- a future HSO change folds this shape without preserving `i32.trunc_f32_s` evaluation before the intervening `global.set`.
