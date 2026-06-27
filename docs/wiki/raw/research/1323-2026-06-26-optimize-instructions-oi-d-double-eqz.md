# Optimize Instructions OI-D Double Eqz Rewrite

Date: 2026-06-26

## Question

Does Binaryen `version_130` rewrite nested `eqz(eqz(x))` boolean normalization shapes, and should Starshine cover the narrow direct HOT subset?

## Oracle probe

Probe: `.tmp/oi-eqz-eqz-probe.wat`

```wat
(module
  (func $one (result i32) (i32.const 1))
  (func (export "dbl") (param i32) (result i32)
    (i32.eqz (i32.eqz (local.get 0))))
  (func (export "dbl64") (param i64) (result i32)
    (i32.eqz (i64.eqz (local.get 0))))
  (func (export "call") (result i32)
    (i32.eqz (i32.eqz (call $one)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-eqz-eqz-probe.wat -o .tmp/oi-eqz-eqz-probe.out.wat
```

Observed Binaryen output:

- `i32.eqz(i32.eqz(local.get))` rewrites to `i32.ne(local.get, 0)`.
- `i32.eqz(i64.eqz(local.get))` rewrites to `i64.ne(local.get, 0)`.
- The effectful inner `i32.eqz(call)` form rewrites to `i32.ne(call, 0)`, preserving the call exactly once as the comparison operand.

## Starshine slice

Extended `optimize_instructions_try_fold_eqz(...)` in `src/passes/optimize_instructions.mbt` to recognize direct nested `i32.eqz` and `i64.eqz` operands under an outer `i32.eqz`. The rewrite replaces the outer node with the matching integer `ne` against a zero constant, preserving the original inner operand and requiring it to be live.

Added red-first HOT coverage in `src/passes/optimize_instructions_test.mbt` with `optimize-instructions rewrites double eqz into ne zero`. Before implementation the i32 case still rooted at `i32.eqz`; after the fix both i32 and i64 cases produce `ne` against zero.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-eqz-eqz-probe.wat -o .tmp/oi-eqz-eqz-probe.out.wat` passed and showed the rewrites described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*double eqz*'` failed before implementation and passed `1/1` after implementation.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

This is a narrow OI-D boolean-normalization slice. It does not claim broader boolean algebra, arbitrary nested expression equality, branch-condition rewrites beyond existing OI-F control cleanup, or any trap-relaxed/TNH/IIT behavior.
