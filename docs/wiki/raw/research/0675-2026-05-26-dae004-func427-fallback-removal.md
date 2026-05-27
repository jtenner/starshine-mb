# DAE004 Func427 fallback removal

## Scope

Advance `[DAE004-D7]` by removing `427` from the handpicked selected dropped-result fallback after proving the ordinary fact/core path already covers the broad-large fixture shape.

## Test-first failure

I extended `dae-optimizing reaches fallback-neighborhood dropped result through fact path` in `src/passes/dae_optimizing_test.mbt` to include `427` alongside previously retired fallback entries.

Before the implementation change, the focused test failed because trace output still contained:

- `pass[dae-optimizing]:selected-dropped-result-candidate def=427 ... bucket=selected-fallback ...`

The same run also showed the result was already removed earlier by ordinary DAE core/fact work:

- `pass[dae-optimizing]:core iter=0 primary_def=427`

So the handpicked fallback entry was stale for this fixture; the failure was trace-based fallback dependence, not a missing result-removal transform.

## Implementation

Removed `427` from the selected dropped-result fallback lists in `src/passes/dead_argument_elimination.mbt` and removed it from the black-box selected mid-prefix fixture inventory in `src/passes/dae_optimizing_test.mbt`.

No broad-large productive-attempt cap was raised, and the rejected bucketed broad-large scheduler switch remains disabled.

## Validation

Focused tests:

```sh
moon test src/passes -f "dae-optimizing reaches fallback-neighborhood dropped result through fact path"
moon test src/passes -f "dae-optimizing removes selected mid-prefix dropped callee results"
```

Both passed after the implementation change. The first focused command failed before the fallback removal, as expected for TDD.

Debug artifact timing and validation:

```sh
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-d7-func427-timing-20260526
wasm-opt --all-features .tmp/dae004-d7-func427-timing-20260526/starshine.wasm -o .tmp/dae004-d7-func427-timing-20260526/starshine.validated.wasm
```

Results:

- Starshine runtime: `1798.361ms`
- Binaryen runtime: `1149.427ms`
- Starshine pass runtime: `1443.049ms`
- Binaryen pass runtime: `855.557ms`
- Pass-local ratio is within the DAE target (`Starshine <= 2x Binaryen`).
- `wasm-opt --all-features` passed with only the existing large-local-count VM warning.

Direct compare refresh:

```sh
bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass dae-optimizing --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-dae004-d7-func427-20260526
```

Results:

- Compared cases: `998/1000`
- Normalized matches: `615`
- Compare-normalized matches: `373`
- Remaining mismatches: `10`
- Validation failures: `0`
- Command failures: `2`

Agent classification: the remaining mismatches are the already accepted DAE generator raw-cleanup / unreachable-control-debris family not fully covered by exact normalized matching; with both explicit normalizers enabled, these are not evidence of a true dropped-result scheduling gap. Command failures are Binaryen/tool failures, not Starshine validation failures.

## Status

`427` is retired from handpicked selected dropped-result fallback coverage. `[DAE004-D7]` remains open for the remaining dense mid-prefix, high-index bridge, and late-cluster entries: `299`, `459`, `472`, `476`, `3566`, `3732`, `3814`, `4232`, `4240`, `4241`, and `4242`.
