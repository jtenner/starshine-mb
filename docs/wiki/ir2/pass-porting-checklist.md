---
kind: concept
status: supported
last_reviewed: 2026-07-18
sources:
  - ../../../src/passes/registry_test.mbt
  - ../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md
  - ../../../src/lib/types.mbt
  - ../../../src/validate/env.mbt
  - ../../../src/validate/validate.mbt
related:
  - ./execution-plan.md
  - ./test-matrix.md
  - ../../../src/passes/pass_common.mbt
  - ../../../src/passes/pass_common_test.mbt
  - ../../../src/passes/pass_test_helpers.mbt
  - ../validate/type-section-and-subtyping.md
  - ../wast/gc-type-authoring.md
---

# IR2 Pass Porting Checklist

## Durable Conclusions

- Hot pass work runs through the public pipeline:
  `lift -> verify -> run passes -> verify -> lower -> validate`
- Pass descriptors must declare truthful `requires` and `invalidates` metadata; any pass that calls `pass_require_*` helpers should have descriptor tests locking the corresponding `requires` entries.
- Analysis overlays should come from shared helpers, not ad hoc pass-local builders.
- Rewrites should use public hot-IR mutation helpers and mark mutations explicitly when the shared wrappers are not enough.
- Pass tests should run through the public pipeline on WAT fixtures instead of private execution paths.

## Shared Helper Rules

- Use [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt) for `pass_prepare_requirements(...)` and the specific `pass_require_*` helpers.
- When adding or discovering a `pass_require_*` dependency, update the pass descriptor first-test style and cover it in [`../../../src/passes/registry_test.mbt`](../../../src/passes/registry_test.mbt), as the `optimize-instructions` `use_def` / `effects` assertion, the `remove-unused-brs` `use_def` assertion, and the audited descriptor-contract table do.
- Use shared mutation helpers such as `pass_replace_node(...)`, `pass_splice_region(...)`, and `pass_delete_detached_nodes(...)` where they fit.
- Call `pass_mark_mutated(...)` for mutation flows outside the shared wrappers.
- Verify with `pass_verify_before_after(...)`.
- Use [`../../../src/passes/pass_test_helpers.mbt`](../../../src/passes/pass_test_helpers.mbt) to build fixtures and run `pass_test_run_pipeline(...)`.

## Function-Section Type Index Invariant

- Module-level function declarations, `FuncSec`, and pass-local function-signature caches should use absolute `TypeIdx` values.
- `RecIdx` is only valid inside the temporary recursive type context while validating a `RecType`; normalize it before writeback, binary emission, or cross-pass caching.
- The canonical validator reference is [`../validate/type-section-and-subtyping.md`](../validate/type-section-and-subtyping.md); the current source bridge is [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md), with the older 2026-05-20 bridge retained as provenance for the original invariant audit.

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

- Archived original pass-porting note: research note 0062
- Current GC type/subtyping bridge: [`../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md`](../raw/wasm/2026-06-04-gc-type-subtyping-current-refresh.md)
- Shared helper layer: [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)
- Shared helper tests: [`../../../src/passes/pass_common_test.mbt`](../../../src/passes/pass_common_test.mbt)
