---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `merge-locals` implementation structure and tests

## Purpose

This page is the owner-file and proof-surface map for Binaryen `merge-locals`.
It exists because the previous dossier had overview and strategy pages but did not have the standard implementation/test map, and because that gap let a stale algorithm story survive.

## Owner files

| Surface | Role |
| --- | --- |
| `src/passes/MergeLocals.cpp` | Owns the pass: local-name bailout, eager `LocalGraph`, candidate scan, source-local reuse, fresh-temp creation, postwalk materialization, and public pass factory. |
| `src/passes/pass.cpp` | Registers the `merge-locals` pass and schedules it only for stronger optimize/shrink settings in the default function-optimization cluster. |
| `src/passes/passes.h` | Declares the pass factory. |
| `src/ir/local-graph.h` | Supplies ordinary influence and set-influence data used by the pass. |
| `test/lit/passes/merge-locals.wast` | Main official proof surface for user-visible rewrites and bailouts. |

## Main implementation phases in `MergeLocals.cpp`

### 1. Function-level bailout

The pass skips functions with local names.
This is not just a cosmetic implementation detail: it is part of the current source-backed contract because the pass would otherwise rewrite local identity in a way that can make debug-facing local names misleading.

### 2. Eager `LocalGraph`

The implementation constructs the graph in eager mode, then computes:

- ordinary influences
- set influences

The reviewed source comment says the non-lazy choice avoids missed opportunities and avoids a measured slowdown seen in Binaryen benchmarking.

### 3. One-set candidate discovery

The pass scans locals through the graph's set list.
A candidate must have exactly one set, and that set must have a value.
This is the central implementation fact future readers should remember.

### 4. Simple-value and influenced-get gates

The set value must be simple enough to move safely.
Then every influenced get for the local must still trace to that exact same set.
If either rule fails, the local is skipped.

### 5. Target selection

There are two implementation outputs:

- **existing source local:** if the set's value is a `local.get` and the source chain is small enough, the pass can reuse that source local
- **fresh temp:** otherwise, if the value is simple, the pass creates a new temp local and stores the value there

This is the source-backed split that replaces the stale 2026-04-23 `EquivalentCopies` / existing-winner-only story.

### 6. Postwalk rewrite

The pass materializes the plan by rewriting gets and replacing redundant sets.
The visible output is fewer redundant local hops, sometimes with a fresh helper local when direct source reuse is not profitable or legal.

## Official lit-test map

The dedicated `test/lit/passes/merge-locals.wast` file is the central behavioral proof.
It is especially useful because it covers both positive and conservative families.

| Family | What it proves |
| --- | --- |
| Simple copy / source-local reuse | A one-set local whose value is a small `local.get` chain can redirect to an existing source local. |
| Fresh-temp families | A simple non-`local.get` value can be saved once in a new temp and shared by rewritten gets. |
| Branching / arity families | The pass can operate through structured control when the graph still proves one set feeds the influenced gets. |
| Ordering-sensitive copies | The pass is graph-guided rather than adjacent-only. |
| DAG-like influence sharing | Multiple use paths can still be optimized if they share the same proven set story. |
| Loop-backedge copies | Loop shape alone is not a bailout when the influence facts remain safe. |
| `keepSimple*` negatives | Complex or non-simple values stay put. |
| `between-unreachable` negative | Unreachable-adjacent influence ambiguity stays conservative. |

## Current-main check

The 2026-04-25 primary-source recheck compared the same owner, registration, helper, and test surfaces on current `main`.
No teaching-relevant drift was found from the corrected `version_129` contract.

## Starshine implementation/test status

Starshine has no dedicated implementation or test file today:

- no `src/passes/merge_locals.mbt`
- no `src/passes/merge_locals_test.mbt`
- no exact `merge-locals` active backlog slice in `agent-todo.md`

The existing local proof surface is only registry-level:

- removed-name registration in [`../../../../../src/passes/optimize.mbt:144-151`](../../../../../src/passes/optimize.mbt)
- removed-pass request rejection in [`../../../../../src/passes/optimize.mbt:455-473`](../../../../../src/passes/optimize.mbt)
- generic removed-pass rejection test in [`../../../../../src/passes/registry_test.mbt:171-179`](../../../../../src/passes/registry_test.mbt)

## Validation checklist for a future local port

A faithful Starshine implementation should add tests in this order:

1. source-local reuse positives
2. fresh-temp positives
3. branch / arity positives
4. ordering-sensitive and DAG-like influence positives
5. loop-backedge positives
6. extra-set negatives
7. complex-value / non-simple negatives
8. named-local bailout or an explicit documented local policy divergence
9. Binaryen pass-targeted parity comparison

Until those exist, keep `merge-locals` documented as removed/unimplemented locally.
