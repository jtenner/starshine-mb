# Optimize Instructions OI-M Selected-Twenty-Seventh Child Multi-Result Boundary

Date: 2026-07-03

## Question

Does Binaryen `version_130` localize the selected twenty-seventh scalar result from a multi-result tuple child under `--optimize-instructions`, and should Starshine claim that behavior after the arity-26 slice?

## Probe

Input fixture: `.tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.wat`.

```wat
(module
  (import "env" "many" (func $many (result i32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32 i64 f32 f64 i32 i64 f32 i64 f32 f64 i32 i64 f32 f64 i32 i64 i32)))
  (func (result i32)
    (tuple.extract 28 26
      (tuple.make 28
        (call $many)
        (i32.const 27)))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.wat -o .tmp/oi-m-tuple-multiresult-selected-twenty-seventh-child-probe.binaryen.20260703.wat
```

## Finding

Binaryen localizes the twenty-seven-result call into a tuple scratch local, extracts and drops the first lane, stores the selected twenty-seventh `i32` lane in a scalar temp, drops that temp write, and returns the scalar temp. This is the same tuple-scratch family observed for selected arities 2 through 26.

## Starshine coverage

Original direct-HOT boundary/status coverage in `src/passes/optimize_instructions_test.mbt` used:

- `optimize-instructions intentionally keeps tuple.extract with multi-result selected twenty-seventh child-lane boundary`

That boundary asserted Starshine kept `TupleExtract` index `26`, the `TupleMake`, and the twenty-seven-result selected `Call` unchanged.

## 2026-07-03 supersession

This boundary is superseded by `docs/wiki/raw/research/1416-2026-07-03-optimize-instructions-oi-m-generalized-selected-child-localization.md`.

The former boundary test is now positive helper-backed coverage named:

- `optimize-instructions localizes twenty-seventh lane from twenty-seven-result selected tuple child`

Red-first evidence: before implementation, the focused selected-child run failed because the root stayed `TupleExtract`. After the generalized selected-child localizer replaced the hardcoded accepted-result-count list with a non-empty selected-result predicate, the same fixture passed and asserted stack-pop-order `LocalSet` roots plus a selected-lane `LocalGet`.

## Status

Starshine's current tuple.extract OI localizer now supports arbitrary direct one-use selected-child scalar result arity under the safe preconditions recorded in research note `1416`. This note is retained as Binaryen probe history, not an active arity-27 blocker. Reopen this boundary if the arity-27 implementation regresses, if public/binary tuple fixture coverage exposes a different representation, or if a future Binaryen source/oracle refresh stops localizing it.
