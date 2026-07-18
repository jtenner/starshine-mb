---
kind: entity
status: supported
starshine_status: upstream-only
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/releases/tag/version_131
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/constraint.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/constraint.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/constraint-analysis.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/constraint-analysis-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/constraint-analysis-cont.wast
  - ../../../raw/research/1573-2026-07-18-binaryen-version-131-release-impact-audit.md
  - ../../../../../src/passes/optimize.mbt
related:
  - ../tracker.md
  - ../../release-horizon-and-oracles.md
  - ../../../ir2/architecture-rules.md
---

# `constraint-analysis`

## Status

`constraint-analysis` is a new public Binaryen pass in `version_131`. It is registered under the exact CLI name `constraint-analysis`, but it is not added to Binaryen's default optimize/shrink scheduler.

Starshine has no registry spelling or implementation for this pass. Treat it as **upstream-only**, not as an O4z blocker.

## What the pass does

The pass performs function-parallel CFG dataflow over mathematical constraints on locals. Its first released implementation focuses on facts such as:

- a local equals a constant;
- a local equals another local;
- a local is null or non-null;
- integer equality and inequality relations that can be parsed by the shared constraint layer.

It propagates those facts through basic blocks and two-way control-flow edges, then folds conditions that are proven true or false.

A beginner-safe example is:

```wat
(if (i32.eq (local.get $x) (i32.const 10))
  (then
    ;; Here x != 0 is provably true.
    (drop (i32.ne (local.get $x) (i32.const 0)))))
```

Binaryen can replace the redundant inner comparison with a constant while preserving required child evaluation.

## Released algorithm shape

1. Build a CFG with one `Info` record per basic block.
2. Record local writes and constraint-bearing unary, binary, `ref.eq`, and `ref.is_null` expressions.
3. Seed defaultable non-parameter locals with their zero/default values at function entry.
4. Propagate block-start constraint maps to a fixed point.
5. Refine successor facts from two-way `if`, conditional `br`, `br_on_null`, and `br_on_non_null` edges.
6. Rewalk actions with the inferred facts and replace proven predicates with constants.
7. Replace actions in proven-unreachable states with side-effect-preserving `unreachable` sequences.
8. Refinalize and repair nested EH pops when unreachable rewrites changed types.

## Important boundaries in v131

The initial release is deliberately incomplete:

- no tuple-local defaults;
- no switch/multi-successor constraint propagation;
- no `br_on_cast*` subtype constraint solving;
- two-local relations are parsed more broadly than they are fully queried;
- the implementation has TODOs for speed and relevant-local filtering;
- it is an explicit pass, not a default O4z slot.

## Test surface

Binaryen ships three focused files:

- `constraint-analysis.wast` for scalar/local/control facts;
- `constraint-analysis-eh.wast` for exception-handling control flow;
- `constraint-analysis-cont.wast` for continuation/stack-switching CFG behavior.

Any future Starshine port should begin with analyzer-only fact tests and CFG edge semantics before mutating expressions. The natural local substrate is the revision-keyed HOT CFG/dominance analysis layer, but a faithful port must still match Binaryen's observable predicate folding and unreachable repair.

## Tracker rule

Do not add this pass to `optimize` or `shrink` merely because Binaryen released it. First require:

- an honest registry category;
- red-first direct fixtures;
- CFG and constraint-lattice design;
- EH/continuation boundary decisions;
- a pass-specific GenValid profile;
- direct Binaryen v131 closeout;
- separate evidence for any future preset scheduling proposal.
