# SGO003B transparent block wrapper guardrails

Date: 2026-05-25

## Slice

`[SGO]003B - Read-Only-To-Write Broader Control Wrappers`

## Goal

Pin the narrow transparent `block (result i32)` wrapper grammar that Binaryen accepts for read-only-to-write self guards and verify Starshine already handles that exact grammar without broadening the matcher.

This is a source-alignment / guardrail slice, not a new behavior implementation. `[SGO]003` remains active/partial.

## Binaryen probe

Fixture saved under `.tmp/sgo003b-probes/nested-block.wat`:

```wat
(module
  (global $g (mut i32) (i32.const 0))
  (func (export "run")
    block (result i32)
      block (result i32)
        global.get $g
      end
    end
    if
      i32.const 1
      global.set $g
    end))
```

Command:

```sh
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo003b-probes/nested-block.wat -o -
```

Binaryen rewrites the mutable global to an immutable `i32` and leaves only `nop` in the function body. This confirms nested transparent result-block wrappers around the candidate read are positive for this exact no-branch/no-call/no-extra-read shape.

## Starshine coverage

Added focused local regressions in `src/passes/simplify_globals_optimizing_test.mbt`:

- positive: nested `block (result i32)` wrappers around `global.get $once` feeding the outer no-else same-global set guard;
- negative: a branchy result-block wrapper containing `br 0` before the candidate read preserves the mutable global and `global.get`/`global.set` traffic.

The tests passed before implementation changes because Starshine's existing condition-body collector recursively flattens transparent blocks and rejects branchy wrappers by leaving the `br` in the flattened condition stream. No matcher broadening was needed.

## Boundaries preserved

This slice does not accept any new calls, `call_indirect`, `call_ref`, returns, catch-bearing `try_table`s, trapping global-derived loads/table operations, extra same-global reads, `else` arms, or post-join observable uses. Those remain separate `[SGO]003*` work items.

## Validation

- `moon test src/passes` passed (`1592/1592`).
- Full quick gate and direct SGO fuzz are recorded in the commit validation report for this slice.
