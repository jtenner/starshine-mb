---
kind: research
status: supported
date: 2026-06-25
sources:
  - ../../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/index.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/starshine-hot-ir-strategy.md
  - ../../../../wiki/binaryen/passes/optimize-instructions/wat-shapes.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M selected trapping tuple lane with two earlier and two later siblings

## Question

Does the covered one-use `tuple.extract(tuple.make(...))` localizer preserve a selected trapping lane when two effectful siblings appear before it and two effectful siblings appear after it?

## Binaryen oracle

Probe: `.tmp/oi-m-tuple-selected-trapping-two-earlier-two-later-probe.wat`.

```wat
(module
  (memory 1)
  (func $a (result i64) (i64.const 1))
  (func $b (result i64) (i64.const 2))
  (func $c (result i32) (i32.const 3))
  (func $d (result i32) (i32.const 4))
  (func (param $p i32) (result i32)
    (tuple.extract 5 2
      (tuple.make 5
        (call $a)
        (call $b)
        (i32.load (local.get $p))
        (call $c)
        (call $d))))
)
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-m-tuple-selected-trapping-two-earlier-two-later-probe.wat -o -
```

Observed Binaryen output:

- drops `call $a`;
- drops `call $b`;
- stores/drops the selected `i32.load` through a tuple scratch local;
- drops `call $c`;
- drops `call $d`;
- reloads the selected temp as the final result.

## Starshine coverage

Added direct-HOT test:

- `optimize-instructions preserves selected trapping tuple.extract lane with two earlier and two later siblings`

The fixture builds a one-use tuple with two earlier `i64` call siblings, a selected exact `i32.load`, and two later `i32` call siblings. Starshine's existing direct-HOT localizer produces a behavior-preserving block with:

- two earlier `drop(Call)` roots;
- `LocalSet(i32.load)` for the selected lane;
- two later `drop(Call)` roots;
- a final `LocalGet` from the same temp.

This is coverage/status evidence for existing behavior, not a red-first implementation slice.

Focused validation:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*two earlier and two later siblings*'
```

passed `1/1`.

## Boundary

This slice covers the single-result direct-HOT tuple localizer only. Public tuple text/parser coverage, multi-result selected/sibling tuple-scratch localization, full `simplify-locals` replay of the `InvalidChildRef` shape, and dedicated `tuple-optimization` neighbor parity remain open.
