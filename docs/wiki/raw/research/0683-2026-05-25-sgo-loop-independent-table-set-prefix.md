# SGO loop independent table-set prefix

Date: 2026-05-25

## Question

Can the narrow `[SGO]003C5` direct-loop read-only-to-write prefix matcher safely admit an independent `table.set` side effect before the yielded candidate-global read, matching Binaryen's `SimplifyGlobals.cpp` behavior without enabling broad loop FlowScanner reuse?

## Binaryen probe

Fixture shape:

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
      table.set 0
      global.get $once
    end
    if
      i32.const 1
      global.set $once
    end))
```

`wasm-opt --all-features --simplify-globals-optimizing -S` promotes `$once` to immutable and removes the fake `global.get` / `global.set` traffic while preserving the independent `table.set`. A paired tainted-index probe with `global.get $once; ref.func $f; table.set 0; global.get $once` keeps `$once` mutable and preserves the later write, so the accepted shape is operand-clean rather than a broad table-side-effect rule.

## Implementation

- Added focused positive and negative tests in `src/passes/simplify_globals_optimizing_test.mbt`.
- Extended `sgo_loop_independent_prefix_scalar_store_matches(...)` in `src/passes/simplify_globals_optimizing.mbt` to recognize `@lib.TableSet(_)` when both preceding operands are `sgo_const_instr(...)` constants.
- Kept the loop matcher narrow: no branch/control bodies, `br_if`, returns, trapping candidate-derived consumers, growth operations, atomics, SIMD memory operations, broad bulk operations, or call operands are admitted by this slice.

## TDD and validation

- TDD failure before implementation: `moon test src/passes` failed on `simplify-globals-optimizing removes loop-wrapped independent table-set effect prefixes`; `$once` stayed mutable.
- Focused pass tests after implementation: `moon test src/passes` passed (`1623/1623`) with existing DAE/pass-manager unused warnings.
- Full validation after docs: `moon fmt`, `moon info`, and full `moon test` passed (`3699/3699`) with existing DAE unused warnings.
- Direct SGO fuzz: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --out-dir .tmp/pass-fuzz-sgo-loop-table-set-0683-10000` compared `6759/10000`, with `6759` normalized matches, `0` mismatches, `0` Starshine validation failures, and `20` Binaryen/tool command failures under the configured stop.

## Classification

The implemented family is classified as semantic-safe and Binaryen-positive because the table index and stored reference are independent constants, so the table side effect still occurs in order while the removed global traffic is fake state used only for the final same-global guard. The tainted operand guardrail keeps cases where the candidate global can affect a trap, table target, or stored reference conservative.
