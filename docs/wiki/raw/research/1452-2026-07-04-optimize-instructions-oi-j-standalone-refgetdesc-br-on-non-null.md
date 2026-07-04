# OI-J standalone `ref.get_desc` self-contained `br_on_non_null` slice

Date: 2026-07-04

## Scope

This finite slice extends standalone `ref.get_desc(ref.as_non_null(block ...))` cleanup to one self-contained reference-branch child:

```wat
(ref.get_desc $A
  (ref.as_non_null
    (block $b (result (ref null $A))
      (local.get $x)
      (br_on_non_null $b)
      (ref.null $A))))
```

The non-null branch must target the nullable child block itself, and the fallthrough result must be an explicit nullable `ref.null`. The rewrite only retargets the standalone `ref.get_desc` child from the explicit `ref.as_non_null` node to the original nullable block node.

Out of scope: `br_on_null`, `br_on_cast`, `br_on_cast_fail`, escaping labels, descriptor-cast descriptor operands, `if`, `loop`, EH, multivalue children, broader descriptor/exactness behavior, and `ref.test_desc`.

## Binaryen evidence

A local Binaryen `version_130` probe in `.tmp/oi-j-next-probes/br-on-non-null.wat` shows `wasm-opt --all-features --optimize-instructions -S` removing the explicit `ref.as_non_null` for the self-contained `br_on_non_null` child. Binaryen prints the block directly under `ref.get_desc`, with `br_on_non_null` targeting the child block and an explicit `ref.null none` fallthrough.

The local proof is the same trap-locality argument as the preceding standalone block slices: the child block stays in place, the non-null branch returns the tested reference to the block, and the fallthrough produces null. The removed `ref.as_non_null` and the remaining `ref.get_desc` trap on the same null block result.

## Implementation

`src/passes/optimize_instructions.mbt` now allows `BrOnNonNull` inside the standalone child-control predicate only when its target label is internal to the nullable child block. The block proof accepts an explicit `RefNull` final root only after seeing a direct internal `BrOnNonNull` root earlier in the same child block. This keeps branch-free `ref.null` blocks and other `br_on_*` forms outside this slice.

## Tests and validation

New red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc br_on_non_null block null checks`

Red result before implementation:

```text
failed: expected self-contained br_on_non_null block child, got Heap
```

Green focused result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc br_on_non_null block null checks'
Total tests: 1, passed: 1, failed: 0.
```

The focused test covers default-mode and TNH standalone roots. Additional validation passed:

```text
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null
moon info
moon fmt
moon test
moon build --target native --release src/cmd
```

Full `moon test` passed `7426/7426`; the native `src/cmd` build passed with pre-existing warnings. Manual default and TNH Starshine replays for `.tmp/oi-j-next-probes/br-on-non-null.wat` validated with `wasm-tools --features all`, printed one `br_on_non_null`, and printed zero residual `ref.as_non_null` instructions.

Focused descriptor-profile TNH smoke:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-br-on-non-null --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining blockers include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, useful-type-info and exactness breadth, TNH/IIT escaping/control descriptor surfaces beyond the currently self-contained standalone branch subsets, `br_on_null`/`br_on_cast*` standalone children, and generalized descriptor effect/control localization.
