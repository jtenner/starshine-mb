# OI-J standalone `ref.get_desc` self-contained `br_on_cast` slice

Date: 2026-07-04

## Scope

This finite slice extends standalone `ref.get_desc(ref.as_non_null(block ...))` cleanup to one self-contained ordinary `br_on_cast` shape:

```wat
(ref.get_desc $a
  (ref.as_non_null
    (block $b (result (ref null $a))
      (local.get $x)
      (br_on_cast $b (ref null $a) (ref $a)))))
```

The `br_on_cast` success branch must target the nullable descriptor child block itself, the source and target heaps must be identical, the source must be nullable, the target must be non-null, and the tested value must be a nullable `local.get` of that same heap. The rewrite only retargets the standalone `ref.get_desc` child from the explicit `ref.as_non_null` node to the original nullable block node.

Out of scope: `br_on_cast_fail`, descriptor `br_on_cast_desc*` forms, arbitrary cast targets, escaping labels, payload prefixes, effectful or control-shaped tested operands, descriptor-cast descriptor operands, EH, multivalue children, broader descriptor/exactness behavior, and `ref.test_desc`.

## Binaryen evidence

A local Binaryen `version_130` probe in `.tmp/oi-j-next-probes/br-on-cast-self-contained.wat` shows `wasm-opt --all-features --optimize-instructions -S` removing the explicit `ref.as_non_null` for the self-contained nullable-to-non-null same-heap `br_on_cast` child. Binaryen prints the block directly under `ref.get_desc`, with the `br_on_cast` still targeting the child block:

```wat
(ref.get_desc $a
  (block $b (result (ref null $a))
    (br_on_cast $b (ref null $a) (ref $a)
      (local.get $x))))
```

The same probe under `--traps-never-happen` has the same relevant shape: the explicit `ref.as_non_null` is absent and the `br_on_cast` remains in the child block.

The locality proof is deliberately narrow: the child block stays in place, a successful cast branches to the child block with the non-null value, and the only failure case for nullable-to-non-null same-heap is the original nullable local falling through as null. The removed `ref.as_non_null` and the remaining `ref.get_desc` therefore trap on the same null block result.

## Implementation

`src/passes/optimize_instructions.mbt` now recognizes only this standalone `br_on_cast` final-root shape in the block-child null-check proof. The helper requires:

- an outer block with one nullable reference result;
- a final `BrOnCast` root whose label is owned inside the descriptor child block;
- exactly one child, which must be a nullable `LocalGet`;
- `source_nullable == true`, `target_nullable == false`, and identical source/target heaps; and
- the local child's nullable heap must match the cast source heap.

Other `br_on_cast` placements, `br_on_cast_fail`, effectful children, payload-bearing forms, and escaping labels remain fail-closed.

## Tests and validation

New red-first focused test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc br_on_cast block null checks`

Red result before implementation:

```text
failed: expected self-contained br_on_cast block child, got Heap
```

Green focused results after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc br_on_cast block null checks'
Total tests: 1, passed: 1, failed: 0.

moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc*'
Total tests: 5, passed: 5, failed: 0.
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

Full `moon test` passed `7428/7428`; the native `src/cmd` build passed with pre-existing warnings. Manual default and TNH Starshine replays for `.tmp/oi-j-next-probes/br-on-cast-self-contained.wat` validated with `wasm-tools --features all`, printed one `br_on_cast`, and printed zero residual `ref.as_non_null` instructions in both modes.

Focused descriptor-profile TNH smoke:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-br-on-cast --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface`. Remaining blockers include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, useful-type-info and exactness breadth, broader TNH/IIT escaping/control descriptor surfaces, `br_on_cast_fail` standalone/control children, EH/control descriptor surfaces, and generalized descriptor effect/control localization.
