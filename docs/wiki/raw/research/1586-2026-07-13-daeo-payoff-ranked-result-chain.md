# DAEO payoff-ranked dropped-result chain

Date: 2026-07-13

## Scope

This slice activates a generic broad-module dropped-result transaction for the source-attributed wrapper/callee family from note `1583`, then applies the bounded structured-copy cleanup from note `1585` only to the selected callee. Plain `dead-argument-elimination` remains unchanged.

## Red-first contract

A new `8193`-function fixture models a dropped wrapper whose terminal undropped call is the last observation of a large structured callee result. The callee has `128` locals and repeated pure local-copy carriers. Before implementation, DAEO removed the two results through existing small-shape logic but left all `local.set` traffic and emitted no payoff-chain evidence; the test failed on the required bounded selected cleanup.

The implementation now:

1. considers only modules above the old `8192` broad-result boundary;
2. finds owned one-result wrappers whose direct calls all drop the result;
3. follows an exact terminal direct call to a one-result defined callee;
4. ranks candidates by recursively counted downstream local-copy payoff, requiring at least `128` locals and payoff `128`;
5. removes the wrapper result first, refreshes call facts, then removes the callee result transactionally;
6. rejects the transaction if either result removal fails;
7. selects only the highest-payoff completed chain for bounded `simplify-locals` plus `vacuum` cleanup.

The retained artifact selects defined wrapper `12293` before defined callee `8429` with payoff `6179`; no definition indices are hardcoded in the selector.

## Fresh artifact evidence

Fresh native release binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `2e69c9602f2fa252f8e7ef13f40659b8cc8e6ef763fb12ab1a3041fd4e1d3905`.

Direct input and output:

- input `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- output `.tmp/daeo-payoff-20260713/starshine-direct-final.wasm`;
- output SHA-256 `a7cf62cb05d25cb81a831bfc571d8021e2beffb2321ea7a18dd8a4714f154556`;
- valid under `wasm-tools validate --features all`;
- whole direct command `7.475s` shell elapsed;
- DAEO pass-local `6814.078ms` versus Binaryen `8083.49ms`, or `0.84x`, inside the repository `<=2x` target.
- The final output is byte-identical to the preceding warm-up replay, so the measured size endpoint is deterministic across the two fresh runs.

Size movement versus the retained note `1583` Starshine output:

| dimension | previous | payoff-chain | delta |
|---|---:|---:|---:|
| raw wasm | `3201367` | `3200059` | `-1308` |
| canonical wasm | `3278451` | `3277302` | `-1149` |
| current-tool WAT | `183511371` | `179320811` | `-4190560` |

Against Binaryen, the current canonical gap narrows from `+15995` to `+14846`. Func `8429`'s canonical body gap narrows from `+2636` to `+1478`; it is no longer the largest owner, with Func `9347` now first at `+2437`. The current-tool WAT is `95103` bytes smaller than Binaryen, but canonical wasm remains larger, so the remaining module gap stays open rather than being classified away.

Agent judgment: the retained transaction is source-contract aligned, valid, raw/canonical/WAT improving versus Starshine's prior endpoint, and within the pass-local target. It is not a claim that the remaining `+14846` canonical gap is acceptable.

## Tests and compare smoke

- focused red/green broad-chain test: `1/1`;
- full `dae_optimizing_test.mbt`: `311/311`;
- dedicated DAEO `.tmp/pass-fuzz-daeo-payoff-dedicated-1000-final-20260713`: `1000/1000` normalized, zero mismatches/failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-daeo-payoff-regular-1000-final-20260713`: `1000/1000` normalized, zero mismatches/failures, Binaryen cache `1000/0`.

Both generated lanes used `--normalize drop-consts --normalize unreachable-control-debris`, `--jobs auto`, and the explicit rebuilt native binary.

## Follow-up

This retained behavior makes note `1581`'s four-lane matrix stale. Before closeout, rebuild native again and rerun all four required lanes. The next direct owner is now Func `9347`, not Func `8429`. Scheduled optimize/O4z/shrink blockers from note `1584` remain separate.
