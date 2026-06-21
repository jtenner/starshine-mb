# Heap Store Optimization Later-Field Select Trap-Condition Boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a call-valued later `struct.set` into a descriptor constructor when a later constructor field is a typed `select` whose condition may trap?

This complements the later-field select pure/effectful split from `0873`: call conditions are effectful barriers, and this note checks a trapping-but-non-call condition (`i32.load`).

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
  (memory 1)
  (func $f
    (local $s (ref null $pair))
    (local.set $s
      (struct.new_desc $pair
        (i32.const 0)
        (select (result i32)
          (i32.const 2)
          (i32.const 3)
          (i32.load (i32.const 0)))
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-probe-later-field-select-load-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-select-load-cond.opt.wat && \
grep -E "struct.set|struct.new_desc|select|i32.load|call|global.get" \
  .tmp/hso-probe-later-field-select-load-cond.opt.wat
```

Observed result: Binaryen preserves the later `struct.set`. The optimized text still contains `struct.new_desc`, `select`, the trapping `i32.load`, descriptor `global.get`, the later `call`, and `struct.set`.

Interpretation: a trapping later-field select condition is an effect-order barrier for a moved call-valued store. Folding would move the call before a possible `i32.load` trap.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when later field select condition may trap`

The test uses a descriptor constructor with a later typed-select field whose condition is `i32.load`, then a call-valued field-0 `struct.set`. It asserts that Starshine preserves `struct.set`, `select`, `i32.load`, and the call.

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this trapping later-field select boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `236/236`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E coverage, not a behavior change.
- Binaryen behavior: preserve the call-valued later `struct.set` when a later-field select condition may trap.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen starts folding this trapping-condition shape, if Starshine starts moving call-valued stores before trapping later-field operands, or if broader later-field expression handling regresses the pure/effectful/trapping split documented by `0873`, `0875`, `0878`, and this note.
