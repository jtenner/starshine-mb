# Optimize-instructions OI-M runtime-exported scratch generator slice

Date: 2026-07-03

## Scope

This slice narrows `OI-M-SB005-generalized-tuple-scratch-reconstruction-localization` by adding runtime-observable `pass-oi-tuple` generator representatives for previously open runtime-exported tuple-scratch surfaces:

- `oi-tuple:runtime-all-results`
- `oi-tuple:runtime-effectful-scratch-localized-selected-lane`
- `oi-tuple:runtime-multi-selected-effectful-lanes`

This is generator/runtime evidence only. It does not close generalized tuple-scratch reconstruction, grouped wrapper variants, mixed effect/trap producer wrappers, or control/EH reconstruction.

## Red-first tests

Focused test:

```sh
moon test --package jtenner/starshine/validate --file gen_valid_tests.mbt -f 'OI-M tuple trigger-smoke profile selects distinct seed-indexed multivalue cases'
```

Red-first failures:

1. Seed `0x6000` labeled as `oi-tuple:localtee-produced-selected-lane` before `oi-tuple:runtime-all-results` existed.
2. Seed `0x6001` labeled as `oi-tuple:effectful-select-operand-selected-lane` before `oi-tuple:runtime-effectful-scratch-localized-selected-lane` existed.
3. Seed `0x6002` first labeled as `oi-tuple:runtime-all-results`, then the generated module lacked the runtime multi-selected signature until helper-effect detection covered helper functions beyond index 1.

After implementation, the focused test passed 1/1.

## Implemented generator shapes

`src/validate/gen_valid.mbt` now emits 21 seed-indexed `pass-oi-tuple` trigger cases.

### `oi-tuple:runtime-all-results`

Seed: `0x6000`.

Exports four lane-observing functions: `run_i32`, `run_i64`, `run_f32`, and `run_f64`. Each function materializes the same branch-free four-result multivalue block, stores all lanes into scalar locals, and returns one lane.

### `oi-tuple:runtime-effectful-scratch-localized-selected-lane`

Seed: `0x6001`.

Exports `run`. The selected i32 lane is produced by a helper that performs `global.set`, then the selected lane is stored and reloaded through scratch local traffic before return.

### `oi-tuple:runtime-multi-selected-effectful-lanes`

Seed: `0x6002`.

Exports `run_i32` and `run_i64`. Both functions materialize the same branch-free four-result block. The i64 lane is produced by a helper that performs `global.set`; the exported functions return the i32 and i64 selected lanes respectively.

## Runtime compare evidence

Command:

```sh
bun scripts/pass-fuzz-compare.ts --count 126 --seed 0x5eed --pass optimize-instructions --gen-valid-profile pass-oi-tuple --out-dir .tmp/oi-m-runtime-new-cases-count126-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --jobs auto --runtime-execution node --max-failures 2000 --keep-going-after-command-failures
```

Result:

- compared: 126/126
- normalized matches: 0
- raw mismatches: 126
- validation/generator/property/command failures: 0/0/0/0
- runtime checked/unsupported/failed: 126/0/0
- runtime matrix: all-equal, total 52, equal results 52, semantic mismatches 0
- Binaryen cache hits/misses: 113/13
- all 21 tuple labels sampled
- new label counts:
  - `oi-tuple:runtime-all-results`: 6
  - `oi-tuple:runtime-effectful-scratch-localized-selected-lane`: 3
  - `oi-tuple:runtime-multi-selected-effectful-lanes`: 6

A smaller preliminary direct lane, `.tmp/oi-m-runtime-new-cases-count63-20260703`, compared 63/63 with zero validation/generator/property/command/runtime failures and runtime matrix all-equal total 20, but it did not sample `oi-tuple:runtime-all-results`; the count126 lane supersedes it for this slice.

## Focused representative size/opcode checks

Representatives from `.tmp/oi-m-runtime-new-cases-count126-20260703/failures/`:

| label | case | Starshine raw | Binaryen raw | raw delta | opcode/effect check |
| --- | --- | ---: | ---: | ---: | --- |
| runtime-effectful-scratch | `case-000005-gen-valid` | 127 | 132 | -5 | local.set 14/14, local.get 11/11, call 1/1, global.set 1/1, scalar constants match |
| runtime-multi-selected | `case-000025-gen-valid` | 209 | 226 | -17 | local.set 26/26, local.get 20/20, call 2/2, global.set 1/1, scalar constants match |
| runtime-all-results | `case-000072-gen-valid` | 352 | 393 | -41 | local.set 52/52, local.get 40/40, calls/global.set 0/0, scalar constants match |

Starshine WAT remains larger for these representatives due to the known nested block-result expression spelling, while raw wasm is smaller and local/effect traffic is preserved.

## Classification

This slice provides runtime-observable generator coverage and direct runtime smoke evidence for three SB005 surfaces. It narrows the prior open risk that all-result/effectful/multi-selected scratch variants had no runtime-exported generated representatives.

It is **not** generalized tuple-scratch closure:

- grouped wrapper variants for these new runtime-exported labels were not audited in this slice;
- mixed effect/trap producer wrappers remain open;
- branch/EH/control-transfer reconstruction remains open under `OI-M-SB004`/`OI-M-SB005`;
- runtime equality is supporting evidence only and does not by itself close raw output-shape mismatches.

## Reopening criteria

Reopen this runtime-generator evidence if any of the new labels stop sampling, validation fails, Node runtime execution becomes unsupported or mismatches, helper/global.set effects drift, scalar local traffic or constants drift, Starshine raw wasm becomes larger for the representative shapes without a measured win, or Binaryen source/lit/probe evidence requires scalarized-local output for semantic reasons.
