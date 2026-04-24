---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md
  - ../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./dfa-partitions-casts-and-refinalization.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Upstream implementation structure and test map for `type-merging`

Use this page with the 2026-04-24 raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md).
The manifest is the immutable source list; this page is the teaching map.

## Why this page exists

`type-merging` is easy to misunderstand if you look only at its public pass name.
This page maps the actual upstream source surface that defines the pass contract.

## File map

| File | Why it matters | What it proves |
| --- | --- | --- |
| `src/passes/TypeMerging.cpp` | Core implementation | The real pass: closed-world+GC gates, cast scanning, private-type candidate pool, supertype-vs-sibling partitioning, DFA refinement, descriptor-chain handling, `TypeMapper` rewrite, and post-merge `ReFinalize`. |
| `src/passes/pass.cpp` | Public registration | `type-merging` is a real public Binaryen pass with a stable CLI name and a tiny public description. |
| `src/wasm-type-ordering.h` | Ancestor ordering helper | The pass's target-choice and partition seeding are deliberately supertype-first rather than arbitrary set iteration. |
| `src/support/dfa_minimization.h` | Partition-refinement engine | The pass's equivalence proof is a generic DFA partition minimizer, not an ad hoc loop over local type syntax. |
| `src/ir/module-utils.h` | Module helper surface | `ModuleUtils::getPrivateHeapTypes` defines the candidate pool and visibility boundary. |
| `src/ir/type-updating.h` | Post-merge typing repair context | Helps explain why `ReFinalize` and whole-module type updating are part of the correctness story after graph rewrites. |
| `test/lit/passes/type-merging.wast` | Dedicated official lit surface | The main positive, bailout, regression, and known-limitation contract for the pass. |

## Public registration facts from `pass.cpp`

The reviewed registration lines show:

- `type-merging`
- description: `merge types to their supertypes where possible`

That description is intentionally small.
The implementation file is what expands it into the real contract.

## Freshness check against current `main`

I did a narrow current-`main` spot check and recorded it in the 2026-04-24 raw primary-source manifest.

### `TypeMerging.cpp`

The checked diff from `version_129` to current `main` on the reviewed surface is only:

- a comment typo fix (`differentiatable` -> `differentiable`)

No reviewed algorithmic drift appeared in that diff.

### `pass.cpp`

Current `main` still registers `type-merging` under the same public name.

### `type-merging.wast`

Current `main` still ships the dedicated lit file and its leading run line matches the reviewed `version_129` surface.

So `version_129` is a safe source oracle for this dossier.

## What the dedicated lit file proves

The official `type-merging.wast` file is large and unusually valuable.
It proves much more than a toy happy path.

## Section group 1: direct supertype merges and obvious blockers

Early modules prove that Binaryen can merge a subtype into its parent when the subtype:

- adds no fields
- does not refine nullability or heap type
- is not final/open-shape incompatible
- is not protected by a cast

The same early modules also prove the most important blockers:

- extra fields
- nullability refinement
- heap-type refinement
- finality differences
- cast observability

## Section group 2: multi-level and recursive chain collapse

The next modules show:

- multiple levels can collapse transitively
- recursive subtype chains can merge
- mutually recursive chains can merge as pairs or collapse further into a single type

These tests are the clearest evidence that the implementation really is graph-aware, not just local-parent-aware.

## Section group 3: child-type convergence

Several mid-file modules prove that a parent merge can become legal only after child types also merge.

This is exactly the family that justifies the DFA partition-refinement algorithm.
A shallow textual comparer would miss these cases.

## Section group 4: root-type variety

The file explicitly covers more than structs.
It includes:

- arrays
- function heap types
- mixed field/reference shapes
- tuple-bearing signature structure

So the pass is a general heap-type-graph pass, not a structs-only cleanup.

## Section group 5: public/private visibility

The public-type module proves a central boundary:

- public types are preserved as identities
- private descendants may merge into them

That module is especially useful for beginners because it separates “structural equality” from “allowed to merge.”

## Section group 6: refinalization and exact-LUB repair

The later modules explicitly exercise cases where merging changes expression typing, including exact-result `select` behavior.

These sections prove that:

- post-merge typing repair is part of the pass contract
- `ReFinalize` is not optional polish

## Section group 7: cast and exactness barriers

The later tests also explicitly check that merging is inhibited by:

- `ref.test`
- `br_on_cast`
- `call_indirect`
- exact-cast-sensitive families from earlier modules

That confirms the `CastFinder` surfaces are not accidental implementation details; they are part of the tested public contract.

## Section group 8: known upstream limitation

One dedicated lit section contains an upstream TODO noting that a certain private-under-public merge should be possible but is not currently found because the pass does not encode successors of public DFA states.

That section is valuable because it turns a surprising non-merge into an explicit upstream limitation rather than a documentation bug.

## Section group 9: historical regression coverage

The later file portions also include regressions for:

- merging in the wrong direction
- incorrect supertype ordering after type updates
- unsound single-step supertype+sibling merging
- missing refinalization after LUB sharpening

These regressions are the best evidence for the trickiest implementation rules.

## Practical takeaway from the source map

If you want the shortest high-confidence ownership map:

- `TypeMerging.cpp` defines the algorithm
- `pass.cpp` proves the public pass name
- `wasm-type-ordering.h` explains safe ancestor-first ordering
- `dfa_minimization.h` explains why the pass can solve recursive equivalence precisely
- `module-utils.h` explains the private-type candidate boundary
- `type-merging.wast` proves both the happy paths and the real corner cases

## Sources

- [`../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-merging-primary-sources.md)
- [`../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md`](../../../raw/research/0294-2026-04-24-type-merging-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md`](../../../raw/research/0181-2026-04-21-type-merging-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeMerging.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/wasm-type-ordering.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/support/dfa_minimization.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-merging.wast>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast>
