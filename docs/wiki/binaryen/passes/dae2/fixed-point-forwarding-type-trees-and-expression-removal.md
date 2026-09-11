---
kind: entity
status: working
last_reviewed: 2026-09-10
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - ../../../../../src/passes/dead_argument_elimination2.mbt
  - ../../../../../src/passes/dead_argument_elimination2_types.mbt
  - ../../../../../src/passes/dead_argument_elimination2_legacy.mbt
  - ../../../../../src/passes/dead_argument_elimination2_wbtest.mbt
  - ../../../../../src/passes/dead_argument_elimination2_intake_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# DAE2 graph and type-family invariants

This is the current Binaryen 132 account. The earlier parameter-only explanation
and its “no result analysis” limitation are superseded by #8903.

A location is live only if a seeded observable use reaches it. Parameter and
whole-result locations share the same graph as expression values. For a direct
call, live parameter `p` requires its argument expression; a live call value
requires the callee result. A return connects its value to the caller result.
Tail calls require matching result signatures in both directions.

Starting unused yields the least fixed point. A closed cycle of unused parameter
and result forwarding has no observable root and can disappear. Worklist
membership is bounded by the number of graph locations; it does not simulate
recursive execution.

Referenced functions connect to synthetic family locations. Public type exposure
is transitively closed through function arguments/results, GC fields, supertypes,
metadata and continuation signatures. An unknown external caller is not evidence
of an unused signature. Continuations and `call.without.effects` retain their
conservative restrictions. In an open world, an unchangeable indirect tail call
also pins caller results (#8994).

Analysis and mutation are separate. Preserve old block/loop signatures when a
function type used as a control signature changes. Keep recursive groups and
subtype metadata, give private siblings separate signatures where necessary,
and rebuild module analyses after rewriting definitions and all uses.

Expression removal preserves child evaluation in original order. Calls, traps,
allocation identity, exceptions and synchronization cannot disappear merely
because their values are unused. Legacy catch payloads are captured before new
wrappers; handler rethrows retain the same exception reference. Validation alone
is not behavioral or output-quality evidence; use the [dedicated checks](fuzzing.md).
