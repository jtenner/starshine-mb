---
kind: research
status: supported
created: 2026-06-20
sources:
  - ../../../src/passes/heap_store_optimization_test.mbt
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ../../binaryen/passes/heap-store-optimization/swap-safety-and-control-flow.md
---

# `heap-store-optimization` loop-backedge local-read control-flow negative

Question: how should `heap-store-optimization` handle a moved `struct.set` value that can branch back to a loop header where the fresh-struct target local is read before the next `local.set`?

## Answer

Binaryen `version_130` preserves the `struct.set` for this loop-backedge shape. The local read at the top of the loop is an in-function target-local observation that can become exposed if the branch-valued store operand is moved into the constructor before the fresh-struct `local.set`.

Starshine already matched this behavior. This slice added focused negative coverage only; no pass implementation changed.

## Binaryen probe

Fixture:

```wat
(module
  (type $S (struct (field (mut i32))))
  (func (param $c i32) (result i32)
    (local $x (ref null $S))
    (block $out (result i32)
      (loop $loop
        (drop (local.get $x))
        (local.set $x (struct.new_default $S))
        (struct.set $S 0
          (local.get $x)
          (block $v (result i32)
            (local.get $c)
            (br_if $loop)
            (i32.const 7)))
      )
      (i32.const 42)
    )
    (drop)
    (struct.get $S 0 (local.get $x))
  )
)
```

Command:

```sh
wasm-opt .tmp/hso-probe-loop-backedge-prior-read.wat --heap-store-optimization -all -S -o -
```

Observed result: Binaryen preserved the `struct.set` and kept the `struct.new_default`, confirming this is a control-flow skip-local-set negative rather than a foldable one-disappearing-bad-get shape.

A related probe without the prior loop-header target-local read did fold in Binaryen; that shape is not the negative guarded here.

## Starshine coverage

Added test:

- `heap-store-optimization keeps loop backedge values before prior local reads`

The fixture uses local 0 as the fresh-struct target and local 1 as the dynamic branch condition. The loop body reads local 0 before assigning the new struct, then the store value can `br_if` back to the loop. The expected result preserves `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Result: `222/222` focused HSO tests passed.

## Classification

- Family: HSO-F in-function branch / loop-backedge skip-local-set hazard.
- Binaryen behavior: preserve the store.
- Starshine behavior: preserve the store.
- Implementation change: none.
- Reopening criteria: reopen if Starshine starts folding branch-valued loop-backedge stores that can reach any target-local read before the corresponding fresh-struct assignment, or if a future Binaryen release changes `LazyLocalGraph::canMoveSet(...)` behavior for this loop-backedge family.
