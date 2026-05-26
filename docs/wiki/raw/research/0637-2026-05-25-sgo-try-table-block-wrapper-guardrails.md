# SGO003G try_table block-wrapper guardrails

Date: 2026-05-25

## Slice

`[SGO]003G - TryTable Transparency Beyond No-Catch Wrapper`

## Goal

Check a narrow wrapper-composition case beyond the already-tested bare no-catch `try_table`: a no-catch `try_table (result i32)` whose body is a transparent `block (result i32)` around the candidate `global.get`, feeding the usual no-else same-global constant set guard.

This is a source-alignment / guardrail slice. It does not broaden SGO implementation behavior; `[SGO]003` remains active/partial.

## Binaryen probes

Fixtures saved under `.tmp/sgo003g-probes/`.

Positive no-catch wrapper composition:

```wat
(module
  (tag $e)
  (global $g (mut i32) (i32.const 0))
  (func (export "run")
    try_table (result i32)
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
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo003g-probes/try-table-block.wat -o -
```

Binaryen rewrote the mutable global to immutable and removed the fake self-guard traffic.

Paired caught-wrapper boundary:

```wat
(module
  (tag $e)
  (global $g (mut i32) (i32.const 0))
  (func (export "run")
    try_table (result i32) (catch $e 0)
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
wasm-opt --all-features --simplify-globals-optimizing -S .tmp/sgo003g-probes/try-table-catch-block.wat -o -
```

Binaryen preserved the mutable global and the guard traffic. The catch boundary remains a hard guardrail for Starshine.

## Starshine coverage

Added focused tests in `src/passes/simplify_globals_optimizing_test.mbt`:

- positive: no-catch `try_table (result i32)` with a transparent result block around the candidate `global.get`;
- negative: caught `try_table` with the same transparent result-block body.

Both passed without implementation changes. The existing no-catch `try_table` body extractor and condition-body transparent block collector already cover the positive, while caught wrappers are excluded by the no-catch check.

## Boundaries preserved

This slice does not add catch-bearing `try_table` transparency, post-`try_table` join facts, catch/control-transfer matching, branches/returns through handlers, calls, trapping/effectful candidate consumers, extra same-global reads, `else` arms, or exception-observable body-effect reasoning.

## Validation

- `moon test src/passes` passed (`1594/1594`).
- Full quick gate and direct SGO fuzz are recorded in the commit validation report for this slice.
