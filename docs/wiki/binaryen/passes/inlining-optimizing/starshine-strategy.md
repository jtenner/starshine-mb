---
kind: concept
status: supported
last_reviewed: 2026-09-26
sources:
  - ./index.md
  - ../inlining/starshine-strategy.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals_liveout_perf_wbtest.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./planning-partial-inlining-and-reruns.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
---

# Starshine Strategy For `inlining-optimizing`

> **Comparison baseline — September 26, 2026:** new comparisons use [Binaryen 133](../../release-horizon-and-oracles.md). Recorded v131 and v132 evidence retains its historical version and does not establish v133 signoff.

## Current status

`inlining-optimizing` is an active, supported module pass. Its direct engine is the same v131-aligned engine documented for plain [`inlining`](../inlining/starshine-strategy.md). Optimizing mode adds touched-function cleanup in Binaryen's v131 order.

## Local execution path

1. Build summaries and choose direct inlining actions.
2. Rewrite all selected callsites in each caller.
3. Repair locals, multivalue blocks, returns, branch depths, nested tail calls, and EH hoists.
4. Remove now-dead private helpers and remap sections/metadata.
5. Convert absolute touched-function bits to defined-function bits.
6. Run touched-only `precompute-propagate`.
7. Run `inlining_nested_function_pipeline_passes(...)` on touched functions.
8. Validate or fall back if a nested candidate is invalid.

## Nested-pipeline invariants

- exact v131 ordering is tested;
- option-gated passes follow optimize/shrink levels;
- untouched functions are not mutated;
- imports do not shift touched defined-function indices;
- large modules are not skipped wholesale;
- surviving tail calls are not a blanket bypass;
- plain `inlining` never runs the suffix;
- trace output identifies each nested slot.

The shared scheduler abstraction for DAE/inlining/SGO is still tracked under `[O4Z-NESTED]001`. Consolidating that API must preserve this pass's current tested order and behavior.

## Direct behavior inherited from `inlining`

- all six Binaryen tuning controls and aliases;
- v131 `@binaryen.inline` policy;
- no/full/partial inline markers;
- complete represented trivial-instruction policy;
- direct-call-only recursion hazard tracking;
- Pattern A/B partial splitting;
- EH-aware direct/indirect/ref tail-call repair;
- table64 indirect target spills;
- branch/catch depth repair;
- root survival, helper deletion, and metadata remapping.

## Performance

The durable pass-local fixture is the inline-heavy helper-chain matrix described in [`fuzzing.md`](./fuzzing.md). The accepted post-repair ratios meet the repository's `<= 1x Binaryen` target across 1, 5, 10, 20, 50, and 100 helper cases. Reopen on repeated regression above that target or a new nested-pass scaling cliff.

### September 26, 2026 selective lifetime summaries

