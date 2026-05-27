# DAE004 Func4229 fallback removal

Date: 2026-05-26

Recovery slice for `[DAE004-D7]`: retire selected dropped-result fallback entry `4229` after proving the ordinary fact/core path already covers the broad-large fixture shape without relying on the handpicked fallback loop.

## Test-first result

Extended `dae-optimizing reaches singleton fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to include `4229`.

Before implementation, `moon test src/passes --target native` failed because the output trace still contained:

- `pass[dae-optimizing]:selected-dropped-result-candidate def=4229 ... bucket=selected-fallback`

The same failing trace showed the result was already removed before the selected fallback path (`pass[dae-optimizing]:core iter=0 primary_def=4229`), so the fallback entry was redundant for this fixture.

## Change

Removed `4229` from both selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt` without raising the broad-large cap and without enabling the rejected bucketed broad-large scheduler.

After implementation, `moon test src/passes --target native` passed with `1474` tests.

## Artifact and fuzz evidence

Release debug-artifact replay:

```sh
moon build --target native --release
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm \
  --starshine-bin target/native/release/build/cmd/cmd.exe \
  --dae-optimizing --timing-only \
  --out-dir .tmp/dae004-d7-4229-timing-20260526
```

Result: Starshine pass `1671.491ms`, Binaryen pass `916.191ms`, inside the `Starshine <= 2x Binaryen` target. The whole-command timing was `2051.412ms` Starshine versus `1220.837ms` Binaryen. A traced release replay to `.tmp/dae004-d7-4229-validation-20260526/starshine.wasm` no longer emitted selected fallback trace lines for `4229`, and `wasm-opt --all-features` validated the output with only the existing large-local-count VM warning.

Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed \
  --pass dae-optimizing --normalize drop-consts \
  --out-dir .tmp/pass-fuzz-dae004-d7-4229-20260526
```

Result: `571/1000` compared, `352` normalized matches, `200` drop-const compare-normalized matches, `19` remaining mismatches, `0` validation failures, and `1` command failure.

Agent classification: the remaining mismatches stay in the already accepted DAE010/DAE011/DAE004-D7 `gen-valid` raw-cleanup/control-debris family: Starshine removes audited pure/nontrapping dropped debris and cleanup wrappers that Binaryen preserves in generated-valid cases. This run did not expose a validation failure or a true dropped-result scheduling semantic mismatch.

## Status

`4229` is retired from handpicked selected fallback coverage. `[DAE004-D7]` remains open for remaining dense mid-prefix, high-index bridge, or late-cluster entries (`298`, `299`, `427`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, `4242`) until artifact/fuzz evidence proves further removals or promotes a closeout blocker.
