# DAEO payoff-chain type-stable local ordering

Date: 2026-07-14

## Scope

This bounded slice first re-attributed the leading Func `7008` family, rejected an unsafe/size-losing direct-callee convergence probe, then moved to the already source-backed dropped-result payoff owners as required by the continuation contract. The retained change applies the existing type-stable local rewrite to the exact payoff-chain callees already selected by DAEO after their bounded `simplify-locals` / `vacuum` cleanup.

Plain `dead-argument-elimination` is unchanged. Public scheduling is unchanged.

## Func 7008 cycle attribution and rejected probe

The current canonical call neighborhood confirms the multi-function shape:

- defined Func `7008` calls `7007`;
- Funcs `7007` and `7009` call `7010`;
- Func `7010` calls `7008`;
- Binaryen removes the forwarded `i32` parameter from Funcs `7007`, `7008`, and `7010`, and removes that parameter plus two nullable reference parameters from Func `7009`;
- the only external call to Func `7009` supplies an arbitrary local-derived `i32` and two null references, so the `i32` is not a uniform constant.

A temporary generic direct-callee closure probe selected reachable functions from the existing adjacent pair and repeatedly applied the existing unread-parameter helper. The bounded `128`-definition probe selected five productive definitions but not the pair and worsened the retained artifact by `+629` raw / `+598` canonical bytes. A wider depth-eight closure selected `793` definitions and `33` productive definitions, still did not remove the pair parameter, and worsened the artifact by `+899` raw / `+804` canonical bytes. Pass-local time also rose to `13.59s` and `17.57s` respectively.

The probe was rejected and fully reverted. Direct reachability is not a sufficient ownership proof for a forwarding-only parameter transaction, and accepting its unrelated removals would violate the direct-difference classification rule. A future cycle slice needs parameter-position dependency evidence and an all-or-nothing multi-function call/signature rewrite; it must reject escapes, tail calls, writes, unowned callers, and unclassified entry uses.

## Retained payoff-chain local ordering

Binaryen's optimizing DAE contract reruns local cleanup and local reordering after productive boundary changes. DAEO already selects the generic dropped-result payoff chains and applies bounded cleanup to their exact callees. The retained follow-up now applies the existing type-stable local rewrite to that same exact callee list:

- no artifact function index is added;
- parameters stay fixed;
- unreferenced body locals are dropped;
- referenced locals move only within existing contiguous type runs;
- plain DAE does not enter the lane.

The red-first `8193`-definition payoff fixture keeps one observable tail local across an imported call. Before implementation, optimizing DAEO retained all `128` body locals and failed `128 != 1`. After implementation, plain DAE keeps `128`, DAEO keeps one live local, the observable `i32.const 77` and call remain, the dropped wrapper/callee results are still removed, and the module validates.

## Direct artifact evidence

Implementation probe output:

```text
.tmp/daeo-8429-order-probe-20260714/starshine.wasm
.tmp/daeo-8429-order-probe-20260714/starshine.canonical.wasm
```

The output validates under `wasm-tools validate --features all`.

| dimension | note 1599 | payoff local order | delta |
|---|---:|---:|---:|
| raw wasm | `3197484` | `3197420` | `-64` |
| canonical wasm | `3274937` | `3274877` | `-60` |
| Func `8429` canonical body | `27220` | `27190` | `-30` |
| Func `9347` canonical body | `16715` | `16685` | `-30` |
| DAEO pass-local | `12448.452ms` | `12571.155ms` | `+122.703ms` |

Binaryen remains raw `3177421`, canonical `3262456`, and pass-local `8083.49ms`. The retained endpoint is about `1.56x` Binaryen, inside the required `<=2x` bound. The overall open gaps narrow to `+19999` raw / `+12421` canonical. Func `8429` narrows from `+1478` to `+1448`; Func `9347` narrows from `+1310` to `+1280`.

## Judgment and next step

The retained change is a measured raw/canonical direct Starshine size win connected to Binaryen's optimizing-only local cleanup replay. It is not direct parity and does not classify the remaining positive bytes. The next bounded commit should preserve identical output while avoiding unnecessary payoff-callee list/remap work, then the third commit must rebuild the explicit native binary and refresh the full Binaryen-v130 matrix, scheduling, validation, docs, backlog, and log.
