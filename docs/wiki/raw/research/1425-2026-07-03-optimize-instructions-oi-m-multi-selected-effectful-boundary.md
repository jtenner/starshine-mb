# Optimize-instructions OI-M multi-selected effectful boundary

Date: 2026-07-03

## Question

Does `OI-M-SB005-generalized-tuple-scratch-reconstruction-localization` require Starshine to mimic Binaryen's local-heavy scalarization for the generated `oi-tuple:multi-selected-effectful-lanes` cases, or can this generated two-selected-lane effectful subset be documented as an evidence-backed Starshine-win boundary?

This slice investigates only the generated shape where a branch-free four-result block is materialized twice, the direct `i32` lane and an effectful helper-produced `i64` lane are each selected once, and the selected scalars are dropped. The grouped representatives include OI-M metamorphic wrappers around that generated shape, including effectful-sibling scaffolding outside the tuple shell and one local-carried wrapper. This does **not** close arbitrary multi-selected tuple-scratch reconstruction, source-visible producer wrappers, runtime-exported multi-selected returns, mixed effect/trap tuple wrappers, branch/EH/control-transfer reconstruction, or generalized tuple-scratch localization.

## Representative cases

Direct representatives from the existing direct lane:

- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000022-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000046-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000070-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000086-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000108-gen-valid`

Grouped representatives from the refreshed grouped OI-M lane:

- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000022-gen-valid-transform-oi-effectful-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000046-gen-valid-transform-oi-effectful-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000070-gen-valid-transform-oi-effectful-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000086-gen-valid-transform-oi-effectful-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000108-gen-valid-transform-oi-local-carried`

The direct input repeats this branch-free four-result block twice:

```wat
(block (result i32 i64 f32 f64)
  (i32.const 11)
  (call 1)
  (f32.const 33)
  (f64.const 44))
```

The helper call performs a `global.set` before returning `i64.const 22`. The first materialization stores all four lanes and drops `local.get 0`; the second materialization stores all four lanes and drops `local.get 1`. Binaryen v130 `--optimize-instructions` scalarizes the repeated block shells to straight-line locals. Starshine preserves nested block-result expression spelling. Both tools eliminate `tuple.make`/`tuple.extract` and preserve matching scalar local traffic, helper calls, and global effects in the inspected representatives.

## Evidence

Direct lane source artifact:

```sh
bun scripts/pass-fuzz-compare.ts --count 108 --seed 0x5eed \
  --pass optimize-instructions \
  --gen-valid-profile pass-oi-tuple \
  --out-dir .tmp/oi-m-effectful-scratch-count108-20260701 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --jobs auto --runtime-execution node \
  --max-failures 2000 --keep-going-after-command-failures
```

Result summary from `result.json`:

- Compared `108/108` cases.
- Normalized matches `0`, cleanup-normalized matches `0`, raw mismatches `108`.
- Validation, generator, property, command, and runtime failures: all `0`.
- Runtime checked/unsupported/failed: `108/0/0`.
- Runtime matrix: `all-equal total=9`.
- Binaryen cache hits/misses: `97/11`.
- `oi-tuple:multi-selected-effectful-lanes` sampled `5` cases.

Grouped OI-M lane source artifact:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --count 108 \
  --out-dir .tmp/oi-m-effectful-scratch-grouped-count108-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --execute -- --max-failures 2000 \
  --keep-going-after-command-failures --runtime-execution node
```

Summarized with:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M \
  --out-dir .tmp/oi-m-effectful-scratch-grouped-count108-20260703 \
  --summarize-existing
```

Grouped summary:

- Compared `108/108` cases.
- Normalized matches `0`, cleanup-normalized matches `0`, raw mismatches `108`.
- Validation, generator, property, and command failures: all `0`.
- Runtime checked/unsupported/failed: `108/0/0`.
- Runtime matrix: `all-equal total=9`, semantic mismatches `0`.
- Binaryen cache hits/misses: `108/0`.
- All 18 `pass-oi-tuple` labels sampled; `oi-tuple:multi-selected-effectful-lanes` sampled `5` cases.
- Raw mismatch caveat remains active: mismatches are only accepted after agent classification.