The [shared guard now builds summaries only when an earlier capture needs their reads](../simplify-globals-optimizing/starshine-strategy.md#september-26-2026-selective-lifetime-summaries).
It preserves the existing lifetime boundary and avoids rescanning capture-free
parents before a late nested hazard. Focused helper gains remain separate from
optimizing-inlining artifact and final aggregate evidence.

### September 26, 2026 structured-lifetime summaries

Nested cleanup uses the [shared structured-lifetime summary](../simplify-globals-optimizing/starshine-strategy.md#september-26-2026-structured-lifetime-summaries).
Candidate-rich helper benchmarks improve from `220.96 → 18.21 µs` and
`881.46 → 37.14 µs` at 128/256 captures. Touched-function isolation, pass order
and the lifetime predicate remain unchanged; no whole-inlining speedup is
inferred from these helper measurements.

### September 26, 2026 shared structured-lifetime guard

The subsequent [guard-bound optimization](../simplify-globals-optimizing/starshine-strategy.md#september-26-2026-structured-lifetime-guard-bounds) reduces small-fixture optimizing-inlining pipeline time from `129.889ms` to `120.510ms` (7.2%) across three alternating pairs after one warmup, with identical output. It preserves the existing call-capture lifetime predicate and avoids searching ordinary tails without a later structured body.

### September 26, 2026 precompute tail rejection

After the raw SimplifyLocals improvements below, the nested precompute infinite-loop matcher still scanned the growing instruction prefix after every emitted instruction. A backward suffix scan now stops at the first blocking instruction with the same transform contract. Three alternating native pairs after one warmup on the 192,893-byte fixture improve this pipeline from `204.648ms` to `128.793ms` (37.1%), and command time from `208.888ms` to `133.174ms`, with byte-identical output. A fresh verified-v133 sweep still measures `140.302ms` versus `44.769ms` pass-local; the remaining gap stays open. The [precompute strategy](../precompute/starshine-hot-ir-strategy.md#september-26-2026-infinite-loop-tail-scan) owns the implementation proof, scaling fixtures, hashes and renewed comparison evidence.

### September 26, 2026 raw cleanup suffix scans

The shared SimplifyLocals raw cleanup rebuilt continuation read sets for every instruction. It now accumulates original-subtree reads once in reverse sibling order, writes rewritten children into their original positions, and skips continuation analysis in flat bodies. Loops retain their own next-iteration reads. This follows the same aim as [Binaryen 133's linear execution traversal](https://github.com/WebAssembly/binaryen/blob/version_133/src/passes/SimplifyLocals.cpp): avoid repeatedly analyzing instruction suffixes.

On the 192,893-byte fixture, three alternating paired native samples after one warmup reduced the `inlining-optimizing` pipeline median from `1,892.011ms` to `214.775ms` (8.81x); command median fell from `1,896.974ms` to `219.582ms`. On the 6,211,596-byte fixture, full SimplifyLocals pipeline time fell from `27,115.200ms` to `22,658.906ms` (16.4%). These are whole-pipeline measurements, including raw cleanup, not just HOT pass timers. Every paired baseline/current output hash is identical across eight passes on both fixtures.

A separate verified-v133 small sweep measured `inlining-optimizing` at `223.547ms` pass-local versus Binaryen's `47.037ms`; the remaining 4.75x gap stays open. The large fixture's inlining and SimplifyGlobals guards miss cleanup, so their favorable oracle timing ratios are not comparable optimization wins. A seven-sample no-structure confirmation measured pipeline `750.413ms → 756.744ms` and command `1,572.920ms → 1,574.132ms`; the initial three-sample apparent regression did not repeat materially. Other small timing movements are not claimed as gains.

Four bounded regressions cover flat dead-capture removal, later sibling reads, original reads removed by child cleanup, and structured sibling scaling. The structured test first failed at 8,384 suffix root visits and now needs at most 130. All 1,250 focused SimplifyLocals, inlining, DAE optimizing and SimplifyGlobals tests pass on wasm-gc. `moon info`, formatting and the native release build pass; this unit adds no public API.

Paired artifacts are `.tmp/liveout-linear-paired-{small,large}-20260926/` and `.tmp/liveout-linear-paired-nostructure-confirm-20260926/`; oracle sweeps are `.tmp/pass-sweep-v133-liveout-linear-{small,large}-20260926/`. Baseline native SHA-256 is `72b55be2e092167030dccf79d6e48f646d338c16791852a9a9171d73b41b9894`; updated SHA-256 is `2a1772b917dcd61d58b6949524243dec37903c36f7761d8500cef0850b935552`. Binaryen reports version 133 and SHA-256 `8f25e9fd5db0fc5f210003aaa432922feb2e52d309e430def2f929e34da9466b`.

#### v133 aggregate comparison renewal

All eight dedicated aggregate profiles completed 10,000 cases each with seed `0x5eed`, explicit prebuilt native compiler/generator and eight subprocesses. There were zero validation, property, generator or command failures and zero cleanup-normalized matches; the DAE optimizing lane enabled both documented debris normalizers. Runtime semantic execution was not enabled.

| Pass | Normalized matches | Residuals | Canonically larger | Oracle cache hits/misses |
| --- | ---: | ---: | ---: | ---: |
| `inlining-optimizing` | 10,000 | 0 | 0 | 9,992/8 |
| `dae-optimizing` | 5,153 | 4,847 | 0 | 7,370/2,630 |
| `simplify-globals-optimizing` | 5,055 | 4,945 | 0 | 9,992/8 |
| `simplify-locals` | 380 | 9,620 | 0 | 10,000/0 |
| `simplify-locals-nonesting` | 5,026 | 4,974 | 0 | 10,000/0 |
| `simplify-locals-notee` | 0 | 10,000 | 0 | 10,000/0 |
| `simplify-locals-nostructure` | 0 | 10,000 | 1,662 | 10,000/0 |
| `simplify-locals-notee-nostructure` | 0 | 10,000 | 0 | 10,000/0 |

Agent classification: optimizing inlining matches this aggregate. Other residuals remain open parity gaps; no-structure's 1,662 larger cases are size-losing gaps. Inspected examples include DAE local-constant/call-operand cleanup with retained dropped reads, and SimplifyGlobals' removed empty-body `nop`; smaller output alone does not settle their whole families. All 140 saved residual outputs are byte-identical to the pre-change compiler, establishing that these saved differences predate this optimization. This is bounded regression evidence, not a semantic proof for every residual.

Reports, selected-subprofile counts and per-case manifests are under `.tmp/pass-fuzz-<pass>-liveout-v133-10000-20260926/`; replay evidence is `.tmp/liveout-baseline-residual-replay/`. Profile names are the documented `<pass>-all` aggregates, except DAE optimizing's `dae-optimizing` profile.

## Evidence

- focused behavior: `120/120`;
- white-box: `14/14`;
- full repository: `9452/9452`;
- official-v131 aggregate: `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000`, `10000/10000` normalized matches and zero failures.

## Non-pass boundaries

Expression-level branch hints, source maps, copied callee debug-name synthesis, and legacy `try_delegate` remain shared representation/metadata work. They do not reduce the represented v131 wasm behavior contract.

## Reopening criteria

Reopen for a minimized semantic/validation mismatch, a source-backed missing v131 family, a measured size regression without a Starshine benefit, a pass-local timing regression, or a shared scheduler change that alters the tested touched-only roster.

### September 27, 2026: copied-local initialization

Both inlining modes use the shared single traversal described in the
[plain inlining strategy](../inlining/starshine-strategy.md#september-27-2026-one-initialization-scan-per-callee).
The optimization preserves conservative write boundaries across structured
control and handlers; the command regression verifies default values after
optimizing cleanup as well as plain inlining.

Helper removal also uses the [lazy signature table](../inlining/starshine-strategy.md#september-27-2026-lazy-helper-retention-signatures):
empty quotas skip signature work; positive quotas share one build and preserve
first-retained helper order.

## September 27, 2026: sparse retention candidates

The retention cache now formats keys only for eligible helpers, memoizing by
flattened type slot. A positive quota no longer formats every unrelated function
signature. The shared bulk builder uses the same resolver, so grouped types,
invalid-index fallbacks, structural signature equivalence and retention order
keep their existing behavior.

A bounded fixture with 64 distinct type slots and two eligible helpers first
formatted 64 signatures; it now formats at most two, retains the first eligible
helper and preserves every unrelated function. The result validates. Sparse
256/512-function native controls improved from **33.95/63.80 µs to
14.99/28.66 µs**; dense, no-quota and full-table controls did not regress.
Final measurements and generated renewal are recorded in the
[tracing playbook](../../../tooling/tracing-playbook.md).

Sources: [cache and removal](../../../../../src/passes/inlining.mbt),
[retention invariants](../../../../../src/passes/inlining_retention_signatures_wbtest.mbt),
[sparse/dense benchmarks](../../../../../src/passes/inlining_retention_signatures_perf_wbtest.mbt),
[grouped-type resolver control](../../../../../src/passes/inlining_signature_keys_perf_wbtest.mbt).
