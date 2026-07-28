---
kind: concept
status: supported
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
  - ./index.md
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

## Released-v131 check

The 2026-07-28 audit read the released `version_131` owner plus both dedicated fixture surfaces. The owner contract remains temporary-tee instrumentation, eager `LocalGraph` influences, two orientation choices, post-graph rollback, cleanup, and DWARF invalidation. The all-features fixture adds forward sibling sets, partial influence, reverse boundaries, reverse rollback, nested copy interactions, loop confusion, a fuzz stress shape, and strict-subtype rejection; the lit fixture anchors `between-unreachable` robustness.

## Starshine implementation/test status

| Local surface | What it proves |
| --- | --- |
| [`src/passes/merge_locals.mbt`](../../../../../src/passes/merge_locals.mbt) | HOT graph algorithm, straight-line snapshot path, and recursive legacy-EH regional path. |
| [`src/passes/merge_locals_test.mbt`](../../../../../src/passes/merge_locals_test.mbt) | Public spelling, both orientations, cross-control influence, tee candidates, rollback, unreachable preservation, legacy `try`, and O4z placement. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | Candidate admission, byte-preserving no-candidate bypass, legacy-EH routing, and HOT fallback. |
| [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) | Fifteen source-family leaves plus `merge-locals-all`. |
| [`src/validate/gen_valid_merge_locals_tests.mbt`](../../../../../src/validate/gen_valid_merge_locals_tests.mbt) | Validity, copy opportunities, exact labels, type topology, and four legacy-EH region forms. |
| [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) | Direct Binaryen-v131 comparison, replay, runtime, and idempotence evidence. |

The only raw regional specialization is legacy EH because general HOT lift still rejects decoded legacy `Try`. The bridge rewrites only region-local straight-line copy traffic, preserves block types, catch order and kind, tags, and delegate targets, and leaves wider cross-region traffic unchanged.

## Current validation ladder

1. focused public pass and profile tests;
2. official lit and all-features fixture replay;
3. `100000` regular GenValid;
4. `10000` dedicated `merge-locals-all`;
5. `10000` random all profiles;
6. `10000` wasm-smith;
7. runtime/idempotence and pass-local performance probes.

See [`./fuzzing.md`](./fuzzing.md) and [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for final counts and reopening criteria.
