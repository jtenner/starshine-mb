---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# `heap-store-optimization` target-local write negative

Question: does Starshine explicitly cover the Binaryen target-local hazard where the value being moved into a constructor field writes the same local that holds the fresh struct?

## Answer

Yes after this coverage slice.

Binaryen's `version_130` source rejects folds when the candidate set value reads or writes the target local. This slice probed a local-set/later-`struct.set(local.get)` shape where the set value is a value-producing block that overwrites the same local with another `struct.new` before yielding the stored `i32`:

```wat
(module
  (type $S (struct (field (mut i32))))
  (func $f (result i32)
    (local $s (ref null $S))
    (local.set $s
      (struct.new $S (i32.const 0)))
    (local.get $s)
    (block (result i32)
      (local.set $s
        (struct.new $S (i32.const 8)))
      (i32.const 1))
    (struct.set $S 0)
    (local.get $s)
    (struct.get $S 0)))
```

The local Binaryen oracle (`wasm-opt version 130 (version_130)`) preserved `struct.set` under `--heap-store-optimization -all -S`, matching the target-local write hazard. Folding would move the local overwrite before the original constructor local assignment and change which object the later `local.get` observes.

Starshine already matched this behavior. The new focused test is:

- `heap-store-optimization keeps struct.set when the moved value writes the target local`

## Classification

- Slice type: coverage-only HSO-E progress.
- Binaryen behavior family: source-backed target-local hazard; this slice covers writes to the target local inside the moved set value.
- Starshine result: already matched Binaryen.
- Implementation change: none.
- Direct compare: not run because no pass behavior changed; the focused HSO test and explicit Binaryen probe were enough for this coverage-only slice.

## Commands

```sh
wasm-opt .tmp/hso-probe-target-local-write-value.wat --heap-store-optimization -all -S -o -
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result:

```text
Total tests: 206, passed: 206, failed: 0.
```

## Remaining HSO-E work

This only closes the direct moved-value target-local write negative. HSO-E remains open for target-local hazards in later local-set chains, target-local hazards mixed with descriptor operands or later fields, and any source-backed moved-value effect conflicts not already covered by HSO-D/G.
