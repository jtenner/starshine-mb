---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0852-2026-06-20-heap-store-optimization-subsequent-old-field-effects.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# `heap-store-optimization` subsequent old-field negative

Question: does Starshine explicitly cover the subsequent-chain counterpart of Binaryen's side-effect conflict family, where a later `struct.set(local.get)` would have to move a side-effecting set value before a side-effecting later constructor field that must stay before it?

## Answer

Yes after this coverage slice.

Binaryen's dedicated `version_130` lit includes the tee-shaped `$side-effect-conflict`: field `1` in the constructor calls `$helper-i32(0)`, and the store into field `0` calls `$helper-i32(1)`. Binaryen keeps the `struct.set`, because folding would move the second call before the later constructor field's call and reorder side effects.

This slice probed the local-set/later-`struct.set(local.get)` counterpart against the local Binaryen oracle (`wasm-opt version 130 (version_130)`) with:

```wat
(module
  (type $struct2 (struct (field (mut i32)) (field (mut i32))))
  (type $helper_t (func (param i32) (result i32)))
  (import "env" "helper" (func $helper-i32 (type $helper_t)))
  (func $subsequent-side-effect-conflict (local $ref (ref null $struct2))
    (local.set $ref
      (struct.new $struct2
        (i32.const 10)
        (call $helper-i32 (i32.const 0))))
    (struct.set $struct2 0
      (local.get $ref)
      (call $helper-i32 (i32.const 1)))))
```

`wasm-opt --heap-store-optimization -all -S` preserved the `struct.set`, matching the side-effect ordering rule from the lit family.

Starshine already matched this behavior. The new focused test is:

- `heap-store-optimization keeps subsequent struct.set when later field call orders before moved call`

The test proves the local-set/later-store path keeps `struct.set` and preserves both call argument constants when the moved field-0 call would cross the side-effecting field-1 constructor operand.

## Classification

- Slice type: coverage-only HSO-D progress.
- Binaryen behavior family: source/lit-backed old-field side-effect conflict, extended to the subsequent-chain shape by a local `version_130` oracle probe.
- Starshine result: already matched Binaryen.
- Implementation change: none.
- Direct compare: not run because no pass behavior changed; the focused HSO test and explicit Binaryen probe were enough for this coverage-only slice.

## Commands

```sh
wasm-opt .tmp/hso-probe-subsequent-side-effect-conflict.wat --heap-store-optimization -all -S -o -
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 205, passed: 205, failed: 0.
```

## Remaining HSO-D work

This only closes the subsequent-chain old-field side-effect negative for plain `struct.new`. HSO-D remains open for arbitrary descriptor expressions, remaining later-field directional barriers, default/descriptor old-field combinations, and broader old-field side-effect negatives.
