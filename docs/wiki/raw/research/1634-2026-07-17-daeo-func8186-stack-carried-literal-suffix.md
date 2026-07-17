---
kind: research
status: supported
created: 2026-07-17
updated: 2026-07-17
sources:
  - ../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../src/passes/pass_manager_wbtest.mbt
  - ../binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ./1633-2026-07-17-daeo-func8185-productive-cleanup-order.md
---

# DAEO Func 8186 stack-carried literal suffix

## Goal

Continue the source-backed broad-high DAEO parity audit after note `1633`, preferring residual Func `8185` unless an adjacent dependency had to land first, while preserving exact call/signature safety, wasm validity, one-invocation raw/canonical convergence, the `< +10000` canonical-module boundary, plain-DAE separation, and explicit runtime accounting.

Defined Func `8186` / absolute Func `8207` had to precede further Func `8185` cleanup. It was a six-parameter carrier with canonical body `218` versus Binaryen v130's one-parameter, `10`-byte body. Func `8185` called it `16` times. Every call ended in the same immediate `i32.const 0`, but older arguments remained stack-carried across effectful void calls, so Starshine's complete actual-value slicing correctly refused to claim the whole argument list.

## Attribution

Binaryen's DAE contract materializes a parameter when all direct callsites provide the same value, then updates the function signature, every callsite, and the callee body before optimizing changed functions. The observed Func `8186` family is still that exact constant-actual contract: the final control parameter is uniformly zero at all `16` owned direct calls. The blocker was Starshine's conservative call-value reconstruction, not a different semantic transform.

The required widening is narrow. A void effect can consume values above older call arguments while those arguments remain below it on the wasm stack. Complete backward slicing therefore encounters a zero-result instruction before reconstructing all operands and fails closed. For this artifact family, the final `i32` argument remains the instruction immediately before the direct call and is independently provable without treating the older effectful stack as constant or removable.

## Red-first coverage

The existing broad-high normalized-literal-chain fixture was widened with:

- a six-parameter carrier whose final `i32` controls a branch;
- two calls with the same immediate final zero;
- older scalar arguments carried across imported effectful void calls;
- productive imported calls whose order and count must remain unchanged;
- plain `dead-argument-elimination` assertions proving the optimizing-only separation.

Before implementation the carrier retained six parameters. The retained behavior reduces it to one parameter, folds the zero-controlled branch, preserves four `touch` calls and two `sink` calls in the middle function, and still converges the surrounding chain. A white-box negative fixture proves conflicting immediate suffix literals reject the candidate.

A temporary global opt-in regressed the existing Func323 inter-argument boundary. The retained implementation makes the fallback explicit only in the broad-high exact-literal chain; ordinary DAEO and plain DAE keep the prior complete-slice requirement.

## Retained implementation and safety

- Recursively inspect only the already-owned direct-caller set from current call-boundary facts.
- Require every direct target call to have an immediate final `i32.const` suffix and require the literal to be identical across the exact recorded direct-call count.
- Reject exports, escapes, self callers, tail/unowned boundaries, conflicting literals, count drift, malformed nested control, non-`i32` final parameters, final-parameter writes, and any candidate already containing unread parameters.
- Prioritize this exact stack-carried suffix family before ordinary broad-high payoff ranking so Func `8186` is reduced before its caller Func `8185` receives finalized cleanup and ordering.
- Use the existing verified materialized-constant suffix transaction for the initial final-parameter rewrite. It rechecks every callsite, rewrites the callee body and function type, validates the module, and rolls back on any failure.
- Thread an explicit `allow_stack_carried_void_effects` mode through value slicing and callsite localization only for the follow-up unread-parameter retry. The alternate slice includes intervening void effects in the preceding removed operand rather than dropping or reordering them.
- Retry unread-parameter cleanup only when exactly one parameter remains and every removed parameter is unwritten. Existing direct-call counts, caller ownership, signature repair, local remapping, localization, validation, and rollback stay authoritative.
- Keep the fallback disabled by default and enable it only from the optimizing-only broad-high chain. Plain DAE remains unchanged.
- Avoid the generic cleanup setup for tiny zero-local productive bodies; direct structural cleanup is sufficient after the signature transaction.

