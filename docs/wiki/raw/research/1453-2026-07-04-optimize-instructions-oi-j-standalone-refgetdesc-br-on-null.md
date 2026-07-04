# OI-J standalone `ref.get_desc` self-contained `br_on_null` slice

Date: 2026-07-04

## Scope

This finite slice extends standalone `ref.get_desc(ref.as_non_null(block ...))` cleanup to one self-contained `br_on_null` trampoline shape:

```wat
(ref.get_desc $a
  (ref.as_non_null
    (block $b (result (ref null $a))
      (block $n
        (local.get $x)
        (br_on_null $n)
        (br $b))
      (ref.null $a))))
```

The inner zero-result block must catch the null branch, the non-null fallthrough must immediately branch to the descriptor child block, and the outer fallthrough must be an explicit nullable `ref.null`. The rewrite only retargets the standalone `ref.get_desc` child from the explicit `ref.as_non_null` node to the original nullable outer block node.

Out of scope: arbitrary nested control, escaping labels, `br_on_cast`, `br_on_cast_fail`, descriptor-cast descriptor operands, EH, multivalue children, broader descriptor/exactness behavior, and `ref.test_desc`.

## Binaryen evidence

A local Binaryen `version_130` probe in `.tmp/oi-j-next-probes/br-on-null-nested.wat` shows `wasm-opt --all-features --optimize-instructions -S` removing the explicit `ref.as_non_null` for the self-contained `br_on_null` trampoline child. Binaryen prints the outer block directly under `ref.get_desc`, with the inner zero-result block containing `br_on_null` and the non-null fallthrough branch, followed by the explicit `ref.null none` outer fallthrough.

The locality proof is deliberately narrow: the child block stays in place, the null branch reaches only the inner zero-result block and then the explicit null fallthrough, and the non-null fallthrough immediately branches to the outer nullable child block. The removed `ref.as_non_null` and the remaining `ref.get_desc` therefore trap on the same null outer block result.

## Implementation

`src/passes/optimize_instructions.mbt` now recognizes only this standalone `br_on_null` trampoline in the block-child null-check proof. The helper requires:

- an outer block with one nullable reference result;
- a zero-result inner `Block` root before the final `RefNull`;
- a `BrOnNull` targeting the inner block's own label, fed by a nullable `LocalGet`;
- an immediate `Br` from the non-null fallthrough to the outer descriptor child block; and
- no extra roots or generalized nested-control acceptance.

The previous `br_on_non_null` proof and this new trampoline proof share the final explicit `RefNull` acceptance path, but other `br_on_*` forms remain fail-closed.

## Tests and validation

New red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc br_on_null block null checks`

Red result before implementation:

```text
failed: expected self-contained br_on_null block child, got Heap
```

Green focused results after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc br_on_null block null checks'
Total tests: 1, passed: 1, failed: 0.

moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc*'
Total tests: 4, passed: 4, failed: 0.
```

Additional validation for this slice passed:

```text
python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null
moon info
moon fmt
moon test
moon build --target native --release src/cmd
git diff --check
```

Full `moon test` passed `7427/7427`; the native `src/cmd` build passed with pre-existing warnings. Manual default and TNH Starshine replays for `.tmp/oi-j-next-probes/br-on-null-nested.wat` validated with `wasm-tools --features all`, printed one `br_on_null`, and printed zero residual `ref.as_non_null` instructions in both modes.

Focused descriptor-profile TNH smoke:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-br-on-null --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining blockers include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, useful-type-info and exactness breadth, broader TNH/IIT escaping/control descriptor surfaces, `br_on_cast*` standalone/control children, EH/control descriptor surfaces, and generalized descriptor effect/control localization.
