---
kind: concept
status: supported
last_reviewed: 2026-06-04
sources:
  - ../raw/ir2/2026-06-04-ir2-architecture-current-refresh.md
  - ../raw/ir2/2026-05-20-ir2-test-matrix-repository-refresh.md
  - ../raw/ir2/2026-05-20-local-ssa-source-bridge.md
  - ../raw/research/0059-2026-03-24-ir2-architecture-rules.md
  - ../../../src/ir/README.md
  - ../../../src/ir/architecture.mbt
  - ../../../src/ir/hot_core.mbt
  - ../../../src/ir/analysis_cache.mbt
  - ../../../src/passes/pass_common.mbt
related:
  - ./cfg-contract.md
  - ./local-ssa-policy.md
  - ./test-matrix.md
  - ./pass-porting-checklist.md
  - ./execution-plan.md
  - ../../../src/ir/README.md
  - ../../../src/ir/hot_lift.mbt
  - ../../../src/ir/hot_verify.mbt
  - ../../../src/ir/hot_lower.mbt
---

# IR2 Architecture Rules

## Overview

IR2 is Starshine's optimizer-internal architecture for working on WebAssembly function bodies. Its central rule is intentionally small: **`HotFunc` is the only owned optimizer body representation.** Everything else is either a boundary WebAssembly module/expression, a derived analysis overlay, or a pass-facing helper around that one owned body.

A beginner-friendly flow is:

```text
raw @lib.Module / @lib.Expr
  -> lift one function body into HotFunc
  -> verify the HOT body
  -> build revision-keyed overlays such as CFG, dominators, effects, or local SSA
  -> mutate through HOT mutation helpers
  -> verify again
  -> lower back to raw @lib instructions/function body
  -> validate the resulting module
```

The current source bridge is [`../raw/ir2/2026-06-04-ir2-architecture-current-refresh.md`](../raw/ir2/2026-06-04-ir2-architecture-current-refresh.md). It rechecked the current official WebAssembly Core 3.0 boundary pages plus local `src/ir` and `src/passes` files. The official WebAssembly sources support the boundary split between modules/instructions/expressions/binary/validation and Starshine's optimizer-local HOT form; the local repository files are authoritative for HOT ownership, revisioning, side tables, descriptors, and cache behavior.

## The Three Layers

| Layer | Owned by | What it is for | What it must not do |
| --- | --- | --- | --- |
| Boundary module/expression | `src/lib`, WAT/binary parser, validator, command pipeline | Decode, encode, validate, print, run spec/static harnesses, and carry whole-module resources. | Do not become a pass-private recursive optimizer body. |
| HOT body | One [`HotFunc`](../../../src/ir/hot_core.mbt) per lifted function body | Dense function-body storage for optimizer rewrites, with stable ids, side tables, labels, locals, types, roots, tombstones, and a revision counter. | Do not skip verification/lowering/validation; do not mutate storage behind the public APIs. |
| Analysis overlays | CFG, dominance, post-dominance, loop info, use-def, liveness, effects, local SSA, traversal orders | Reusable facts derived from a `HotFunc` at a specific revision. | Do not own body state, persist across revisions, or patch themselves after mutation. |

This separation prevents a common compiler failure mode: building several half-owned IRs that disagree about control flow, locals, side effects, or validation state. If a pass needs a fact, it should request or build an overlay. If it needs to change semantics, it should mutate `HotFunc` and let revision-based invalidation force fresh overlays.

## `HotFunc` Ownership Shape

[`HotFunc`](../../../src/ir/hot_core.mbt) owns the function-body data that optimizer passes are allowed to rewrite:

- dense `nodes`, `children`, and `roots` arrays;
- `HotLocals` for parameter/body-local metadata;
- interned result/type records;
- labels with owner and branch-arity metadata;
- typed side tables for constants, memory arguments, branch tables, catches, call signatures, and exact boundary-instruction payloads;
- body result and optional function type metadata;
- tombstone/free-node tracking for deleted nodes;
- `revision`, the cache key for every derived overlay.

Important practical consequences:

