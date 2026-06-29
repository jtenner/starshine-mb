# RemoveUnusedBrs dedicated profile validation reduction

Date: 2026-06-29

## Scope

Continuation of `[O4Z-AUDIT-RUB-Q]` final closeout. The previous dedicated `remove-unused-brs-all` compact lane failed before comparison with `1000` Starshine output validation failures. This slice reduced the first failure and added a focused guard, but did **not** clear the dedicated-profile blocker.

## Reduction

Primary artifact:

- `.tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3/failures/case-000001-gen-valid`
- Manifest: `selected_profile=remove-unused-brs-control`, `seed=24301`, `index=1`
- Failure: Starshine output failed wasm-tools validation with `func 1 failed to validate: type mismatch: expected i64 but nothing on stack (at offset 0x429)`.

The printed Starshine output showed a value-returning function ending in a void block whose body performed a stack-form multi-value `return`, with the original trailing result-producing `local.get` suffix removed:

```wat
block
  i32.const 925
  i64.const 965
  return
end
```

A reduced public WAT shape reproduces the invalid output after `--remove-unused-brs`:

```wat
(module
  (func (result i32 i64)
    (local i32 i64)
    block
      i32.const 1
      i64.const 2
      return
      unreachable
    end
    local.get 0
    local.get 1))
```

No-pass Starshine preserves the suffix and wasm-tools validates the output. Direct `--remove-unused-brs` currently lowers/encodes an invalid function that drops the suffix.

## Code changes in this slice

- Added focused HOT coverage in `src/passes/remove_unused_brs_test.mbt` ensuring RUB itself keeps the value-producing suffix after a void nonfallthrough block and that direct HOT lowering still exposes the two suffix `local.get` roots.
- Added conservative guards in `src/passes/remove_unused_brs.mbt`, `src/ir/hot_lower.mbt`, and `src/passes/pass_manager.mbt` so void structured control is not casually treated as a value-producing nonfallthrough suffix killer in the touched helpers.

Important caveat: these changes are not sufficient for CLI/pass-fuzz closeout. The public reduced WAT still produces invalid wasm through the full command path, and the dedicated profile still reports `1000` validation failures.

## Commands and results

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` after adding the first public-pipeline regression failed red: the optimized output lost the value-producing suffix and internal validation reported the reduced invalid body.
- After switching to focused HOT/lowering coverage and guards: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed, `213/213`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Reduced public CLI replay remained invalid:
  - Input: `.tmp/rub-public-regression.wasm`
  - Command: `target/native/release/build/cmd/cmd.exe .tmp/rub-public-regression.wasm --remove-unused-brs -o .tmp/rub-public-regression-out3.wasm`
  - `wasm-tools validate --features all .tmp/rub-public-regression-out3.wasm` failed with `expected i64 but nothing on stack`.
- Original failure replay remained invalid:
  - Command: `target/native/release/build/cmd/cmd.exe .tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-compact-norm3/failures/case-000001-gen-valid/input.wasm --remove-unused-brs -o .tmp/rub-case-000001-after-cleanup-fix.wasm`
  - `wasm-tools validate --features all .tmp/rub-case-000001-after-cleanup-fix.wasm` failed.
- Dedicated profile rerun remained blocked:
  - `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --gen-valid-profile remove-unused-brs-all --normalize drop-consts --normalize unreachable-control-debris --normalize local-cleanup-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-dedicated-all-1000-after-void-structured-suffix --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: `0/1000` compared, `1000` Starshine validation failures, `0` generator/property/command failures, `0` mismatches.

## Current classification

Superseded for current source by [`1389-2026-06-29-remove-unused-brs-dedicated-validation-unblocked.md`](1389-2026-06-29-remove-unused-brs-dedicated-validation-unblocked.md). The validation-failure conclusion below applied to the stale command replay captured in this note; the next slice found that `target/native/release/build/cmd/cmd.exe` was stale in this workspace and that the current `_build/native/release/build/cmd/cmd.exe` preserves the reduced suffix and validates. The remaining dedicated-profile blocker is now output-shape mismatch classification, not the `1000/1000` validation failure described here.

Historical classification: the blocker was a Starshine correctness/validation failure, not a generator, Binaryen, command, or normalizer issue. The reduced family was a value-returning function where RUB/full command cleanup removed the trailing value suffix after a void structured block containing stack-form function `return`/`unreachable` debris.

## Next steps

1. Continue from the reduced public WAT and compare HOT roots before pass, after `hot_pass_run`, after HOT lowering, after pass-manager `run_hot_pipeline_canonicalize_lowered_func_for_descriptor`, and after final module encode. The focused HOT test proves one local path keeps the suffix, so the remaining loss is likely a full-pipeline lowered/module cleanup or a distinct raw/stack path.
2. Add the failing full-pipeline regression once the exact owner can be exercised without relying on the project validator's current polymorphic-stack disagreement.
3. Rerun `.tmp/rub-public-regression.wasm`, the original `case-000001`, and then the dedicated `remove-unused-brs-all` `1000` lane. Only attempt the `10000` lane after the `1000` lane has zero validation failures.
