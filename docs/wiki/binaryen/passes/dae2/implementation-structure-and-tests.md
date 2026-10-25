---
kind: entity
status: working
last_reviewed: 2026-10-26
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_identity.mbt
  - ../../../../../src/passes/dae2_identity_dependencies_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_round2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_host_types_wbtest.mbt
  - ../../../../../src/cmd/dae2_host_types_wbtest.mbt
  - ../../../../../src/cmd/dae2_family_dispatch_wbtest.mbt
  - ../../../../../src/validate/match.mbt
  - ../../../../../tests/optimizer/regressions/round2-correctness.test.ts
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
  - ../../../../../src/passes/dae2_field_query_regression_wbtest.mbt
  - ../../../../../src/passes/dae2_field_query_perf_wbtest.mbt
  - ../../../../../src/ir/hot_mutate.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# DAE2 source and tests

## October 25, 2026: measured gains landing

### Measured item 5

This completed landing supersedes this item's earlier measurement-pending wording below. **GAIN:** Recursive GC/descriptor/continuation dependency discovery **2.708 → 0.580 ms/call (-78.67%)**, peak RSS **9,944 → 9,968 KiB**; embedded definition **2.654 → 0.585 ms (-77.87%)**, RSS **9,992 → 9,996 KiB**. Pass-local gains have limited enclosing CLI benefit; no general memory gain.

