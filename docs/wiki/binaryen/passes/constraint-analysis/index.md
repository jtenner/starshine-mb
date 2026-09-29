---
kind: entity
status: working
starshine_status: active-partial
last_reviewed: 2026-09-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/passes/ConstraintAnalysis.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/src/ir/constraint.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis.wast
  - https://github.com/WebAssembly/binaryen/blob/version_132/test/lit/passes/constraint-analysis-loops.wast
  - ../../../../../src/passes/constraint_analysis.mbt
  - ../../../../../src/passes/constraint_domain.mbt
  - ../../../../../src/passes/constraint_analysis_wbtest.mbt
  - ../../../../../src/passes/constraint_loop_plan_perf_wbtest.mbt
  - ../../../../../src/passes/constraint_domain_wbtest.mbt
  - ../../../../../src/validate/gen_valid_constraint.mbt
related:
  - ./fuzzing.md
  - ./wat-shapes.md
  - ../../version-132-upgrade.md
  - ../tracker.md
---

# Constraint analysis

## September 25, 2026 loop-plan visitation scratch

Parameterized-loop planning now reuses one node work array and generation-mark array across sibling loops. Each loop still traverses its own body and associated CFG blocks; the change removes a full node-sized visited allocation and clear per loop. The [native white-box benchmark](../../../../../src/passes/constraint_loop_plan_perf_wbtest.mbt) uses valid sibling loops with one carried i32 parameter and measures `ca_loop_plan` after HOT lifting and CFG construction. Mean time fell from **15.07 → 13.01 µs** (13.7%) for 32 loops and **35.81 → 29.29 µs** (18.2%) for 64. All 34 existing ConstraintAnalysis tests pass. Full-pass and Binaryen-v132 comparison impact remain unmeasured.

`constraint-analysis` is a runnable, opt-in HOT pass initially ported against
Binaryen **132**; current comparisons require verified **133**, including the
[September 28 renewal](fuzzing.md#current-verified-v133-lane).
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

Use the [v132 shape catalog](wat-shapes.md) for concrete before/after forms.
It separates straight-line predicates, copy chains, branch joins, relational
fusing, loop widening and unreachable cleanup from the solver's internal state
normalization. The release page also records the exact v131-to-v132 commit
families and the distinction between released behavior and post-tag guardrails.

## September 28, 2026 performance reuse contracts

Constraint-analysis lowering and raw cleanup share the dispatcher’s existing lazy module environment rather than rebuilding it per function or twice per refinalization. Type-changing pipeline operations retain the existing environment invalidation. Active integer fixtures prove a constrained comparison folds; i32/i64 typed-block and source-reuse tests guard refinalization correctness.

Tests and native controls: [constraint_lower_module_env_wbtest.mbt](../../../../../src/passes/constraint_lower_module_env_wbtest.mbt), [constraint_lower_module_env_perf_wbtest.mbt](../../../../../src/passes/constraint_lower_module_env_perf_wbtest.mbt), [registry_active_perf_wbtest.mbt](../../../../../src/passes/registry_active_perf_wbtest.mbt). The [campaign report](../../../tooling/tracing-playbook.md#september-28-2026-performance-backlog-campaign) owns frozen-binary artifact timings, verified-v133 evidence and final correctness outcomes; helper timings alone do not close the remaining pipeline or parity gaps.
