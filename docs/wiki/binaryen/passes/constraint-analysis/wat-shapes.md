---
kind: concept
status: working
starshine_status: active-partial
last_reviewed: 2026-09-16
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/ir/constraint.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis-loops.wast
  - ../../../../../src/passes/constraint_analysis.mbt
  - ../../../../../src/passes/constraint_domain.mbt
  - ../../../../../src/passes/constraint_lower.mbt
  - ../../../../../src/passes/constraint_analysis_wbtest.mbt
  - ../../../../../src/passes/constraint_domain_wbtest.mbt
related:
  - ./index.md
  - ./fuzzing.md
  - ../../version-132-upgrade.md
---

# Constraint analysis shapes

This page is the concrete WAT guide for the Binaryen 132
`constraint-analysis` additions. The pass proves predicates from local facts;
it does not evaluate arbitrary expressions or assume that an unfinished CFG
analysis is complete. The output examples show the Boolean result that can be
folded. The predicate's children still run, so a trap or observable call inside
one of them stays in the same order.

## Straight-line facts

An assigned constant gives the solver an exact fact:

```wat
(local.set $x (i32.const 10))
(drop (i32.eq (local.get $x) (i32.const 10)))
(drop (i32.ne (local.get $x) (i32.const 20)))
```

The two dropped comparisons become `i32.const 1`. A comparison against an
unrelated value remains unknown. The same fact can be reached through a copy:

```wat
(local.set $x (local.get $y))
(drop (i32.eq (local.get $x) (i32.const 10)))
```

The analysis marks `$y` relevant when `$x` is relevant and follows the copy
backward. A later write to either value ends the old relation.

The pass also consumes constants exposed by an earlier canonicalizing pass:

```wat
(local.set $x (i32.add (i32.const 10) (i32.const 20)))
(drop (i32.eq (local.get $x) (i32.const 30)))
```

With `optimize-instructions` first, this becomes a known comparison. Without
that earlier fold, the add is outside this pass's expression evaluator and the
comparison stays unknown.

## Branch facts and joins

A condition sends its fact into the corresponding CFG arm:

```wat
(if (i32.eq (local.get $x) (i32.const 10))
  (then (drop (i32.ne (local.get $x) (i32.const 0))))
  (else (drop (i32.eq (local.get $x) (i32.const 10)))))
```

The then-arm comparison is true and the else-arm comparison is false. The
condition is negated when the physical successor is the false branch. Conditional
`br` uses the same rule. `br_on_null` and `br_on_non_null` add nullness facts;
cast branches are not parsed by this v132 integer/reference constraint solver.

At a merge, facts from reachable predecessors are joined. If both arms assign
`10`, a later equality with `10` is true. If one arm assigns `10` and the other
assigns `20`, the post-merge state knows the value is one of those possibilities
but cannot prove either equality. An unreachable predecessor contributes no
fact.

## Relational and Boolean patterns

The v132 solver grows bounds from signed and unsigned constant comparisons. Its
notable fused forms are:

```text
x == C || x > C  ->  x >= C
x <= C && x < C  ->  x < C
```

The fused relation is a proof fact; it is not a request to rewrite the source
Boolean tree into a particular text shape. The solver separately handles
relation swapping and logical negation. Boolean `and`, `or` and nested `eqz`
refine a path only when the operands are Boolean-valued.

Signed and unsigned domains use the operand width. An i64 comparison can
produce an i32 Boolean result without truncating the i64 bound. Ranges are
stored as bit patterns, so a signed range crossing zero does not become an
incorrect unsigned interval. Missing or contradictory facts produce unknown.

## Incrementing loops

The common bounded loop shape is:

```wat
(local.set $x (i32.const 0))
(loop $loop
  (local.set $x
    (i32.add (local.get $x) (i32.const 1)))
  (if (i32.lt_u (local.get $x) (i32.const 100))
    (then (br $loop))))
```

The increment transfer wraps at the local's width. When the backedge returns,
the solver widens the carried range instead of enumerating 100 iterations. An
unconditional loop or an overflow-sized loop must converge without turning the
entire body into a false constant state. The dedicated upstream loop fixture
also covers a loop that stops only after wrapping to zero; it is a termination
guard, not a positive optimization case.

Loop parameters use the same rule as locals: their initial arguments are
evaluated in the preheader, then carried values enter the body on the backedge.
An analysis must not reuse the initial zero argument as every iteration's value.

## Unreachable and effectful cases

When a proved contradiction makes a region unreachable, the pass can replace
that region with `unreachable` after collecting and preserving child effects.
It refinalizes the function and repairs exception-handler nesting. A predicate
with a trapping child is still evaluated before its result is dropped. A known
Boolean result is therefore a value-fold opportunity, not permission to delete
its operands.

The local tests exercise these rules through signed/unsigned boundaries, i64
width, reference nullness/equality, copied locals, joins, loop backedges, tees,
effectful control and unreachable predecessors. The upstream source fixtures are
[`constraint-analysis.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis.wast)
and [`constraint-analysis-loops.wast`](https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis-loops.wast).

Floating-point comparisons are deliberately absent. NaN and signed-zero rules
need their own proof domain before this pass can fold them.
