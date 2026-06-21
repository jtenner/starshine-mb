# Heap Store Optimization Descriptor Select Call-Condition Boundary

Date: 2026-06-20

## Question

Does Binaryen `version_130` preserve `struct.set` when a descriptor constructor operand is a typed `select` whose condition is a call, and the moved store value is also a call?

This complements the pure descriptor-select positive from `0864`: a select between immutable descriptor globals is reorderable only when all descriptor-select children that must stay before the constructor are safe to cross.

## Binaryen probe

Local oracle: `wasm-opt version 130 (version_130)`.

Probe shape:

```wat
(module
  (rec
    (type $pair (descriptor $descT) (struct (field (mut i32))))
    (type $descT (describes $pair) (struct)))
  (type $helper (func (param i32) (result i32)))
  (import "env" "desc" (global $desc (ref (exact $descT))))
  (import "env" "helper" (func $helper (type $helper)))
  (func $f
    (local $s (ref null $pair))
    (local.set $s
      (struct.new_desc $pair
        (i32.const 0)
        (select (result (ref (exact $descT)))
          (global.get $desc)
          (global.get $desc)
          (call $helper (i32.const 99)))))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-probe-desc-select-helper-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-desc-select-helper-cond.opt.wat
```

Observed result: Binaryen preserves `struct.set`. The descriptor `select` and its condition call remain before `struct.new_desc`; the later call-valued store is not folded into the constructor.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when descriptor select condition calls`

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this descriptor-select call-condition boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `229/229`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E boundary coverage, not a behavior change.
- Binaryen behavior: keep `struct.set` when folding a call-valued store would move it before a call-valued descriptor `select` condition.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen changes this descriptor-select call-condition behavior, if Starshine starts folding this shape, or if later descriptor-expression work generalizes select movement and accidentally treats effectful select conditions as pure descriptor operands.
