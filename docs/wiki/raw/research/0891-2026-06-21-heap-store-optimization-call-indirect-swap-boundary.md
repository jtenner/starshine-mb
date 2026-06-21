---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
---

# Heap-store-optimization call_indirect swap boundary

## Question

HSO-G still tracks broader `trySwap(...)` legality for constructor operands with effects beyond the already-covered direct `call`, `memory.grow`, `table.grow`, memory/table size, ordinary store, and bulk/passive roots. This slice checks whether an indirect-call-valued constructor field may be moved across an unrelated mutable `global.set` while folding a later `struct.set`.

## Binaryen oracle probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe fixture: `.tmp/hso-probe-call-indirect-swap.wat`.

Shape:

```wat
(module
  (type $fn (func (result i32)))
  (type $s (struct (field (mut i32))))
  (table 1 funcref)
  (elem (i32.const 0) $g)
  (global $g0 (mut i32) (i32.const 0))
  (func $g (result i32) i32.const 5)
  (func (export "f")
    (local $s (ref null $s))
    (local.set $s
      (struct.new $s
        (call_indirect (type $fn) (i32.const 0))))
    (global.set $g0 (i32.const 1))
    (struct.set $s 0 (local.get $s) (i32.const 2))
    (drop (local.get $s))))
```

Command:

```sh
wasm-opt --all-features .tmp/hso-probe-call-indirect-swap.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-call-indirect-swap.opt.wat
```

Observed Binaryen output preserves the constructor `local.set`, keeps `call_indirect` before the `global.set`, and leaves the later `struct.set`. It does not fold the later store into the constructor because that would move the indirect call across the intervening root.

## Starshine coverage

Added focused coverage:

- `heap-store-optimization keeps call_indirect constructor operands before unrelated global.set`

The test uses Starshine's existing table+global HSO fixture surface, feeds `call_indirect` as an original constructor field, places an unrelated mutable `global.set` before the later `struct.set`, and asserts that the optimized output still contains `call_indirect`, `global.set`, and `struct.set`, with `global.set` before `struct.set`.

This is coverage-only: the test passed on first run, so no implementation behavior changed.

## Classification

This is a source/oracle-backed HSO-G boundary, not a Starshine win or non-goal. Binaryen treats indirect calls as effectful constructor operands that cannot be swapped across even an unrelated mutable global write for this fold. Starshine already matches.

Reopen if:

- Binaryen changes `trySwap(...)` / effect analysis to allow a specific nontrapping/pure indirect-call subset;
- Starshine adds call-target or table-element reasoning that claims an indirect call is pure enough to move; or
- a fuzz/direct compare mismatch shows indirect calls crossing roots during HSO.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `249/249`.

No native `src/cmd` rebuild or direct 10000-case compare was run because this slice only added coverage for behavior Starshine already matched; no pass implementation changed.
