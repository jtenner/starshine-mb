# Heap Store Optimization Later-Field Block `br_if` Pure-Condition Fold

Date: 2026-06-20

## Question

Does Binaryen `version_130` fold a call-valued later `struct.set` into a descriptor constructor when a later constructor field is a block with a value-carrying `br_if` whose branch value and condition are pure?

This complements the effectful later-field block `br_if` boundary in `0875` and the descriptor-side pure/effectful split in `0876`/`0877`.

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
              (i32.const 1)))
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
  .tmp/hso-probe-later-field-block-br-if-pure-cond-call-value.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-later-field-block-br-if-pure-cond-call-value.opt.wat && \
grep -E "struct.set|struct.new_desc|br_if|call|global.get|block|drop|i32.const" \
  .tmp/hso-probe-later-field-block-br-if-pure-cond-call-value.opt.wat
```

Observed result: Binaryen removes the later `struct.set` and folds the call-valued replacement into `struct.new_desc`, while preserving the later-field `block` / `br_if`, descriptor `global.get`, and call value in the constructor operand order.

## Starshine coverage

Added focused HSO-D/E coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization folds through later field block br_if with pure condition`

The test passed on the first focused run, so this was coverage-only progress: Starshine already matched Binaryen for the pure side of this branch-containing later-field split.

## Validation

- `moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt` — passed `235/235`.

No implementation behavior changed, so no native `src/cmd` rebuild or direct compare lane was required for this slice.

## Classification

- HSO-D/E coverage, not a behavior change.
- Binaryen behavior: fold a call-valued store through a later-field block `br_if` when the branch value and condition are pure.
- Starshine behavior: matches Binaryen.
- Reopening criteria: reopen if Binaryen changes this branch-containing later-field behavior, if Starshine starts preserving `struct.set` for this pure later-field `br_if` shape, or if future generalized later-field expression handling regresses the pure/effectful split documented by `0875` and this note.