1. **Node ids are HOT-local ids.** They are not raw `@lib.Instruction` pointers and are not stable after lowering/re-lifting a function.
2. **Side tables preserve exact boundary details.** Generic HOT families such as heap/reference/string/SIMD/atomic forms may carry exact instruction payloads so lift/lower can preserve opcode identity that a pass does not understand deeply yet.
3. **Deleted nodes are tombstones, not an alternate body.** Tombstones keep ids stable during a pass, but later queries must check liveness instead of assuming every allocated node is semantically present.
4. **Revision is part of correctness.** Any semantic mutation that changes roots, children, nodes, locals, labels, types, or lowered meaning must bump the revision through the public mutation surface.

## Revision-Keyed Overlays

[`analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt) is the shared cache for derived facts. It stores each overlay with `built_at_revision` and reuses it only while `built_at_revision == hot_revision_current(func)`.

Current cache entries include:

- CFG and deterministic CFG orders;
- dominators and post-dominators;
- loop info;
- use-def and liveness;
- conservative effects summaries;
- local SSA.

The pass-facing helper layer in [`pass_common.mbt`](../../../src/passes/pass_common.mbt) turns descriptor requirements into typed `pass_require_*` calls. That means a pass should normally say what it needs through [`HotPassDescriptor`](../../../src/ir/architecture.mbt), then call shared helpers rather than constructing its own private CFG, liveness, or SSA cache.

```moonbit
HotPassDescriptor::new(
  "example-pass",
  requires=[HotAnalysis::cfg(), HotAnalysis::effects()],
  invalidates=[HotAnalysis::liveness(), HotAnalysis::ssa()],
)
```

The exact syntax above is illustrative, but the shape is locked by [`architecture.mbt`](../../../src/ir/architecture.mbt) and [`architecture_test.mbt`](../../../src/ir/architecture_test.mbt): descriptors expose `requires` and `invalidates`, while direct HOT mutations advance the revision.

## Lift / Verify / Analyze / Mutate / Lower Contract

The durable pass contract is:

```text
lift -> verify -> analyze -> mutate -> verify -> lower -> validate
```

- **Lift**: [`hot_lift.mbt`](../../../src/ir/hot_lift.mbt) reads validated boundary expressions/functions and module context into a `HotFunc`.
- **Verify before mutation**: [`hot_verify.mbt`](../../../src/ir/hot_verify.mbt) catches corrupted HOT storage, control metadata, labels, and analysis assumptions early.
- **Analyze**: request overlays through the shared cache/helper layer.
- **Mutate**: use [`hot_mutate.mbt`](../../../src/ir/hot_mutate.mbt), [`hot_region_edit.mbt`](../../../src/ir/hot_region_edit.mbt), and pass-level wrappers such as `pass_replace_node(...)` or `pass_splice_region(...)` where possible.
- **Verify after mutation**: do not trust a local rewrite just because it was small.
- **Lower**: [`hot_lower.mbt`](../../../src/ir/hot_lower.mbt) reconstructs boundary instructions/function bodies, including label-depth remapping and exact instruction recovery.
- **Validate**: module validation remains the final local semantic floor before pass-specific Binaryen oracle comparison.

The shared fixture path in [`test-matrix.md`](./test-matrix.md) describes how IR tests prove this loop with WAT fixtures, HOT verification, lowering, and module validation.

## Module Split Rule

`src/ir` has already moved beyond the original March plan's “future split” language. Treat the current package files as the ownership map:

- `architecture.mbt`: revision reads and pass-descriptor metadata.
- `hot_core.mbt`: dense HOT storage and basic ids.
- `hot_builders.mbt`, `hot_mutate.mbt`, `hot_region_edit.mbt`, `hot_query.mbt`, `hot_walk.mbt`: construction, mutation, structured edits, read-only queries, and traversals.
- `hot_types.mbt`, `hot_labels.mbt`, `hot_flags.mbt`, `hot_side_tables.mbt`, `hot_module_context.mbt`: type/label/flag/payload/module-context support.
- `hot_lift.mbt`, `hot_verify.mbt`, `hot_lower.mbt`: boundary conversion and correctness checkpoints.
- `cfg*.mbt`, `dominators.mbt`, `postdominators.mbt`, `loop_info.mbt`, `use_def.mbt`, `liveness.mbt`, `effects.mbt`, `ssa_*.mbt`, `analysis_cache.mbt`: derived overlays.
- `test_helpers.mbt`: shared IR fixture and golden helpers.
- `hot.mbt`: compatibility-free facade/glue for consumers, not permission to re-centralize logic.

When adding a new invariant, prefer a focused module or the existing focused owner. Do not rebuild a monolithic `hot.mbt`, and do not revive deleted recursive optimizer-body compatibility layers.

## Correctness Constraints

- **Single owned body:** a pass may use raw `@lib.Module` for module-level facts, but function-body optimizer mutation should converge on `HotFunc`, not on a second owned function IR.
- **Public mutation only:** direct writes to HOT storage are architecture debt unless they are inside the owning IR module. Shared mutation helpers exist so revisioning, tombstones, labels, and region membership stay consistent.
- **Analysis invalidation by revision:** never carry `BlockId`, dominance facts, liveness bitsets, effect masks, SSA value ids, or phi ids across a revision-changing mutation.
- **Overlay honesty:** local SSA is an overlay and destruction/writeback step; it must not become persistent HOT phi nodes. See [`local-ssa-policy.md`](./local-ssa-policy.md).
- **CFG honesty:** CFG blocks and edges are overlay ids and edge facts, not owned body nodes. See [`cfg-contract.md`](./cfg-contract.md).
- **Module-level passes stay explicit:** a module pass such as function reordering, global cleanup, or type-section rewriting may need module-level logic outside one `HotFunc`, but any lifted function-body rewrite still has to respect HOT verification and module validation boundaries.

## Concrete Example: Tiny Peephole Pass

For a simple peephole that deletes a pure redundant wrapper inside one function:

1. Parse and validate the input module through the normal command/pass fixture path.
2. Lift the target function into `HotFunc`.
3. Verify the HOT body.
4. Request only the overlays needed by the proof, such as effects if the rewrite depends on non-trapping/pure behavior.
5. Replace or splice the node through pass/HOT mutation helpers, causing the revision to change.
6. Let any stale overlays rebuild; do not reuse old `BlockId` or effect-summary objects.
7. Verify, lower, validate, and then run pass-specific oracle/signoff if the pass has a Binaryen equivalent.

That example is deliberately ordinary: most IR2 bugs come from skipping one boring step, such as reusing stale liveness after a mutation or preserving a side-table payload without checking the exact lowered opcode.

## Practical Rules

- Start architecture or invariant work from this page, then follow the focused pages for CFG, local SSA, test placement, and pass porting.
- Add or update tests before changing IR semantics. Use [`test-matrix.md`](./test-matrix.md) to choose the owner file.
- Add descriptor requirements and invalidations when a pass begins depending on a new overlay.
- Keep public docs clear about what is current architecture versus archived March planning context.
- If an old research note has been absorbed, cite it as provenance, not as the freshest source of truth.

## Sources

- Current source bridge: [`../raw/ir2/2026-06-04-ir2-architecture-current-refresh.md`](../raw/ir2/2026-06-04-ir2-architecture-current-refresh.md)
- Current test matrix bridge: [`../raw/ir2/2026-05-20-ir2-test-matrix-repository-refresh.md`](../raw/ir2/2026-05-20-ir2-test-matrix-repository-refresh.md)
- Local SSA source bridge: [`../raw/ir2/2026-05-20-local-ssa-source-bridge.md`](../raw/ir2/2026-05-20-local-ssa-source-bridge.md)
- Archived original architecture note: [`../raw/research/0059-2026-03-24-ir2-architecture-rules.md`](../raw/research/0059-2026-03-24-ir2-architecture-rules.md)
- Package-local ownership summary: [`../../../src/ir/README.md`](../../../src/ir/README.md)
- Revision and descriptor layer: [`../../../src/ir/architecture.mbt`](../../../src/ir/architecture.mbt), [`../../../src/ir/architecture_test.mbt`](../../../src/ir/architecture_test.mbt)
- HOT storage: [`../../../src/ir/hot_core.mbt`](../../../src/ir/hot_core.mbt)
- Analysis cache: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt)
- Pass helper layer: [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)
