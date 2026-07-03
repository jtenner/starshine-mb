# Optimize-instructions OI-M all-result selected-lane boundary

Date: 2026-07-03

## Question

Does `OI-M-SB005-generalized-tuple-scratch-reconstruction-localization` require Starshine to mimic Binaryen's local-heavy scalarization for the generated `oi-tuple:selected-lane-all-results` cases, or can the branch-free generated all-result selected-lane subset be documented as an evidence-backed Starshine-win boundary?

This slice investigates only the generated shape where a pure four-result block is materialized four times and each scalar lane is stored, reloaded, and dropped. The refreshed grouped lane also includes two pure `oi-tuple-selected-lane` transformed representatives and one synthetic branch-free trapping-sibling representative. This does **not** close generalized all-result materialization with source-visible effects, runtime-exported all-result returns, producer wrappers, multiple selected live consumers, mixed effect/trap tuple wrappers, branch/EH/control-transfer reconstruction, or arbitrary tuple-scratch reconstruction.

## Representative cases

Direct representatives from the existing direct lane:

- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000005-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000097-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000107-gen-valid`

Grouped representatives from the refreshed grouped OI-M lane:

- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000005-gen-valid-transform-oi-tuple-selected-lane`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000097-gen-valid-transform-oi-tuple-selected-lane`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000107-gen-valid-transform-oi-trapping-sibling`

The direct input repeatedly evaluates this pure four-result block:

```wat
(block (result i32 i64 f32 f64)
  (i32.const 11)
  (i64.const 22)
  (f32.const 33)
  (f64.const 44))
```

Each result lane is stored to locals, then one lane is reloaded and dropped. Binaryen v130 `--optimize-instructions` scalarizes the repeated all-result shells to straight-line local traffic. Starshine preserves a more nested block-result expression spelling. Both tools eliminate `tuple.make`/`tuple.extract` and preserve matching scalar local traffic for the inspected representatives.

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
- `oi-tuple:selected-lane-all-results` sampled `3` cases.

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
- All 18 `pass-oi-tuple` labels sampled; `oi-tuple:selected-lane-all-results` sampled `3` cases.
- Raw mismatch caveat remains active: mismatches are only accepted after agent classification.

Focused validation:

```sh
wasm-tools validate --features all <representative>/binaryen.wasm
wasm-tools validate --features all <representative>/starshine.wasm
```

All 12 Binaryen/Starshine canonical artifacts for the three direct and three grouped representatives validated.

Direct representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000005/000097/000107 direct total | 783 | 507 | -276 | 906 | 783 | -123 | 9294 | 11625 | +2331 |

Direct opcode counts for the three representatives match between Binaryen and Starshine: `local.set=156/156`, `local.get=120/120`, `local.tee=12/12`, `drop=12/12`, `i32.const=12/12`, `i64.const=12/12`, `f32.const=12/12`, and `f64.const=12/12`. Starshine has `block=36` where Binaryen has `block=0`, which is the measured block-result spelling difference.

Grouped representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000005/000097/000107 grouped total | 1249 | 819 | -430 | 1468 | 1249 | -219 | 15747 | 19644 | +3897 |

Grouped opcode counts also match for scalar local traffic and constants: `local.set=260/260`, `local.get=200/200`, `local.tee=20/20`, `drop=24/24`, `i32.const=26/26`, `i64.const=22/22`, `f32.const=20/20`, and `f64.const=20/20`. The one synthetic trapping-sibling grouped representative preserves `i32.div_u=1/1` and `i64.div_u=1/1`; this is a dead branch-free trapping-sibling smoke, not proof for arbitrary live trapping tuple children.

## Classification

The generated branch-free `oi-tuple:selected-lane-all-results` residual subset is an evidence-backed Starshine-win boundary, not a P0 implementation blocker by itself, while the measured preconditions hold:

- The direct all-result materialization shape is pure, branch-free, and EH-free.
- Both tools preserve matching scalar local traffic and constants in the inspected direct representatives.
- The grouped representatives preserve the same scalar local traffic, and the synthetic trapping-sibling sample preserves the generated divide-by-zero carriers.
- Both raw and canonical Starshine wasm remain smaller than Binaryen's scalarized-local output.
- The grouped lane has zero validation/generator/property/command/runtime failures and no sampled runtime semantic mismatches.

This does **not** generalize to the rest of `OI-M-SB005`. Generalized tuple-scratch reconstruction remains active for all-result variants with source-visible effects, runtime-exported all-result behavior, mixed effect/trap wrappers, broader producer wrappers, multiple selected consumers, branch/EH/control-transfer reconstruction, and any future representative where Starshine loses raw/canonical size or validation/runtime/effect-order evidence fails.

## Reopening criteria

Reopen this narrow boundary if any of the following occur:

- A generated branch-free all-result selected-lane representative fails validation.
- A runtime-exported all-result variant reports a semantic mismatch, trap drift, unsupported runtime regression, or returned-lane drift.
- Scalar local traffic, constants, or synthetic trap carriers are removed, duplicated, or reordered in a way that changes semantics.
- Starshine becomes raw/canonical larger than Binaryen for this subset.
- Binaryen source/lit/probe evidence shows scalarized-local output is required for semantics rather than a representation choice.
- A representative includes source-visible effects, live traps, branches, EH, escaping labels, local-carried tuple values, producer wrappers, or multiple selected live consumers beyond this generated smoke.
- The OI-M summary tooling stops reporting runtime/failure/profile/case-label fields needed to classify residuals.

## Sources

- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/result.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000005-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000097-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000107-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/result.json`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000005-gen-valid-transform-oi-tuple-selected-lane/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000097-gen-valid-transform-oi-tuple-selected-lane/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000107-gen-valid-transform-oi-trapping-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `scripts/oi-parity-sweep.ts --summarize-existing`
