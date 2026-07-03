# OI-M Runtime-Exported Grouped Wrapper Evidence

Date: 2026-07-03

## Question

Does the grouped OI-M metamorphic lane preserve the new runtime-exported tuple generator labels from `1426`, or does grouped wrapping reopen OI-M-SB005 for those runtime-observable all-result, effectful scratch-localized, and multi-selected effectful representatives?

## Command

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --count 126 \
  --out-dir .tmp/oi-m-runtime-new-cases-grouped-count126-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --execute -- --runtime-execution node --max-failures 2000 \
  --keep-going-after-command-failures
```

Result row: `.tmp/oi-m-runtime-new-cases-grouped-count126-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/result.json`.

## Summary

The grouped wrapper lane compared 126/126 cases with 126 raw mismatches, zero validation/generator/property/command/runtime failures, and Node runtime execution checked/unsupported/failed 126/0/0. The runtime matrix was all-equal with 52 equal results. Binaryen cache hits/misses were 100/26.

All twenty-one `pass-oi-tuple` labels were sampled. The new runtime-exported labels were sampled as:

- `oi-tuple:runtime-all-results`: 6 residuals.
- `oi-tuple:runtime-effectful-scratch-localized-selected-lane`: 3 residuals.
- `oi-tuple:runtime-multi-selected-effectful-lanes`: 6 residuals.

The grouped lane used these transforms: `oi-tuple-selected-lane`, `oi-effectful-sibling`, `oi-trapping-sibling`, and `oi-local-carried`.

## Focused representatives

Manual `wasm-tools validate --features all` accepted raw and canonical Binaryen/Starshine artifacts for these representatives:

| Label / wrapper | Representative | Starshine raw/canonical | Binaryen raw/canonical | Observed structural facts |
| --- | --- | ---: | ---: | --- |
| runtime effectful scratch, selected-lane wrapper | `case-000005-gen-valid-transform-oi-tuple-selected-lane` | 390 / 578 | 578 / 679 | Matching counts for local.set/local.get/local.tee/call/global.set/constants/drop; Starshine raw/canonical smaller. |
| runtime multi-selected effectful, selected-lane wrapper | `case-000025-gen-valid-transform-oi-tuple-selected-lane` | 585 / 880 | 880 / 1041 | Matching counts for local.set/local.get/local.tee/call/global.set/constants/drop; Starshine raw/canonical smaller. |
| runtime all-results, local-carried wrapper | `case-000072-gen-valid-transform-oi-local-carried` | 308 / 392 | 392 / 433 | Matching counts for local traffic/constants/drop; no helper calls or global.set; Starshine raw/canonical smaller. |
| runtime all-results, effectful-sibling wrapper | `case-000086-gen-valid-transform-oi-effectful-sibling` | 460 / 552 | 552 / 593 | Matching counts for local traffic/constants/global.set/drop/select; Starshine raw/canonical smaller. |

## Classification

This narrows OI-M-SB005 for the grouped wrappers sampled around the three runtime-exported labels. It does **not** close generalized tuple-scratch reconstruction. The evidence is runtime-observable and grouped-wrapper-positive for the sampled labels, but remains bounded to generated branch-free representatives and the four current grouped transforms.

Keep OI-M active/P0 for:

- mixed effect+trap runtime-exported wrappers;
- multi-selected variants beyond the generated two-lane effectful smoke;
- broader producer wrappers;
- branch/EH/control-transfer tuple-scratch reconstruction under OI-M-SB004/OI-M-SB005;
- any raw mismatch without measured Starshine-win or source-backed boundary evidence.

This evidence does not close OI-G, OI-I, OI-J, or OI-K.
