---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md
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

This page is the implementation-readiness and validation bridge for the active local `coalesce-locals` pass.
It does not replace the upstream strategy or shape catalog.
Instead, it answers: which Starshine surfaces are now active, which placement/artifact caveats remain, and which Binaryen shape families are locked by tests first?

## Current readiness snapshot

| Area | Current Starshine state | Port implication |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:277` tracks `coalesce-locals` as an active module pass. | Keep the public spelling stable and leave public preset placement for ordered-neighborhood replay. |
| Dispatcher | `src/passes/pass_manager.mbt:8936` dispatches to `coalesce_locals_run_module_pass`. | Direct `--coalesce-locals` requests are active and covered by registry/CLI tests. |
| Presets | `src/passes/optimize_test.mbt` locks the current partial preset honesty rule around missing local-neighborhood passes. | Do not add `reorder-locals` / `coalesce-locals` late slots in isolation; preserve the Binaryen neighborhood order when the missing passes land. |
| Backlog | `agent-todo.md:392-399` keeps slice `CL` with compatibility/lifetime analysis and dual-slot rewrite work. | Treat `CL` as the active planning home before coding. |
| Local-index rewrite substrate | `src/passes/reorder_locals.mbt:118`, `:183`, and `:544` already scan and rewrite local users and rebuild declarations for a landed module pass. | Reuse the local-index and metadata-repair lessons; do not copy the exact reorder algorithm as the coalescing algorithm. |
| Later cleanup substrate | `src/passes/simplify_locals.mbt:70`, `:4126`, `:4191`, `:4245`, and `:4348` already own HOT local-traffic cleanup phases. | Let later cleanup remain a consumer; do not grow `coalesce-locals` into generic simplify-locals. |
| Core pass | `src/passes/coalesce_locals.mbt:2-5,347-574,576-850,851-1031,1032-1057` implements action scanning, value-aware interference, exact-type greedy coloring, index rewrite, redundant-copy cleanup, ineffective-write cleanup, and name-section invalidation. | Keep future changes parity-driven and add focused fixtures before changing coloring or cleanup behavior. |

## Landed direct-pass shape

The landed Starshine port is deliberately narrow:

1. collect locals, declared types, params, and synthetic zero-init facts for one function;
2. walk local uses/defs with enough liveness information to reject different-value overlap;
3. allow same-value overlap only when a local value-number proof is available;
4. require exact type equality for all locals sharing a final index;
5. allow body locals to reuse compatible param slots only when liveness proves the param slot is no longer live;
6. choose an index mapping using the Binaryen-tested greedy-order objective;
7. rewrite local indices and declarations through module-safe metadata repair;
8. delete redundant copies and dead sets only when the value/effect rules are already proven;
9. refinalize or revalidate after any dead tee / unreachable cleanup family that can change expression types;
10. compare isolated pass output first, and leave surrounding Binaryen order for separate preset/neighborhood replay.

This keeps the pass aligned with [`./binaryen-strategy.md`](./binaryen-strategy.md) and avoids two common overextensions:

- subtype-aware merging, which belongs outside default `coalesce-locals`;
- dead-store elimination, which belongs to neighboring cleanup passes unless it is the specific post-coalescing debris Binaryen removes.

## Landed first tests

The local test set is small but covers the core correctness envelope.

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

Current status before moving the direct pass into public preset slots:

1. **Unit shape tests** are green for active registration, non-overlap merging, interference negatives, redundant-copy cleanup, and dead write cleanup.
2. **Registry tests** prove `--coalesce-locals` is an active module pass with dispatcher and CLI coverage.
3. **Preset honesty tests** still keep broader locals-neighborhood scheduling separate from the direct pass.
4. **Fuzz parity** is green for `.tmp/pass-fuzz-cl-genvalid-10000-livecount` at `10000/10000` normalized matches and mixed-generator comparable cases at `.tmp/pass-fuzz-cl-mixed-1000-livecount` with zero mismatches.
5. **Artifact Starshine-side validation** is green: running Starshine `--coalesce-locals` over the rebuilt debug WASI artifact writes a validating output.
6. **Self-opt artifact compare** is canonically/function equal with Binaryen on both `.tmp/self-opt-cl-debug-livecount` and `.tmp/self-opt-cl-optimized-livecount`; the optimized-artifact direct pass timer is now faster than Binaryen (`591.437ms` vs `629.109ms`), while total wall time remains slightly above Binaryen.
7. **Neighborhood tests** for `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` remain future work once the neighboring passes exist.
8. **Reorder interaction tests** for `reorder-locals -> coalesce-locals -> reorder-locals` remain the next ordered-slot proof because local-index repair and local-name repair are observable in Starshine.

If one of those steps fails, keep the pass out of public presets even if isolated reduced tests pass.

## Health-check outcome from this run

The 2026-05-05 implementation run promoted `coalesce-locals` from removed-name planning to active direct module-pass status.
No contradiction was found between the 2026-04-22 tagged source manifest and the 2026-05-05 current-main recheck for the teaching-level `coalesce-locals` contract.
The remaining uncertainty is placement-specific: direct fuzz parity, artifact-level Binaryen comparison, and direct-pass artifact timing are green with the compatible Binaryen 128 oracle, but public preset scheduling still needs ordered-neighborhood proof.

## Sources

- [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md`](../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md)
- [`../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md`](../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
