---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md
  - ../../../raw/research/0400-2026-04-26-precompute-port-readiness.md
  - ../../../raw/binaryen/2026-04-22-precompute-primary-sources.md
  - ../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md
  - ../../../../../src/passes/precompute.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/precompute_test.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./propagation-partial-precompute-and-gc-identity.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
  - ../precompute-propagate/index.md
---

# Starshine `precompute` port readiness and validation

This page is the implementation-readiness bridge for Starshine's active `precompute` pass. It does **not** claim that Starshine already implements the full Binaryen `Precompute.cpp` engine. It explains what is implemented, what to validate, and how to extend the pass without confusing Starshine's HOT cleanup subset with Binaryen's interpreter-driven strategy.

## Current local contract

Starshine `precompute` is an active HOT pass with a narrow, practical contract:

- fold exact trap-free i32/i64 unary and binary expressions;
- fold exact i32/i64 comparisons to i32 booleans;
- replace immutable defined `global.get` values with constants or `ref.null` where the module context can prove the initializer;
- choose constant `if` arms and rebuild the chosen root shape;
- remove pure dropped values and clean up `nop` residue that would otherwise make HOT writeback harder;
- validate suspicious lowered output before committing it back to the module.

That contract is source-backed by [`src/passes/precompute.mbt:1-1158`](../../../../../src/passes/precompute.mbt), [`src/passes/pass_manager.mbt:8185-8484`](../../../../../src/passes/pass_manager.mbt), and the proof lanes in [`src/passes/precompute_test.mbt:1-342`](../../../../../src/passes/precompute_test.mbt).

## What Binaryen does that Starshine does not yet do

Binaryen's plain `precompute` is much broader than the current Starshine pass. The source dossier records these upstream responsibilities:

- bounded compile-time execution via the `ConstantExpressionRunner` / interpreter family;
- `Flow`-aware handling of values, breaks, and returns;
- child-retention for local/global writes encountered during speculative computation;
- emitability checks separate from “we know the value”; 
- partial precompute through parent shapes such as selected `select` arms;
- GC identity caching for immutable object reasoning;
- final refinalization after type-affecting rewrites.

Starshine should keep those gaps explicit. The local pass is currently a HOT fold-and-cleanup fixpoint, not a miniature Binaryen interpreter.

## Safe next-slice order

### 1. Keep registry and preset behavior stable

Before changing rewrite semantics, keep these public surfaces green:

- [`src/passes/optimize.mbt:207-215`](../../../../../src/passes/optimize.mbt) registers the active `precompute` hot pass.
- [`src/passes/optimize.mbt:254-276`](../../../../../src/passes/optimize.mbt) and [`src/passes/optimize.mbt:394-417`](../../../../../src/passes/optimize.mbt) keep two `precompute` slots in both optimize and shrink presets.
- [`src/passes/registry_test.mbt:110-166`](../../../../../src/passes/registry_test.mbt) and [`src/passes/optimize_test.mbt:290-334`](../../../../../src/passes/optimize_test.mbt) prove those user-visible placements.

### 2. Prefer small trap-free scalar or module-constant additions

The cheapest safe extensions are still direct, trap-free shapes adjacent to what the pass already handles:

- additional integer bit operations with exact wasm wraparound semantics;
- more comparisons when both operands are exact constants;
- immutable-global literal families already representable in HOT;
- pure cleanup cases that preserve every side effect and trap.

Each new family should add a focused `src/passes/precompute_test.mbt` case before implementation and should avoid divisions, remainders, loads, atomics, or heap/object reads unless a stronger semantics proof exists.

### 3. Treat float, string, GC, and interpreter-like work as separate slices

Do not smuggle the larger Binaryen contract into a small fold patch. These families need dedicated design and oracle tests:

- floating point folding, especially NaN payload and signed-zero behavior;
- `StringConst` and string helper surfaces;
- immutable GC field/array reads and object identity;
- partial parent precompute through `select` or other value-carrying control;
- local-flow propagation, which belongs closer to the separate upstream `precompute-propagate` contract.

