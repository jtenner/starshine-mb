# OI-M Runtime Mixed Effect+Trap Evidence

Date: 2026-07-03

## Question

Does the new `oi-tuple:runtime-mixed-effect-trap-scratch-localized-selected-lane` generator produce runtime-observable evidence for a tuple-scratch shape that combines an effectful selected lane with a trapping non-selected lane?

## Generator shape

Seed `0x6003` in `pass-oi-tuple` emits an exported `run` function. The multivalue block has:

- selected i32 lane from helper function 1, which performs `global.set` before returning the selected value;
- non-selected i64 lane from helper function 2, which traps by integer division by zero;
- f32/f64 constant lanes;
- selected-lane scratch `local.set` / `local.get` traffic after tuple materialization.

The exported `run` traps before the selected value is returned because the non-selected i64 lane is evaluated. This makes the mixed effect+trap path runtime-observable as equal traps rather than equal scalar results.

## Direct runtime compare

```sh
bun scripts/pass-fuzz-compare.ts --count 132 --seed 0x5eed \
  --pass optimize-instructions --gen-valid-profile pass-oi-tuple \
  --out-dir .tmp/oi-m-runtime-mixed-effect-trap-count132-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe --jobs auto \
  --runtime-execution node --max-failures 2000 \
  --keep-going-after-command-failures
```

Result:

- Compared 132/132.
- Raw mismatches: 132.
- Normalized matches: 0.
- Validation/generator/property/command/runtime failures: 0.
- Runtime checked/unsupported/failed: 132/0/0.
- Runtime matrix: all-equal total 56, equalResults 53, equalTraps 3, semanticMismatches 0.
- Binaryen cache hits/misses: 97/35.
- `oi-tuple:runtime-mixed-effect-trap-scratch-localized-selected-lane` sampled 3 residuals.

## Grouped runtime compare

```sh
bun scripts/oi-parity-sweep.ts --family OI-M --count 132 \
  --out-dir .tmp/oi-m-runtime-mixed-effect-trap-grouped-count132-20260703 \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --execute -- --runtime-execution node --max-failures 2000 \
  --keep-going-after-command-failures

bun scripts/oi-parity-sweep.ts --family OI-M \
  --out-dir .tmp/oi-m-runtime-mixed-effect-trap-grouped-count132-20260703 \
  --summarize-existing
```

Result:

- Compared 132/132.
- Raw mismatches: 132.
- Normalized matches: 0.
- Validation/generator/property/command/runtime failures: 0.
- Runtime checked/unsupported/failed: 132/0/0.
- Runtime matrix: all-equal total 56, equalResults 53, equalTraps 3, semanticMismatches 0.
- Binaryen cache hits/misses: 98/34.
- `oi-tuple:runtime-mixed-effect-trap-scratch-localized-selected-lane` sampled 3 grouped residuals.
- The grouped summary kept the raw-mismatch caveat: raw mismatches remain agent-classified active parity evidence unless separately measured and accepted.

## Focused representatives

Manual `wasm-tools validate --features all` accepted raw and canonical Binaryen/Starshine artifacts for these representatives:

| Label / wrapper | Representative | Starshine raw/canonical | Binaryen raw/canonical | Observed facts |
| --- | --- | ---: | ---: | --- |
| direct mixed effect+trap | `.tmp/oi-m-runtime-mixed-effect-trap-count132-20260703/failures/case-000067-gen-valid` | 121 / 140 | 140 / 145 | Both outputs preserve two helper calls, one `global.set`, scalar locals, constants, and the trapping helper; Starshine raw/canonical smaller. |
| grouped trapping-sibling mixed effect+trap | `.tmp/oi-m-runtime-mixed-effect-trap-grouped-count132-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000067-gen-valid-transform-oi-trapping-sibling` | 200 / 219 | 219 / 224 | Both outputs preserve two helper calls, one `global.set`, grouped trap/drop scaffolding, scalar locals, and constants; Starshine raw/canonical smaller. |
| grouped selected-lane mixed effect+trap | `.tmp/oi-m-runtime-mixed-effect-trap-grouped-count132-20260703/oi-m/OI-M-tuple-multivalue-selected-lanes/failures/case-000085-gen-valid-transform-oi-tuple-selected-lane` | 540 / 820 | 820 / 969 | Both outputs preserve two helper calls, one `global.set`, grouped selected-lane local traffic, constants, and drops; Starshine raw/canonical smaller. |

## Classification

This is an evidence-backed narrowing of OI-M-SB005 for the generated mixed effect+trap runtime smoke and the sampled grouped wrappers. It is not generalized mixed effect/trap closure and does not prove arbitrary producer wrappers, control/EH reconstruction, or source-visible non-generated tuple-scratch reconstruction.

Keep OI-M active/P0 for:

- mixed effect+trap variants beyond this generated runtime smoke and sampled grouped wrappers;
- broader producer wrappers;
- multi-selected variants beyond generated two-lane smokes;
- branch/EH/control-transfer tuple-scratch reconstruction under OI-M-SB004/OI-M-SB005;
- any raw mismatch without measured Starshine-win or source-backed boundary evidence.

This evidence does not close OI-G, OI-I, OI-J, or OI-K.
