# OI-J standalone `ref.get_desc` self-contained branch-child slice

Date: 2026-07-04

## Scope

This slice extends the standalone `ref.get_desc(ref.as_non_null(block ...))` cleanup from direct locals and branch-free blocks to a finite self-contained branch subset:

- a block child with a branch that targets the child block's own label;
- `br` terminal payload shapes;
- `br_if` payload/fallthrough shapes whose final fallthrough value is a nullable `local.get`;
- default mode and `--traps-never-happen` (TNH), with IIT covered by the same non-TNH helper path.

The rewrite still only retargets the standalone `ref.get_desc` child from the explicit `ref.as_non_null` to the original nullable block child. It does not rebuild, move, duplicate, or sink the block.

Out of scope:

- descriptor-cast descriptor operands;
- branches escaping outside the descriptor child block;
- `br_table`, `br_on_*`, `if`, `loop`, `try`, `try_table`, EH, and multivalue children;
- `ref.test_desc`, broader descriptor-cast behavior, useful-type-info/exactness breadth, and generalized descriptor effect/control localization.

## Binaryen evidence

The focused control-boundary probes from note `1441` remain the anchors:

- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/inputs/05-br-control-boundary.wat`
- `.tmp/oi-j-standalone-refgetdesc-block-child-20260703/inputs/06-br-if-control-boundary.wat`

Binaryen `version_130` removes the explicit `ref.as_non_null` for these standalone self-contained branch children. The previous Starshine behavior deliberately kept the null check as a conservative boundary; this slice reduces that boundary only for the internally-targeted `br` / `br_if` forms above.

## Implementation

`src/passes/optimize_instructions.mbt` now threads the descriptor child block id into the standalone child-control predicate. The predicate still rejects nested structured control, EH, branch tables, `br_on_*`, returns, throws, delegates, catches, and multivalue nodes, but it allows `br` and `br_if` when their label owner is contained in the nullable child block. The block proof also accepts a terminal internal `br` as the block's final root; branch-free and fallthrough-final-`local.get` proofs remain unchanged.

## Tests and validation

Updated red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc branch-free block null checks`

Red result before implementation:

```text
... failed: func code[4] ... body_raw: (block ... (local.get (Local 1))(br (Label 0))(end))ref.as_non_null(ref.get_desc (Type 0))(end)
```

Green focused result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc branch-free block null checks'
Total tests: 1, passed: 1, failed: 0.
```

The updated test now checks default-mode self-contained `br` and `br_if` children remove `ref.as_non_null`, and also checks TNH self-contained `br` and `br_if` children keep the block under `ref.get_desc` without the explicit null check. Existing fail-closed checks still cover `if`, `loop`, `try_table`, ordinary non-descriptor `ref.as_non_null`, and descriptor-operand behavior outside this standalone-root slice.

Additional validation after implementation:

```text
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null
moon fmt
moon info
moon test
moon build --target native --release src/cmd
```

JSON validation, `moon fmt`, `moon info`, full `moon test` (`7424/7424`), and native `src/cmd` build passed, with pre-existing warnings where emitted. Manual default/TNH Starshine replays for probes 05 and 06 validated with `wasm-tools --features all` and printed zero residual `ref.as_non_null` instructions in both modes.

Focused descriptor-profile TNH smoke:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-self-contained-branch --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining blockers include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, useful-type-info and exactness breadth, TNH/IIT escaping/control descriptor surfaces beyond this self-contained standalone branch subset, and generalized descriptor effect/control localization.
