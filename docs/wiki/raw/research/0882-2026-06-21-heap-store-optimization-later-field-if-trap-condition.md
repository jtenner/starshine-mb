# Heap Store Optimization Later-Field If Trap-Condition Boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a call-valued later `struct.set` into a descriptor constructor when a later constructor field is an `if` whose condition may trap?

This complements `0874` for later-field `if` call conditions, `0879` for later-field `select` trap conditions, and `0881` for descriptor `if` trap conditions.

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
        (if (result i32)
          (i32.load (i32.const 0))
          (then (i32.const 2))
          (else (i32.const 3)))
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-probe-later-field-if-load-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-if-load-cond.opt.wat && \
grep -E "struct.set|struct.new_desc|if|i32.load|call|global.get" \
  .tmp/hso-probe-later-field-if-load-cond.opt.wat
```

Observed result: Binaryen preserves the later `struct.set`. The optimized text still contains `struct.new_desc`, the later-field `if`, `i32.load`, descriptor `global.get`, the later `call`, and `struct.set`.

Interpretation: a trapping later-field `if` condition is an effect-order barrier for a moved call-valued store. Folding would move the call before a possible `i32.load` trap in the later constructor field.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when later field if condition may trap`

The test uses a descriptor constructor whose second field is an `if` with an `i32.load` condition, then a call-valued field-0 `struct.set`. It asserts that Starshine preserves `struct.set`, the `if`, the trapping `i32.load`, and the call.

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this trapping later-field-if boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `239/239`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E coverage, not a behavior change.
- Binaryen behavior: preserve the call-valued later `struct.set` when a later-field `if` condition may trap.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen starts folding this trapping later-field-condition shape, if Starshine starts moving call-valued stores before trapping later-field operands, or if broader later-field expression handling regresses the pure/effectful/trapping split documented by `0873`, `0874`, `0875`, `0878`, `0879`, and this note.
