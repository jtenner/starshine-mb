# SGO loop independent table-fill prefix

Date: 2026-05-25

## Slice

`[SGO]003C5` loop-specific scanner follow-up.

## Question

Can Starshine safely match Binaryen's `simplify-globals-optimizing` behavior for a non-branching value loop where an independent `table.fill` effect precedes the yielded candidate-global read?

Focused shape:

```wat
(module
  (table (export "tab") 2 funcref)
  (func $f)
  (elem declare func $f)
  (global $once (mut i32) (i32.const 0))
  (func (export "run")
    loop (result i32)
      i32.const 0
      ref.func $f
      i32.const 1
      table.fill 0
      global.get $once
    end
    if
      i32.const 1
      global.set $once
    end))
```

## Binaryen probe

Command:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo-loop-table-fill-probe.wat -o .tmp/sgo-loop-table-fill-probe.opt.wat
```

The optimized output preserves `table.fill` and removes the fake `$once` `global.get` / `global.set` guard traffic. This makes the shape a Binaryen-positive loop-prefix case analogous to the already covered `memory.fill` / `memory.copy` / `memory.init` prefixes, with the important difference that the table value operand is a clean reference constant (`ref.func $f`) rather than a numeric literal.

## Implementation

- Added a focused positive regression in `src/passes/simplify_globals_optimizing_test.mbt` proving the loop prefix keeps `table.fill`, makes `$once` immutable, and removes the fake guard traffic.
- Added a paired negative where the table-fill destination index is candidate-derived; Starshine keeps the mutable global and preserves the guard traffic.
- Extended the narrow loop triple-effect prefix matcher in `src/passes/simplify_globals_optimizing.mbt` to admit `TableFill` when all three operands are recognized clean constants by the existing `sgo_const_instr` contract.

## TDD and validation

- TDD failure before implementation: `moon test src/passes` failed the new positive test because `$once` remained mutable.
- Focused pass validation after implementation: `moon test src/passes` passed (`1631/1631`).
- Standard validation: `moon fmt`, `moon info` (existing DAE warnings only), and full `moon test` passed (`3707/3707`).
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-table-fill-0687-10000` compared `6759/10000` cases before the configured `20` Binaryen/tool command-failure stop, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures (`17` rec-group-zero plus one each bad-section-size, table-index-out-of-range, and invalid-tag-index).

## Classification

This is a narrow semantic-safe / representation-independent broadening: only an independent table-fill side effect with constant/clean operands is preserved while the fake candidate-global guard traffic is removed. Candidate-derived operands remain conservative, so table effects whose index/value/count depends on the candidate global are not reordered or hidden.