This is not permission to skip arbitrary effectful instructions while reconstructing call arguments. It is a bounded proof for one uniform immediate final literal, followed by the existing effect-preserving transactional machinery for all removed older arguments.

## Artifact result

Input: `.tmp/daeo-scheduled-current-artifact-20260713/cmd-stripped.wasm`.

Accepted artifacts: `.tmp/daeo-func8186-final-20260717/`.

- raw size: `3203392` bytes, `-241` versus note `1633`;
- canonical size: `3264245` bytes, `-241` versus note `1633`;
- Binaryen-v130 canonical module: `3262456` bytes;
- canonical module gap: `+1789`;
- raw SHA-256: `f709e2356f29cc57d7f201f2f6d1d6774d182ad3b6cd1964b0f1c129acbcad70`;
- canonical SHA-256: `0597478a6acf4bf7285e3b08f7e1bc7bae9f2b9aae737ef421eb47262f0efaa4`;
- native SHA-256: `26ed277bff6a886fb199289857ddf18e79d9fb2052f2da53ea15e227841429ec`.

Canonical body matrix:

| defined Func | note `1633` | retained | Binaryen v130 | retained delta |
|---:|---:|---:|---:|---:|
| `8184` | `27` | `27` | `11` | `+16` |
| `8185` | `2748` | `2716` | `2429` | `+287` |
| `8186` | `218` | `11` | `10` | `+1` |
| `8187` | `767` | `767` | `961` | `-194` |
| `8429` | `25694` | `25694` | `25742` | `-48` |
| `9347` | `14706` | `14706` | `15405` | `-699` |

Func `8186` falls by `207` canonical body bytes and is effectively closed at `+1`. Reducing the carrier also improves its caller Func `8185` by `32` bytes without worsening the closed Func `8187` or payoff bodies. The module improves equally in raw and canonical form, so this slice has no raw/canonical size tradeoff.

The first and second DAEO outputs are byte-identical in raw and Binaryen-v130 `--all-features -O0 --strip-debug` canonical form. Both validate with `wasm-tools validate --features all`.

## Performance judgment

The best uncontaminated-looking retained trace observed during implementation was `81795817us` pass-local / `83.672s` wall, about `5.5%` above note `1633`'s `77550540us` endpoint. That is an explicit runtime cost for the `207`-byte carrier closure plus `32`-byte caller improvement; it remains far below the rejected note-`1633` all-generic probe at `102574320us`.

The final artifact rerun recorded `92064054us` pass-local / `93.967s` wall while an unrelated `100000`-case simplify-locals compare process was consuming substantial CPU in another workspace. Treat that final number as contaminated reproducibility evidence, not as a hidden clean baseline or a claim that the retained implementation is faster.

The wider whole-pass runtime remains open. This slice preserves bounded candidate selection and does not schedule the fallback globally.

## Validation

- red-first broad-high carrier fixture: failed before implementation by retaining six parameters;
- conflicting-literal white-box rejection: passed;
- `moon info`: passed with pre-existing warnings;
- `moon fmt`: passed;
- `pass_manager_wbtest.mbt`: `269/269`;
- `dae_optimizing_test.mbt`: `336/336`;
- full `moon test`: `8885/8885`;
- native release build: passed;
- first/second `wasm-tools validate --features all`: passed;
- first/second raw and Binaryen-v130 canonical `cmp`: byte-identical;
- dedicated profile `.tmp/pass-fuzz-dae-optimizing-func8186-profile-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`;
- regular GenValid `.tmp/pass-fuzz-dae-optimizing-func8186-regular-1000`: `1000/1000` normalized, zero cleanup-normalized matches, mismatches, validation/generator/property/command failures, Binaryen cache `1000/0`.

Both compare lanes used seed `0x5eed`, Binaryen v130, `--jobs auto`, the explicit native binary, and both DAE cleanup normalizers. They are focused slice smokes, not replacements for the required four-lane closeout matrix.

## Remaining work

Func `8186` is no longer the prerequisite. The next direct body owner is again Func `8185`, now canonical `2716` versus Binaryen's `2429` (`+287`), followed by Func `8184 +16`. Continue from source-backed residual local/control shape in Func `8185`; do not retry blanket local ordering or the rejected all-generic productive replay. The full four-lane DAEO closeout matrix and pre-slot public optimize/shrink/O4z blockers remain active.
