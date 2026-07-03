# Optimize-instructions OI-M effectful scratch-localized multivalue boundary

Date: 2026-07-03

## Question

Does the `OI-M-SB005-generalized-tuple-scratch-reconstruction-localization` residual bucket require Starshine to mimic Binaryen's local-heavy scalarization for generated `oi-tuple:effectful-scratch-localized-selected-lane` cases, or can a narrow effectful selected-lane subset be documented as an evidence-backed Starshine-win boundary?

This slice only investigates the branch-free selected-lane smoke where the selected `i32` lane is produced by a helper that performs `global.set`, then the selected scalar is spilled through local scratch traffic after tuple result materialization. It does **not** close all-result materialization, multiple selected lanes, runtime-exported effectful scratch variants, mixed effect/trap wrappers, local-carried tuple values, producer wrappers beyond this smoke, branch/EH/control-transfer siblings, or generalized structured tuple-scratch reconstruction.

## Representative cases

Inspected direct representatives from the existing direct lane:

- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000081-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000083-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000091-gen-valid`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000095-gen-valid`

Inspected grouped representatives from the refreshed grouped OI-M lane:

- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000081-gen-valid-transform-oi-tuple-selected-lane`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000083-gen-valid-transform-oi-trapping-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000091-gen-valid-transform-oi-trapping-sibling`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000095-gen-valid-transform-oi-trapping-sibling`

The direct input evaluates a four-result block, with the selected `i32` lane produced by a helper call that performs `global.set 0` and returns `77`; the remaining lanes are constants. The tuple results are stored to scratch locals and the selected scalar lane is reloaded and dropped.

Binaryen v130 `--optimize-instructions` scalarizes these shapes into straight-line local traffic. Starshine preserves a more nested block-result expression spelling. In both outputs, the helper call, `global.set`, `local.tee`, scratch `local.set`/`local.get`, and drop counts match for the inspected representatives.

## Evidence

Direct lane summary from the existing artifact:

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
- Normalized matches `0`, raw mismatches `108`.
- Validation, generator, property, command, and runtime failures: all `0`.
- Runtime checked/unsupported/failed: `108/0/0`.
- Runtime matrix: `all-equal total=9`.
- `oi-tuple:effectful-scratch-localized-selected-lane` sampled `4` cases.
- Binaryen cache hits/misses: `97/11`.

Refreshed grouped OI-M sweep:

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
- All 18 `pass-oi-tuple` labels sampled; `oi-tuple:effectful-scratch-localized-selected-lane` sampled `4` cases.
- Raw mismatch caveat remains active: mismatches are only accepted after agent classification.

Focused validation:

```sh
wasm-tools validate --features all <representative>/binaryen.wasm
wasm-tools validate --features all <representative>/starshine.wasm
```

All 16 Binaryen/Starshine canonical artifacts for the four direct and four grouped representatives validated.

Direct representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000081/000083/000091/000095 direct total | 488 | 396 | -92 | 508 | 488 | -20 | 4220 | 5004 | +784 |

Direct opcode counts for the four representatives match between Binaryen and Starshine: `call=4/4`, `global.set=4/4`, `local.set=56/56`, `local.get=44/44`, `local.tee=4/4`, and `drop=4/4`.

Grouped representative aggregate size/opcode check:

| Cases | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000081/000083/000091/000095 grouped total | 1098 | 834 | -264 | 1214 | 1098 | -116 | 12183 | 14523 | +2340 |

Grouped opcode counts for the four representatives also match: `call=4/4`, `global.set=4/4`, `local.set=160/160`, `local.get=124/124`, `local.tee=12/12`, and `drop=36/36`.

## Classification

The branch-free `oi-tuple:effectful-scratch-localized-selected-lane` residual subset is an evidence-backed Starshine-win boundary, not a P0 implementation blocker by itself, while the measured preconditions hold:

- The selected lane's only effect is the preserved helper call and `global.set` before the selected value is returned.
- The shape is branch-free and EH-free.
- Both tools preserve the inspected helper/effect/local/drop traffic counts.
- Both raw and canonical Starshine wasm remain smaller than Binaryen's scalarized-local output.
- The grouped lane has zero validation/generator/property/command/runtime failures and no sampled runtime semantic mismatches.

The effectful scratch case itself is not runtime-exported in the inspected generator shape, so this boundary relies on structural/effect-order inspection plus whole-lane runtime smoke for the exported tuple cases. Add or require runtime-exported effectful scratch coverage before claiming broader runtime-observable closure.

This does **not** generalize to the rest of `OI-M-SB005`. Generalized tuple-scratch reconstruction remains active for all-result materialization, multiple selected lanes, mixed effect/trap wrappers, broader producer wrappers, branch/EH/control-transfer reconstruction, runtime-exported variants of this effectful scratch shape, and any future representative where Starshine loses raw/canonical size or validation/runtime/effect-order evidence fails.

## Reopening criteria

Reopen this narrow boundary if any of the following occur:

- An effectful scratch-localized selected-lane representative fails validation.
- A runtime-exported variant reports a semantic mismatch, trap drift, unsupported runtime regression, or selected-lane return drift.
- The helper call or `global.set` is removed, duplicated, or reordered relative to selected-lane scratch traffic.
- Scratch local traffic is lost in a way that changes semantics or obscures effect/trap order.
- Starshine becomes raw/canonical larger than Binaryen for this subset.
- Binaryen source/lit/probe evidence shows scalarized-local output is required for semantics rather than a representation choice.
- A representative includes traps, branches, EH, escaping labels, local-carried tuple values, multiple selected lanes, all-result consumers, or broader producer wrappers.
- The OI-M summary tooling stops reporting runtime/failure/profile/case-label fields needed to classify residuals.

## Sources

- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/result.json`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000081-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000083-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000091-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-count108-20260701/failures/case-000095-gen-valid/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/result.json`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000081-gen-valid-transform-oi-tuple-selected-lane/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000083-gen-valid-transform-oi-trapping-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000091-gen-valid-transform-oi-trapping-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-effectful-scratch-grouped-count108-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000095-gen-valid-transform-oi-trapping-sibling/{input.print.wat,binaryen.wat,starshine.wat}`
- `scripts/oi-parity-sweep.ts --summarize-existing`
