# Local-subtyping closeout lane evidence

Date: 2026-07-03

## Question

Refresh the remaining direct `local-subtyping` closeout evidence after the generated `local-subtyping-all` profile gained the unreachable-tail leaf, and identify whether the audit can close or which blockers remain.

## Commands and results

All commands used `_build/native/release/build/cmd/cmd.exe` as the explicit Starshine binary.

- `moon info` passed with the existing warnings in `binary/decode.mbt`, `binary/encode.mbt`, `ir/hot_verify.mbt`, `validate/gen_valid.mbt`, and `validate/gen_valid_ssa.mbt`.
- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file local_subtyping_test.mbt` passed `63/63`.
- `moon test` passed `7379/7379`.
- `moon build --target native --release src/cmd` reported no work to do.
- Regular GenValid closeout lane:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 100000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-genvalid-100000-20260703 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: requested/compared `100000/100000`, normalized `100000`, cleanup-normalized `0`, mismatches `0`, validation/generator/property/command failures `0`.
  - Cache: wasm-smith `0/0`; Binaryen `1326` hits / `98674` misses; Binaryen failures `0/0`.
  - All cases came from `binaryen-oracle-portable` and had unreachable/may-trap feature flags.
- Explicit wasm-smith closeout lane:
  - Command: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass local-subtyping --out-dir .tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260703 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `0`, mismatches `1`, validation/generator/property failures `0`, command failures `44`.
  - Command-failure classes: Binaryen rec-group-zero `39`, Binaryen invalid-tag-index `1`, Binaryen table-index-out-of-range `1`, Binaryen bad-section-size `3`.
  - Cache: wasm-smith `10000` hits / `0` misses; Binaryen `106` hits / `9850` misses; Binaryen failures `0` hits / `44` misses.
- wasm-smith cleanup-normalized replay:
  - Command: `bun scripts/pass-fuzz-compare.ts --wasm-smith --count 10000 --seed 0x5eed --pass local-subtyping --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260703-unreachable-normalized --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: requested `10000`, compared `9956`, normalized `9955`, cleanup-normalized `1`, mismatches `0`, validation/generator/property failures `0`, command failures `44` with the same command-failure classes.
  - Cache: wasm-smith `10000` hits / `0` misses; Binaryen `9956` hits / `0` misses; Binaryen failures `44` hits / `0` misses.
- Ordered GC/local neighborhood attempt:
  - Command: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass heap2local --pass optimize-casts --pass local-subtyping --pass coalesce-locals --pass local-cse --out-dir .tmp/pass-fuzz-local-subtyping-gc-local-neighborhood-10000-20260703 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures`
  - Result: timed out after 3600s before `summary.json` or `result.json` was written. The partial `cases.jsonl` contains `200` cases: `18` matches and `182` mismatches, with `182` failure dirs.
  - Sample case `case-000001-gen-valid` is a generated portable/unreachable module. The mismatch is local declaration/count drift after the multi-pass neighborhood (`func $1` Binaryen keeps one `i32` local; Starshine has three `i64` locals plus one `i32`; `func $2` similarly keeps an extra local). This points at downstream local-cleanup/neighborhood representation and performance debt rather than direct LS narrowing behavior.

## wasm-smith mismatch classification

The sole raw wasm-smith mismatch is `.tmp/pass-fuzz-local-subtyping-wasm-smith-10000-20260703/failures/case-009332-wasm-smith`.

Input shape:

```wat
(func (param i31ref) (result i32)
  memory.size
  block (result i64)
    f64.const ...
    unreachable
  end
  unreachable)
```

Binaryen normalized output drops the unreachable result debris directly to a final `unreachable`. Starshine leaves an extra syntactic `drop (unreachable)` before the final `unreachable`.

Measured size direction for the normalized artifacts is Binaryen `77` bytes versus Starshine `79` bytes, so this is not a Starshine win. Agent classification: pass-independent unreachable-control cleanup debris / compare-normalizer residual, not an LS semantic mismatch and not evidence of a missing local-subtyping behavior family. The cleanup-normalized replay with `--normalize unreachable-control-debris` converts this case into the single cleanup-normalized match.

Reopening criteria: reopen under LS only if a reduced case shows the mismatch depends on LS-local declaration narrowing, get/tee retagging, dominance, or refinalization. Otherwise route any requirement for raw exact equality to the shared unreachable-control cleanup / normalizer owner, because adding generic unreachable cleanup to LS would mix pass responsibilities.

## Current closeout status

Progress:

- Regular 100000 GenValid lane is now green for the current binary.
- Explicit wasm-smith 10000 lane has no validation, generator, property, or LS-semantic mismatches; its one raw mismatch is a precise cleanup-debris residual and is cleanup-normalized by `--normalize unreachable-control-debris`.
- Focused LS tests, full Moon tests, formatting, info, and native build were refreshed.

Still open:

- Ordered GC/local neighborhood evidence is blocked by downstream neighborhood drift/performance, not direct LS evidence.
- The final LS behavior-family review remains open, especially broader structural dominance, EH/try_table post-state, loop/if joins, broad get/tee expression retagging, repeated refinalization, and the direct block-return non-defaultable-local validator boundary.
- The dedicated `local-subtyping-all` and random-all-profiles lanes were green in the previous slice for this binary; rerun them only if code/generator behavior changes before final closeout.
