---
kind: concept
status: strong
last_reviewed: 2026-07-28
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/MergeLocals.cpp
  - ./index.md
  - ../../../../../src/passes/merge_locals.mbt
  - ../../../../../src/passes/merge_locals_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_merge_locals_tests.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../coalesce-locals/index.md
---

# Starshine strategy for `merge-locals`

## Current status

`merge-locals` is closed against Binaryen `version_131` for the maintained direct-pass contract.

Starshine uses two execution paths:

- a HOT/CFG path implementing temporary source-tee instrumentation, eager `HotLocalGraph` influences, both Binaryen orientations, exact type checks, post-graph verification, sibling rollback, and cleanup;
- an immutable-snapshot raw path for straight-line functions, plus a recursive legacy-`try` region bridge for protected bodies, typed catches, catch-all handlers, and delegate-bearing nesting that HOT lift does not yet admit.

The pass is registered publicly and scheduled in O4z immediately after `heap2local` and before `optimize-casts`.

## Implementation map

| Surface | Responsibility |
| --- | --- |
| [`src/passes/merge_locals.mbt`](../../../../../src/passes/merge_locals.mbt) | HOT graph algorithm, straight-line raw algorithm, recursive legacy-EH region bridge. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | Candidate admission, no-candidate byte-preserving bypass, legacy-EH raw routing, HOT fallback. |
| [`src/passes/merge_locals_test.mbt`](../../../../../src/passes/merge_locals_test.mbt) | Public pass, both orientations, control flow, tee candidates, rollback, unreachable preservation, legacy-`try`, and O4z slot tests. |
| [`src/validate/gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) | Fifteen source-family leaves and `merge-locals-all`. |
| [`src/validate/gen_valid_merge_locals_tests.mbt`](../../../../../src/validate/gen_valid_merge_locals_tests.mbt) | Profile validity, copy opportunity, source-family labels, GC type boundary, and four legacy-EH region forms. |

## Source-family coverage

The maintained generator covers:

- forward single-use and multi-sibling retargeting;
- partial influence before a later write, both linear and branch-local;
- reverse orientation;
- reverse lifetime-end boundaries;
- block, `if`, and loop influence;
- `local.tee` copy candidates;
- merge/phi rejection;
- exact local type equality and strict-subtype rejection;
- forward and reverse rollback, including conditional and nested target clobbers;
- nested copy instrumentation;
- the upstream `trivial-confusion` loop interaction;
- `between-unreachable` robustness;
- legacy `try` protected, typed-catch, catch-all, and delegate-bearing regions.

See [`fuzzing.md`](fuzzing.md) for the exact profile names and final counts.

## Residual classifications

Two output families intentionally remain different:

1. `trivial-confusion`: Starshine removes an unread `local.tee` shell after retargeting. Every dedicated residual is two canonical bytes smaller than Binaryen and preserves the same branch condition value.
2. Broad `remove-unused-brs-control` inputs sampled by random-all: Starshine retains a structured result block instead of Binaryen's scratch-local scalarization. Every residual is eight canonical bytes smaller; a replayed representative is idempotent, validates, and produces the same runtime trap.

The wasm-smith case `9332` is not pass-owned: it has no local copy candidates, and Starshine's no-pass and `--merge-locals` outputs are byte-identical. Binaryen's reader/writer removes unreachable stack debris during canonicalization. Keep that residual under `[TOOL]001`.

## Performance boundary

On a 143,734-byte, one-function workload with 10,000 copy/use groups, nine post-warmup pass-local samples report medians of `7.548 ms` for Starshine and `27.1409 ms` for Binaryen v131. Starshine is `0.278x` Binaryen time, or about `3.60x` as fast.

Whole-command timing remains codec-dominated: the multi-function synthetic workload is slower in Starshine despite the faster pass. That is a `[WALL]001` decode/validate/encode attribution, not a `merge-locals` pass-local regression.

## Reopening criteria

Reopen this pass for:

- a validation or true-semantic failure;
- a newly identified Binaryen-v131 source family not represented by the fifteen-leaf aggregate;
- a pass-owned canonical size loss without a measured semantic or performance benefit;
- legacy-EH traffic that crosses region boundaries and demonstrates an observable Binaryen transform missed by the regional bridge;
- pass-local median regression to slower than Binaryen on the copy-heavy benchmark.
