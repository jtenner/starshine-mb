# Heap Store Optimization Descriptor-If Trap-Condition Boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a call-valued later `struct.set` into a descriptor constructor when the descriptor operand is an `if` whose condition may trap?

This complements `0872` and `0880` for descriptor `select` conditions and `0876`/`0877` for descriptor block `br_if` operands.

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
        (i32.const 10)
        (if (result (ref (exact $descT)))
          (i32.load (i32.const 0))
          (then (global.get $desc))
          (else (global.get $desc)))))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-probe-descriptor-if-load-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-descriptor-if-load-cond.opt.wat && \
grep -E "struct.set|struct.new_desc|if|i32.load|call|global.get" \
  .tmp/hso-probe-descriptor-if-load-cond.opt.wat
```

Observed result: Binaryen preserves the later `struct.set`. The optimized text still contains `struct.new_desc`, descriptor `if`, `i32.load`, descriptor `global.get`, the later `call`, and `struct.set`.

Interpretation: a trapping descriptor-`if` condition is an effect-order barrier for a moved call-valued store. Folding would move the call before a possible `i32.load` trap in the descriptor operand.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when descriptor if condition may trap`

The test uses a descriptor constructor whose descriptor operand is an `if` over exact descriptor globals with an `i32.load` condition, then a call-valued field-0 `struct.set`. It asserts that Starshine preserves `struct.set`, `if`, `i32.load`, and the call.

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this trapping descriptor-if boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `238/238`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E coverage, not a behavior change.
- Binaryen behavior: preserve the call-valued later `struct.set` when the descriptor-if condition may trap.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen starts folding this trapping descriptor-condition shape, if Starshine starts moving call-valued stores before trapping descriptor operands, or if broader descriptor expression handling regresses the pure/effectful/trapping split documented by `0864`, `0872`, `0876`, `0877`, `0880`, and this note.
