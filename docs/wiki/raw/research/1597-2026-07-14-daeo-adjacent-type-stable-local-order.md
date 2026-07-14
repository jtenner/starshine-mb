# DAEO adjacent type-stable local ordering

Date: 2026-07-14

## Scope

This bounded iteration re-attributes the current leading direct owners, defined Funcs `7008` and `7007`, after note `1596`. Both Starshine bodies still declare hundreds of locals and encode substantially more local traffic than Binaryen. The retained change does not claim parity: it adds a generic optimizing-only local-order refinement to the already selected broad adjacent family and keeps the remaining positive bytes open.

Plain `dead-argument-elimination` remains unchanged. Public scheduling remains unchanged.

## Source-backed transform

Binaryen's optimizing DAE replay includes local cleanup and local reordering after productive boundary changes. Running Starshine's ordinary frequency-only `reorder-locals` on the selected pair was rejected: the controlled probe improved canonical size by only `86` bytes while increasing raw output by `1549` bytes.

The retained helper instead preserves each existing contiguous local-type run. Within a run it:

1. drops unreferenced body locals;
2. ranks referenced locals by access count, then first use and original index;
3. remaps only within that same type run;
4. leaves parameter slots fixed and rewrites the name section through the existing local remap support.

Preserving type runs avoids fragmenting the compact local-declaration encoding while moving hot locals toward lower local indices. The helper is applied only to the two functions selected by the existing generic broad adjacent selector, after its bounded `simplify-locals` / `vacuum` cleanup. No artifact function index is hardcoded.

## Red-first regression

The existing `8193`-definition adjacent fixture now keeps one live tail local across an observable call in each selected function. Before implementation, optimizing DAEO retained all `128` body locals and the focused test failed `128 != 1`. After implementation:

- plain DAE keeps `128` locals;
- DAEO keeps the one referenced local and its observable `i32.const 77` write/read behavior;
- the generic trace ends with `local_order=type-stable`;
- the optimized module validates.

Focused command:

```text
moon test --package jtenner/starshine/passes --file dae_optimizing_test.mbt --filter '*broad exact-param adjacent*'
```

## Direct artifact evidence

Fresh implementation-probe native binary:

```text
_build/native/release/build/cmd/cmd.exe
SHA-256 67a3173087b9970fffecb98778f2df111a94f25c196b954dee6c086300111e66
```

Output:

```text
.tmp/daeo-7008-probes-20260714/type-stable.wasm
SHA-256 58523a1416ac35b6793ab1831fc8d8c827fa583cc02f4c8d712effe0a9263d02
```

The output validates under `wasm-tools validate --features all`. Binaryen-v130 no-pass canonicalization produced `.tmp/daeo-7008-probes-20260714/type-stable.canonical.wasm`.

| dimension | note 1596 | type-stable local order | delta |
|---|---:|---:|---:|
| raw wasm | `3197559` | `3197484` | `-75` |
| canonical wasm | `3275027` | `3274937` | `-90` |
| Func `7007` canonical body | `5414` | `5354` | `-60` |
| Func `7008` canonical body | `6143` | `6113` | `-30` |
| DAEO pass-local | `12763.150ms` | `12590.664ms` | `-172.486ms` |

Binaryen remains raw `3177421`, canonical `3262456`, and pass-local `8083.49ms`. The retained pass is about `1.56x` Binaryen, inside the required `<=2x` target. The overall canonical gap narrows to `+12481`; the pair remains `+3251` aggregate canonical body bytes (`7008 +1781`, `7007 +1470`).

## Judgment and next step

This is a measured, source-connected raw/canonical size win with no raw-size tradeoff, not direct Binaryen parity. The leading adjacent family remains open. The next bounded commit should preserve this output while reducing the helper's scan/allocation cost or otherwise tighten its generic candidate gate before the final four-lane and repository signoff commit.