Focused validation:

```sh
wasm-tools validate --features all <representative>/binaryen.wasm
wasm-tools validate --features all <representative>/starshine.wasm
```

All 20 Binaryen/Starshine canonical artifacts for the five direct and five grouped representatives validated.

Direct representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000022/000046/000070/000086/000108 direct total | 865 | 630 | -235 | 955 | 865 | -90 | 8800 | 10750 | +1950 |

Direct opcode counts for the five representatives match between Binaryen and Starshine: `local.set=130/130`, `local.get=100/100`, `local.tee=10/10`, `drop=10/10`, `call=10/10`, `global.set=5/5`, `i32.const=10/10`, `i64.const=15/15`, `f32.const=10/10`, and `f64.const=10/10`. Starshine has `block=30` where Binaryen has `block=0`, which is the measured block-result spelling difference.

Grouped representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000022/000046/000070/000086/000108 grouped total | 1296 | 1062 | -234 | 1381 | 1296 | -85 | 13411 | 15361 | +1950 |

Grouped opcode counts also match for scalar local traffic, selected-lane helper effects, and wrapper scaffolding: `local.set=132/132`, `local.get=102/102`, `local.tee=10/10`, `drop=36/36`, `call=10/10`, `global.set=45/45`, `i32.const=106/106`, `i64.const=15/15`, `f32.const=10/10`, `f64.const=10/10`, and `select=8/8`. Starshine has `block=38` where Binaryen has `block=8`; the extra Starshine blocks are retained result-expression spelling, while the grouped transform scaffolding is preserved on both sides.

## Classification

The generated `oi-tuple:multi-selected-effectful-lanes` residual subset is an evidence-backed Starshine-win boundary, not a P0 implementation blocker by itself, while the measured preconditions hold:

- The tuple shell is branch-free and EH-free.
- The selected lanes are exactly the generated direct `i32` lane plus the generated helper-produced `i64` lane.
- Both tools preserve matching scalar local traffic, helper call count, `global.set` effects, constants, and grouped wrapper scaffolding in the inspected representatives.
- Both raw and canonical Starshine wasm remain smaller than Binaryen's scalarized-local output.
- The direct and grouped lanes have zero validation/generator/property/command/runtime failures and no sampled runtime semantic mismatches.

This does **not** generalize to the rest of `OI-M-SB005`. Generalized tuple-scratch reconstruction remains active for multiple selected lanes beyond this generated two-lane smoke, source-visible producer wrappers, mixed effect/trap tuple wrappers, runtime-exported multi-selected behavior, branch/EH/control-transfer reconstruction, and any future representative where Starshine loses raw/canonical size or validation/runtime/effect-order evidence fails.

## Reopening criteria

Reopen this narrow boundary if any of the following occur:

- A generated branch-free multi-selected effectful representative fails validation.
- A runtime-exported multi-selected variant reports a semantic mismatch, trap drift, unsupported runtime regression, or returned-lane drift.
- Scalar local traffic, helper calls, constants, or `global.set` effects are removed, duplicated, or reordered in a way that changes semantics.
- Grouped OI-M transform scaffolding changes effect/order behavior around the tuple shell.
- Starshine becomes raw/canonical larger than Binaryen for this subset.
- Binaryen source/lit/probe evidence shows scalarized-local output is required for semantics rather than a representation choice.
- A representative includes source-visible producer wrappers, live traps beyond the generated helper effect, branches or EH inside the tuple shell, escaping labels, local-carried tuple values, or additional selected consumers beyond this generated smoke.
- The OI-M summary tooling stops reporting runtime/failure/profile/case-label fields needed to classify residuals.

## Sources

- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/result.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000022-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000046-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000070-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000086-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000108-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/result.json`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000022-gen-valid-transform-oi-effectful-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000046-gen-valid-transform-oi-effectful-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000070-gen-valid-transform-oi-effectful-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000086-gen-valid-transform-oi-effectful-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000108-gen-valid-transform-oi-local-carried/{input.print.wat,binaryen.wat,starshine.wat}`
- `scripts/oi-parity-sweep.ts --summarize-existing`
