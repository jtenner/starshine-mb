---
title: SGO loop independent memory/table grow prefix
kind: research
status: supported
date: 2026-05-25
sources:
  - ../binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md
  - ../../../../src/passes/simplify_globals_optimizing.mbt
  - ../../../../src/passes/simplify_globals_optimizing_test.mbt
  - ../../binaryen/passes/simplify-globals-optimizing/parity-matrix.md
---

# SGO loop independent memory/table grow prefix

## Question

Can the narrow `[SGO]003C5` value-loop prefix matcher safely cover independent `memory.grow` and `table.grow` effects before the yielded candidate-global read, matching Binaryen's `SimplifyGlobals.cpp` behavior without enabling broad loop `FlowScanner` reuse?

## Binaryen probe

Reduced probe shape:

```wat
(module
  (memory 1)
  (table 1 funcref)
  (global $once (mut i32) (i32.const 0))
  (func $f)
  (func (export "mem")
    (if
      (loop (result i32)
        i32.const 0
        memory.grow
        drop
        global.get $once)
      (then
        i32.const 1
        global.set $once)))
  (func (export "tab")
    (if
      (loop (result i32)
        ref.func $f
        i32.const 0
        table.grow 0
        drop
        global.get $once)
      (then
        i32.const 1
        global.set $once))))
```

Command:

```sh
wasm-opt --all-features -O --simplify-globals-optimizing .tmp/sgo-loop-grow-probe.wat -S -o .tmp/sgo-loop-grow-probe.opt.wat
```

Binaryen preserved the independent grow effects and removed the fake `$once` guard traffic, so the shape is a Binaryen-positive loop-prefix family.

## Local change

Added focused positives for:

- `i32.const; memory.grow; drop; global.get <candidate>` in a value loop feeding the no-else same-global constant-set guard.
- `ref.func; i32.const; table.grow; drop; global.get <candidate>` in the same position.

Added paired negatives for candidate-derived grow sizes:

- `global.get <candidate>; memory.grow; drop; global.get <candidate>` remains conservative.
- `ref.func; global.get <candidate>; table.grow; drop; global.get <candidate>` remains conservative.

Implementation keeps this inside the existing narrow loop-prefix matcher. It accepts only constant/reference-constant grow operands followed by `drop`, then the final candidate `global.get`; it does not reuse the full block `FlowScanner` in loops, and it still rejects candidate-derived operands.

## TDD and validation

- Before implementation, `moon test src/passes` failed on the two new positives with `$once` still mutable.
- After implementation, `moon test src/passes` passed (`1639/1639`).

- `moon fmt`, `moon info`, and full `moon test` passed after docs/code updates (`3715/3715`).
- Direct SGO fuzz at `.tmp/pass-fuzz-sgo-loop-grow-0689-10000` compared `6759/10000` cases before the configured 20 Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and command failures classified as the established Binaryen/tool classes: `17` `binaryen-rec-group-zero`, `1` `binaryen-bad-section-size`, `1` `binaryen-table-index-out-of-range`, and `1` `binaryen-invalid-tag-index`.

## Decision

`[SGO]003C5` now covers independent memory/table grow-and-drop loop prefixes under the same conservative contract as the existing loop store/table/bulk prefixes. Future loop broadening still requires exact Binaryen-positive probes plus guardrail negatives, especially for branch/control bodies, grow results that are consumed by the condition, candidate-derived grow operands, atomics, SIMD memory operations, relaxed SIMD, and calls.
