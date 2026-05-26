# DAE003 high exact-literal revisit

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE]003` constant-actual and unread-parameter generalization. The existing low-prefix exact-literal revisit only rescanned the first `64` defined functions and therefore could starve a safe later exact-literal callee in mid-size modules after earlier productive rewrites.

## Test-first evidence

Added `dae-optimizing materializes high fact-discovered exact literal outside selected list` in `src/passes/dae_optimizing_test.mbt`. The fixture builds a mid-size module with nine earlier removable exact-literal callees and a later private direct callee at defined function `1500`, outside the handpicked selected lanes.

Failing command before implementation:

```sh
moon test src/passes -f 'dae-optimizing materializes high fact-discovered exact literal outside selected list'
```

Failure: the target still had one parameter (`1 != 0`).

## Implementation

Changed `src/passes/dead_argument_elimination.mbt` so the low-forwarded-const revisit can run on modules up to `4096` defined functions and scan candidates through definition `4096` instead of stopping at the first `64` definitions. The broader revisit still uses the existing exact-literal candidate rewriter and its safety guards:

- private direct callee only;
- no escaped or tail-call use;
- no self-call in the callee body;
- every direct caller must provide the same materializable actual for a read-only parameter;
- removed actuals are repaired at call sites and the callee body materializes the constant.

This intentionally does not widen the huge debug artifact path beyond the existing selected high-wrapper exact-literal chain; that artifact remains above the `4096` guard.

## Validation

- Focused regression failed before the implementation and passed after it.
- `moon test src/passes` passed (`1380` tests).
- `moon info` passed.
- `moon fmt` passed.
- `moon test` passed (`3452` tests).
- Direct compare: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae003-high-exact-20260526-full --max-failures 10000 --keep-going-after-command-failures` reported `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, and `25` Binaryen/tool command failures.

Agent classification: the compare result reproduces the accepted `[DAE]010` / `[DAE]011` / `[DAE]004` family. All mismatches are the known `gen-valid` size-winning semantic-safe raw-cleanup drift where Starshine strips dropped pure/nontrapping generator debris that Binaryen preserves; no wasm validation failures were reported. Command failures are tool/Binaryen failures in the accepted parser/section/table/tag families.

## Backlog impact

`[DAE]003` remains open for broader carrier shapes and artifact-frontier closure, but mid-size exact-literal starvation outside the first `64` definitions is now covered by a focused regression and implementation guard.
