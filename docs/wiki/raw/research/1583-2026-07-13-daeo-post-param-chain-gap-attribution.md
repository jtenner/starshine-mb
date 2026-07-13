# DAEO post-parameter-chain gap attribution

Date: 2026-07-13

## Scope

This investigation rebuilds the native CLI, replays the retained direct `dae-optimizing` artifact, attributes the remaining canonical code gap by function, and probes one newly identified Binaryen-owned result-removal/cleanup chain. Probe source changes were restored; no optimizer behavior changed in this slice.

## Fresh baseline

Fresh explicit native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `48abcd5da8b92b45423915c0cd70740ff072cd420d21ab76e55ceabb0e5e5812`.

Fresh direct replay:

- input `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`;
- output `.tmp/daeo-iteration-20260713/starshine-direct.wasm`;
- output SHA-256 `8c6db64956625844b99fb09bab299c89cca9ccc41f13fd77ab28649108bf12a1`, byte-identical to note `1580`;
- valid under `wasm-tools validate --features all`;
- raw `3201367` bytes;
- canonical `3278451` bytes versus Binaryen `3262456`, retaining the `+15995` canonical gap;
- whole direct command `5990ms` in this replay; the trace still reports the retained pass-local baseline from note `1580` as `5645.054ms` versus Binaryen `8083.49ms`.

The canonical section payloads now attribute the net gap as:

| section | Starshine | Binaryen | Starshine delta |
|---|---:|---:|---:|
| type | `75294` | `78167` | `-2873` |
| function | `25327` | `25369` | `-42` |
| code | `2990857` | `2971947` | `+18910` |
| module | `3278451` | `3262456` | `+15995` |

Starshine's smaller type/function sections offset `2915` bytes of the larger code section. The remaining blocker is therefore code-shape convergence, not type-section size.

## Largest current code owners

A fresh code-body parser compared all `13162` defined functions. The largest positive canonical body deltas are:

| defined func | absolute func | Starshine body | Binaryen body | delta |
|---:|---:|---:|---:|---:|
| `8429` | `8450` | `28378` | `25742` | `+2636` |
| `9347` | `9368` | `17842` | `15405` | `+2437` |
| `41` | `62` | `7480` | `5417` | `+2063` |
| `7007` | `7028` | `5757` | `3884` | `+1873` |
| `7008` | `7029` | `6180` | `4332` | `+1848` |
| `8187` | `8208` | `2217` | `961` | `+1256` |
| `7556` | `7577` | `6158` | `5025` | `+1133` |
| `6377` | `6398` | `4185` | `3153` | `+1032` |

The old Func-41 attribution is no longer the largest owner after note `1580`; defined Func `8429` is now first.

## Defined Func 8429 result chain

Current Starshine keeps defined Func `8429` as `(ref $0, ref $62) -> i32`. Binaryen removes the `i32` result and refines the second reference parameter. The function has five direct callsites:

- two self-recursive calls, both dropped;
- dropped calls from defined Funcs `8442` and `11935`;
- one terminal undropped call from defined Func `12293`.

Defined Func `12293` itself returns that `i32`, but all three of its direct callers drop the result. Binaryen therefore removes Func `12293`'s result first, which turns its terminal call to Func `8429` into a dropped call and unlocks Func `8429` result removal. This is a source-contract-shaped dropped-result convergence chain, not representation-only drift.

The existing broad-module dropped-result scheduler does not run for `original_defined > 8192`. A controlled activation of the old descending/bucketed lane selected Funcs `12905`, `12904`, `12903`, `12902`, `12901`, `12698`, `12697`, and `12696`; it missed the `12293 -> 8429` chain and worsened both raw and canonical size:

- raw `3201408`, `+41` versus baseline;
- canonical `3278461`, `+10` versus baseline;
- pass-local `6283.381ms`.

Agent judgment: reject. Descending definition order is not a useful profitability proxy on this artifact.

## Controlled exact-chain probes

A second temporary probe selected only the source-attributed `12293 -> 8429` result chain with fresh call facts.

### Result removal only

The result-only endpoint was valid and fast enough, but size-losing because the newly dropped value debris was not consumed:

- raw `3201375`, `+8` versus baseline;
- canonical `3278618`, `+167` versus baseline;
- current `wasm-opt -S` text `183557243`, `+45872` versus a same-tool baseline `183511371`;
- pass-local `6090.964ms`.

Agent judgment: reject. Matching the signatures without the Binaryen optimizing replay is not a signable endpoint.

### Result removal plus selected `simplify-locals` / `vacuum`

Running cleanup only on Funcs `8429` and `12293` produced a valid, all-size-dimensions improvement:

- raw `3199807`, `-1560` versus baseline and `+22386` versus Binaryen;
- canonical `3277050`, `-1401` versus baseline and `+14594` versus Binaryen;
- same-tool `wasm-opt -S` text `183207216`, `-304155` versus baseline and `-208698` versus Binaryen;
- Func `8429` alone shrank by `1568` canonical body bytes;
- Func `12293` required no additional body cleanup after result repair.

However, pass-local time rose to `33027.052ms`, about `4.09x` Binaryen's `8083.49ms`, outside the repository `<=2x` target. Trace attribution shows the selected raw `simplify-locals` path chose `structured-pure-copy-call-tail`; it consumed the time before HOT lifting and rewrote hundreds of local copy/set/get carriers. `vacuum` was not the runtime owner.

Agent judgment: reject as a landing endpoint despite the size win. The semantic owner and profitable final shape are now proved, but the current raw `simplify-locals` implementation is too slow on this giant structured function. Retaining result removal without cleanup is size-losing, while retaining cleanup as measured violates pass-local performance.

## Next implementation shape

The next safe slice should:

1. select broad-module dropped-result chains by downstream cleanup payoff rather than descending definition index;
2. process the dropped wrapper before its terminal callee with fresh call facts;
3. provide a bounded, function-filtered equivalent of the `structured-pure-copy-call-tail` cleanup for the selected giant function without the current multi-pass raw cost;
4. retain only an endpoint that is valid, raw/canonical/WAT non-losing, and `<=2x` Binaryen pass-local;
5. keep plain DAE free of this optimizing-only selection and cleanup.

The direct four-lane matrix from note `1581` remains current because no behavior change was retained.
