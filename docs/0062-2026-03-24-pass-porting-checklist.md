# IR2 Pass Porting Checklist

## Scope

- Canonical checklist for porting optimizer passes onto the IR2 `jtenner/starshine/passes` package.
- Covers pass-author scaffolding, required helper APIs, and minimum validation for each migrated pass.

## Current Behavior

- Hot passes run through `lift -> verify -> run passes -> verify -> lower -> validate`.
- Shared pass helpers live in [`src/passes/pass_common.mbt`](../src/passes/pass_common.mbt).
- Shared pass test helpers live in [`src/passes/pass_test_helpers.mbt`](../src/passes/pass_test_helpers.mbt).
- The registry and preset surface remain the only CLI-visible source of pass ids.

## Porting Checklist

- Define a `HotPassDescriptor` with truthful `requires` and `invalidates` metadata.
- Use `pass_prepare_requirements(...)` or the specific `pass_require_*` helpers instead of building overlays ad hoc.
- Perform rewrites through public hot-IR mutation helpers, preferably the shared wrappers:
  `pass_replace_node(...)`, `pass_splice_region(...)`, and `pass_delete_detached_nodes(...)`.
- Call `pass_mark_mutated(...)` for any helper flow that mutates outside the shared wrappers.
- Use `pass_node_use_count(...)` or `pass_node_is_unused(...)` before detached-node cleanup decisions.
- Keep structured-region edits local and explicit; do not reach into storage internals directly.
- Verify through `pass_verify_before_after(...)` and keep the pass runnable under the public pipeline.
- Add pass tests through WAT fixtures and `pass_test_run_pipeline(...)` instead of private execution paths.

## Rewrite Patterns

- Subtree peepholes:
  Use direct node replacement and detached-node cleanup when a rewrite only changes one rooted subtree.
- CFG-local rewrites:
  Request CFG, dominance, liveness, or effects through the shared helpers and keep edits inside the touched blocks or regions.
- SSA-assisted rewrites:
  Request SSA through `pass_require_ssa(...)`, perform the rewrite, then rely on mutation invalidation before any later overlay rebuild.
- Worklist rewrites:
  Build the worklist in pass-local code, but use the shared mutation and verification helpers for every applied rewrite.

## Correctness Rules

- Shared helpers only use public hot-IR APIs.
- Pass ids exposed to the CLI must come from the real registry.
- Unknown pass names must reject instead of silently acting as no-ops.
- Overlay reuse is revision-keyed; any hot mutation must invalidate stale cached analyses before later reuse.

## Validation Plan

- Add a red test for the shared helper or migrated pass first.
- Run `moon test src/passes`.
- Before commit, run `moon info`, `moon fmt`, `bun validate readme-api-sync`, and `moon test`.

## Performance Impact

- Shared helper APIs keep analysis reuse centralized and avoid repeated ad hoc overlay construction.
- Mutation invalidation remains coarse for now through full cache reset; finer-grained invalidation can come later without changing pass-author call sites.

## Open Questions

- Whether future pass ports need first-class shared worklist runner helpers rather than pass-local loops.
- Whether mutation invalidation should grow from full-cache reset to descriptor-driven selective invalidation.
