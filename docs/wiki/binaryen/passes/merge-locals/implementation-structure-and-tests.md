---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
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
It exists because the corrected dossier needed a compact map of the copy-shape implementation, and because the earlier one-set-local overread obscured where the real behavior comes from.

## Owner files

| Surface | Role |
| --- | --- |
| `src/passes/MergeLocals.cpp` | Owns the pass: copy-shape discovery, synthetic tee insertion, eager `LocalGraph`, orientation choice, post-graph rollback, and cleanup. |
| `src/passes/pass.cpp` | Registers the pass and schedules it only for stronger optimize/shrink settings in the default function-optimization cluster. |
| `src/passes/passes.h` | Declares the pass factory. |
| `src/ir/local-graph.h` | Supplies the set-influence data used by the pass. |
| `test/lit/passes/merge-locals.wast` | Official behavioral proof surface. The reviewed capture is narrow and currently centers the conservative `between-unreachable` family. |

## Main implementation phases in `MergeLocals.cpp`

### 1. Copy discovery and instrumentation

The pass scans for copy-shaped `local.set` / `local.get` pairs.
Instead of treating them as abstract equivalence classes, it instruments the source side with a trivial `local.tee` candidate so the copy relation can be analyzed directly.

### 2. Eager `LocalGraph`

The implementation constructs an eager graph and asks for set influences.
The graph is used to decide whether the source local or destination local should own the rewritten gets.

### 3. Orientation solve

For each candidate, the pass checks two orientations:

- influenced gets move toward the original destination local
- influenced gets move toward the synthetic tee source local

The candidate only survives if the target orientation keeps the right single-set story and the affected gets keep matching local types.

### 4. Post-graph rollback

The pass rebuilds graph state after the rewrite and undoes the candidate if the post-rewrite relationships no longer hold.
This is the safety step that keeps the pass conservative despite mutating local identity.

### 5. Cleanup

Successful rewrites strip the trivial tee wrapper and leave behind the simplified copy shape.

## Official lit-test map

The reviewed `test/lit/passes/merge-locals.wast` capture is narrow.
It visibly anchors the conservative `between-unreachable` family, which is enough to prove that the pass remains careful around unreachable boundaries but not enough to stand in for a broad coverage suite.

## Current-main check

The 2026-05-04 primary-source recheck compared the same owner, registration, helper, and test surfaces on current `main`.
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

1. source-to-destination retargeting positives
2. destination-to-source retargeting positives
3. type-mismatch negatives
4. post-graph rollback cases
5. conservative `between-unreachable` coverage
6. Binaryen pass-targeted parity comparison

Until those exist, keep `merge-locals` documented as removed/unimplemented locally.
