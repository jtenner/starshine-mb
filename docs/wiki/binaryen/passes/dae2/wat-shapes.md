---
kind: entity
status: working
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

The released output makes the distinction visible:

```wat
;; No caller observes the result.
(func $test (result i32)
  (i32.const 42))

;; The result is removed, but evaluating the old body remains.
(func $test
  (drop (i32.const 42)))

;; A fully unused tuple keeps both child evaluations while dropping the tuple.
(func $test
  (tuple.drop 2
    (tuple.make 2 (i32.const 42) (i64.const 100))))
```

If a caller extracts one element, the function still returns the complete tuple:

```wat
(func $caller
  (global.set $g (tuple.extract 2 0 (call $test))))
```

This is why “unused results” means whole-result liveness in v132 rather than
independent component elimination.

## Open-world indirect tail calls

A private wrapper ending in `return_call_indirect` cannot lose its result if the
external indirect callee's signature must stay fixed. This is the post-tag #8994
correction included with the port, not behavior to copy from the released bug.

## Reference and continuation families

A referenced function can change only with its eligible family and all affected
reference-call sites. A private unreferenced sibling may receive a new signature
without rewriting a public or continuation-associated old signature. Intrinsic
call targets retain their protected signatures.

The control-flow fixtures also cover effectful result-producing `if` and block
forms. DAE2 drops the selected value after retaining the conditional call or
write, and it preserves a possible divide-by-zero trap even when the result is
unused. The source roster is [`dae2-results.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results.wast),
[`dae2-results-control-flow.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-control-flow.wast),
[`dae2-results-cycles.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cycles.wast),
[`dae2-results-indirect.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-indirect.wast),
[`dae2-results-open-world.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-open-world.wast),
[`dae2-results-intrinsics.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-intrinsics.wast),
[`dae2-results-returns.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-returns.wast),
and [`dae2-results-cont.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/dae2-results-cont.wast).

See [bounded fixtures](implementation-structure-and-tests.md) and
[GenValid families](fuzzing.md) for executable forms and measured signoff.
