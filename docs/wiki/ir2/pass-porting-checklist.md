---
kind: concept
status: supported
last_reviewed: 2026-04-09
sources:
  - ../../0062-2026-03-24-pass-porting-checklist.md
related:
  - ./execution-plan.md
  - ./test-matrix.md
  - ../../../src/passes/pass_common.mbt
  - ../../../src/passes/pass_common_test.mbt
  - ../../../src/passes/pass_test_helpers.mbt
---

# IR2 Pass Porting Checklist

## Durable Conclusions

- Hot pass work runs through the public pipeline:
  `lift -> verify -> run passes -> verify -> lower -> validate`
- Pass descriptors must declare truthful `requires` and `invalidates` metadata.
- Analysis overlays should come from shared helpers, not ad hoc pass-local builders.
- Rewrites should use public hot-IR mutation helpers and mark mutations explicitly when the shared wrappers are not enough.
- Pass tests should run through the public pipeline on WAT fixtures instead of private execution paths.

## Shared Helper Rules

- Use [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt) for `pass_prepare_requirements(...)` and the specific `pass_require_*` helpers.
- Use shared mutation helpers such as `pass_replace_node(...)`, `pass_splice_region(...)`, and `pass_delete_detached_nodes(...)` where they fit.
- Call `pass_mark_mutated(...)` for mutation flows outside the shared wrappers.
- Verify with `pass_verify_before_after(...)`.
- Use [`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt) to build fixtures and run `pass_test_run_pipeline(...)`.

## Rewrite Patterns

- Subtree peepholes:
  replace one rooted subtree, then clean up detached nodes.
- CFG-local rewrites:
  request only the analyses needed for the touched blocks or regions.
- SSA-assisted rewrites:
  request SSA through the shared helper, then rely on revision-based invalidation after mutation.
- Worklist rewrites:
  keep the worklist local to the pass, but use shared mutation and verification helpers for each applied rewrite.

## Current In-Tree Status

- Shared helper behavior is exercised in [`../../../src/passes/pass_common_test.mbt`](../../../src/passes/pass_common_test.mbt).
- The shared WAT fixture runner lives in [`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt).
- The shared fixture and golden contract for IR2 work lives in [`./test-matrix.md`](./test-matrix.md).

## Practical Rule

- Start with the failing test.
- Use the public helper layer instead of reaching into IR internals directly.
- Keep CLI-visible pass ids grounded in the real registry.
- Let revision-keyed invalidation clear stale overlays after mutation instead of trying to preserve caches by hand.

## Sources

- Numbered research doc: [`../../0062-2026-03-24-pass-porting-checklist.md`](../../0062-2026-03-24-pass-porting-checklist.md)
- Shared helper layer: [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)
- Shared helper tests: [`../../../src/passes/pass_common_test.mbt`](../../../src/passes/pass_common_test.mbt)
