---
kind: concept
status: supported
last_reviewed: 2026-09-25
sources:
  - ./index.md
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/passes/no_inline.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ../inlining-optimizing/starshine-strategy.md
  - ../inline-main/starshine-strategy.md
---

# Starshine Strategy For `inlining`

## September 26, 2026 combined body facts

The planner and multivalue preparation now compute instruction count, direct
calls, loops, tail calls and tail calls nested in `try_table` in one traversal.
The previous independent shape/count helpers remain as bounded reference
checks. Candidate selection, profitability and rewrite order are unchanged.
The native helper benchmark improves `3.27 µs → 648 ns` for 128 blocks and
`12.98 → 2.66 µs` for 512 blocks. These are helper measurements, not full-pass
ratios. A red traversal-count regression, four structural fixtures and both
plain/optimizing command dispatch paths pass after implementation.

Sources: `src/passes/inlining.mbt`,
`src/passes/inlining_body_facts_{wbtest,perf_wbtest}.mbt`,
`src/cmd/perf_inlining_wbtest.mbt`, and the local
`.tmp/pass-perf-work-20260926/inlining-facts-*` measurement logs.
The [final shared renewal](../../../tooling/tracing-playbook.md#september-26-2026-pass-time-allocation-and-indexing-renewal) records verified-v133
artifact measurements and aggregate fuzzing; earlier v131/v132 evidence below
retains its original scope.

## September 25, 2026 dead-suffix call scan

The dead-suffix preservation query now traverses the root suffix once and tests call targets against the marked-function array as it visits them. It no longer copies the suffix or recursively rescans it for every marked target. The self-call query uses a scalar target comparison instead of allocating a Boolean array through the function index. The traversal keeps the existing `Call`/`ReturnCall`, Block, Loop, TryTable, and If coverage; legacy Try remains outside this query.

In the [native helper benchmark](../../../../../src/passes/inlining_marked_suffix_perf_wbtest.mbt), 128 absent calls and 128 absent marked targets improved from `14.60 µs` to `183 ns`; 256 of each improved from `57.21 µs` to `354 ns`. Absent self-call queries on a 16-instruction body improved from `1.83 µs` to `21.14 ns` at function index 2048 and from `3.55 µs` to `21.50 ns` at index 4096. These synthetic negative queries isolate the helper; full-pass impact remains unmeasured.

## September 25, 2026 top-level marked dead-suffix query

The private-function collapse path has a separate query that recognizes only top-level calls after a top-level `unreachable` or one void block containing only `unreachable`. It now walks that body once and checks each call target against the marked array, rather than rescanning the body for every marked function. The [native helper benchmark](../../../../../src/passes/inlining_dead_suffix_marked_perf_wbtest.mbt) improved **21.33 µs → 171.24 ns** for 128 marked targets and 128 numeric pairs, and **83.38 µs → 329.25 ns** for 256 of each. Boundary tests preserve before/after-root, tail-call, nested-call, and invalid-index behavior; 30 existing Inlining white-box tests pass. Full-pass impact remains unmeasured.

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## September 25, 2026 signature-key builder measurement

The bulk signature-key builder now flattens the recursive type section once and memoizes formatted keys by flattened type slot. It preserves the existing per-absolute-function fallback for missing, recursive, or nonfunction type entries. In the [native white-box benchmark](../../../../../src/passes/inlining_signature_keys_perf_wbtest.mbt), 256 functions sharing the last of 256 type entries improved from `41.13` to `4.07 µs` (10.1×); 512 functions and types improved from `135.31` to `7.65 µs` (17.7×). A mixed single/grouped-type regression and 144 existing inlining tests pass. Direct individual signature lookups outside this builder still scan the type section; full-pass impact remains unmeasured.

## Current status

`inlining` is an active, supported module pass with no open Binaryen v131 pass-owned behavior gap. It shares its planner and rewrite engine with `inlining-optimizing` and `inline-main`, while preserving each public pass's distinct chooser and cleanup contract.

## Local owner map

- `src/passes/inlining.mbt`
  - whole-module summary and profitability;
  - partial splitter;
  - direct-call planner;
  - body-copy and local/type/control repair;
  - EH tail-call localization and hoisting;
  - helper removal and metadata remapping;
  - plain and optimizing entrypoints;
  - `inline-main` exact-target reuse.
- `src/passes/no_inline.mbt`
  - `no-inline`, `no-full-inline`, and `no-partial-inline` wildcard policy;
  - stable numeric names for stripped functions;
  - policy annotation copy/deduplication.
- `src/cli/cli.mbt` and `src/cmd/cmd.mbt`
  - Binaryen-compatible tuning flags, aliases, help, JSON config, merge precedence, and option propagation.
- `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`
  - active registry entries and module-pass dispatch.

## Implemented behavior

### Summary and eligibility

- direct-call and `ref.func` reference accounting;
- export/start/element/table/global roots;
- released v131 toolchain Always/Never hints;
- explicit no-full/no-partial policy separation;
- Binaryen's exact tiny, one-caller, trivial, flexible, loop, and shrink/speed ordering;
- generic trivial-instruction classification from HOT direct children, including `Shrinks` and `MayNotShrink`;
- direct-call-only recursion hazard tracking, so indirect/ref calls and their tail forms remain flexible-policy candidates;
- strict 2.5-bytes-per-expression combined-size estimate and strict configured ceiling.

### Partial splitting

- Pattern A leading-return guards;
- Pattern B multiple guarded bodies and optional final value;
- complete represented v131 Unary/`RefIsNull` simple-condition family;
- terminal result arms for returns, tail calls, traps, throws, and represented terminal-unreachable instructions;
- deterministic `byn-split-outlined-A$...` / `B$...` names;
- parameter forwarding, annotation copy, temporary-marker cleanup, and policy inheritance.

### Rewrite and repair

- operand evaluation into fresh parameter locals;
- copied body-local append/remap;
- per-execution initialization of numeric, vector, and nullable-reference locals;
- non-nullable local preservation without invalid zero synthesis;
- scalar and multivalue wrapper block types, including synthesized zero-param result types;
- callee `return` to wrapper-branch repair;
- nested direct/indirect/ref tail preservation at tail sites;
- nested direct/indirect/ref tail lowering at non-tail sites;
- EH-aware operand spills and call hoisting from `try_table`;
- table32/table64-aware indirect target spills;
- branch-depth repair for added hoist wrappers, all represented branch-on-* forms, branches to the function label, and `try_table` catch targets;
- reachable-call gating after unconditional terminators;
- bounded iteration and same-wave race guards.

### Removal and metadata

- private helper removal only after all represented uses disappear;
- function-index rewriting across module sections;
- function-name and function-annotation remapping;
- valid caller local-name preservation;
- untouched label-name preservation and rewritten label-map removal;
- outlined-helper annotation copy;
- plain mode remains free of the optimizing sibling's nested pipeline.

## Public options

The following Binaryen spellings are accepted and propagated end to end:

- `--always-inline-max-function-size` / `-aimfs`;
- `--one-caller-inline-max-function-size` / `-ocimfs`;
- `--flexible-inline-max-function-size` / `-fimfs`;
- `--inline-max-combined-binary-size` / `-imcbs`;
- `--inline-functions-with-loops` / `-ifwl`;
- `--partial-inlining-ifs` / `-pii`.

## Deliberate non-pass boundaries

These do not reopen direct inlining:

- legacy `try_delegate` representation;
- expression-level branch hints and other byte-offset code metadata;
- source-map offset repair;
- copied callee local/label debug-name synthesis;
- speculative indirect/ref callee recovery.

## Relationship to siblings

- `inlining`: profitability-driven whole-module direct inlining, then stop.
- `inlining-optimizing`: same direct engine, then touched-only `precompute-propagate` and the v131 default function pipeline.
- `inline-main`: exact `main` / `__original_main` chooser, no profitability, helper retained.

## Evidence and reopening criteria

Focused tests are `120/120`; white-box tests are `14/14`; full `moon test` is `9452/9452`. Plain and optimizing official-v131 GenValid closeout are each `10000/10000` normalized matches with no failures.

Reopen direct behavior only for a minimized semantic or validation failure, a source-backed missing v131 transform family, a proven size-losing Starshine divergence, or a pass-local performance regression. Shared nested-scheduler abstraction work remains tracked separately under `[O4Z-NESTED]001`.

## September 25, 2026: dead-suffix target collection

`inl_collect_dead_suffix_targets` retains first-seen target order and counts,
but promotes its linear target search to an integer hash index after eight
distinct targets. One-target suffixes stay on the direct array path to avoid
the allocation and lookup cost seen in an eager-map trial. The native helper
benchmark in `src/passes/inlining_dead_suffix_targets_perf_wbtest.mbt` measured
128 distinct targets at `4.04 → 2.63 µs` and 256 at `15.89 → 5.24 µs`.
Repeated one-target controls were stable at `181.31 → 180.76 ns` for 128 calls
and `316.45 → 311.61 ns` for 256. Full-pass impact remains unmeasured.

## September 27, 2026: one initialization scan per callee

The inline replacement builder now determines read-before-write initialization
for all copied locals in one instruction traversal, instead of traversing the
callee once per local. A write log restores the entry state after each child
region: writes inside blocks, loops, either if arm, and exception handlers do
not become definite writes in the enclosing sequence or a sibling. Parameters
are excluded, `local.tee` establishes a write, and a single copied local retains
the original early-return scan.

The bounded regression first failed with 16,384 instruction visits for 64 locals
and a 256-instruction body; the shared scan visits at most 256. Native focused
benchmarks compare both algorithms in the same binary: **20.22 µs → 428.04 ns**
at 64 locals and **314.29 µs → 1.49 µs** at 256. These isolate initialization
analysis, not the entire inlining pass. All 176 focused inlining tests and the
command fixture for both modes pass. Artifact timings and aggregate fuzz renewal
are recorded in the campaign section of the
[tracing playbook](../../../tooling/tracing-playbook.md).

Sources: [implementation](../../../../../src/passes/inlining.mbt),
[invariants](../../../../../src/passes/inlining_initialization_wbtest.mbt),
[benchmark](../../../../../src/passes/inlining_initialization_perf_wbtest.mbt),
[dispatcher fixture](../../../../../src/cmd/inlining_initialization_wbtest.mbt).

## September 27, 2026: lazy helper-retention signatures

Dead inlined helpers no longer resolve and format a function signature when
there is no positive retention quota. If a candidate requires quota checks,
removal lazily builds one signature table using the existing flattened-type
memoization. Removal order, first-retained helper selection, structural
signature grouping across type slots, and index remapping are unchanged.

The two bounded regressions first failed at three signature builds; they now
require zero builds without quotas and at most one with quotas, while asserting
the exact surviving original function indices and validating the result.
Native removal benchmarks measure **51.94 → 2.33 µs** (256 helpers, no quota),
**53.10 → 10.56 µs** (256, quota), **166.43 → 4.15 µs** (512, no quota), and
**170.03 → 20.24 µs** (512, quota). Whole-pass results and final generated
renewal are tracked in the [tracing playbook](../../../tooling/tracing-playbook.md).

Sources: [implementation](../../../../../src/passes/inlining.mbt),
[retention tests](../../../../../src/passes/inlining_retention_signatures_wbtest.mbt),
[benchmark](../../../../../src/passes/inlining_retention_signatures_perf_wbtest.mbt).

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

## September 27, 2026: rejected conditional-copy remapping

A prototype returned unchanged expression arrays and copied only the ancestors
of remapped function references. Red-first copied-slot checks, NaN payload,
source-array isolation, control/return-call/ref.func and active-dispatch fixtures
passed (148 focused tests). Native helpers improved 30.80 → 12.39 µs for 128
unchanged regions and 126.66 → 50.64 µs for one edit among 512 regions.

The full-pass evidence rejected this design. One warmup and three isolated
alternating compiler pairs measured these pipeline medians:

| Input | Pass | Before ms | Prototype ms |
| --- | --- | ---: | ---: |
| Small | inlining | 7.186 | 6.323 |
| Large | inlining | 1,999.105 | 2,219.615 |
| Small | inlining-optimizing | 121.070 | 116.702 |
| Large | inlining-optimizing | 718.368 | 738.684 |

All outputs were byte-identical, traced/untraced agreed and independent validation
passed. The **11.0% large plain-inlining regression** outweighs the small-input
and helper wins. Large optimizing inlining remains guarded; its admission timing
does not establish useful cleanup throughput. The prototype and its uncommitted
tests were removed completely. No production improvement or oracle signoff is
claimed. A future remapping design needs controls with dense changed references,
not only unchanged nested bodies, before another artifact comparison.

Evidence: `.tmp/pass-perf-next-20260927/rejected-inlining-cow.json`,
`inlining-cow-pairs-{small,large}/result.json`, `inlining-cow-bench-0.log`, and
saved sources under `rejected-inlining-cow/` in that directory. Rejected native
SHA-256: `441283bcd90e839f5e88fa04d9f7ae9db3040d09c597e834d4dc1e2763df998b`.
The restoration exactly matches the campaign's initial `inlining.mbt`, retaining
the user's pre-existing annotation changes. [Implementation](../../../../../src/passes/inlining.mbt).

## September 27, 2026: rejected coarse remap preflight

A second prototype scanned each top-level expression for an actually changed
function reference, retained unchanged trees, and used the original linear
copy for changed trees. Recursive copying did not repeat the preflight. The
unchanged-tree ownership assertion failed before implementation; all 148 focused
checks subsequently passed, including NaN payloads, source isolation, control
references and active dispatch.

Same-binary native controls measured unchanged 128-region trees **30.34 →
3.45 µs**, sparse late edits over 512 regions **122.16 → 137.08 µs**, and dense
edits **203.40 → 195.75 µs**. The extra scan costs work when a late reference
changes. In one warmup and three accepted alternating compiler pairs, large
plain inlining regressed **2,020.262 → 2,087.051 ms (3.3%)**. Small plain
inlining was 5.983 → 5.847 ms and small optimizing inlining 116.240 →
114.449 ms. Large optimizing inlining remains guarded (690.420 → 659.628 ms);
its admission timing cannot justify retaining a plain-pass regression.

All four pairs kept identical independently validated bytes and traced/untraced
agreement. The prototype and tests were removed; the original source including
pre-existing user annotation edits was restored exactly. No production win or
new oracle signoff is claimed. Any later remapping attempt should reuse facts
from an existing reference scan rather than adding another body traversal.

Evidence: `.tmp/pass-perf-next-20260927/rejected-inlining-preflight.json`,
`inlining-preflight-pairs-{small,large}/result.json`,
`inlining-preflight-bench-1.log` (the first round had foreign CPU contention),
and saved sources under `rejected-inlining-preflight/`. Rejected native SHA-256:
`a33adcdd12d05630a5a23f0fdc09d98839683b4964ecf621d0055a4bca69da5a`. [Implementation](../../../../../src/passes/inlining.mbt).
