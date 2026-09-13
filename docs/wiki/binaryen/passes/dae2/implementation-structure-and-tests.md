---
kind: entity
status: working
last_reviewed: 2026-09-13
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_identity.mbt
  - ../../../../../src/passes/dead_argument_elimination2_round2_wbtest.mbt
  - ../../../../../tests/optimizer/regressions/round2-correctness.test.ts
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# DAE2 source and tests

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
