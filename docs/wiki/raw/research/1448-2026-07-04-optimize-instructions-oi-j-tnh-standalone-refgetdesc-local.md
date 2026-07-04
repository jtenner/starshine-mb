# OI-J TNH standalone `ref.get_desc` direct-local null-check slice

Date: 2026-07-04

## Scope

This slice covers one finite OI-J trap-mode gap from roadmap probe 03:

```wat
(func (param $x (ref null $a)) (result anyref)
  (ref.get_desc $a
    (ref.as_non_null (local.get $x))))
```

Binaryen `version_130` behavior:

- default `--optimize-instructions`: removes the explicit `ref.as_non_null`, relying on `ref.get_desc` to preserve the null trap;
- `--ignore-implicit-traps --optimize-instructions`: same as default for this direct-local shape;
- `--traps-never-happen --optimize-instructions`: also removes the explicit `ref.as_non_null`.

Starshine already matched default/IIT direct-local standalone behavior. Before this slice, Starshine kept the explicit `ref.as_non_null` in TNH mode because the standalone helper deliberately fail-closed all TNH paths.

This slice only admits the TNH direct-local child. TNH branch-free block children, control/EH/multivalue children, descriptor-cast descriptor operands, `ref.test_desc`, and broader descriptor/exactness/TNH/IIT behavior remain outside scope.

## Probe evidence

Probe directory: `.tmp/oi-j-tnh-standalone-refgetdesc-local-20260704/`.

Source input:

- `.tmp/oi-j-roadmap-probes-20260703/inputs/03-get-desc-as-non-null.wat`
- `.tmp/oi-j-roadmap-probes-20260703/inputs/03-get-desc-as-non-null.input.wasm`

Binaryen probe:

```text
wasm-opt --all-features --traps-never-happen --optimize-instructions -S \
  .tmp/oi-j-roadmap-probes-20260703/inputs/03-get-desc-as-non-null.wat \
  -o .tmp/oi-j-tnh-standalone-refgetdesc-local-20260704/binaryen-tnh.wat
```

Binaryen TNH prints `local.get` directly under `ref.get_desc` with no residual `ref.as_non_null`.

Pre-implementation Starshine TNH replay kept `local.get; ref.as_non_null; ref.get_desc`.

## Implementation

`src/passes/optimize_instructions.mbt` now lets `optimize_instructions_try_move_standalone_ref_get_desc_null_check` run in TNH mode only when the nullable child of `ref.as_non_null` is a direct `LocalGet`. The existing nullable-child checks still prove a single nullable reference result before replacing the `ref.get_desc` child with the original local.

The guard intentionally keeps TNH branch-free block children fail-closed for a future slice, even though default-mode branch-free blocks remain covered.

## Tests and validation

Updated red-first test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions moves standalone ref.get_desc branch-free block null checks`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc branch-free block null checks'
... failed: expected TNH direct-local child, got Heap
```

Green results after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions moves standalone ref.get_desc branch-free block null checks'
Total tests: 1, passed: 1, failed: 0.

moon test
Total tests: 7424, passed: 7424, failed: 0.
```

Native `src/cmd` build passed with pre-existing warnings. Manual TNH Starshine replay of roadmap probe 03 validated with `wasm-tools --features all` and printed one `ref.get_desc` with zero residual `ref.as_non_null`, matching the Binaryen TNH probe. The focused descriptor-profile TNH smoke remained clean:

```text
bun scripts/pass-fuzz-compare.ts --pass optimize-instructions --traps-never-happen --gen-valid-profile pass-oi-descriptor-gc --count 12 --seed 0x5eed --out-dir .tmp/oi-j-descriptor-tnh-compare-count12-20260704-standalone-refgetdesc-local --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures
Compared cases: 12/12; Normalized matches: 12; Mismatches: 0; failures: 0.
```

## Remaining OI-J work

OI-J remains `blocked-surface` after this slice. Active residuals include `ref.test_desc` representation/tooling, broader descriptor-cast behavior, TNH/IIT branch-free block/control descriptor surfaces, broader useful-type-info and exactness breadth, and generalized descriptor effect/control localization.
