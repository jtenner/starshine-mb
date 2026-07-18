---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - ./index.md
  - ../../../../../src/passes/merge_locals.mbt
  - ../../../../../src/passes/merge_locals_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Starshine strategy for `merge-locals`

## Honest current status

`merge-locals` is now an active Starshine module pass for direct `--merge-locals` execution.
It is no longer a removed-name placeholder.

The landed slice rewrites same-typed copy-shaped local traffic in one expression body: after adjacent `local.get src; local.set dst` instructions, later source-local gets can be retargeted to the destination local while the destination's write epoch remains unchanged. It recursively handles nested bodies but clears parent aliases at every structured-control boundary. This covers the direct O4z copy-balancing lane that was signed off against Binaryen, but it is still narrower than Binaryen's full `LocalGraph`-checked, bidirectional retargeting and rollback engine.

## Exact local code and doc map

| Local surface | Meaning |
| --- | --- |
| [`src/passes/merge_locals.mbt`](../../../../../src/passes/merge_locals.mbt) | Active module-pass owner for copy-shaped local retargeting. |
| [`src/passes/merge_locals_test.mbt`](../../../../../src/passes/merge_locals_test.mbt) | Public spelling, same-typed retargeting, and write-invalidation regressions. |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | Registry classifies `merge-locals` as a module pass. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | Module dispatcher runs `merge_locals_run_module_pass`. |
| [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) | Direct oracle harness exposes `--merge-locals`. |
| [research note 0535](./index.md) | Post-fuzzer-change direct parity evidence. |

## Validation evidence

The 2026-05-06 revalidation lane ran:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-locals --out-dir .tmp/pass-fuzz-merge-locals`

The compare-pass run reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, 0 validation failures, 0 generator failures, and 20 Binaryen parser/canonicalization command failures from the known empty-recursion-group class.

## Remaining implementation debt

A fuller Binaryen-equivalent port still needs:

1. a `LocalGraph`-equivalent set-influence proof across control flow;
2. destination-to-source as well as source-to-destination orientation decisions;
3. post-rewrite validation / rollback for graph-invalidated candidates;
4. conservative coverage for `between-unreachable`, type mismatch, and other control-flow-spanning shapes;
5. late local-cleanup neighborhood proof before any public preset scheduling.

Neighboring local-cleanup dossiers remain the right context:

- [`../optimize-casts/index.md`](../optimize-casts/index.md)
- [`../local-subtyping/index.md`](../local-subtyping/index.md)
- [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

## Bottom line

Starshine's current `merge-locals` strategy is **active direct-pass parity for the landed copy-retargeting slice**, not full upstream `LocalGraph` parity and not preset-ready local cleanup. Keep the broader graph/orientation work as future implementation debt.
