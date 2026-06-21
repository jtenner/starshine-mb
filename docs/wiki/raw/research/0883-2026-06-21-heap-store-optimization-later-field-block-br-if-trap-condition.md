# Heap Store Optimization Later-Field Block Br_if Trap-Condition Boundary

Date: 2026-06-21

## Question

Does Binaryen `version_130` fold a call-valued later `struct.set` into a descriptor constructor when a later constructor field is a value-carrying `block` with `br_if` whose condition may trap?

This completes the current later-field block `br_if` pure/effectful/trapping split around `0875` and `0878`, and complements the trapping later-field `select` / `if` boundaries in `0879` and `0882`.

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
        (block (result i32)
          (i32.const 2)
          (br_if 0 (i32.load (i32.const 0)))
          (drop)
          (i32.const 3))
        (global.get $desc)))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --version && \
wasm-opt --all-features \
  .tmp/hso-probe-later-field-block-br-if-load-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-block-br-if-load-cond.opt.wat && \
grep -E "struct.set|struct.new_desc|block|br_if|i32.load|call|global.get" \
  .tmp/hso-probe-later-field-block-br-if-load-cond.opt.wat
```

Observed result: Binaryen preserves the later `struct.set`. The optimized text still contains `struct.new_desc`, the later-field `block`, `br_if`, `i32.load`, descriptor `global.get`, the later `call`, and `struct.set`.

Interpretation: a trapping later-field `block` / `br_if` condition is an effect-order barrier for a moved call-valued store. Folding would move the call before a possible `i32.load` trap in the later constructor field.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when later field block br_if condition may trap`

The test uses a descriptor constructor whose second field is a value-carrying `block` with `br_if` conditioned by an `i32.load`, then a call-valued field-0 `struct.set`. It asserts that Starshine preserves `struct.set`, the block, `br_if`, the trapping `i32.load`, and the call.

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for this trapping later-field block-branch boundary.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `240/240`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E coverage, not a behavior change.
- Binaryen behavior: preserve the call-valued later `struct.set` when a later-field `block` / `br_if` condition may trap.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen starts folding this trapping later-field branch-condition shape, if Starshine starts moving call-valued stores before trapping later-field operands, or if broader later-field expression handling regresses the pure/effectful/trapping split documented by `0873`, `0874`, `0875`, `0878`, `0879`, `0882`, and this note.
