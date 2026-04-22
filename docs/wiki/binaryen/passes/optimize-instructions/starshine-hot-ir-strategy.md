---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-instructions-primary-sources.md
  - ../../../raw/research/0131-2026-04-20-optimize-instructions-binaryen-research.md
  - ../../../raw/research/0248-2026-04-22-optimize-instructions-primary-sources-and-implementation-followup.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./gc-casts-call_ref-and-trap-sensitive-rewrites.md
  - ./wat-shapes.md
---

# Current Starshine `optimize-instructions` strategy

This page describes the **current local implementation**, not upstream Binaryen's AST pass.
For the upstream contract, start with [`./binaryen-strategy.md`](./binaryen-strategy.md).

## Short version

Current Starshine `src/passes/optimize_instructions.mbt` is **much narrower** than Binaryen `version_129` `OptimizeInstructions.cpp`.

The in-tree implementation is still a real, useful hot pass.
Its center of gravity is:

- exact constant and `eqz` folding
- compare-to-zero and relational constant canonicalization
- commutative operand ordering with HOT use-def safety guards
- add/sub/mul/shift rewrites
- constant-`if` folding
- nested boolean-`if` normalization and `eqz` wrapping
- duplicate-branch collapse in then-regions
- dead-region-suffix cleanup with explicit fallback-branch and zero-sentinel preservation

That is a meaningful implemented pass.
But it is not yet the same surface as upstream Binaryen.

## Exact local code map

### Registry and preset placement

The public registry surface lives in `src/passes/optimize.mbt`:

- `optimize_instructions_descriptor()` declares the active HOT descriptor
- `optimize_instructions_summary()` provides the public help text
- `pass_registry_entries()` registers `optimize-instructions` as a hot pass
- `optimize_preset_passes(...)` and `shrink_preset_passes(...)` place it in both the early and late cleanup slots of the default preset order

That file is the local answer to:

- is the pass active?
- how is it described publicly?
- where does it sit in the preset order?

### Pass-manager dispatch

The main pipeline handoff lives in `src/passes/pass_manager.mbt`:

- `run_hot_pipeline_run_descriptor(...)` dispatches the descriptor name `optimize-instructions` into `optimize_instructions_run(...)`

Unlike several neighboring passes, the current local `optimize-instructions` integration does **not** add a large raw pre-lift classifier family in `pass_manager.mbt`.
That is itself a useful local distinction:

- the current implementation expects the work to happen after HOT lift
- the artifact-driven safeguards live mostly inside the pass file itself, not in a large raw skip layer

### Core algorithm owner file

The main implementation lives in `src/passes/optimize_instructions.mbt`.
The fastest read-along path is:

- descriptor and summary
  - `optimize_instructions_descriptor()`
  - `optimize_instructions_summary()`
- HOT-specific traversal scaffolding
  - `OptimizeInstructionsScratch::new(...)`
  - `optimize_instructions_mark_loop_input_nodes(...)`
  - `optimize_instructions_can_cross_local_get(...)`
- constant and control cleanup helpers
  - `optimize_instructions_try_fold_constant_if_condition(...)`
  - `optimize_instructions_try_optimize_if_condition(...)`
  - `optimize_instructions_negate_boolean_expr_recursive(...)`
  - `optimize_instructions_try_wrap_boolean_if_value_in_eqz(...)`
  - `optimize_instructions_try_collapse_duplicate_then_branch(...)`
  - `optimize_instructions_try_collapse_dead_region_suffix(...)`
- canonicalization helpers
  - `optimize_instructions_try_canonicalize_commutative(...)`
  - `optimize_instructions_try_canonicalize_relational_const(...)`
  - `optimize_instructions_try_canonicalize_relational_operands(...)`
  - `optimize_instructions_try_canonicalize_compare_const(...)`
- arithmetic and compare rewrites
  - `optimize_instructions_try_rewrite_add_sub(...)`
  - `optimize_instructions_try_rewrite_mul_shift(...)`
  - `optimize_instructions_try_rewrite_shift(...)`
  - `optimize_instructions_try_rewrite_compare_eqz(...)`
