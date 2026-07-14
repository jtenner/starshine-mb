---
kind: concept
status: supported
last_reviewed: 2026-07-11
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - ../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
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

The 2026-07-11 recheck compared the upstream owner, registration, and dedicated fixture on current `main`. No teaching-relevant drift was found from the corrected `version_129` contract: Binaryen still combines temporary-tee instrumentation, eager `LocalGraph` influences, two orientation choices, post-graph rollback, and DWARF invalidation.

## Starshine implementation/test status

Starshine now has a dedicated active direct-pass slice:

| Local surface | What it proves |
| --- | --- |
| [`src/passes/merge_locals.mbt`](../../../../../src/passes/merge_locals.mbt) | Owns a same-typed, forward `src -> dst` epoch-alias rewrite for adjacent `local.get src; local.set dst` copies. |
| [`src/passes/merge_locals_test.mbt`](../../../../../src/passes/merge_locals_test.mbt) | Proves public spelling, a forward positive, destination-write invalidation, and a structured-control boundary negative. |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | Registers `merge-locals` as an active module pass. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | Dispatches the module pass. |
| [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) | Admits `--merge-locals` to direct Binaryen comparison. |

The local pass is deliberately not an upstream algorithm port: it has no `LocalGraph`, no destination-to-source orientation, and no post-rewrite rollback. It recursively rewrites nested expression bodies, but clears parent aliases after `block`, `loop`, `if`, and `try_table`; control-flow-spanning aliasing is therefore intentionally out of scope.

## Validation checklist for a fuller local port

The landed direct subset already has focused tests and historical 10,000-case comparison evidence. A fuller Binaryen-equivalent expansion should add, in order:

1. destination-to-source orientation positives;
2. control-flow-spanning `LocalGraph` influence positives and negatives;
3. type-mismatch and `between-unreachable` regressions;
4. post-graph rollback cases;
5. focused pass-targeted parity after each expansion; and
6. late-local-cleanup neighborhood proof before preset scheduling.

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the exact active-subset versus full-parity boundary.
