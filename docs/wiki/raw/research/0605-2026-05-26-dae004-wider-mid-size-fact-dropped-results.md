# DAE004 wider mid-size fact-dropped result queue

Date: 2026-05-26

## Scope

Recovery/completion slice for `[DAE]004` selected result-removal broadening. The prior bounded fact-driven dropped-result queue covered modules through `defined <= 2048`; this slice widens that same guarded queue to `defined <= 4096` while leaving the huge debug-artifact selected-def fallback in place.

## Test-first evidence

Updated `src/passes/dae_optimizing_test.mbt` so `dae-optimizing removes high fact-discovered dropped callee result outside selected list` places the dropped-result target at defined function `3000`, outside the previous mid-size guard.

Failing command before implementation:

```sh
moon test src/passes -f 'dae-optimizing removes high fact-discovered dropped callee result outside selected list'
```

Failure: the optimized target still had one result (`1 != 0`).

## Implementation

Changed `src/passes/dead_argument_elimination.mbt` so the fact-driven dropped-result queue runs when `original_defined <= 4096` instead of `<= 2048`. The queue still uses current direct-call facts and the caller-filtered dropped-result helper, so it keeps the existing guards:

- candidate callee is private / not escaped;
- no tail-call use;
- direct call count is positive;
- every current direct call drops the single result;
- result removal still revalidates the current callee/caller shape before mutating.

This is intentionally not the final `[DAE]004` fallback-removal slice. The large debug artifact remains above the widened guard and therefore still uses the historical handpicked selected-def fallback until separate measured artifact evidence proves the broad queue can replace it without reopening the closed DAE011 runtime cliff.

## Validation

- `moon test src/passes -f 'dae-optimizing removes high fact-discovered dropped callee result outside selected list'` passes after the guard widening; existing unused helper warnings remain.

- `git diff --check` passed.
- `moon info` passed.
- `moon fmt` passed.
- `moon test` passed (`3451` tests).
- Direct compare: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass dae-optimizing --out-dir .tmp/pass-fuzz-dae004-4096-20260526-full2 --max-failures 10000 --keep-going-after-command-failures` reported `9975/10000` compared, `6078` normalized matches, `3897` mismatches, `0` validation failures, and `25` Binaryen/tool command failures.

Agent classification: the compare result reproduces the accepted `[DAE]010` / `[DAE]011` family. All mismatches are the known `gen-valid` size-winning semantic-safe raw-cleanup drift where Starshine strips dropped pure/nontrapping generator debris that Binaryen preserves; no wasm validation failures were reported. Command failures are tool/Binaryen failures (`binaryen-rec-group-zero` and the same accepted parser/section/table/tag families as earlier DAE010/DAE011 lanes).

## Backlog impact

`[DAE]004` remains open. Completed breadth now includes small modules, mid-size modules through `2048`, and wider mid-size modules through `4096`. Remaining work is still to remove the large-artifact handpicked selected-def fallback only when artifact/fuzz evidence proves the fact-driven queue covers the remaining result-removal frontier without reopening DAE011 pass-local runtime risk.
