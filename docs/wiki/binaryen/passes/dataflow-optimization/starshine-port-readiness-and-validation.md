---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-dataflow-optimization-port-readiness-primary-sources.md
  - ../../../raw/research/0423-2026-04-27-dataflow-optimization-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../raw/research/0369-2026-04-25-dataflow-optimization-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-dataflow-optimization-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/simplify_locals.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-dataflow-ir-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../precompute/index.md
  - ../souperify/index.md
---

# Starshine port readiness and validation for `dataflow-optimization` / `dfo`

## Current decision point

`dataflow-optimization` is understood well enough to plan, but not implemented in Starshine today.
The next Starshine decision is not “which peephole do we write first?” It is:

- build a faithful local Flat IR + DataFlow graph substrate, **or**
- define a narrower HOT/IR2-native approximation and document where it intentionally differs from Binaryen.

Until that choice is made, the safe strategy is analyzer-first documentation and tests. A mutating pass should not land by silently treating ordinary HOT trees as if they were Binaryen's flat input.

## Exact local status to verify before implementation

Recheck these before any coding branch:

- removed registry spelling
  - [`src/passes/optimize.mbt#L143-L153`](../../../../../src/passes/optimize.mbt#L143-L153)
  - `pass_registry_removed_names()` includes `dataflow-optimization`.
- no active registry entry
  - [`src/passes/optimize.mbt#L155-L279`](../../../../../src/passes/optimize.mbt#L155-L279)
  - no `HotPass` or `ModulePass` entry currently owns the name.
- explicit request rejection
  - [`src/passes/optimize.mbt#L485-L491`](../../../../../src/passes/optimize.mbt#L485-L491)
  - removed names return the removed-registry error instead of no-oping.
- closest local constant-folding neighbor
  - [`src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt)
  - upstream `dfo` delegates actual constant evaluation to nested `precompute`.
- closest local locals-cleanup neighbor
  - [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
  - this is cleanup infrastructure, not a hidden `dfo` implementation.
- absent local substrate
  - workspace search on 2026-04-27 still found no `src/passes/dataflow_optimization.mbt`, no `src/dataflow/`, and no `src/ir/flat*` files.
- absent active backlog slice
  - [`agent-todo.md`](../../../../../agent-todo.md) still has no dedicated `dataflow-optimization` / `dfo` slice.

## Binaryen contract that must drive validation

A faithful local port must preserve the source-backed behavior explained in:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./flat-ir-dataflow-ir-and-boundaries.md`](./flat-ir-dataflow-ir-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)

The short checklist is:

1. require flat input, or prove an equivalent local precondition;
2. focus on integer-local graph facts;
3. represent unsupported results as unknown precision barriers;
4. keep loop-carried changing values conservative;
5. collapse only constant-identical phis;
6. fold expression nodes only when nested `precompute` produces an actual constant;
7. rely on later cleanup instead of making `dfo` responsible for all flatten scaffolding.

## Recommended implementation slices

### Slice 0: registry honesty only

If the first change is only plumbing, keep it non-mutating:

- decide whether local users should also get an upstream alias `dfo`;
- keep `dataflow-optimization` removed until a real pass exists;
- add CLI/API tests that prove explicit requests are rejected or accepted according to that decision;
- update this folder and the tracker in the same change.

Do not advertise a real pass while the implementation still no-ops.

### Slice 1: analyzer-only candidate classifier

Before mutating code, add a classifier that reports whether a function or region is in the future port's intended domain:

- flat-like local traffic versus ordinary nested value trees;
- integer-local relevant values;
- supported unary, binary, and `select` families;
- branch-merge candidates;
- loop-carried precision cutoffs;
- unsupported-op and EH bailout reasons.

This slice should have no output changes. Its value is proving the local substrate choice.

### Slice 2: same-constant branch-merge rewrite

The first mutating slice should be the smallest source-backed positive family:

```wat
(local.set $x (i32.const 7)) ;; true arm
(local.set $x (i32.const 7)) ;; false arm
(local.get $x)               ;; replaceable after merge proof
```

Acceptance criteria:

- only same constant on every relevant incoming branch;
- no loop-carried varying local involved;
- no unsupported side-effecting rewrite hidden in the proof;
- validation after rewrite;
- Binaryen oracle comparison on reduced fixtures.

### Slice 3: supported all-constant expression folding

After branch-merge replacement is stable, add expression folding for the source-backed supported subset:

- integer unary families (`clz`, `ctz`, `popcnt`, `eqz`);
- integer binary arithmetic/bitwise/compare families;
- `select` when both arms and the condition are representable;
- commit the rewrite only if local `precompute` or an explicitly equivalent helper yields a literal constant.

Trap-sensitive negatives are mandatory. A constant-child division by zero must not become an arbitrary harmless constant just because the DataFlow inputs are known.

### Slice 4: integration with flatten-era neighbors

Only after reduced positives are green should the pass be tested in its real neighborhood:

- `flatten` / flatness-producing local equivalent;
- `simplify-locals-nonesting` or the Starshine closest equivalent;
- `precompute`;
- later ordinary cleanup.

This is where the official combo-lit shape belongs. It should not be the only proof.

## Required negative tests

A local port needs explicit tests for:

- non-flat input rejected or skipped according to the chosen local substrate;
- non-integer value traffic not optimized as if it were relevant integer traffic;
- unsupported opcode becomes a precision barrier;
- EH remains unsupported unless a later source-backed design adds it;
- true loop-varying values do not get constantized;
- all-constant operands that nested `precompute` refuses still remain unchanged;
- request behavior for `dataflow-optimization` and any future `dfo` alias is stable.

## Binaryen oracle lanes

Use at least these lanes once a mutating slice exists:

- reduced fixtures with explicit `wasm-opt --flatten --dfo -S` expectations;
- combo fixtures matching the official shape: `--flatten --simplify-locals-nonesting --dfo -O3`;
- local pass-fuzz comparison only after the local pass declares the same preconditions as Binaryen, or after the harness filters to flat-compatible fixtures;
- a negative EH/unsupported-op lane to ensure Starshine is not optimizing outside the source-backed domain.

## Open design choices

- **Substrate choice:** faithful Flat IR + DataFlow graph versus narrower HOT/IR2 approximation.
- **Alias policy:** keep only local `dataflow-optimization` or also accept upstream `dfo`.
- **Scheduler policy:** keep it explicit-only until `flatten` / equivalent flatness support exists locally, or schedule it only in a controlled experimental pipeline.
- **Evaluation helper:** reuse current Starshine `precompute` behavior as the constantization gate, or build a dedicated wrapper that proves equivalence with Binaryen's nested `precompute` usage.

Record the chosen answers in this page before moving `dataflow-optimization` out of the removed registry.

## Bottom line

The pass is now documentation-ready and planning-ready, but not implementation-ready without a substrate decision. The safe Starshine path is:

1. keep current removed-registry honesty;
2. add analyzer-only classification first;
3. land same-constant merge rewriting before broader expression folding;
4. validate with reduced fixtures plus Binaryen's flatten-era combo lane;
5. only then consider scheduler or alias expansion.
