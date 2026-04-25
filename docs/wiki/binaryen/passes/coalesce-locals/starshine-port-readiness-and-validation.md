---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
---

# Starshine `coalesce-locals` port readiness and validation matrix

This page is the implementation-readiness bridge for the unimplemented local `coalesce-locals` pass.
It does not replace the upstream strategy or shape catalog.
Instead, it answers: if a future agent starts porting the pass, which existing Starshine surfaces are ready, which ones are missing, and which Binaryen shape families must become tests first?

## Current readiness snapshot

| Area | Current Starshine state | Port implication |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:144-151` tracks `coalesce-locals` as a removed known pass name. | Keep the public spelling stable, but do not schedule the pass until an owner and dispatcher exist. |
| Dispatcher | `src/passes/pass_manager.mbt` has no `coalesce-locals` case. | A real port needs a module or function-pass owner hook before direct `--coalesce-locals` requests can stop failing. |
| Presets | `src/passes/optimize_test.mbt` locks the current partial preset honesty rule around missing local-neighborhood passes. | Do not add `reorder-locals` / `coalesce-locals` late slots in isolation; preserve the Binaryen neighborhood order when the missing passes land. |
| Backlog | `agent-todo.md:392-399` keeps slice `CL` with compatibility/lifetime analysis and dual-slot rewrite work. | Treat `CL` as the active planning home before coding. |
| Local-index rewrite substrate | `src/passes/reorder_locals.mbt:118`, `:183`, and `:544` already scan and rewrite local users and rebuild declarations for a landed module pass. | Reuse the local-index and metadata-repair lessons; do not copy the exact reorder algorithm as the coalescing algorithm. |
| Later cleanup substrate | `src/passes/simplify_locals.mbt:70`, `:4126`, `:4191`, `:4245`, and `:4348` already own HOT local-traffic cleanup phases. | Let later cleanup remain a consumer; do not grow `coalesce-locals` into generic simplify-locals. |
| Missing core | No compatibility/interference engine, coloring choice, or `applyIndices`-style cleanup exists locally. | The first implementation milestone must be a faithful local version of Binaryen's value-aware interference plus exact-type coloring contract. |

## Minimum viable port shape

A faithful first Starshine port should be deliberately narrow:

1. collect locals, declared types, params, and synthetic zero-init facts for one function;
2. walk local uses/defs with enough liveness information to reject different-value overlap;
3. allow same-value overlap only when a local value-number proof is available;
4. require exact type equality for all locals sharing a final index;
5. keep params fixed unless the Binaryen rule being ported explicitly permits the case;
6. choose an index mapping using the Binaryen-tested greedy-order objective;
7. rewrite local indices and declarations through module-safe metadata repair;
8. delete redundant copies and dead sets only when the value/effect rules are already proven;
9. refinalize or revalidate after any dead tee / unreachable cleanup family that can change expression types;
10. compare the result in the surrounding Binaryen order, not only as an isolated pass.

This keeps the pass aligned with [`./binaryen-strategy.md`](./binaryen-strategy.md) and avoids two common overextensions:

- subtype-aware merging, which belongs outside default `coalesce-locals`;
- dead-store elimination, which belongs to neighboring cleanup passes unless it is the specific post-coalescing debris Binaryen removes.

## Required first tests

The first local test set should be small but cover the whole correctness envelope.

| Test family | Why it is required | Existing wiki anchor |
| --- | --- | --- |
| Exact-type positive | Coalescing is type-exact, not subtype-based. | [`./wat-shapes.md`](./wat-shapes.md) |
| Type mismatch negative | Prevents silent invalid local index reuse. | [`./wat-shapes.md`](./wat-shapes.md) |
| Different-value overlap negative | Protects ordinary liveness interference. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Same-value overlap positive | Proves the pass is value-aware rather than lifetime-only. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Zero-init / param entry | Locks the implicit-entry facts that affect merge legality. | [`./binaryen-strategy.md`](./binaryen-strategy.md) |
| Redundant-copy removal | Proves the pass optimizes for copy removal, not just local-count reduction. | [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) |
| Dead set / dead tee cleanup | Exercises `applyIndices` cleanup and refinalization boundaries. | [`./wat-shapes.md`](./wat-shapes.md) |
| Loop backedge priority | Prevents a locally valid but Binaryen-divergent greedy order. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Dual scheduler slot replay | Verifies both no-DWARF roles: after `local-subtyping` and after `reorder-locals`. | [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

## Validation ladder

Use this ladder before moving the pass from removed to active:

1. **Unit shape tests** for the families above, with direct before/after WAT fixtures.
2. **Registry tests** proving `--coalesce-locals` stops being a removed-name rejection only after the dispatcher and owner are active.
3. **Preset honesty tests** proving partial `optimize` / `shrink` still do not claim missing neighbors out of order.
4. **Neighborhood tests** for `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` once the neighboring passes exist.
5. **Reorder interaction tests** for `reorder-locals -> coalesce-locals -> reorder-locals` because local-index repair and local-name repair are observable in Starshine.
6. **Fuzz parity** with the canonical pass spelling once the basic reduced families are green.
7. **Late-tail replay** against Binaryen where final debris cleanup and repeated slots matter.

If one of those steps fails, keep the pass out of public presets even if isolated reduced tests pass.

## Health-check outcome from this run

The touched-area check found one wiki-health issue rather than a source-strategy issue: the folder already had the required overview, Binaryen strategy, transformed-shape catalog, implementation/test map, and Starshine strategy page, but the tracker still labeled the dossier as `dossier` while neighboring pages treated it as a deep multi-page guide.
This page closes the remaining beginner-to-advanced port-readiness gap and makes the `deep` status justified.

No contradiction was found between the 2026-04-22 tagged source manifest and the 2026-04-25 current-main recheck for the teaching-level `coalesce-locals` contract.
The only remaining uncertainty is implementation-specific: a future local port must choose whether to model Binaryen's liveness/value-number facts directly in a module pass or use a HOT-assisted per-function analysis with a module-level declaration/name repair tail.

## Sources

- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md`](../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
