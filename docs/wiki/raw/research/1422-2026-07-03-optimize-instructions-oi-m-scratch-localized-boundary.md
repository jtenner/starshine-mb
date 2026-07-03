# Optimize-instructions OI-M scratch-localized multivalue block boundary

Date: 2026-07-03

## Question

Does the `OI-M-SB005-generalized-tuple-scratch-reconstruction-localization` residual bucket require Starshine to mimic Binaryen's local-heavy scalarization for the generated `oi-tuple:scratch-localized-selected-lane` cases, or can a narrower subset be documented as an evidence-backed Starshine-win boundary?

This slice only investigates the branch-free, pure multivalue-block local-spill shape sampled in `.tmp/oi-m-tuple-scratch-count102b-20260630`. It does **not** close effectful scratch-localized lanes, all-result lanes, multi-selected lanes, local-carried tuple values, branch/EH/control-transfer siblings, or generalized structured tuple-scratch reconstruction.

## Representative cases

Inspected representatives:

- `.tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000017-gen-valid-transform-oi-tuple-selected-lane`
- `.tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000045-gen-valid-transform-oi-tuple-selected-lane`

Both inputs repeatedly evaluate a pure four-result block, store all lanes, then drop one selected scalar lane. Binaryen v130 `--optimize-instructions` scalarizes each multivalue block into many temporary scalar locals and drops the selected lane through those temps. Starshine preserves a more nested block-result expression spelling with fewer locals.

## Evidence

Existing grouped sweep summary:

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --out-dir .tmp/oi-m-tuple-scratch-count102b-20260630 --summarize-existing
```

Result summary:

- Compared `102/102` cases.
- Normalized matches `0`, raw mismatches `102`.
- Validation, generator, property, and command failures: all `0`.
- Runtime checked/unsupported/failed: `102/0/0`.
- Runtime matrix: `all-equal total=12`.
- `oi-tuple:scratch-localized-selected-lane` sampled `10` cases.
- Raw mismatch caveat remains active: mismatches are only accepted after agent classification.

Focused validation:

```sh
wasm-tools validate --features all \
  .tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000017-gen-valid-transform-oi-tuple-selected-lane/{binaryen.wasm,starshine.wasm}
wasm-tools validate --features all \
  .tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000045-gen-valid-transform-oi-tuple-selected-lane/{binaryen.wasm,starshine.wasm}
```

All four artifacts validated.

Size check for the two representatives:

| Case | Binaryen raw wasm | Starshine raw wasm | Raw delta | Binaryen canonical wasm | Starshine canonical wasm | Canonical delta | Binaryen WAT | Starshine WAT | WAT delta |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| 000017 | 320 | 220 | -100 | 373 | 320 | -53 | 3959 | 4934 | +975 |
| 000045 | 320 | 220 | -100 | 373 | 320 | -53 | 3959 | 4934 | +975 |

The WAT growth comes from Starshine's nested block-result expression spelling. The raw and canonical wasm artifacts are smaller for Starshine in both inspected representatives.

## Classification

The pure branch-free `oi-tuple:scratch-localized-selected-lane` residual subset is an evidence-backed Starshine-win boundary, not a P0 implementation blocker by itself, while the measured preconditions hold:

- The relevant multivalue producer is pure and branch-free.
- Runtime execution remains equal.
- Both raw and canonical Starshine wasm remain smaller than Binaryen's scalarized-local output.
- No effect/trap/control-transfer ordering is involved.

This does **not** generalize to the rest of `OI-M-SB005`. Generalized tuple-scratch reconstruction remains active for shapes where scalarization may be semantically required or size-winning for Binaryen, including effectful scratch-localized selected lanes, all-result materialization, multiple selected lanes, mixed effect/trap wrappers, producer wrappers, branch/EH/control-transfer reconstruction, and any future representative where Starshine loses raw/canonical size or runtime/validation evidence fails.

## Reopening criteria

Reopen this narrow boundary if any of the following occur:

- A pure branch-free scratch-localized selected-lane case fails validation or runtime equality.
- Starshine becomes raw/canonical larger than Binaryen for this subset.
- Binaryen source/lit/probe evidence shows scalarized-local output is required for semantics rather than a representation choice.
- A representative includes effects, traps, branches, EH, escaping labels, local-carried tuple values, or multiple selected/all-result consumers.
- The OI-M summary tooling stops reporting runtime/failure/profile/case-label fields needed to classify residuals.

## Sources

- `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`
- `.tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/result.json`
- `.tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000017-gen-valid-transform-oi-tuple-selected-lane/{input.print.wat,binaryen.wat,starshine.wat}`
- `.tmp/oi-m-tuple-scratch-count102b-20260630/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000045-gen-valid-transform-oi-tuple-selected-lane/{input.print.wat,binaryen.wat,starshine.wat}`
- `scripts/oi-parity-sweep.ts --summarize-existing`
