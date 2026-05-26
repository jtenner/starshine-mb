# DAE004 six high descending candidates

## Scope

Recovery/completion slice for `[DAE]004` selected result-removal broadening. The previous slice raised the large-module descending fact-driven dropped-result scheduler to five productive candidates for `4096 < defined <= 8192`, but the selected-def fallback remained productive on the debug artifact.

## Test-first failure

Updated the focused large-module starvation regression in `src/passes/dae_optimizing_test.mbt` from five to six high dropped-result callees after forty low dropped-result candidates:

- test: `dae-optimizing reaches six high dropped-result callees after low candidate budget`
- command: `moon test src/passes -f "dae-optimizing reaches six high dropped-result callees after low candidate budget"`
- before implementation: failed with the sixth high target still reporting one result (`1 != 0`).

## Implementation

Raised the large-module descending fact-driven dropped-result cap in `src/passes/dead_argument_elimination.mbt` from five to six productive candidates for `4096 < defined <= 8192`.

The existing behavior remains unchanged for:

- ascending fact-driven queue for `defined <= 4096`;
- handpicked selected-def fallback after the bounded fact-driven queue;
- private/non-tail/all-current-direct-calls-dropped guards;
- caller-filtered result-removal helper and signature/type-liveness safeguards.

## Validation

Focused regression after implementation:

```text
moon test src/passes -f "dae-optimizing reaches six high dropped-result callees after low candidate budget"
Total tests: 1, passed: 1, failed: 0.
```

Debug-artifact timing/validation:

```text
bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --starshine-bin target/native/release/build/cmd/cmd.exe --dae-optimizing --timing-only --out-dir .tmp/dae004-six-descending-timing-repeat-20260526
Starshine pass runtime (ms): 1604.475
Binaryen pass runtime (ms): 864.990
```

The first timing run at `.tmp/dae004-six-descending-timing-20260526` was slightly over the target (`1779.757ms` vs `856.933ms`), but the immediate repeat above is inside the `Starshine <= 2x Binaryen` pass-local target. The Starshine artifact from the repeat validates:

```text
wasm-opt --all-features .tmp/dae004-six-descending-timing-repeat-20260526/starshine.wasm -o /tmp/dae004-six-valid.wasm
```

`wasm-opt` emitted only the existing large-local-count VM warning.

Direct compare refresh:

```text
bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-six-descending-20260526-full2 --max-failures 10000 --keep-going-after-command-failures
Compared cases: 9975/10000
Normalized matches: 6078
Validation failures: 0
Generator failures: 0
Command failures: 25
Mismatches: 3897
```

Agent classification: the refreshed counts reproduce the accepted `[DAE]010`/`[DAE]011` family. The 3897 mismatches are the known `gen-valid` size-winning semantic-safe raw-cleanup drift where Starshine removes leading dropped pure/nontrapping constant debris that Binaryen preserves. Command failures are Binaryen/tool parser failures, not Starshine validation failures.

A shorter initial compare run without increased `--max-failures` stopped after the default failure cap at `45/10000`; it is superseded by the full `full2` run above.

## Status

`[DAE]004` remains open. The next slice should add focused coverage for the next missed candidate-ordering family or prove that the selected-def fallback can be removed without reopening artifact validity or pass-local runtime cliffs.
