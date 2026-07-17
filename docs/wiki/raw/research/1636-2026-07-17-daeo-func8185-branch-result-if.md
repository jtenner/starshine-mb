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
  - ./1635-2026-07-17-daeo-func8185-linear-coalescing.md
  - ./1633-2026-07-17-daeo-func8185-productive-cleanup-order.md
---

# DAEO Func 8185 branch-result `if` cleanup

## Goal

Continue the source-backed DAEO parity audit at defined Func `8185` / absolute Func `8206` after note `1635`, without accepting the residual block/branch/`unreachable` shape as representation drift.

The pre-slice endpoint was raw `3203257`, canonical `3264173`, and canonical-module gap `+1717` versus Binaryen v130. Func `8185` was canonical body `2644` versus `2429` (`+215`) with `68` blocks, `47` branches, and `9` `unreachable` instructions versus Binaryen's `50` / `38` / `0`.

## Source attribution

Binaryen sends every DAE-changed function through filtered `OptUtils::optimizeAfterInlining(...)`, which prepends `precompute-propagate` and reruns the default function optimization pipeline. Binaryen v130's `pass.cpp` deliberately runs `simplify-locals-nostructure` before coalescing because that early pass must not create `if`/block return values, then runs full `simplify-locals` after the first `coalesce-locals`. The late pipeline follows with repeated `vacuum`, local ordering/coalescing, `merge-blocks`, and `remove-unused-brs` cleanup.

Fresh current raw/canonical inspection found nine identical Func `8185` families matching that late structural result-formation contract:

- a non-void inner block contains a void `if`;
- the then arm computes the block result and branches to the inner block;
- the else arm computes an alternate result and branches to an outer result block;
- the `if` is followed by `unreachable` because neither arm falls through;
- the inner result is stored, an effectful call runs only on the then path, and the stored result is read back;
- a surrounding result block carries that value into the next outer continuation.

This is not a generic `unreachable` deletion. The semantic owner is the late full-`simplify-locals` result-`if` formation enabled by the filtered `optimizeAfterInlining` replay, with later block/branch cleanup consuming the exposed wrappers.

## Red-first coverage

The existing public broad-high normalized-literal fixture now includes the exact control family around an effectful imported call:

- plain `dead-argument-elimination` preserves the original `unreachable` form and all `65` body locals;
- optimizing DAEO converts the branch-valued void `if` to a result `if`, removes the redundant then-arm branch and `unreachable`, preserves the effectful continuation, validates, and still converges the surrounding exact-literal chain;
- exact `touch` and `sink` call counts remain asserted.

Before implementation, the public test failed because the optimized body still contained `unreachable`.

White-box coverage separately proves:

- the artifact-shaped depth-`3` outer branch is rebased to depth `2` while the then-arm depth-`1` branch disappears;
- an intervening read of the branch-result local rejects the rewrite and leaves the body unchanged.

## Retained implementation and safety

The selected broad-high structural cleanup now recognizes only this exact family.

- The inner block must be non-void and end in `if (void) ... else ...; unreachable`.
- The then arm must end in `br 1`; the else arm must end in the observed `br 2` or `br 3` family.
- Conditions and both result producers must contain no other branches, so removing one block requires only the proved terminal else-label decrement.
- The parent must immediately store the inner result and end with the same local read, optionally followed by the existing `br 1` to its parent.
- No nested access to that local is allowed inside the inner block, and no intervening access is allowed between the store and terminal read. The same physical slot may still be reused by conservative coalescing in disjoint regions; global one-use counts are not incorrectly required after coalescing.
- The then producer becomes the fallthrough result of a typed `if`; the else producer keeps its outer exit with the label depth decremented by exactly one.
- The local store, effectful continuation, terminal read, outer branches, calls, traps, and result types remain in source order.
- The rewrite runs only in the optimizing-only broad-high productive-definition cleanup. Plain DAE remains separate.
- Existing deep-cloned selected-definition validation, selected-function encoded-size profitability, and rollback remain authoritative. No encoded growth is accepted.

This is not permission for generic unreachable-if flattening, arbitrary branch rebasing, or broad structured coalescing.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8185-branch-result-if-final3-20260717/`.

- raw size: `3203203`, `-54` versus note `1635`;
- canonical size: `3264119`, `-54` versus note `1635`;
- Binaryen-v130 canonical module: `3262456`;
- canonical module gap: `+1663`;
- raw SHA-256: `f38070759716efaa44b9e248e501f497b35378c57121042c9a6ecf5bcdb1f3ca`;
- canonical SHA-256: `10b8176ebd28b2a7c4fd970785302296da6a41ec7df2b05c6ca3416e3cf5546d`;
- native SHA-256: `6647b9913d403b170ad2f672198c622382a97e391ba6b48c0c0a62765a7cff37`.

Canonical body matrix:

| defined Func | note `1635` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2644` | `2590` | `2429` | `+161` |
| `8186` | `11` | `11` | `10` | `+1` |
| `8187` | `767` | `767` | `961` | `-194` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

All nine exact families fire. Func `8185` control counts become `59` blocks / `38` branches / `0` `unreachable`, versus Binaryen's `50` / `38` / `0`. The branch and unreachable gaps are closed exactly; nine extra blocks remain. Declared locals and local traffic stay at `101` locals and `241/86/16` gets/sets/tees versus Binaryen's `107` and `156/142/18`.

The remaining `+161` is therefore still a parity gap dominated by excess local gets and nine residual blocks, not accepted representation drift.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0 --strip-debug` canonical form. Both raw and canonical outputs validate with `wasm-tools validate --features all`.

## Runtime accounting

The retained run records `77860456us` pass-local / `79.662s` wall. This is about `0.4%` slower than note `1635`'s `77548061us` trace while removing `54` raw and canonical bytes and closing all nine branch/`unreachable` residuals.

The converged second invocation is `5096864us` pass-local / `6.729s` wall.

No unrelated CPU-heavy side-work was active at the baseline snapshot.

## Validation

- red-first public fixture: failed before implementation because optimizing DAEO retained `unreachable`;
- focused branch-result white-box tests: `2/2`;
- focused public broad-high fixture: `1/1`;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `273/273`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8889/8889`;
- native release build: passed with pre-existing warnings;
- first/second raw and canonical validation: passed;
- first/second raw and canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-branch-result-if-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-branch-result-if-regular-1000`: same result.

Both compare lanes use seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused slice smokes, not replacements for the full required four-lane closeout matrix.

## Remaining work

Func `8185` remains the next direct body owner at `+161`. Its branch and `unreachable` counts now match Binaryen exactly, leaving nine extra blocks and much higher local-get traffic. Re-extract the retained WAT before coding and identify the first repeated residual local/block family. Do not retry blanket local ordering, full selected structured coalescing, or the rejected all-generic productive replay without new evidence.

Func `8184 +16`, the full four-lane DAEO closeout matrix, and pre-slot public optimize/shrink/O4z blockers remain active.
