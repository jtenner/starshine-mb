---
kind: concept
status: supported
last_reviewed: 2026-10-07
sources:
  - index.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/precompute_propagate_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_precompute_propagate_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-worklist-fallthrough-and-merge-boundaries.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../precompute/index.md
  - ../precompute/starshine-hot-ir-strategy.md
  - ../dae-optimizing/starshine-strategy.md
  - ../inlining-optimizing/starshine-strategy.md
---

# Starshine `precompute-propagate` strategy

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

## September 27, 2026 cleanup context reuse

The [shared precompute cleanup repair](../precompute/starshine-hot-ir-strategy.md#september-27-2026-shared-cleanup-environment)
also covers propagation's raw-result, unchanged-HOT, lowered-result and stacked
paths. It retains parameter-block and snapshot boundaries and the existing
one-solve/one-rerun behavior. Both modes have bounded dispatcher/command
regressions and 128/512-function native benchmarks. The initial large propagation
runs overlapped another build; retain their validation/byte evidence without
using their elapsed times as accepted performance evidence.

## Current status

`precompute-propagate` is an active public Starshine hot/function pass.

It is not an alias of plain `precompute`. The public runner performs:

1. one SSA solve for allocation facts and a LocalGraph solve over the operand-expanded CFG for scalar reaching writes;
2. replacement of only concrete, type-matching local reads whose reaching facts agree;
3. one bounded plain-precompute evaluator/cleanup run.

This preserves Binaryen's mode split and stopping rule while reusing Starshine's accepted plain-precompute base.

## Public code map

### Descriptor and implementation

[`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt) owns:

- `precompute_propagate_descriptor()` with an SSA requirement and conservative analysis invalidation;
- `precompute_propagate_summary()`;
- literal/default-local payload handling;
- recursive evaluation of set fallthrough values, direct tees, unbranched value blocks, constant-selected `if` values, and exact unary/binary expressions;
- phi/reaching-value consensus;
- the one-solve/one-rerun public runner.

The same file retains plain `precompute` as a separate descriptor and runner.

### Registry, presets, and dispatch

[`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt):

- removes `precompute-propagate` from removed-name handling;
- registers the exact public name;
- uses it in both aggressive optimize/shrink PC slots.

[`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt):

- dispatches the exact public name;
- gives it the same lowering, empty-function, escape-carrier, and per-function writeback validation treatment as plain precompute;
- uses conservative raw propagation before retained load/call/set and large-lowered no-op gates when the raw evaluator proves a changed result; selected structured `memory.grow` functions also use this path, while unsupported SIMD/parser/`br_table` hazards remain fail-closed;
- uses the public pass in DAE's touched-function nested prefix.

[`src/passes/inlining.mbt`](../../../../../src/passes/inlining.mbt) uses the public descriptor for its optimizing nested prefix as well. The former private `precompute-propagate-prefix` descriptor/runner no longer exists.

### Harness and generator

[`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) accepts `--pass precompute-propagate` and maps it to Binaryen's `--precompute-propagate`.

[`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) exposes `precompute-propagate-local-facts`, with compatibility aliases `precompute-propagate` and `precompute-propagate-closeout`.

The profile emits:

- agreeing branch definitions;
- differing-definition bailouts;
- defaultable-local entry reads;
- direct and block-fallthrough tees;
- a bounded chained propagation/evaluation opportunity;
- a parameter boundary.

## Safety boundaries

### Result-producing `if` writes

The artifact closeout exposed a HOT SSA limitation: branch-local writes nested inside a result-producing `if` can be absent from the post-expression merge. Propagating a stale default or prior fact is unsound.

Starshine therefore fails closed for every local written in a result-`if` arm. It also refuses a direct default-init origin when that local has any write in the function. Focused tests cover both stale-default and stale-prior-fact forms.

This is a conservative local representation boundary, not a Binaryen semantic difference. Reopen it when HOT SSA proves complete post-expression merges for result-producing control.

### Large lowered functions and known lowering hazards

Public propagation inherits plain precompute's raw safety gates:

- load/call/set ownership hazards;
- more than `64` locals together with more than `500` lowered instructions;
- the SIMD/parser/`br_table` stack hazard.

These guards prevented an invalid self-optimized output in function `2641`. They remain correctness gates, not optimization claims.

### Shared plain-precompute scope

The propagating member reuses Starshine's plain-precompute evaluator. The July 26 v131 renewal covers returned scalars, partial `select`, strings, exact heap identity and nested immutable aggregates, ordered multi-effect retention, result-`if`, general constant control `Flow`, emitability, exact cast refinalization, large functions, type-indexed block/loop label arities, terminal multivalue payload preservation, nested raw-cleanup fixpoints, and exact dropped pure-reference cleanup. No-local control-only functions now take the same raw cleanup path under both public names. Legacy EH and stack switching remain intentionally conservative. Propagation-specific behavior remains exactly one SSA consensus solve followed by one evaluator rerun.

## Tests

[`src/passes/precompute_propagate_test.mbt`](../../../../../src/passes/precompute_propagate_test.mbt) covers fifteen behavior and safety families:

- plain-versus-propagating distinction;
- agreeing and differing reaching definitions;
- default-entry zero;
- tee/block fallthrough;
- stale and agreeing result-`if` behavior;
- direct condition-tee facts;
- high-local large-function positive propagation;
- reachable atomic-fence preservation with surrounding cleanup;
- raw loop invariants and loop-carried-local invalidation;
- bounded one-solve/one-rerun behavior.

Registry, preset, and nested scheduler expectations are covered in:

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt);
- [`src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt);
- [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt).

Generator name, limits, validation, and trigger floors are covered by [`src/validate/gen_valid_precompute_propagate_wbtest.mbt`](../../../../../src/validate/gen_valid_precompute_propagate_wbtest.mbt).

## Historical v131 signoff summary

The July 17-18 public-port, evaluator, and correctness-repair findings are absorbed into this page and its fuzzing dossier. Their exact source and artifact details remain represented by the local implementation/test map and the historical matrices below; the numbered notes are no longer live sources.

Historical results against explicit Binaryen `version_131`:

- regular GenValid: `100000/100000`, `41287` direct plus `58713` cleanup-normalized, zero residuals/failures;
- dedicated `precompute-all`: `10000/10000`, `6423` direct plus `3577` cleanup-normalized, zero residuals/failures;
- random all-profiles: `10000/10000`, `2135` smaller dead-read/control cleanup wins plus `328` intentional reachable-fence differences, net `-24,119` canonical bytes;
- wasm-smith: `9956/10000` comparable, `9954` direct, one fence-preservation correctness win, one seven-byte-smaller exact scratch-local form, and `44` Binaryen-only parser/tool failures;
- runtime/idempotence: `500/500`, with `475` Node-supported executions, `25` unsupported GC/reference cases, and zero semantic/property/validation/command failures;
- fresh debug-WASI artifact: `5,134,293` Starshine canonical bytes versus Binaryen `5,230,996`, saving `96,703` bytes; seven-run pass-local medians are `1,204.796 ms` versus `725.132 ms` (`1.661x`, within the maintained `2x` ceiling).

The former first difference at defined `4`, absolute `31` is closed. On the rebuilt artifact the first difference is defined `23`, absolute `50`, where Starshine preserves a valid result-typed return-dominated `if`/loop carrier and Binaryen refinalizes the same control to void with explicit trailing `unreachable`.

## Maintenance rule

- Keep plain and propagating descriptors separate.
- Preserve the one-solve/one-rerun bound.
- Keep stale result-`if` facts rejected unless a real phi or direct condition proof exists; keep raw branch/loop facts conservative and invalidate loop-written locals before body evaluation.
- Use the public descriptor in all top-level and nested propagating slots; do not recreate a private prefix fork.
- Use Binaryen `version_132` for new comparisons. Keep the recorded v131 oracle, commands, artifacts, and inherited plain-precompute boundaries explicitly historical.


## Nested loop-copy reaching writes

A dropped result-producing conditional can contain a loop-body local copy.
The root-only CFG does not include every condition operand and backedge.
Resolving scalar constants from that graph used an earlier write of 5 after a
changing counter had overwritten the same local. It changed a terminating loop
into an infinite loop in Dewdrop's optimizing DAE and inlining cleanup.

`precompute_propagate_prefix_fold_local_gets` now builds scalar LocalGraph facts
with `cfg_build(..., expand_operand_control=true)`. The existing SSA solve still
serves allocation facts. This repairs the input proof rather than skipping the
loop transform. The pass retains its single evaluator rerun.

`src/passes/precompute_dew_loop_copy_wbtest.mbt` checks the body copy as the
reaching write and executes twelve combinations of stale values and starting
counters. Execution is bounded at 500 instructions; an endless loop is a visible
failure. Input and output must both return 9, and cleanup must still change the
body. The original regression was red; all 179 native Precompute family tests
now pass. All twelve CLI variants validate and run in Node and Wago; each is
136 canonical bytes versus 138 input and 140 Binaryen 131 bytes.

Full saved replay is 941/1000, with 59 remaining failures, no regression, and two
newly passing short-circuit cases (138.260 s). Native family build/run takes
36.726 s; debug build 21.740 s; scoped interfaces 5.128 s; release build
253.354 s. Work over 30 s remains a performance bug. Release SHA-256 is
`a1f870a4e102ab8f2511a70c1ccc68d6191737ef174df6f5d6cb58a680a13296`.
No whole-pipeline speed benefit is established; generated renewal remains open.
Evidence in Dewdrop's `.tmp/starshine-pass-repairs/` includes
`precompute-loop-copy-native-red.log`, `precompute-family-native-wave18.log`,
`precompute-loop-copy-variants/report.json`, `precompute-release-short-circuit.json`,
and `full-replay-regression-wave18/report.json`.

## September 27, 2026: expanded local-flow scratch allocation

The shared forward LocalGraph solver no longer clears a function-sized tuple
flag array for every expanded CFG block. This pass requests expanded operands,
which already execute each producer once; recursive unexpanded traversal keeps
its flags. Reaching-source and influence assertions, existing tuple/control
fixtures, a dispatcher test and focused native controls cover the change. The
256-region full-graph control improved from 1.94 s to 46.75 ms; whole-pass gains
require the final artifact measurements. See the
[IR invariant and evidence](../../../ir2/local-ssa-policy.md#september-27-2026-expanded-cfg-tuple-bookkeeping)
and [campaign report](../../../tooling/tracing-playbook.md).

The forward solver also reuses a block's previous transfer output when its
incoming state is unchanged, after a mandatory first visit. This preserves the
fixed point and avoids repeated instruction walks; exact-state native controls
and branch-join dispatcher coverage are documented in the
[stable-transfer invariant](../../../ir2/local-ssa-policy.md#september-27-2026-stable-forward-transfers).

A subsequent ordered work queue avoids re-merging stable predecessor states.
Ascending visits within each convergence round preserve source order; backedges
and exceptional edges retain their existing semantics. Exact-state comparisons,
a cyclic handler fixture and a finite-loop dispatcher regression pass. Large
pipeline pairs improve **1,983.883 → 1,684.910 ms** with identical bytes, still
above the target. See the [work-queue invariant and focused evidence](../../../ir2/local-ssa-policy.md#september-27-2026-ordered-sparse-forward-work-queues).
Final aggregate renewal remains pending for this follow-up campaign.

## September 28, 2026 performance reuse contracts

Expanded LocalGraph transfers borrow the predecessor array on read-only blocks and copy it once before the first local write; reads still record sources and influences. Recursive transfers keep their owned-copy path. Plain raw Precompute returns the original unchanged function and avoids unneeded large-body statistics. Existing sparse unions and lazy module environments remain in place.

Tests and native controls: [local_graph_transfer_borrow_wbtest.mbt](../../../../../src/ir/local_graph_transfer_borrow_wbtest.mbt), [local_graph_transfer_borrow_perf_wbtest.mbt](../../../../../src/ir/local_graph_transfer_borrow_perf_wbtest.mbt), [precompute_raw_identity_wbtest.mbt](../../../../../src/passes/precompute_raw_identity_wbtest.mbt), [precompute_raw_identity_perf_wbtest.mbt](../../../../../src/passes/precompute_raw_identity_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.

The final raw-fold prototype checks a simple read/scalar-literal tail before the
operator-specific patterns while retaining infinite-loop value-tail cleanup.
The root-global snapshot guard streams its first sixteen non-nop instructions
and stops at an incompatible prefix instead of copying the complete body.
[Bounded tests](../../../../../src/passes/precompute_tail_admission_wbtest.mbt)
prove the active fold, infinite-loop cleanup, unchanged guards, nop handling and
sixteenth-instruction boundary; [native controls](../../../../../src/passes/precompute_tail_admission_perf_wbtest.mbt)
include active operators as well as unchanged value tails and guarded prefixes.


## September 28, 2026 shared follow-up controls

Shared initialization ownership and HOT result queries retain their semantic
contracts in the [IR ownership rules](../../../ir2/architecture-rules.md#performance-reuse-ownership-contracts).
The [follow-up report](../../../tooling/tracing-playbook.md#september-28-2026-follow-up-performance-campaign)
separates new helper evidence from this pass's enclosing timings and final
aggregate status. Prior signoff does not automatically cover the new sources;
guarded paths and remaining size/parity gaps retain their existing limits.

## Precompute propagation correctness repairs — October 7, 2026

Preserve every use of a shared payload holder. Delay transparent holder inlining to a separate phase with one lazy use-count snapshot. Inline only sole-use holders; a shared holder remains attached to all consumers. Keep per-use source effects in order.

Evidence: [precompute.mbt](../../../../../src/passes/precompute.mbt). See the [current checkpoint](../../../tooling/validation-gates.md#october-7-2026--p00-control-exception-and-ownership-repairs) for exact validation, timing and open limits.

Transparent inlining now visits all normal operands in one parent walk and
checks/deletes detached holders in one batch per phase. Copied terminating
values are excluded from later candidates before their checked batch deletion.
The exact scalar identity prefix can move to its consumer without deleting
the shared producer. Other explicit prefixes need an effect-retention proof.
[Direct tests](../../../../../src/passes/p00_precompute_cleanup_wbtest.mbt)
and [command tests](../../../../../src/cmd/p00_precompute_cleanup_wbtest.mbt)
cover both precompute variants, retained call order and valid output.

The raw path removes an empty scalar identity block directly when its one input
and result type are equal. It preserves the already evaluated input and adds
no nop or HOT lift. This closes the active plain-precompute dispatch gap found
by the command regression above.
