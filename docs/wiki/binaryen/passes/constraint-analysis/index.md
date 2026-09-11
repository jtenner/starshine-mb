---
kind: entity
status: working
starshine_status: active-partial
last_reviewed: 2026-09-10
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/ir/constraint.cpp
  - ../../../../../src/passes/constraint_analysis.mbt
  - ../../../../../src/passes/constraint_domain.mbt
  - ../../../../../src/passes/constraint_analysis_wbtest.mbt
  - ../../../../../src/passes/constraint_domain_wbtest.mbt
  - ../../../../../src/validate/gen_valid_constraint.mbt
related:
  - ./fuzzing.md
  - ../../version-132-upgrade.md
  - ../tracker.md
---

# Constraint analysis

`constraint-analysis` is a runnable, opt-in HOT pass targeting Binaryen **132**.
This supersedes the July 18 upstream-only status. The original upstream pass
appeared in v131; v132 substantially expands its solver. Default -O3/-Os/-Oz
scheduling is the later #9010 change and has not been copied into Starshine.

The pass propagates facts over the derived CFG, then rewrites proved predicates
after convergence. Integer values use bit patterns with up to two unsigned
spans, so signed ranges crossing zero do not become invalid unsigned ranges.
Comparisons use operand width, including i64 predicates with i32 Boolean results.
Increment transfer wraps at the operand width. Reference facts include nullness
and equality; local writes invalidate relations that depended on the old value.

Joins include both predecessor value sets, and unreachable edges contribute no
facts. Relation swapping and logical negation are separate operations. Boolean
AND/OR and nested eqz refine paths only when their operands are Boolean-valued.
Loop widening moves bounds outward through source thresholds. A work budget or
an incomplete control-flow view declines affected rewriting, never certifies an
unfinished proof. Floating-point constraint reasoning remains disabled because
ordinary IEEE comparisons do not satisfy NaN-unsafe logical rules.

For example, inside `if (i32.eq (local.get $x) (i32.const 10))`, an inner
`i32.ne $x 0` becomes true. Side effects and traps of the predicate's operands
still execute. A stack-held local value must remain the value evaluated before a
later write; shared HOT lifting captures that dependency explicitly.

Per-block state tracks only predicate-relevant locals, including transitive copy
sources. A sparse expression cache is cleared between block evaluations; no
proof crosses a revision or evaluation context. Lowering removes adjacent
single-use scratch captures without reordering effects.

The implementation is in `constraint_analysis.mbt`, `constraint_domain.mbt` and
`constraint_lower.mbt`;
the active registry and command dispatcher have behavior tests. Shared CFG tests
cover dropped reference branches. Default tests cover signed/unsigned boundaries,
wraparound, i64 width, joins, loops, tees, reference predicates and effects.
Bounded exhaustive small-width domain tests supplement the
[twelve-family GenValid aggregate](fuzzing.md).

Full 10,000-case comparison, execution, opportunity classification and fixed-corpus
cost evidence are tracked in the [132 upgrade](../../version-132-upgrade.md).
Registration does not establish complete opportunity parity or justify a preset
change. Later tee, unreachable-state, width, overflow, mixed-signedness, NaN and
convergence corrections remain part of the correctness intake contract.