- walker and driver
  - `optimize_instructions_visit_node(...)`
  - `optimize_instructions_run(...)`

That exact code map is the main practical improvement in this refresh: readers can now jump straight from the strategy summary to the owning MoonBit helper clusters.

### Focused local proof lanes

The local tests are intentionally split across multiple files:

- `src/passes/optimize_instructions_test.mbt`
  - focused reduced pass behavior: exact constant folding, `eqz` and compare canonicalization, arithmetic rewrites, nested boolean-`if` cleanup, duplicate-branch collapse, dead-region-suffix trimming, commutative reordering, relational constant normalization, and guard-heavy no-reorder cases
- `src/passes/registry_test.mbt`
  - registry/descriptors exposure for the public HOT pass surface
- `src/cmd/cmd_wbtest.mbt`
  - CLI-visible `--optimize-instructions` replay on the debug artifact and on the saved generated-artifact slot-16 / slot-44 predecessor lanes

A useful local honesty note is that there is no dedicated `perf_test.mbt` or `optimize_test.mbt` lane for this pass today.
The strongest evidence surface is the focused reduced pass file plus the CLI replay coverage.

## What Starshine already models reasonably well

## 1. Exact integer and compare peepholes

The local file has dedicated helpers for:

- exact constant folding of binary ops
- `eqz` folding
- compare-to-zero rewrites
- relational operand canonicalization
- relational-constant normalization

This is the part of the implementation that most closely matches the popular mental model of the upstream pass.

## 2. Commutative canonicalization with HOT-specific safety proof

The local file has explicit machinery for:

- moving constants to the preferred side
- sorting local gets and some node kinds conservatively
- refusing reordering across same-local writes, shared tee payloads, trapping loads, and loop-carried inputs

That matches the *strategy* of upstream Binaryen — canonicalize first so later peepholes have fewer spellings to handle — but the proof substrate is very local-HOT-specific.

## 3. Add / sub / mul / shift rewrites

The in-tree HOT pass includes helpers for:

- add/sub normalization
- multiply-by-power-of-two to shift rewrites
- redundant shift-mask removal
- effective-zero shift cleanup
- compare-to-zero reductions

So Starshine already covers a meaningful subset of the classic arithmetic rewrite surface.

## 4. Boolean and nested-`if` cleanup

The local file goes fairly deep on HOT-IR boolean and control patterns.
It can:

- optimize `if` conditions directly
- fold constant conditions
- recursively negate nested boolean trees
- wrap certain boolean value-`if`s in `eqz`
- flip some nested conditions when the tree is unshared
- collapse duplicate then-branch `if`s into a direct branch

This is one area where the local code is more explicit than the upstream `visitIf()` teaching surface because several helpers exist mainly to preserve local HOT/writeback behavior.

## 5. Artifact-backed dead-suffix and fallback-branch cleanup

The current local pass includes logic for:

- truncating dead suffixes after escaping control
- preserving value-carrying fallback branches in mixed-label and nested-return shapes
- keeping explicit zero sentinels when the result carrier still flows to a `drop` or another value-preserving boundary

Those are not a direct copy of Binaryen `OptimizeInstructions.cpp`.
They are local HOT-IR and writeback-survival work shaped by this repo's artifact history.

## What upstream Binaryen does that Starshine still lacks

This is still the bigger story.

## 1. No broad AST reference / GC optimization surface yet

The local file does not implement the upstream visitor families for things like:

- `ref.eq`
- `ref.cast`
- `ref.test`
- `ref.is_null`
- `ref.as_non_null` cleanup
- descriptor-aware casts
- exactness-aware cast tightening

So the upstream cast/null-trap/descriptor story is still largely missing locally.

## 2. No `call_ref` directization surface

The local HOT implementation does not currently model the upstream `visitCallRef(...)` story:

- `ref.func` target to direct call
- `table.get` target to `call_indirect`
- select-of-known-direct-target rewrites
- `return_call_ref`-adjacent directization families

