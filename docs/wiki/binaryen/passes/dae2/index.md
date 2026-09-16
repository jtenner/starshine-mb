---
kind: entity
status: working
starshine_status: active-partial
last_reviewed: 2026-09-16
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/DeadArgumentElimination2.cpp
  - https://github.com/WebAssembly/binaryen/pull/8903
  - https://github.com/WebAssembly/binaryen/pull/8994
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-control-flow.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cycles.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-indirect.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-open-world.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-intrinsics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-returns.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cont.wast
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

# DAE2

`dae2` is a runnable Starshine module pass targeting Binaryen **132**. It solves
unused parameters and entire function-result tuples in one dependency graph.
It is separate from ordinary `dae` and is opt-in. The [shape catalog](wat-shapes.md)
maps the released result, control-flow, cycle, indirect, open-world, intrinsic,
return and continuation fixtures to their rewrite boundaries.

This September 10 implementation supersedes this dossier's earlier upstream-only
status and parameter-only account. Binaryen #8903 added result usage to the
released algorithm. The older statement that DAE2 cannot remove results is no
longer current. Existing ordinary-DAE evidence remains evidence for ordinary DAE.

The solver starts locations unused, seeds observable uses and propagates usage
backward. A forwarding cycle stays unused unless an observable consumer reaches
it. Definitions, calls, returns and eligible function-type families are rewritten
only after the graph converges. Effects and traps of removed values still execute.

Open-world entry points, imports/exports, referenced types, continuation
signatures and effect-free-call intrinsics constrain signature changes.
Post-tag #8994 is included: an unchangeable indirect tail callee also pins its
caller's matching results. Multi-value results are one usage unit, not independent
slots.

The released Binaryen registry has `dae2` only. Starshine additionally exposes
`dae2-optimizing`, defined as DAE2 followed by `simplify-locals` and `vacuum`.
The comparison adapter requests that same sequence upstream. Neither spelling
aliases ordinary DAE; neither has been added to default presets.

See [implementation](implementation-structure-and-tests.md),
[type-family and graph rules](fixed-point-forwarding-type-trees-and-expression-removal.md),
[examples](wat-shapes.md), [validation](starshine-port-readiness-and-validation.md),
and the [fourteen-family GenValid aggregate](fuzzing.md). Complete campaign and
performance signoff is tracked in the [132 upgrade](../../version-132-upgrade.md).
