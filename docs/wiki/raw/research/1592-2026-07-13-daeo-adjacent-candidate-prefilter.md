# DAEO adjacent candidate prefilter

Date: 2026-07-13

## Scope

This slice preserves note `1591`'s exact output while reducing the selector cost. The first implementation scanned every definition below `8192` for exact-literal candidacy and only then checked the eight-definition adjacent-pair neighborhood. On the retained artifact that inspected `44` exact-literal candidates even though only one high-local adjacent same-signature caller/callee pair was eligible.

The retained implementation inverts the search:

1. scan the bounded `4096..8199` neighborhood once for adjacent same-signature pairs with at least `128` locals each and a second-to-first direct-call edge;
2. expand only the preceding eight possible root definitions for each pair;
3. run exact-literal candidacy checks only for those bounded roots;
4. rank the same aggregate-constructor root and pair payoff as note `1591`.

A trace contract reports the number of productive roots and pairs considered. This is a bounded-work performance invariant, not telemetry-only coverage.

## Red-first contract

The existing `8193`-function adjacent-pair regression now requires:

```text
pass[dae-optimizing]:broad-exact-param-adjacent-candidates roots=1 pairs=1
```

The test failed before the prefilter because the trace and bounded candidate worklist did not exist. It passes after the implementation while preserving root selection, cleanup output, validation, and plain-DAE separation.

## Artifact evidence

Fresh explicit native binary:

- `_build/native/release/build/cmd/cmd.exe`;
- SHA-256 `2c6dd2c0173554363a1b4b7a8b7d6249591f5988eb405ed2637f96798e35f883`.

Output:

- `.tmp/daeo-adjacent-prefilter-20260713/starshine-direct.wasm`;
- SHA-256 `5f799dd0bd6c347041c33147f8c2230c19ed8a384cad5c0d1f0f67c6c6cbdf05`;
- byte-identical raw and canonical output to note `1591`;
- valid under `wasm-tools validate --features all`;
- candidate trace: `roots=2 pairs=1` on the artifact, followed by the same `root_def=7003 defs=[7007, 7008] payoff=4686` selection.

Performance:

| dimension | note 1591 | prefilter | delta |
|---|---:|---:|---:|
| DAEO pass-local | `12890.262ms` | `11098.255ms` | `-1792.007ms` (`-13.9%`) |
| DAEO / Binaryen `8083.49ms` | `1.59x` | `1.37x` | more headroom under `<=2x` |
| raw wasm | `3198310` | `3198310` | identical |
| canonical wasm | `3275701` | `3275701` | identical |

Agent judgment: this is an output-preserving pass-local performance win that narrows work to the source-connected neighborhood and keeps the selector bounded. No direct artifact difference is classified away.