That is a major upstream feature gap.

## 3. No broad memory and bulk-memory lowering surface

The local pass does not currently cover upstream families like:

- tiny constant-size `memory.copy` to load/store
- tiny `memory.fill` to store/store pair or SIMD store
- trap-relaxing zero-size bulk-memory cleanup
- stored-value and offset canonicalization for the general load/store surface

## 4. No GC constructor / field / atomics surface

The local pass does not yet model upstream visitors such as:

- `StructNew`
- `StructGet`
- `StructSet`
- `StructRMW`
- `StructCmpxchg`
- `ArrayNew`
- `ArrayNewFixed`
- `ArrayGet`
- `ArraySet`
- `ArrayLen`
- `ArrayCopy`
- `ArrayRMW`
- `ArrayCmpxchg`

So important upstream behaviors are still absent locally, including default-constructor cleanup and unshared GC atomic lowering.

## 5. No tuple extraction parity surface

The local file does not model upstream `visitTupleExtract(...)`:

- `tuple.extract(tuple.make(...))` simplification with the surrounding tee/drop reconstruction

## 6. No whole-function local prescan equivalent

Upstream Binaryen runs a whole-function `LocalScanner` to infer:

- `maxBits`
- `signExtBits`

Current Starshine has direct HOT pattern matching and some local ordering logic, but it does not currently appear to have the same function-wide local prescan that powers many upstream width/sign rules.

## 7. No deferred `ReFinalize` / EH-pop-fixup equivalent inside this pass

Upstream Binaryen explicitly depends on:

- deferred `ReFinalize`
- `EHUtils::handleBlockNestedPops(...)`

The current local HOT pass has its own HOT / lower / writeback validity story, but it is not the same helper contract.

## Important current divergence: constant `if` folding

One of the most useful durable differences between the local and upstream implementations is:

- current Starshine has an explicit `optimize_instructions_try_fold_constant_if_condition(...)`
- upstream Binaryen `version_129` `visitIf()` does **not** do generic constant-if folding here

That does not automatically make the local rule wrong.
But it does mean:

- the local pass is not a direct copy of the upstream phase boundary
- some landed local behavior belongs more naturally to `precompute` in the Binaryen mental model

## Important current divergence: artifact-driven dead-region cleanup

Several local helpers are clearly tailored to HOT / lowering issues rather than directly to upstream source structure.
Examples include:

- duplicate-then-branch collapse helpers
- dead-region-suffix cleanup with sentinel preservation
- nested boolean-tree inversion and wrapping logic
- fallback-branch preservation around escaping `if`s and carried labels

Those local rules may still be useful or necessary.
But they should be documented as:

- current Starshine HOT-IR and writeback strategy

not automatically as:

- direct evidence of how upstream Binaryen `OptimizeInstructions.cpp` is structured

## Ordered-artifact blocker story: now retired, still important context

The saved generated-artifact `-O4z` audit originally found two hard failure slots for `optimize-instructions`:

- slot `16`
- slot `44`

The durable repo-local conclusion is still:

- both slots are now retired
- the fixes were not new upstream-shape peepholes inside the pass
- they were HOT-lowering / writeback safety fixes around carried-result wrappers and parent-exit payload packing

So the remaining gap is breadth and honesty of upstream parity, not a still-open hard corruption witness.

## What a future honest Starshine port must preserve

A future port does **not** need to copy the entire Binaryen file literally.
But it does need to preserve these big truths:

1. the pass is broader than arithmetic
2. canonicalization is part of the algorithm
3. helper substrate matters
4. phase boundaries should stay honest when local behavior intentionally differs

## Practical maintenance rule

Treat the current local implementation as:

- a real implemented HOT pass
- strongest today on integer / boolean / control canonicalization
- intentionally carrying extra writeback-safety logic for local artifact history
- still missing most of the upstream `call_ref`, memory, bulk-memory, GC, tuple, and helper-substrate surface

For this pass, "what Starshine does today" and "what Binaryen `version_129` does" are not the same thing.
The wiki should keep that difference explicit.
