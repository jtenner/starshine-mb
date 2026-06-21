# Heap Store Optimization Later-Field Select Call-Condition Boundary

Date: 2026-06-20

## Question

Does Binaryen `version_130` preserve `struct.set` when a later constructor field is a typed `select` whose condition is a call, and the moved store value is also a call?

This complements the descriptor-select boundary from `0872`: not only descriptor operands, but also later field operands, must keep effectful children ordered before the later call-valued store.

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
        (select (result i32)
          (i32.const 2)
          (i32.const 3)
          (call $helper (i32.const 99)))
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-probe-later-field-select-call-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-select-call-cond.opt.wat
```

Observed result: Binaryen preserves `struct.set`. The later field's `select` and its condition call remain inside `struct.new_desc`; the later call-valued store is not folded into the constructor.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when later field select condition calls`

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this later-field select call-condition boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `230/230`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E boundary coverage, not a behavior change.
- Binaryen behavior: keep `struct.set` when folding a call-valued store would move it before a call-valued later-field `select` condition.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen changes this later-field select call-condition behavior, if Starshine starts folding this shape, or if later field/descriptor expression work generalizes select movement and accidentally treats effectful select conditions as pure operands.
