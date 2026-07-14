# DAEO adjacent constructor-chain cleanup

Date: 2026-07-13

## Scope

This slice attributes the paired direct-artifact owners defined Funcs `7007` and `7008` to one broad exact-parameter neighborhood. Defined Func `7003` is a private exact-literal aggregate-constructor candidate; within the next eight definitions, Funcs `7007` and `7008` are adjacent, have the same function type, each has at least `128` locals, and Func `7008` directly calls Func `7007`. Their combined local get/set/tee payoff is `4686`.

The retained DAEO-only policy ranks eligible broad exact-literal roots by aggregate-constructor count, rewrites one root, then applies the existing bounded `simplify-locals` / `vacuum` cleanup to the best adjacent same-signature caller/callee pair in that root's eight-definition neighborhood. No artifact function index is hardcoded. Plain `dead-argument-elimination` does not run this selector or cleanup.

## Red-first contract

The new `8193`-function regression places a starved exact-literal root at defined Func `7000` and an adjacent high-local same-signature caller/callee pair at Funcs `7004` and `7005`. Before implementation, DAEO left the root parameter and pair-local copy traffic intact. The retained behavior removes the root parameter, removes the pair's `local.set` debris, emits the generic selection trace, validates, and leaves plain DAE unchanged.

Focused `dae_optimizing_test.mbt` passes `313/313` after the red failure.

## Direct artifact evidence

Fresh explicit native binary used for this probe:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `5efc7e4eca6a1e7b0f26afaf6aebf7ba24d13b5b530b5a125314c11053037e87`.

Retained output:

- `.tmp/daeo-adjacent-pair-20260713/starshine-direct.wasm`;
- SHA-256 `5f799dd0bd6c347041c33147f8c2230c19ed8a384cad5c0d1f0f67c6c6cbdf05`;
- validates with `wasm-tools validate --features all`;
- trace selection: `root_def=7003 defs=[7007, 7008] payoff=4686`.

Size and timing versus note `1590`:

| dimension | note 1590 | adjacent cleanup | delta |
|---|---:|---:|---:|
| raw wasm | `3198681` | `3198310` | `-371` |
| canonical wasm | `3276084` | `3275701` | `-383` |
| canonical gap versus Binaryen | `+13628` | `+13245` | `-383` |
| DAEO pass-local | `9350.478ms` | `12890.262ms` | `+3539.784ms` |
| DAEO / Binaryen `8083.49ms` | `1.16x` | `1.59x` | remains within `<=2x` |

Agent judgment: this is a source-connected, bounded, deterministic, valid, raw/canonical size win with pass-local performance still inside repository guidance. It reduces but does not close the pair: remaining output-shape differences stay open rather than being classified away.

## Follow-up

- Recompute canonical body owners after the retained endpoint; do not assume Funcs `7007` / `7008` are closed.
- The next direct slice should target another concrete owner or extend this chain only with measured non-losing behavior.
- Refresh all four required direct lanes only after the final retained behavior of the iteration.
