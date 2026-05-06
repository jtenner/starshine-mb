---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md
  - ../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md
  - ../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../src/validate/env.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./ordering-cost-model-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-types/index.md
  - ../minimize-rec-groups/index.md
  - ../reorder-globals/index.md
---

# `reorder-types`: Starshine port-readiness and validation

## Why this page exists

The rest of the `reorder-types` dossier explains the upstream contract.
This page answers the planning question: **what should Starshine prove first if a real port ever begins?**

The short answer is: keep registry honesty first, then prove a tiny closed-world private-type reorder, then expand the rewrite surface only after validation catches every stale type-index-bearing field.

## Current local status to preserve

Starshine currently keeps `reorder-types` boundary-only.
That is not a partial implementation:

- `src/passes/optimize.mbt` lists `reorder-types` in the boundary-only registry set
- the same file rejects requested boundary-only passes before execution
- `src/passes/pass_manager.mbt` has no `reorder-types` module-pass case
- no `src/passes/reorder_types.mbt` owner file exists
- `agent-todo.md` has no active dedicated `reorder-types` slice today

A first port decision should make that status deliberate instead of accidental.
It can stay boundary-only, become an explicit module pass, or remain future work, but it should not silently imply partial support.

## Reusable local surfaces

A future module pass would need the following Starshine surfaces to stay coherent:

| Need | Current local surface | Port implication |
| --- | --- | --- |
| Pass registration / rejection | `src/passes/optimize.mbt` | boundary-only honesty or active module-pass entry |
| Module-pass dispatch | `src/passes/pass_manager.mbt` | a new `reorder-types` case |
| Closed-world option plumbing | `src/cli/cli.mbt`, `src/cmd/cmd.mbt` | exact `--closed-world` gating |
| Heap-type model | `src/lib/types.mbt` | `TypeIdx`, `RecType`, `SubType`, and type metadata rewrite surfaces |
| WAT lowering | `src/wast/lower_to_lib.mbt` | fixture coverage for rec groups, descriptor immediates, and type-bearing instructions |
| Validation | `src/validate/env.mbt`, `src/validate/typecheck.mbt` | stale-type-index detection after rewrite |
| Binary roundtrip | `src/binary/encode.mbt`, `src/binary/decode.mbt` | type-index remap and preserved metadata checks |

These are prerequisites, not a port.

## First-slice order

1. **Registry honesty**
   - keep `reorder-types` boundary-only until a real module pass exists, or add a deliberate active entry when implementation starts

2. **Candidate collector**
   - build a tiny closed-world GC-gated collector for used heap types and visibility
   - freeze public types immediately
   - keep private-only candidates separate from any future cleanup passes

3. **Private-only reorder prototype**
   - implement one reorder on a small module fixture
   - preserve the exact upstream legality edges: private supertypes and private described types

4. **Module-wide rewrite**
   - update type-bearing module surfaces in one pass
   - keep type names and preserved index metadata coherent

5. **Validation and parity**
   - binary roundtrip the rewritten module
   - compare the supported subset against Binaryen `reorder-types`

## Validation checklist

For every active slice, require:

- GC gate rejection when GC is unavailable
- `--closed-world` rejection or requirement enforcement
- public-type freeze negatives
- private-only reorder positives
- stable remap of function signatures, locals, tables, element types, globals, tags, and descriptor immediates
- preserved type-name / index metadata after rewrite
- binary roundtrip after rewrite
- Binaryen oracle comparison on the supported subset

## Main non-goals for the first local port

- Do not treat `reorder-types` as a HOT peephole
- Do not merge it into `remove-unused-types`
- Do not collapse it into `minimize-rec-groups`
- Do not skip the full rewrite surface after only changing the type section

## Cross-links

- [`./starshine-strategy.md`](./starshine-strategy.md) for the current local status and exact code map
- [`./binaryen-strategy.md`](./binaryen-strategy.md) for the upstream `version_129` and current-main contract
- [`./ordering-cost-model-and-boundaries.md`](./ordering-cost-model-and-boundaries.md) for the legality and cost model details
- [`./wat-shapes.md`](./wat-shapes.md) for concrete before/after type-layout shapes
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the owner-file and lit-test map

Neighboring pass pages:

- [`../remove-unused-types/index.md`](../remove-unused-types/index.md)
- [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md)
- [`../reorder-globals/index.md`](../reorder-globals/index.md)

## Sources

- [`../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-reorder-types-current-main-recheck.md)
- [`../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md`](../../../raw/research/0492-2026-05-05-reorder-types-port-readiness-and-validation.md)
- [`../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-reorder-types-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-reorder-types-primary-sources.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/cli/cli.mbt`](../../../../../src/cli/cli.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../src/lib/types.mbt`](../../../../../src/lib/types.mbt)
- [`../../../../../src/wast/lower_to_lib.mbt`](../../../../../src/wast/lower_to_lib.mbt)
- [`../../../../../src/validate/env.mbt`](../../../../../src/validate/env.mbt)
- [`../../../../../src/validate/typecheck.mbt`](../../../../../src/validate/typecheck.mbt)
- [`../../../../../src/binary/encode.mbt`](../../../../../src/binary/encode.mbt)
- [`../../../../../src/binary/decode.mbt`](../../../../../src/binary/decode.mbt)
