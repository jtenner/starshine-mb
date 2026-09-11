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

# DAE2 validation and signoff

DAE2 is implemented and registered against Binaryen 132. This supersedes the old
first-slice design document: unused results and referenced type families are
part of the implementation, not excluded future work.

The default tests cover direct forwarding, recursive result/parameter cycles,
whole multi-value tuples, observable argument effects, overwritten locals,
reference calls, exported signatures and the open-world indirect-tail correction
from post-tag #8994. Released intake fixtures exercise legacy exception handlers
and continuation-associated signatures. Every generated family is validated and
run in both open- and closed-world modes in bounded tests.

The full release intake starts from `test/lit/passes/dae2*.wast` at the exact
v132 tag. Original input validation, Starshine transformation, Binaryen output
validation and independent `wasm-tools` validation are recorded separately.
An upstream oracle failure is not a Starshine semantic verdict: the v132
open-world tail-return cases motivating #8994 fail upstream validation.

Signoff requires:

- 10,000 GenValid comparisons with a freshly built explicit native compiler,
  the [aggregate profile](fuzzing.md), parallel workers and bounded artifacts;
- classification of each residual difference, including canonical size and
  downstream cleanup evidence when retaining a different Starshine shape;
- original/optimized runtime checks for supported features, including effects,
  imported-call order and traps, with unsupported execution recorded explicitly;
- module/HOT validation and analysis invalidation after the complete signature
  rewrite; and
- fixed-corpus size and pass-local cost measurements before any preset change.

Registration and bounded tests do not replace these gates. Current results and
remaining failures are recorded in the [132 upgrade](../../version-132-upgrade.md)
and [active backlog](../../../../../agent-todo.md).
