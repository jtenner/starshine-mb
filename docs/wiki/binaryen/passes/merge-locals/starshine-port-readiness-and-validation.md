---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/research/0535-2026-05-06-merge-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/research/0441-2026-05-04-merge-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-locals-current-main-source-correction.md
  - ../../../raw/research/0363-2026-04-25-merge-locals-source-correction-and-test-map.md
  - ../../../raw/binaryen/2026-04-23-merge-locals-primary-sources.md
  - ../../../../../src/passes/merge_locals.mbt
  - ../../../../../src/passes/merge_locals_test.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./local-graph-and-copy-influences.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../optimize-casts/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
---

# Starshine port readiness and validation for `merge-locals`

This bridge tracks the gap between the active Starshine direct pass and a fuller Binaryen-equivalent `merge-locals` port.

Use it with:

- [`./index.md`](./index.md) for the folder overview;
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the corrected upstream algorithm;
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner/test map;
- [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) for the graph/orientation proof;
- [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after examples;
- [`./starshine-strategy.md`](./starshine-strategy.md) for current local status.

## Current local reality

`merge-locals` has an active Starshine module-pass owner and direct explicit-pass parity under the refreshed 2026-05-06 harness. The current implementation covers a conservative same-typed linear copy-retargeting slice, guarded by write invalidation, and is wired through registry, dispatcher, tests, and compare-pass tooling.

It is still not a full `LocalGraph`-equivalent port and should stay out of public presets until the broader local-cleanup neighborhood is oracle-proven.

## Exact Starshine code and proof surfaces

| Surface | Why it matters |
| --- | --- |
| [`src/passes/merge_locals.mbt`](../../../../../src/passes/merge_locals.mbt) | Active module-pass owner for same-typed copy-retargeting. |
| [`src/passes/merge_locals_test.mbt`](../../../../../src/passes/merge_locals_test.mbt) | Public spelling, same-typed retargeting, and destination-write invalidation tests. |
| [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) | `merge-locals` is a module-pass registry entry. |
| [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) | Active module-pass dispatcher invokes `merge_locals_run_module_pass`. |
| [`scripts/lib/pass-fuzz-compare-task.ts`](../../../../../scripts/lib/pass-fuzz-compare-task.ts) | Direct compare-pass harness exposes the `--merge-locals` spelling. |
| [`./local-graph-and-copy-influences.md`](./local-graph-and-copy-influences.md) | Explains the graph/orientation proof still missing from the local subset. |
| `src/lib/types.mbt` | Local declarations and instruction nodes define the validator-visible rewrite surface. |
| `src/validate/typecheck.mbt` | Local get/set/tee typing must stay sound after any rewrite. |
| `docs/wiki/raw/research/0535-2026-05-06-merge-locals-direct-revalidation.md` | Current direct parity evidence: 6759/6759 normalized matches, 0 mismatches. |

## Current validation evidence

The 2026-05-06 direct signoff ran:

- `moon info`
- `moon fmt`
- `moon test`
- `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass merge-locals --out-dir .tmp/pass-fuzz-merge-locals`

The compare-pass run reported 6759 compared cases, 6759 normalized matches, 0 mismatches, 0 validation failures, 0 generator failures, and 20 known Binaryen empty-recursion-group parser/canonicalization command failures.

## Next safe slices

The remaining work is to extend from the current linear same-typed copy slice toward Binaryen's graph-backed behavior:

1. add a `LocalGraph`-style set-influence representation;
2. decide source-side versus destination-side ownership with graph evidence;
3. reject or roll back candidates that fail post-rewrite graph validation;
4. expand tests for type-mismatch negatives, rollback cases, and `between-unreachable` conservatism;
5. rerun direct compare-pass parity after each semantic expansion;
6. only then test the late local-cleanup neighborhood.

Potential neighborhood lanes once surrounding passes are ready:

- `heap2local -> merge-locals -> optimize-casts`
- `optimize-casts -> local-subtyping`
- `local-subtyping -> coalesce-locals -> local-cse`

## Bottom line

The pass is active and direct-green for the landed conservative slice. The readiness question is now about **fuller LocalGraph parity and preset/neighborhood proof**, not about basic registry or dispatcher exposure.
