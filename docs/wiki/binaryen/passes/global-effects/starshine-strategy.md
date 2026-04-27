---
kind: concept
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md
  - ../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md
  - ../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/ir/effects.mbt
  - ../../../../../src/ir/analysis_cache.mbt
  - ../../../../../src/passes/pass_common.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/heap_store_optimization.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./metadata-naming-and-consumers.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../discard-global-effects/starshine-strategy.md
  - ../simplify-locals/index.md
  - ../heap-store-optimization/index.md
  - ../vacuum/index.md
  - ../tracker.md
---

# Starshine strategy for `global-effects`

## Current status

Starshine currently treats `global-effects` as a **boundary-only compatibility name**, not as an active pass.

The exact local facts are:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists `global-effects` in `pass_registry_boundary_only_names()`.
- the same file rejects requested boundary-only passes with the standard “not implemented in the hot pipeline” error during pass expansion.
- [`src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt) proves `--global-effects` is accepted by CLI parsing and normalized to the `global-effects` pass flag.
- no `src/passes/global_effects.mbt` owner file exists today.
- no active HOT pass, module pass, preset slot, or `agent-todo.md` backlog slice exists for this pass today.

The 2026-04-27 readiness bridge makes the next step explicit: keep this boundary-only until Starshine can at least build observable per-function summaries, then promote it as a module pass with dispatcher support and paired consumer validation.

That means the local behavior is intentionally honest: users can spell the compatibility flag, but Starshine refuses to run it until a real implementation exists.

## Why this cannot be a small HOT peephole

Binaryen's `generate-global-effects` is a module-level metadata producer. The reviewed upstream pass computes summaries across the call graph and writes them into per-function `Function.effects` metadata. It is not a local expression rewrite and it usually does not change printed WAT by itself.

A faithful Starshine port therefore needs module-level work:

1. collect per-function shallow effects
2. collect direct call edges
3. model imported, indirect, and otherwise unknown calls conservatively
4. propagate summaries through transitive calls or SCCs
5. expose the summaries to later effect-sensitive analyses
6. invalidate or discard summaries after later transforms mutate function bodies or call targets

Adding a HOT-only tree rewrite under the `global-effects` name would misrepresent the upstream contract.

## Local ingredients already present

Starshine does have useful building blocks, but they are currently **function-local** rather than interprocedural.

### Effect bit vocabulary

[`src/ir/effects.mbt`](../../../../../src/ir/effects.mbt) defines coarse HOT effect bits:

- `EFFECT_MASK_CALL`
- `EFFECT_MASK_THROW`
- `EFFECT_MASK_TRAP`
- `EFFECT_MASK_LOCAL_STATE`
- `EFFECT_MASK_GLOBAL_STATE`
- memory and table read/write masks

The same file maps `HotOp::GlobalGet` and `HotOp::GlobalSet` to the global-state bit and recursively accumulates subtree effects.

This is a useful local equivalent for Binaryen's shallow per-function scanning, but it does not distinguish which global was read or written and it does not propagate through the module call graph.

### Cached function-local summaries

[`src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt) defines `HotEffectsSummary` with node, block, and root-region masks, and caches it by HOT revision.

[`src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt) exposes `pass_require_effects(...)`, which builds and records the same function-local effects analysis for passes that request it.

This gives future work an invalidation pattern, but not Binaryen-style per-module `Function.effects` metadata.

### Current consumers of local effects

[`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt) uses local effect masks to decide whether sinking or reordering local-set payloads is safe around global, memory, table, call, trap, and local-state effects.

[`src/passes/heap_store_optimization.mbt`](../../../../../src/passes/heap_store_optimization.mbt) also consults effect masks for movement safety while folding allocation/store patterns.

These consumers prove Starshine already cares about effect-sensitive movement, but they do not consume module-level callee summaries in the Binaryen `generate-global-effects` sense.

## Required future implementation shape

A future implementation should land as a module analysis/pass, likely near the pass-manager boundary rather than inside one HOT function rewrite.

Minimum data model requirements:

- one summary per defined function
- separate global-read and global-write facts; the current coarse `EFFECT_MASK_GLOBAL_STATE` bit is not precise enough for full parity
- direct-call edge collection from lowered module instructions or HOT-lifted function bodies
- conservative markers for import calls, indirect calls, `call_ref`, unknown bodies, throws, traps, and calls whose target cannot be summarized
- a summary lifecycle model so later transforms can invalidate or discard stale data

Minimum algorithmic requirements:

- compute shallow local summaries using existing effect-mask logic where possible
- either mirror `version_129`'s transitive-callee propagation or use a current-main-style SCC aggregation, but document the choice against the selected Binaryen oracle
- keep recursive cycles conservative enough to preserve trap/effect boundaries
- expose summaries to later passes in a way they must explicitly opt into

Minimum validation requirements:

- a CLI/request test showing boundary-only rejection disappears only when a real pass exists
- direct reader/writer/transitive-wrapper tests for summary contents
- recursive-call tests for conservative cycle handling
- imported/indirect-call tests for unknown-effect poisoning
- consumer tests paired with `vacuum` or local movement passes once summaries are actually consumed
- Binaryen parity checks using `--generate-global-effects --vacuum` and `--generate-global-effects --simplify-locals` shapes

The detailed implementation order and validation ladder now live in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Cross-links for the pass dossier

Read this page with:

- [`./index.md`](./index.md) for the overview, purpose, invariants, inputs/outputs, and validation story
- [`./wat-shapes.md`](./wat-shapes.md) for transformed-or-observed call/global shapes and downstream before/after examples
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for upstream `version_129` and current-`main` strategy notes
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner-file/test map
- [`./metadata-naming-and-consumers.md`](./metadata-naming-and-consumers.md) for lifecycle, naming, and downstream-consumer caveats
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the no-rewrite analyzer first slice, summary model, solver choice, registry/dispatcher sequencing, and paired Binaryen validation lanes

Neighboring consumer docs:

- [`../simplify-locals/index.md`](../simplify-locals/index.md)
- [`../heap-store-optimization/index.md`](../heap-store-optimization/index.md)
- [`../vacuum/index.md`](../vacuum/index.md)

## Non-goals for current Starshine

Until a module-level implementation exists, do not claim that Starshine:

- computes Binaryen-compatible `Function.effects` metadata
- makes later calls less conservative using interprocedural global summaries
- implements upstream [`discard-global-effects`](../discard-global-effects/starshine-strategy.md)
- includes `global-effects` in `optimize` or `shrink` presets
- has a dedicated active backlog slice for this pass

## Sources

- [`../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-global-effects-port-readiness-primary-sources.md)
- [`../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md`](../../../raw/research/0417-2026-04-27-global-effects-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-25-discard-global-effects-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md`](../../../raw/binaryen/2026-04-24-global-effects-primary-sources.md)
- [`../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md`](../../../raw/research/0305-2026-04-24-global-effects-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cli/cli_test.mbt`](../../../../../src/cli/cli_test.mbt)
- [`../../../../../src/ir/effects.mbt`](../../../../../src/ir/effects.mbt)
- [`../../../../../src/ir/analysis_cache.mbt`](../../../../../src/ir/analysis_cache.mbt)
- [`../../../../../src/passes/pass_common.mbt`](../../../../../src/passes/pass_common.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/heap_store_optimization.mbt`](../../../../../src/passes/heap_store_optimization.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
