---
kind: research
status: supported
created: 2026-06-21
sources:
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization_test.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/HeapStoreOptimization.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_130/test/lit/passes/heap-store-optimization.wast
---

# Heap-store-optimization descriptor block `br_if` trap condition

## Question

For a `struct.new_desc` chain, does Binaryen `version_130` fold a later call-valued `struct.set` into the constructor when the descriptor operand is a value-carrying `block` with a `br_if` condition that may trap?

The adjacent HSO-D/E matrix already covered descriptor block `br_if` pure-condition folds and call-condition no-fold behavior. This slice checks the trapping-but-non-call condition counterpart.

## Probe

Local oracle:

```sh
wasm-opt --version
# wasm-opt version 130 (version_130)
```

Probe fixture written to `.tmp/hso-probe-descriptor-block-br-if-load-cond.wat`:

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
        (block (result (ref (exact $descT)))
          (drop
            (br_if 0
              (global.get $desc)
              (i32.load (i32.const 0))))
          (global.get $desc))))
    (struct.set $pair 0
      (local.get $s)
      (call $helper (i32.const 1)))))
```

Command:

```sh
wasm-opt --all-features \
  .tmp/hso-probe-descriptor-block-br-if-load-cond.wat \
  --heap-store-optimization -S \
  -o .tmp/hso-probe-descriptor-block-br-if-load-cond.opt.wat

grep -E "struct.set|struct.new_desc|block|br_if|i32.load|call|global.get" \
  .tmp/hso-probe-descriptor-block-br-if-load-cond.opt.wat
```

The first probe attempt put `(memory 1)` before imports and Binaryen rejected the WAT with `import after non-import`; moving the memory after imports produced the accepted fixture above.

## Result

Binaryen preserved the later `struct.set` and retained the descriptor `block`, `br_if`, `i32.load`, descriptor `global.get`, `struct.new_desc`, and later `call`.

Interpretation: HSO must not fold this shape because folding the call-valued store into `struct.new_desc` would move the call before a possible descriptor-block `br_if` condition trap.

## Starshine coverage

Added focused coverage in `src/passes/heap_store_optimization_test.mbt`:

- `heap-store-optimization keeps struct.set when descriptor block br_if condition may trap`

The test uses `hso_desc_memory_call_test_run(...)` and checks that optimized output still contains `struct.new_desc`, `block`, `br_if`, `i32.load`, the later `call`, and `struct.set`.

Validation:

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
# Total tests: 241, passed: 241, failed: 0.
```

The new test passed on the first focused run. This is therefore coverage-only parity progress, not a behavior change. No native rebuild or direct compare was required.

## Classification

- Family: HSO-D/E descriptor operand movement barrier.
- Binaryen behavior: preserve `struct.set` when a descriptor block `br_if` condition may trap before the later call-valued store would have run.
- Starshine behavior: already matches Binaryen.
- Status: source/probe-backed coverage added.

## Reopening criteria

Reopen if:

- Binaryen changes HSO to fold call-valued stores across descriptor block `br_if` trap conditions,
- Starshine starts dropping the `struct.set` for this shape,
- descriptor branch-result HOT surface changes make a more exact `br_on_non_null` descriptor boundary representable, or
- the final HSO-D/E matrix finds another descriptor block branch shape with different effect-order behavior.