Source `dae/item-05-subtype-trees` at `d20dd9102639d92893f65468d80f26120a6ee403` lands as `fb1e9cc9da182407813c01adbd3a58adcc2456ca` after 15,501/15,501 native tests, 14/14 CI fuzz suites, 100,779 attempts, seed 117504419113374922. The [campaign record](../../../../../experiment-results.md#item-5--landed-under-the-corrected-procedure) retains every workload/control row and the corrected gate investigation. No fresh general parity or combined-build timing claim is made.

## Implementation map

The September 10 Binaryen 132 implementation replaces the earlier research-only
code map and its obsolete exclusion of unused function results.

| Owner | Responsibility |
| --- | --- |
| `src/passes/dead_argument_elimination2.mbt` | Usage graph, fixed point, HOT expression rewriting, parameter/result mutation, final validation. |
| `src/passes/dead_argument_elimination2_types.mbt` | Referenced families, exposure, continuations/intrinsics, control-signature preservation and type-section rewriting. |
| `src/passes/dead_argument_elimination2_identity.mbt` | Canonical recursive-group identity partitions and conflicting signature dependency closures. |
| `src/passes/dead_argument_elimination2_legacy.mbt` | Multiple legacy handlers, label remapping and exception-identity-preserving rethrow adaptation. |
| `src/passes/optimize.mbt`, `pass_manager.mbt` | Real registry entries, module dispatch and the optimizing cleanup sequence. |
| `src/cmd/cmd.mbt` | Active CLI dispatch regression. |
| `src/validate/gen_valid_dae2.mbt` | Fourteen dedicated semantic families. |

`dead_argument_elimination2_wbtest.mbt` tests result/parameter forwarding, cycles,
control flow, effects, multi-value results, open/closed worlds and referenced
types, and runs generated families through the actual pipeline.
`dead_argument_elimination2_intake_wbtest.mbt` imports released binary fixtures,
including catch payloads, handlerless/multiple legacy tries, and continuation
construction/binding. Source fixture identity is recorded in the tests.

Graph analysis precedes mutation. Function-result tuples are one usage unit.
Each function is lifted, analyzed and released before the next; only dependency
locations and callee identities survive until convergence. Mutation relifts the
original body with the same deterministic tuple/catch capture preparation and
checks its node count before using the solved locations. This avoids retaining
all HOT bodies and their side tables at once. The native memory budget and
functional compiler checks must be renewed after this change.
Before analysis, tuple producers are materialized once into lane locals. Local
usage then flows through reaching definitions, allowing unused captures to be
removed without repeating a call or an exception-producing expression. Unknown
reaching definitions retain all possible writes and entry parameters. Exception
and continuation targets keep their payload/result signatures.

The effectful tuple and multi-handler regressions exposed bugs that validation
and pure generated producers did not detect: duplicated tuple calls and lost or
duplicated handler execution. These are behavior regressions, not acceptable
output-shape differences. The generated tuple/exception families now increment
an exported global so the runtime oracle observes call count and handler effects.
A module revision rebuild prevents stale per-function analyses after signature
changes. HOT verification and final module validation are separate checks;
execution, normalized opportunity parity and cost need the dedicated lanes in
[fuzzing](fuzzing.md) and the [upgrade evidence](../../version-132-upgrade.md).

## Shared raw forward-control preflight

The fallback contract covered by
[`dae2_shared_preflight_wbtest.mbt`](../../../../../src/passes/dae2_shared_preflight_wbtest.mbt)
requires one count/qualification result for the exact immutable body and module
context after conditional qualification fails. Rejection must leave the graph
untouched. On success, local-flow planning precedes forward planning; each
planner owns a fresh plan and a separate `64 + 8 * count` work budget.
Standalone planner wrappers must retain their own admission checks.

The bounded cases cover late unsupported instructions, local-flow budget
exhaustion followed by forward success, successful local flow, flat controls,
branch tables and indexed scalar loops. They compare plan fields, boundary and
write demand, encoded output, and unchanged input with the existing HOT path.
Performance and v133 comparison evidence remain pending; the shared-host task
permits focused package tests only, with no fuzz or timing runs.

## Checked fields during expression rewriting

The call-prefix filter reads the current opcode with `hot_node_op`. Child-span
replacement admission reads the current count with `hot_child_count`, then
compares each slot with the existing checked `hot_child_get`. Live-node and
deletion checks, child order, unchanged-span revision behavior, and snapshot
ownership remain intact. Neither query caches a header. The
[bounded regressions](../../../../../src/passes/dae2_field_query_regression_wbtest.mbt)
compare these paths with frozen full-header controls. The
[paired native probe](../../../../../src/passes/dae2_field_query_perf_wbtest.mbt)
is skipped in the default suite. `HotNode` is already a value record: these
changes narrow field return traffic, without removing a record heap allocation.

## Reusing rewritten signatures — 2026-09-11

The `dae2-locals` renewal exposed redundant scalar function types: a private
`(i32, i32) -> i32` function pruned to `(i32) -> i32` received a duplicate type
instead of reusing an exported identity function's existing signature. The
retained memory-capture case was 78 raw bytes against Binaryen's 77 despite a
smaller canonical body (73 versus 77 bytes). This was a size gap, not a win.

After type-family rewriting, DAE2 now canonicalizes newly allocated definition
signatures with the existing full-metadata simple-function type map. Original
referenced type identities stay unchanged; recursive groups, subtyping and
non-function groups retain the canonicalizer's conservative boundary. Existing
unused-type pruning removes the unreferenced duplicate. Public-pipeline and
command tests assert index reuse; a native reproducer failed before the change.
Fresh validation and size measurements are recorded in the
[upgrade ledger](../../version-132-upgrade.md).

## Function-family arity and indirect targets

Function subtyping requires equal parameter and result arities. Parameter
contravariance changes the accepted types, not the number of arguments.
The validator's `Match for Array[T]` enforces equal lengths before the
function-type variance check in
[`match.mbt`](../../../../../src/validate/match.mbt). Thus the reported
one-parameter parent / two-parameter child is invalid. Independent
`wasm-tools 1.262.0 validate --features all` rejects an open-parent version
with `sub type must match super type`; an implicit final parent is also
invalid. Unrelated function members in a recursive group may have different
arities, but `dae2_prepare_type_locations` shares locations only along
declared supertype families.

An element target on the ordinary family path has bidirectional graph edges
between each own parameter/result location and its family location. A live
sibling therefore retains that location in an otherwise unused target too.
The separate private-element path rejects subtyping, recursive groups, and
shared signature keys, and requires scalar bodies without indirect calls,
before it can allocate a distinct signature. These
conditions prevent the reported own-signature / indirect-family split.

The bounded controls in
[`dead_argument_elimination2.mbt`](../../../../../src/passes/dead_argument_elimination2.mbt)
and
[`dae2_family_dispatch_wbtest.mbt`](../../../../../src/cmd/dae2_family_dispatch_wbtest.mbt)
check a shared indirect type with unequal target demand, and a recursive
`eqref` / `anyref` contravariant family that drops a dead second argument.
They assert each surviving member signature and the indirect-call type.
The command controls also require both DAE2 modes to reject unequal-arity
subtypes as invalid input. The valid-family controls pass on the previous
implementation. However, direct `Module` optimization does not require prior
validation: the invalid unequal-parameter-arity command control reached
`dae2_parameter_plan` during identity preservation and failed with a bounds
error. This is an invalid-input robustness defect, rather than the reported
valid-Wasm failure.

`dae2_check_type_family_arities` now rejects unequal parameter or result arities
before allocating family graph locations or running identity preservation.
It scans existing recursive-group members and declared supertypes without
allocating parameter or member arrays. The direct pass and both command modes
require an error for these intentionally invalid modules. Valid-module family
rewriting and indirect-dispatch demand propagation retain their previous
behavior.

## Runtime type identity preservation

The second correctness audit showed that independently pruning signatures can
merge distinct runtime types or split equivalent ones, changing indirect-call
traps. After liveness converges, DAE2 compares the original and proposed
recursive-group identity partitions in both directions. Conflicts retain the
parameter/result locations of their complete type dependency closures, then
liveness is solved again. Unrelated pruning remains available. Embedded type
definitions conservatively retain type-section signatures. Four failing-first
checks in `dead_argument_elimination2_round2_wbtest.mbt` and eight execution
checks in `tests/optimizer/regressions/round2-correctness.test.ts` cover both
directions, including recursive groups. See the
[second audit](../../../ir2/architecture-rules.md#september-12-second-correctness-audit)
for final evidence and limitations.

Identity dependency discovery uses a read-only visitor instead of constructing
and discarding remapped subtype trees. It visits function parameters, results,
struct/array fields and continuation targets, then `describes`, `descriptor`
and supertypes in the same order as the constructing visitor. Repeated edges,
recursive-group star edges and the embedded-definition fallback are retained.
Identity partition keys still use the constructing visitor, and the admission
gate and identity fixed point are unchanged.

The [dependency tests](../../../../../src/passes/dae2_identity_dependencies_wbtest.mbt)
compare complete graph storage and solved observation order with the previous
construction path. They cover absolute and relative indices, exact and nullable
references, packed fields, metadata, continuations, embedded definitions and an
unchanged family. The [command tests](../../../../../src/cmd/dae2_family_dispatch_wbtest.mbt)
cover recursive identity split and collapse through both DAE2 modes.

This is item 5 of `docs/dae-perf-opportunities.md` on
`research/dae-perf-opportunities`. No new timing or memory result is claimed.
Measurement remains pending for closed-world rewrites with large recursive/GC
type graphs: identity split/collapse, descriptors, continuations, embedded
definitions and unchanged-family controls. The expected saving is the removed
temporary subtype construction during dependency discovery; partition-key
construction is still required. Full-suite and fuzz validation are deferred
under the shared-host instruction for this item.

## Host-origin runtime type tests — 2026-10-25

Verification head `be26b7d65` proves that DAE2 can change a retained `ref.test`
target from `(func (param i64))` to `(func)` after an imported function returns
an abstract `funcref`. Internal type-partition checks do not protect identities
supplied by the host. The target and its type dependencies must keep their
original signatures, including when a retained `ref.cast` uses the target.

The [pass regressions](../../../../../src/passes/dead_argument_elimination2_host_types_wbtest.mbt)
check the actual retained instruction target, parameter and result types, nested
control, and both DAE2 modes. The
[command regression](../../../../../src/cmd/dae2_host_types_wbtest.mbt) covers the
active dispatcher. All three pass tests and the command test fail on rewritten
signatures before the repair.

DAE2 now marks `ref.test` and `ref.cast` heap targets in the existing recursive
table-ingress scan. It uses the existing public-type mask before the public
closure is solved. This retains complete target signatures, recursive-group
siblings and referenced type dependencies. The rule also covers exact and
nullable variants and does not depend on a table or global being present.
Private direct function signatures can still shrink independently.

Focused validation passes all 18 tests in the pass host-target, round-two and
signature-reuse files, plus the command host-target and family-dispatch files.
The command was `moon test -j 1` with those five file paths explicitly selected.

The changed preparation path adds target handling to an existing traversal and
reuses its type mask; it adds no traversal or mask allocation. More types can
remain live, which can reduce later optimization. Performance remains
unmeasured. The original shared-host repair deferred full suites and fuzz;
the serial landing results below supersede that gate deferral.

On October 25, candidate `6a370bb5c` merges `a33d71cb41` onto master
`3a31c388f`. The original five-file focused selection passes 18/18. Eight
sequential Wasm batches of at most 300 source files pass 15,455/15,455.
`bun validate full --profile ci --target wasm-gc` passes info/fmt/check,
15,453/15,453 tests and all 14 CI fuzz suites, seed `117503874903495699`.
Both independent wiki-log additions are retained. Six unrelated formatter
migrations were excluded; no API snapshot changed.

No timing measurement, new cross-module host runtime replay or new Binaryen
comparison is claimed. The type-retention effect on runtime, allocation,
output size and signature-pruning yield remains explicit follow-up work in
both DAE2 modes, including host-value and private-direct controls.

## Host-visible abstract function tables

Closed-world analysis does not make an imported or exported abstract `funcref`
table private. `dead_argument_elimination2_types.mbt` builds a table-index mask
for those boundaries, retains type families for materialized function references
that can flow into them, and retains the type operands of indirect and indirect
tail calls through them. The pass and command regressions use an exported table
with an active element plus a separately retained direct sibling; before the fix,
that independent rewrite opportunity changed the active target from
`(i32) -> i32` to `() -> ()` while leaving the host-visible table intact.
The mask also covers a private abstract `funcref` table written by `table.set`,
`table.grow`, `table.fill`, or `table.copy`: a runtime value from an imported
function can enter that table and be called indirectly. The round-two regression
keeps the original `(i32) -> ()` indirect-call type after such an ingress.