### 4. Keep writeback validation in scope

For this pass, correctness is not only “the fold result is right.” Old generated-artifact failures were caused by invalid lowered/writeback shapes. The current guard surfaces are part of the pass contract:

- [`src/passes/pass_manager.mbt:8185-8299`](../../../../../src/passes/pass_manager.mbt) validates precompute writeback and emits `skip-invalid-lower` reasons.
- [`src/passes/pass_manager.mbt:8310-8484`](../../../../../src/passes/pass_manager.mbt) detects the escape-carrier block shapes that made older precompute-adjacent rewrites unsafe.
- [`src/cmd/cmd_wbtest.mbt:6778-7101`](../../../../../src/cmd/cmd_wbtest.mbt) preserves artifact replay coverage for generated `-O4z` precompute witnesses.

Any new structural rewrite should preserve these guard rails and add a validation-facing test when it changes root/control shape.

## Validation ladder

Use this order for future work:

1. Add or update a focused `src/passes/precompute_test.mbt` case for the exact before/after shape.
2. Confirm registry and preset tests still pass if the user-visible summary or pass placement changes.
3. Compare the new family against Binaryen with pass-targeted fuzzing where possible: `bun fuzz compare-pass --pass precompute ...` or the repository's equivalent pass-fuzz command.
4. For control/root-shape rewrites, run full-module validation and keep the `skip-invalid-lower` trace negative unless the test intentionally proves a skip.
5. For artifact-sensitive changes, replay the existing `src/cmd/cmd_wbtest.mbt` lanes before claiming parity improvement.

## Beginner-to-advanced before/after map

| Shape | Starshine today | Binaryen parity note |
| --- | --- | --- |
| `i32.const a; i32.const b; i32.add` | Folds to one i32 const when both operands are exact. | Matches the easy arithmetic subset, not the full interpreter model. |
| `i32.const a; i32.const b; i32.div_s` | Preserved. | Correctly avoids trap-sensitive folding. |
| immutable defined `global.get` | Replaced with literal i32/i64/f32/f64/ref-null constants; `StringConst` is rejected. | Binaryen's emitability and string/GC behavior is broader and subtler. |
| constant void/result `if` | Chooses the surviving arm, emits `nop`, a root, or a rebuilt block. | Related to but narrower than Binaryen's flow-aware computation. |
| `drop(pure-value)` | Replaced with `nop` or spliced away when the value is side-effect-free and nontrapping. | Local HOT cleanup, not the full Binaryen child-retention algorithm. |
| `select` partial precompute | Not implemented. | Binaryen has a source-backed partial-precompute path. |
| local-flow propagation | Not implemented in `precompute`; local sibling `precompute-propagate` is removed today. | Binaryen's `precompute-propagate` uses `LazyLocalGraph` and a rerun. |
| GC/string/atomic reads | Mostly not implemented. | Upstream has drift and special-case safety fixes; treat as a dedicated future design. |

## Open decisions

- Whether Starshine should grow a shared interpreter/constant-flow abstraction or keep `precompute` as a pragmatic HOT peephole-plus-cleanup pass.
- Whether future `precompute-propagate` work should be a separate pass from the start, matching the current local removed registry entry, or should first share helper analysis with plain `precompute`.
- When the wiki should update its baseline from Binaryen `version_129` to a newer upstream release. Until that happens, current-main drift should stay labeled rather than silently changing the taught contract.

## Sources

- [`../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-precompute-current-main-port-readiness.md)
- [`../../../raw/research/0400-2026-04-26-precompute-port-readiness.md`](../../../raw/research/0400-2026-04-26-precompute-port-readiness.md)
- [`../../../raw/binaryen/2026-04-22-precompute-primary-sources.md`](../../../raw/binaryen/2026-04-22-precompute-primary-sources.md)
- [`../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md`](../../../raw/research/0251-2026-04-22-precompute-primary-sources-and-code-map-followup.md)
- [`../../../../../src/passes/precompute.mbt`](../../../../../src/passes/precompute.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/precompute_test.mbt`](../../../../../src/passes/precompute_test.mbt)
