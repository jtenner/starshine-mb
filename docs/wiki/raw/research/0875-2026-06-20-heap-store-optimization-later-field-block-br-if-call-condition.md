# Heap Store Optimization Later-Field Block `br_if` Call-Condition Boundary

Date: 2026-06-20

## Question

Does Binaryen `version_130` preserve `struct.set` when a later constructor field is a block with a value-carrying `br_if` whose condition is a call, and the moved store value is also a call?

This extends the effectful later-field condition coverage from `0873` and `0874` beyond `select` and `if` into a branch-containing block expression that the current Starshine HOT surface can represent.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe shape:

```wat
(module
  (rec
    (type $pair (descriptor $descT) (struct (field (mut i32)) (field (mut i32))))
    (type $descT (describes $pair) (struct)))
  (type $helper (func (param i32) (result i32)))
  (import "env" "desc" (global $desc (ref (exact $descT))))
  (import "env" "helper" (func $helper (type $helper)))
  (func $f
    (local $s (ref null $pair))
    (local.set $s
      (struct.new_desc $pair
        (i32.const 0)
        (block (result i32)
          (drop
            (br_if 0
              (i32.const 2)
              (call $helper (i32.const 99))))
          (i32.const 3))
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-probe-later-field-block-br-if-call-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-block-br-if-call-cond.opt.wat
```

Observed result: Binaryen preserves `struct.set`. The later field's block, `br_if`, branch-condition call, descriptor `global.get`, and later call-valued store all remain; HSO does not fold the later store before the block's call-valued condition.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when later field block br_if condition calls`

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this branch-containing later-field condition boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `232/232`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E boundary coverage, not a behavior change.
- Binaryen behavior: keep `struct.set` when folding a call-valued store would move it before a call in a later-field block `br_if` condition.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen changes this branch-containing later-field condition behavior, if Starshine starts folding this shape, or if later field/descriptor expression work generalizes block/branch movement and accidentally treats effectful `br_if` conditions as pure operands.
