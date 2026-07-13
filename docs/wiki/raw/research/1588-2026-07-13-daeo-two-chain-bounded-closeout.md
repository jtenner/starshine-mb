# DAEO bounded two-chain closeout

Date: 2026-07-13

## Scope

This slice closes the next broad-module dropped-result dependency exposed after the payoff-ranked `12293 -> 8429` transaction from note `1586`. The direct artifact showed that running current `dae-optimizing` a second time selected wrapper `12020` before callee `9347`, removed both results, and reduced the artifact. The retained implementation performs at most two ranked broad payoff transactions in one public DAEO invocation, refreshes call facts between transactions, and applies the existing bounded `simplify-locals` / `vacuum` cleanup to at most two completed payoff callees. Plain `dead-argument-elimination` remains unchanged.

## Red-first contract

The new `8193`-function regression contains two independent owned dropped-result wrapper chains. Both callees have `128` locals and exceed the existing local-copy payoff floor, with the first chain ranked above the second. Before the retained implementation, both results could become void but only the highest-ranked callee received bounded selected cleanup; the second callee retained its `local.set` traffic and the test failed.

The retained behavior:

1. ranks candidates by downstream local-copy payoff;
2. attempts at most two transactional wrapper-before-callee result removals;
3. recomputes current call facts and candidates after each successful transaction;
4. discards a partial wrapper rewrite if the paired callee result cannot be removed;
5. identifies at most two original-to-current completed payoff chains for one shared selected cleanup pass;
6. emits one trace row per completed chain in payoff order.

Focused `dae_optimizing_test.mbt` validation passed `312/312` after the test failed red first.

## Direct artifact evidence

Fresh native release binary after the change:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `15f38bda2c820a9470ab77abce94841fa9e704d0d37514c7cb01a71c73ba9359`.

Input and retained output:

- input `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- output `.tmp/daeo-two-chain-20260713/starshine-direct.wasm`;
- output SHA-256 `8f2d98b6073df0c27c8346cf2a9f7f28eb156ffc63518ea35de47cf9f8e9be0f`;
- repeat output is byte-identical;
- output validates with `wasm-tools validate --features all`;
- traced DAEO pass-local time is `8914.522ms` versus the retained Binaryen `8083.49ms`, or `1.10x`, inside the repository `<=2x` target.

The trace records exactly these two generic transactions:

```text
wrapper_def=12293 callee_def=8429 payoff=6179
wrapper_def=12020 callee_def=9347 payoff=5028
```

No function indices are hardcoded in selection or scheduling.

Size movement from note `1587`'s retained Starshine endpoint:

| dimension | previous | two-chain | delta |
|---|---:|---:|---:|
| raw wasm | `3200059` | `3198785` | `-1274` |
| canonical wasm | `3277302` | `3276187` | `-1115` |
| canonical gap versus Binaryen | `+14846` | `+13731` | `-1115` |

Func `9347`'s canonical body gap falls from `+2437` to `+1310`; it is no longer the largest positive owner. Func `41` is now first at `+2063`, followed by Funcs `7007` and `7008`. The remaining module gap stays open.

## Follow-up

- Inspect the residual `9347` cleanup shape only if it remains a better bounded payoff than the new larger owners; result removal is now complete, but local/control cleanup still differs.
- Attribute Func `41` and the paired `7007` / `7008` family before retaining another generic behavior change.
- Rebuild native and refresh the full four-lane direct matrix only after the final retained behavior of the iteration.
