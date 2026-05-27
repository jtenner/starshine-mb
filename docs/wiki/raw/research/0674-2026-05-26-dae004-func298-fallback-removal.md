# DAE004 Func298 fallback removal

Date: 2026-05-26

Recovery slice for `[DAE004-D7]`: retire selected dropped-result fallback entry `298` after proving the ordinary fact/core path already covers the broad-large fixture shape without relying on the handpicked fallback loop.

## Test-first result

I extended `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to cover `298` and renamed it to `dae-optimizing reaches fallback-neighborhood dropped result through fact path`.

Before implementation, the focused test failed. The trace showed:

- `pass[dae-optimizing]:core iter=0 primary_def=298`
- `pass[dae-optimizing]:selected-dropped-result-candidate def=298 ... bucket=selected-fallback`

The callee result was already removed by the ordinary core path before selected fallback tracing, so the `298` fallback entry was redundant for this fixture.

## Change

Removed `298` from both selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt`:

- the helper-visible `dae_selected_dropped_result_fallback_neighborhood_defs()` list used by bucketed attempt-order tests;
- the active selected fallback loop in `dae_run_core`.

This does not raise the broad-large descending cap, does not enable the rejected broad bucketed scheduler, and does not remove the remaining dense, bridge, or late-cluster selected fallback families.

## Validation

Focused test:

```sh
moon test src/passes -f 'dae-optimizing reaches fallback-neighborhood dropped result through fact path' --target native
```

Result: failed before removing `298`, then passed after implementation.

Artifact timing and validation:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-d7-func298-timing-20260526
wasm-opt --all-features .tmp/dae004-d7-func298-validation-20260526/starshine.wasm -o /tmp/dae004-d7-func298-validated.wasm
```

Result: Starshine pass `1457.925ms`, Binaryen pass `850.752ms`, inside the `Starshine <= 2x Binaryen` target. Output validation passed with only the existing large-local-count VM warning.

Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --max-failures 20 --out-dir .tmp/pass-fuzz-dae004-d7-func298-20260526
```

Result: `998/1000` compared, `615` normalized matches, `373` compare-normalized matches, `10` remaining mismatches, `0` validation failures, and `2` command failures.

Agent classification: the remaining mismatches stay in the already accepted DAE010/DAE011/DAE004-D7 `gen-valid` raw-cleanup/control-debris family: Starshine removes audited pure/nontrapping dropped debris and cleanup wrappers that Binaryen preserves in generated-valid cases. This run did not expose a validation failure or a true dropped-result scheduling semantic mismatch.

## Status

`298` is retired from handpicked selected fallback coverage. `[DAE004-D7]` remains open for remaining dense mid-prefix, high-index bridge, or late-cluster entries (`299`, `427`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, `4242`) until artifact/fuzz evidence proves further removals or promotes a closeout blocker.
