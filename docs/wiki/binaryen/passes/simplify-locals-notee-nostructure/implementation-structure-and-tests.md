---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md
  - ../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
---

# `simplify-locals-notee-nostructure` Implementation Structure And Tests

Use this page as the source-following map for Binaryen `version_129`.
The strategy page explains the algorithm; this page explains **where the contract lives** and which tests prove which part.

## Owner-file map

| Surface | Source | What it proves |
| --- | --- | --- |
| Shared engine | `src/passes/SimplifyLocals.cpp` | The pass is not a separate implementation. It is the shared locals-family walker with a stricter policy tuple. |
| Public factory | `src/passes/SimplifyLocals.cpp` | `createSimplifyLocalsNoTeeNoStructurePass()` constructs the no-tee/no-structure/default-nesting sibling. |
| Public registration | `src/passes/pass.cpp` | The public pass name is `simplify-locals-notee-nostructure`, and Binaryen describes it as locals optimizations with no tees or structure. |
| Aggressive scheduler slot | `src/passes/pass.cpp` | The pass appears in the `optimizeLevel >= 4` aggressive function prelude between `flatten` and `local-cse`, not in the ordinary no-DWARF `-O` / `-Os` top-level path. |
| Nested optimizer reuse | `src/passes/opt-utils.h` | Optimizing passes can rerun the default function pipeline on changed functions, so this aggressive sibling can reappear under high optimize settings. |
| Effect / movement legality | `src/ir/effects.h`, `src/ir/linear-execution.h`, `src/ir/properties.h` | Local sinking is protected by the shared linear-execution walker plus directional effect-ordering, trap, control, memory, table, and EH barriers. |
| Local cleanup helpers | `src/ir/local-utils.h`, `src/ir/equivalent_sets.h` | Late equivalent-get canonicalization and unneeded-set cleanup are shared helper behavior, not a separate no-tee/no-structure file. |
| Branch / control helpers | `src/ir/branch-utils.h`, `src/ir/manipulation.h` | Structure helpers and branch-sensitive repairs are available to the full family, but the no-structure flag prevents this sibling from invoking the block / `if` / loop return-creation paths. |

## The exact variant identity

The important owner-file fact is the public factory identity:

- upstream pass name: `simplify-locals-notee-nostructure`
- local Starshine removed alias today: `simplify-locals-no-tee-no-structure`
- shared engine policy: `SimplifyLocals<false, false, true>`
- `allowTee = false`
- `allowStructure = false`
- `allowNesting = true`

That last boolean is what keeps this pass distinct from `simplify-locals-nonesting`.
`notee-nostructure` may still create ordinary expression nesting by replacing an existing `local.get` consumer with the stored value.

## Test-surface map

| Test source | Direct proof | Caveat |
| --- | --- | --- |
| `test/passes/simplify-locals-notee-nostructure.wast` | Dedicated input for the public sibling. It contains the key contrast shapes for multi-use locals and structure carriers. | The file is intentionally small; many safety rules are inherited from the shared engine and neighboring variant tests. |
| `test/passes/simplify-locals-notee-nostructure.txt` | Golden output proving that a multi-use local remains explicit and structure-carrier families remain unconverted. | It does not isolate every single-use sink, EH, or equivalence cleanup family. |
| `test/passes/simplify-locals-nostructure.wast` / `.txt` | Contrast proof: the no-structure sibling can still create fresh tees where this no-tee sibling cannot. | Do not cite this as direct proof that `notee-nostructure` creates tees; it proves the opposite by contrast. |
| `test/passes/simplify-locals-notee.wast` / `.txt` | Contrast proof for the no-tee sibling that still allows structure formation. | Useful for separating “no tee” from “no structure”; not a direct scheduler proof. |
| `test/passes/simplify-locals-nonesting.wast` / `.txt` | Contrast proof for the strict no-tee/no-structure/no-nesting sibling. | Useful for the flatness boundary; not proof that `notee-nostructure` preserves flatness. |
| `test/passes/simplify-locals.wast` / `.txt` | Broad shared-engine proof for ordinary sink, structure, equivalent-copy, and dead-set families. | Full `simplify-locals` enables behavior this sibling disables, so cite it only for inherited shared helpers with the policy caveat. |
| `test/lit/passes/flatten_simplify-locals-nonesting_*` | Adjacent proof that the locals-family has flat-IR pipeline roles after `flatten`. | These files belong to the stricter `nonesting` sibling; use them as neighborhood context, not as direct `notee-nostructure` evidence. |

## What the dedicated golden proves directly

The dedicated WAT/TXT pair is enough to lock the main public-facing distinction:

- a multi-use local is **not** rewritten through a fresh `local.tee`
- arm-local and block-local carriers are **not** rebuilt as new block / `if` / loop result structure
- the pass has a real public test pair and should not be treated as an undocumented internal mode

This is the strongest beginner-facing proof for the pass name.

## What is source-backed but not isolated by the dedicated golden

Several important behaviors remain source-backed inferences from the shared template rather than direct one-file golden assertions:

- direct single-use sinking still applies
- moving across observable effects stays guarded by directional effect ordering
- `try` / `try_table` invalidates throwing pending values so catches do not change
- late equivalent-get canonicalization still runs
- final dead-set cleanup still runs
- refinalization still repairs types when a replacement exposes a refined value
- full flatness preservation is **not** guaranteed, because `allowNesting = true`

These inferences are strong because they come from the exact owner file and template instantiation.
They should still be labeled as source-backed inferences when a page contrasts direct test proof against broader shared-engine behavior.

## Current-main drift note

A narrow 2026-04-25 current-`main` spot check confirmed that the same public pass name, shared owner file, factory surface, and dedicated test paths still exist.
This page does **not** claim whole-file semantic equivalence between Binaryen `version_129` and current `main` beyond those reviewed surfaces.

## Starshine cross-check

The Starshine side has no equivalent implementation/test owner today.
The closest local code surfaces are documented in [`./starshine-strategy.md`](./starshine-strategy.md):

- `src/passes/optimize.mbt` tracks the local alias as removed
- `src/cmd/cmd.mbt` rejects removed names at the CLI pipeline layer
- `src/passes/pass_manager.mbt` dispatches only active full `simplify-locals`
- `src/passes/simplify_locals.mbt` is the likely future policy-mode landing zone but has no sibling mode yet

The companion [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) page turns that absence into a concrete validation ladder.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-25-simplify-locals-notee-nostructure-primary-sources.md)
- [`../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0333-2026-04-25-simplify-locals-notee-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md`](../../../raw/research/0129-2026-04-20-simplify-locals-notee-nostructure-binaryen-research.md)
