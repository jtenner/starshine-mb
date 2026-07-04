# OI-J standalone `ref.get_desc` self-contained `br_table` slice

Date: 2026-07-04

## Scope

This finite slice extends standalone `ref.get_desc(ref.as_non_null(block ...))` cleanup to self-contained branch-table children:

```wat
(ref.get_desc $A
  (ref.as_non_null
    (block (result (ref null $A))
      (br_table 0 0 ...))))
```

All `br_table` targets must resolve to labels owned inside the nullable child block. The rewrite only retargets the standalone `ref.get_desc` from the explicit `ref.as_non_null` node to the original nullable block node.

Out of scope: escaping branch tables, descriptor-cast descriptor operands, `br_on_*`, `if`, `loop`, EH, multivalue children, broader descriptor/exactness behavior, and `ref.test_desc`.

## Binaryen evidence

The descriptor-operand br_table evidence already lives in the focused test and parity notes, and Binaryen's standalone block-child behavior follows the same `trapOnNull` / `skipNonNullCast` reasoning used by the standalone br/br_if probes: the block remains in place and `ref.get_desc` performs the same nullable-value check after the branch-table result is selected.

This slice is intentionally smaller than the existing descriptor-operand br_table localizer: it does not flatten or retarget descriptor operands, and it does not handle escaping labels.

## Implementation

`src/passes/optimize_instructions.mbt` now allows `BrTable` inside the standalone child-control predicate only when the default target and every table target are internal to the nullable child block. The block proof also accepts a terminal internal `BrTable` root as the final producer for the block's nullable result.

## Tests and validation

New red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc br_table block null checks`

Red result before implementation:

```text
failed: expected self-contained br_table block child, got Heap
```

Green focused result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc br_table block null checks'
Total tests: 1, passed: 1, failed: 0.
```

The focused test covers default-mode and TNH standalone roots. Additional validation passed:

```text
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null
moon fmt
moon test
moon build --target native --release src/cmd
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-brtable --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
```

Full `moon test` passed `7425/7425`; the native `src/cmd` build passed with pre-existing warnings; the descriptor-profile TNH smoke compared `12/12` with `12` normalized matches, zero failures, and zero mismatches. OI-J remains blocked for the broader surfaces listed above.
