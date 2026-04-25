---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md
  - ../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0115-2026-04-20-code-pushing-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/code_pushing.mbt
  - ../../../../../src/passes/code_pushing_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./segment-selection-and-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../late-pipeline-dispatch.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
supersedes:
  - ../../../raw/research/0258-2026-04-22-code-pushing-primary-sources-and-starshine-followup.md
---

# `code-pushing`

## Role

`code-pushing` is an upstream Binaryen function pass and an active explicit HOT pass in Starshine.

Its purpose is to move work later in structured code when doing so preserves execution and ordering.
The corrected source-backed Binaryen mental model is:

- scan block root order,
- handle a one-unreachable-arm `if` sinking family,
- otherwise try local sibling-root movement before a later use,
- let a movement-safety predicate decide whether intervening expressions can be crossed.

The current Starshine implementation is a conservative subset:

- const-like `local.set` sinking into the single `if` arm that contains all reads of that local,
- plus one Starshine-local typed/dead-block flattening helper near unreachable context.

## 2026-04-25 correction

This folder previously over-taught Binaryen `code-pushing` as if `version_129` used:

- `BranchSeeker`,
- `Pusher`,
- generic target-segment sinking,
- local `benefit > cost` profitability,
- and general two-live-arm `if` duplication.

A fresh official-source check found those claims unsupported by the reviewed `CodePushing.cpp`.
The corrected source map is now captured in:

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)

The older raw and research files remain as historical provenance, but current teaching should prefer the 2026-04-25 correction.

## Why it matters

- Binaryen schedules `code-pushing` in the canonical no-DWARF function pipeline between `precompute` and the tuple/local-cleanup neighborhood.
- The saved generated-artifact `-O4z` audit recorded it as top-level skipped slot `20` before Starshine grew the current direct subset.
- Starshine's `tuple-optimization` exact-slot story still depends on this pass and `simplify-locals-nostructure` being represented honestly.
- The pass is easy to over-broaden. Correctness depends on movement safety, trap policy, reference use, and refinalization.

## Inputs and outputs

### Upstream Binaryen input shape

- Function-local structured expression trees.
- Block child order with expression refs available.
- Optimization options that affect trap handling.

### Upstream Binaryen output shape

- Some block roots move later in the same block or into a reachable `if` arm.
- The moved expression should execute on the same paths where Binaryen proves execution is preserved.
- Affected expressions are refinalized.

### Current Starshine input shape

- HOT functions lifted into `HotFunc`.
- Region roots containing local writes, structured `if`s, blocks, and unreachable roots.

### Current Starshine output shape

- Narrow single-consuming-arm local-set sinks become `nop` at the original root plus a cloned `local.set` inside the target arm.
- Some typed/dead block roots near unreachable context are spliced into the parent region.
- Unmatched shapes stay unchanged.

## Invariants and correctness constraints

- Do not move work across effects or trap-sensitive barriers unless the pass explicitly models the option-sensitive rule.
- Do not strand a later use after moving work into only one arm.
- Do not duplicate into both live arms just because a value is pure; that is not the corrected source-backed baseline.
- Preserve function validity after structural mutation.
- Keep Starshine-local dead-block flattening documented separately from upstream Binaryen behavior.
- Do not claim public preset parity until the exact scheduler neighborhood is implemented and validated.

## Notable edge cases

- One `if` arm unreachable: upstream Binaryen's distinctive positive family.
- Both `if` arms reachable and both use a value: now documented as a no-assumption / bailout family unless a source/test proves otherwise.
- Trap-capable expressions: option-sensitive upstream, guarded out by current Starshine's const-like subset.
- GC/reference operations: can participate upstream under movement-safety rules, but current Starshine has no broad parity.
- EH: bailout-rich and should stay covered by focused tests before local widening.
- Starshine dead-block flattening: useful local cleanup, but not an upstream `CodePushing.cpp` claim.

## Validation

For current docs-only maintenance:

- keep the source correction linked from this page, the strategy pages, indexes, tracker, and log;
- search for stale `BranchSeeker`, `Pusher`, `benefit > cost`, two-arm duplication, and “no transform yet” wording in this folder.

For future code work:

1. add focused tests in `src/passes/code_pushing_test.mbt` before widening behavior;
2. validate direct pass execution through `src/passes/registry_test.mbt` and command/native surfaces;
3. compare against Binaryen on reduced WAT families first;
4. then run pass-fuzz / artifact comparisons for the `CP` backlog slice;
5. only after that revisit preset placement.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Corrected source-backed Binaryen strategy: `visitBlock`, `optimizeIntoIf`, `canPushThrough`, `tryPush`, and the removed stale helper/profitability claims.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - Upstream owner-file and lit-test map for the corrected strategy.
- [`./segment-selection-and-barriers.md`](./segment-selection-and-barriers.md)
  - Movement-safety guide centered on one-unreachable-arm `if` sinking, sibling-root pushing, trap/effect/GC/EH barriers, and Starshine-local dead-block flattening.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly before/after and bailout shape catalog, including current Starshine positive and negative families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Exact local code map and remaining `CP` parity plan.

## Sources

- [`../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/binaryen/2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md`](../../../raw/research/0345-2026-04-25-code-pushing-source-correction-and-local-status.md)
- [`../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md`](../../../raw/binaryen/2026-04-22-code-pushing-primary-sources.md)
- [`../../../../../src/passes/code_pushing.mbt`](../../../../../src/passes/code_pushing.mbt)
- [`../../../../../src/passes/code_pushing_test.mbt`](../../../../../src/passes/code_pushing_test.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- Binaryen `version_129` `CodePushing.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CodePushing.cpp>
