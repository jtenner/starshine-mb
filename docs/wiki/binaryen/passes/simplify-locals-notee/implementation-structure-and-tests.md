---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md
  - ../../../raw/research/0329-2026-04-24-simplify-locals-notee-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0166-2026-04-21-simplify-locals-notee-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./variant-boundaries-and-registry-aliases.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../simplify-locals/index.md
  - ../simplify-locals/implementation-structure-and-tests.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
---

# `simplify-locals-notee` implementation structure and tests

Use this page with the immutable raw manifest in [`../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md`](../../../raw/binaryen/2026-04-24-simplify-locals-notee-primary-sources.md).
It records what each upstream source/test surface proves, so the rest of the dossier can stay focused on strategy and shapes.

## Owner and registration files

### `src/passes/pass.cpp`

`pass.cpp` is the public-pass registry surface.
For this dossier it proves two things:

- `simplify-locals-notee` is a public Binaryen pass name.
- The pass is registered beside the other public locals-family variants rather than hidden behind a flag on plain `simplify-locals`.

That matters locally because Starshine's currently tracked name is the alias-like removed spelling `simplify-locals-no-tee`, not the exact upstream spelling.

### `src/passes/passes.h`

`passes.h` is the factory declaration surface.
For this dossier it proves that the no-tee sibling has its own factory boundary in the public pass API:

- `createSimplifyLocalsNoTeePass()`

That factory boundary is the clean source-to-Starshine concept to preserve if the local registry is ever normalized to upstream spellings.

### `src/passes/SimplifyLocals.cpp`

`SimplifyLocals.cpp` is the only implementation owner file for this sibling.
There is no separate `SimplifyLocalsNoTee.cpp`.

The source-backed identity is:

- public pass: `simplify-locals-notee`
- factory: `createSimplifyLocalsNoTeePass()`
- shared engine instantiation: `SimplifyLocals<false, true>`
- expanded teaching identity:
  - `allowTee = false`
  - `allowStructure = true`
  - `allowNesting = true` by default

So the implementation map should always teach this pass as one point in the shared `SimplifyLocals` matrix, not as an independent rewrite algorithm.

## Main shared-engine phases proven by `SimplifyLocals.cpp`

### 1. Function-parallel local cleanup

The pass runs over functions, not over whole-module declarations.
It is part of the local traffic cleanup family and does not reorder imports, memories, globals, functions, or types.

### 2. Sinkable local-set tracking

The shared engine records candidate `local.set` values and tracks whether later motion remains safe.
For `simplify-locals-notee`, the key acceptance rule is that multi-use sinks requiring a newly introduced tee are rejected.

### 3. Linear-execution and effect-aware invalidation

The pass is not a pure textual peephole.
It uses the shared locals-family linear-execution and effect analysis surfaces to reject motion across observable hazards.

High-value safety families to preserve in any future Starshine port:

- local read/write conflicts
- global and memory effects
- calls and traps
- throwing values and EH region movement
- non-linear control-flow exits

### 4. Structure formation remains enabled

This is the most important implementation/testing point for the sibling.
Because `allowStructure = true`, the no-tee variant can still form structured results for:

- blocks
- `if` / `else`
- loops
- branch-payload exits

That is the exact source-backed reason the pass is not equivalent to `simplify-locals-notee-nostructure`.

### 5. Late equivalent-copy cleanup remains enabled

The pass still runs the shared `EquivalentSets` late optimization.
That means it can rewrite redundant gets toward a better representative local and may need refinalization when a more refined local type becomes visible.

### 6. Final dead-set cleanup remains enabled

The final unneeded-set cleanup still runs.
So the pass is not merely a structured-result pass; it can also remove local writes that become unused after earlier phases.

## Helper surfaces and what they prove

- `src/ir/linear-execution.h`
  - the pass reasons about structured linear execution rather than building a full CFG solver for this family.
- `src/ir/effects.h`
  - motion is constrained by effect summaries; the pass must not reorder observable behavior.
- `src/ir/equivalent_sets.h`
  - the late equivalent-copy phase is part of the pass contract, not an unrelated cleanup.
- `src/ir/local-utils.h`
  - local get/set utilities and final dead-local cleanup are part of the shared family implementation.
- `src/ir/branch-utils.h`
  - branch payload and block/loop exit handling participates in structured result formation.
- `src/ir/manipulation.h`
  - expression replacement and local tree rewrites use shared Binaryen manipulation helpers.

## Dedicated tests

### `test/passes/simplify-locals-notee.wast`

This is the direct human-readable proof surface for the sibling.
Read it for the visible before/after shapes that show:

- single-use sinks remain legal
- structured block / `if` results remain legal
- tee-introducing multi-use rewrites are not part of this pass
- the sibling is narrower than full `simplify-locals`, but broader than no-structure variants

### `test/passes/simplify-locals-notee.txt`

This is the paired expected-output file.
Use it to verify the concrete rewritten WAT shape instead of relying on the pass name alone.

## Nearby comparison tests

These are not substitutes for the dedicated sibling test, but they are the right comparison surfaces:

- `simplify-locals.wast` / `.txt`
  - full family behavior including tee-enabled paths
- `simplify-locals-nostructure.wast` / `.txt`
  - structure-disabled sibling that can still create tees
- `simplify-locals-notee-nostructure.wast` / `.txt`
  - no-tee and no-structure sibling
- `simplify-locals-nonesting.wast` / `.txt`
  - strongest flatness-preserving sibling with nesting disabled too

## Current-main spot-check result

A narrow 2026-04-24 current-`main` spot check found the public pass name, factory surface, and dedicated test paths still present.
This page intentionally keeps `version_129` as the detailed source oracle and does not claim whole-file semantic equivalence with current `main`.

## Starshine implication

Starshine already has a real active full `simplify-locals` HOT pass, but it does not expose this sibling mode today.
The source-backed future-port requirement is therefore not “implement another unrelated pass”; it is “parameterize or fork the local full `simplify-locals` machinery so the no-tee policy disables only fresh-tee creation while preserving structure formation, equivalent-copy cleanup, and dead-set cleanup.”

See [`./starshine-strategy.md`](./starshine-strategy.md) for the exact local code map.
