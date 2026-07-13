# DAEO converged exact-param chain cleanup

Date: 2026-07-13

## Scope

This slice extends the existing broad-module low exact-parameter cleanup neighborhood from the prefix pair to every definition that the bounded convergence phase productively rewrites. The motivating current artifact owner is defined Func `41`: DAEO refined it after Funcs `37` and `38`, but the special large-module cleanup set remained fixed at `37,38`, so Func `41` missed the same selected `simplify-locals` / `vacuum` suffix. Plain `dead-argument-elimination` remains unchanged.

Binaryen's optimizing sibling reruns nested optimization on changed functions. Starshine still keeps its artifact-sized broad cleanup bounded, but the selected set now follows actual convergence evidence instead of stopping before a productive function.

## Red-first contract

The existing `4097`-function low null-default chain fixture already converges through defined Funcs `38` and `41`. This slice adds pure local-copy debris to Func `41` and requires:

- the convergence trace to retain `primary_def=41`;
- the selected cleanup trace to report `[37, 38, 41]` for both cleanup passes;
- Func `41` to contain no surviving `local.set` after DAEO.

Before implementation, the test failed on the old `defs=37,38` cleanup trace and Func `41` was not selected. After implementation, focused and full `dae_optimizing_test.mbt` passed `312/312`.

The implementation marks every in-range `convergence.productive_defs` entry in the existing cleanup bitset, derives the trace list from the bitset, and still runs exactly the existing two-pass bounded cleanup sequence once. No artifact function index is added to production selection.

## Direct artifact evidence

Fresh native release binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `62a3c7a118d2119c085a3e2d7cb95bb93c23d772c788028a55dcd7fce4794455`.

Retained direct output:

- `.tmp/daeo-low-chain-cleanup-20260713/starshine-direct.wasm`;
- SHA-256 `465d68ec3c822f7bf3f4d536506479cdd0e8cbf60cede646f25a3e23eea74888`;
- repeat output is byte-identical;
- output validates with `wasm-tools validate --features all`.

The trace selects `[37, 38, 41]`, then preserves the two payoff-ranked transactions from note `1588`:

```text
low-exact-param-chain-cleanup defs=[37, 38, 41] pass=simplify-locals
low-exact-param-chain-cleanup defs=[37, 38, 41] pass=vacuum
payoff-dropped-result-chain wrapper_def=12293 callee_def=8429 payoff=6179
payoff-dropped-result-chain wrapper_def=12020 callee_def=9347 payoff=5028
```

Size and timing movement from note `1588`:

| dimension | two-chain | converged cleanup | delta |
|---|---:|---:|---:|
| raw wasm | `3198785` | `3198681` | `-104` |
| canonical wasm | `3276187` | `3276084` | `-103` |
| canonical gap versus Binaryen | `+13731` | `+13628` | `-103` |
| Func `41` canonical body gap | `+2063` | `+1960` | `-103` |
| DAEO pass-local | `8914.522ms` | `9350.478ms` | `+435.956ms` |
| DAEO / Binaryen pass-local | `1.10x` | `1.16x` | remains within `<=2x` |

Agent judgment: this is a source-aligned, deterministic, valid, size-winning extension to an already productive convergence set. It has no important pass-local regression under repository guidance, but the remaining Func `41` gap is still a parity gap rather than an accepted difference.

## Generated smoke

Dedicated `dae-optimizing` profile output `.tmp/pass-fuzz-daeo-low-chain-cleanup-dedicated-1000-20260713` used both required DAE normalizers, `--jobs auto`, and the explicit rebuilt native binary:

- requested/compared `1000/1000`;
- normalized `1000`;
- cleanup-normalized `0`;
- mismatches/failures `0`;
- Binaryen cache `1000/0`.

## Follow-up

- Func `41` remains the largest positive canonical owner at `+1960`; the simple selected suffix closes only `103` bytes of it.
- Funcs `7007` and `7008` remain a paired `+1873` / `+1848` owner family and should be attributed before broader cleanup widening.
- Refresh the full four-lane direct matrix only after the final retained behavior of the iteration.
