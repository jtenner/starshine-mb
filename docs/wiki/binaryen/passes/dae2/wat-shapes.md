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

# DAE2 result and parameter shapes

These examples describe Binaryen 132's semantic opportunities, not required
byte-for-byte text snapshots. The earlier claim that DAE2 cannot remove results
is superseded by release change #8903.

## Result forwarded only to an unused parameter

```wat
(func $producer (param i32) (result i32) (local.get 0))
(func $sink (param i32))
(func (export "run")
  (call $sink (call $producer (i32.const 8))))
```

The sink parameter is unused. The producer result therefore has no observable
consumer, and the producer parameter also becomes unused. Both private
signatures can become `() -> ()`; calls remain where their effects require them.
An imported or exported producer has a different signature boundary.

## Cyclic forwarding

```wat
(func $a (param i32) (result i32) (call $b (local.get 0)))
(func $b (param i32) (result i32) (call $a (local.get 0)))
```

If their results are unobserved and their signatures private, the forwarding
cycle does not make the parameter/results live. Removing value traffic must
preserve the calls and their nontermination. The GenValid execution profile
uses a separate live countdown so its recursive cases terminate under bounds.

## Argument effects

When a removed argument calls an import or writes state, keep that evaluation
in its original position relative to kept arguments and the callee target.
Typed temporaries may be needed. A dropped trapping division is not a removable
constant expression just because its result is unused.

## Whole result tuples

A private function returning `(i32, i64)` can lose the tuple when no component is
observed. If a component is observed, this parity target keeps the tuple as one
usage unit. Per-slot pruning is a separate extension.

## Open-world indirect tail calls

A private wrapper ending in `return_call_indirect` cannot lose its result if the
external indirect callee's signature must stay fixed. This is the post-tag #8994
correction included with the port, not behavior to copy from the released bug.

## Reference and continuation families

A referenced function can change only with its eligible family and all affected
reference-call sites. A private unreferenced sibling may receive a new signature
without rewriting a public or continuation-associated old signature. Intrinsic
call targets retain their protected signatures.

See [bounded fixtures](implementation-structure-and-tests.md) and
[GenValid families](fuzzing.md) for executable forms and measured signoff.
