---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ./1632-2026-07-17-daeo-func8187-normalized-literal-chain.md
---

# DAEO Func 8185 productive cleanup and local order

## Goal

Reduce the next source-backed canonical body owner after Func `8187`, preferring defined Func `8185` / absolute Func `8206`, while preserving plain-DAE separation, validation, one-invocation raw/canonical convergence, the `< +10000` canonical-module boundary, and explicit runtime accounting.

The accepted pre-slice endpoint was `.tmp/daeo-func8187-final-bench-20260717/`: raw `3203546`, canonical `3264761`, and canonical-module gap `+2305` versus Binaryen v130. Func `8185` was `2978` bytes versus Binaryen's `2429`, the largest remaining local-cluster gap at `+549`.

## Attribution

Binaryen v130's `DeadArgumentElimination.cpp` sends every changed function in `worthOptimizing` through `OptUtils::optimizeAfterInlining(...)`. `opt-utils.h` runs `precompute-propagate` followed by the default function optimization passes. The default pass sequence includes repeated local cleanup and access-frequency `reorder-locals`.

Starshine's broad high exact-literal chain already changed Funcs `8184`, `8185`, and `8187`, but its final changed-function replay selected only the final productive definition, Func `8187`. Canonical WAT/body inspection attributed Func `8185` to two concrete families:

- `220` declared body locals in Starshine versus `107` in Binaryen, with `128` local accesses using indexes `>=128`;
- excess local/control traffic: Starshine had `279/124/17` local gets/sets/tees and `48/48/9` blocks/branches/unreachables versus Binaryen's `156/142/18` and `38/38/0`.

This is an optimizing-after-inlining changed-function cleanup/order owner. It is not a new exact-literal proof and not plain DAE behavior.

## Retained implementation

- Every productive broad-high definition is probed independently, with a deep-cloned selected body, selected-definition validation, selected-function encoded-size profitability for body-changing cleanup, and per-definition rollback. One rejected definition cannot roll back an accepted sibling.
- All productive definitions first receive direct unused-local compaction. The compactor preserves current parameters and remaps only body locals proven unreferenced.
- The final productive callee and small earlier links retain the existing full coalesce/dead-write/structural/generic-cleanup/reorder transaction.
- Large intermediate productive bodies do not run the expensive generic hot-pass round. They receive the direct counted compaction/dead-write/structural subset only, retained only when the selected raw function encoding strictly shrinks.
- After all DAEO body mutation and type handling, the largest productive body is the sole broad-high public `reorder-locals` candidate. It is deep-cloned and validated. This matches Binaryen's source-backed access-frequency ordering and avoids ordering a body before later cleanup changes its access profile.
- Plain `dead-argument-elimination` does not schedule the broad-high chain, productive cleanup, or final broad-high reorder. Existing exact-literal call-count, escape, read-only, signature, callsite, validation, and rollback contracts remain authoritative.

The red-first public regression widens the high-chain middle function above the `64`-local generic-cleanup boundary. Before implementation it retained the removed parameter plus `65` unused locals. After implementation both productive intermediate bodies have no remaining local declarations, while plain DAE retains all three parameters. A white-box regression separately proves selected compaction preserves the parameter index and removes only unused body locals.

## Rejected probe

A first probe ran the entire generic final cleanup round on every productive definition. Func `8185` was not profitable and rolled back, while the artifact pass took `102574320us`. That probe was rejected. The retained direct counted subset plus finalized reorder produces the measured body win without keeping that generic setup cost.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-final-20260717/`.

- raw size: `3203633` bytes, `+87` versus the Func-8187 endpoint;
- canonical size: `3264486` bytes, `-275` versus the Func-8187 endpoint;
- Binaryen-v130 canonical module: `3262456` bytes;
- canonical module gap: `+2030`;
- raw SHA-256: `373905bd613a959c182366226c35a1a77ac05cadc7473e0d03c651577d6521bb`;
- canonical SHA-256: `9dc8d2249c25d5250c54c4bbdf3b8f9c18c1c87989df3cf97d1ed1821664153e`;
- native SHA-256: `68638ed1f1129c93dcb152930173763b467eee1cc7ce60ba342acfe4cb738344`.

Canonical body matrix:

| defined Func | pre-slice | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `40` | `27` | `11` | `+16` |
| `8185` | `2978` | `2748` | `2429` | `+319` |
| `8186` | `218` | `218` | `10` | `+208` |
| `8187` | `767` | `767` | `961` | `-194` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8185` improves by `230` canonical body bytes and its gap falls by about `42%`, from `+549` to `+319`. Func `8184` also improves by `13` bytes. Func `8187` and the closed payoff bodies are unchanged.

After cleanup/order, Func `8185` has `126` declared body locals, zero accesses at indexes `>=128`, and `265/110/16` local gets/sets/tees. The remaining `+319` is still a parity gap: Binaryen has only `107` declared locals, `156/142/18` local gets/sets/tees, and ten fewer block/branch pairs plus nine fewer `unreachable` instructions. This residual is not accepted representation drift.

The raw `+87` / canonical `-275` tradeoff is explicit. The finalized access-frequency reorder changes local declaration grouping in Starshine's raw encoding but removes every two-byte local-index access in Binaryen-v130 canonical form. The tracked goal is the canonical body/module gap, and the retained output is a measured canonical size win with source-backed ordering rather than an unclassified raw regression.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0 --strip-debug` canonical form. Both validate with `wasm-tools validate --features all`.

## Performance judgment

The best final uncontaminated trace is `77550540us` pass-local and `79.42s` wall, only about `0.4%` above the best stable Func-8187-equivalent endpoint `77225519us`. The broad-high chain itself falls from the prior accepted `7626211us` trace to `6909601us` in that run.

A CPU-affinity repeat measured `82052342us`, but its start snapshot records two concurrent near-100% `moonc` link jobs in `/data/workspaces/229/starshine-sidework`; it is contamination evidence, not the baseline. The earlier all-generic rejected probe measured `102574320us` and is the concrete reason large intermediate bodies keep the direct counted subset instead of the full generic round.

Relative to the pre-Func8187 reference `71492436us`, the accepted final trace remains about `8.5%` slower. This slice does not hide that inherited tradeoff; it adds a `230`-byte Func `8185` reduction with essentially flat time versus the accepted Func8187 endpoint. Generic selected hot-pass setup remains a future performance owner.

The converged second invocation is `5488207us` pass-local / `7.22s` wall.

## Validation

- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `268/268`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8884/8884`;
- native release build: passed;
- first/second `wasm-tools validate --features all`: passed;
- first/second raw and Binaryen-v130 canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-func8185-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `984/16`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-func8185-regular-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `0/1000`.

The full four-lane DAEO closeout matrix was not refreshed for this bounded body slice. Func `8185` remains the largest local-cluster parity owner at `+319`, followed by Func `8186 +208` and Func `8184 +16`; the next source-backed Func `8185` audit should inspect the residual block/branch/unreachable and local get/set shape rather than rerunning blanket local order or the rejected all-generic cleanup probe.
