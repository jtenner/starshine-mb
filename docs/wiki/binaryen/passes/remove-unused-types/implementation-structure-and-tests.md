---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `remove-unused-types`: implementation structure and tests

This page exists because `RemoveUnusedTypes.cpp` is much smaller than the real pass contract.
The corrected implementation map is:

- tiny pass file,
- scheduler-side placement,
- shared type-info collection,
- shared global type rewriter,
- one focused lit file.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/RemoveUnusedTypes.cpp` | Tiny coordinator: requires GC, rejects open-world execution, and dispatches to `GlobalTypeRewriter(*module).update()` |
| `src/passes/pass.cpp` | Registers the CLI pass name `remove-unused-types` and places it in the broader closed-world GC/type optimization neighborhood |
| `src/ir/type-updating.h` | Owns `GlobalTypeRewriter`, the real algorithm for collecting used/private/public type facts, rebuilding private types, preserving public groups, and remapping the module |
| `src/ir/module-utils.h` | Supplies shared heap-type information and visibility analysis used by the type-rewriting helper |
| `test/lit/passes/remove-unused-types.wast` | Dedicated lit surface for private removal, public retention, group-rewrite, and closed-world contract cases |

## Corrected call graph

### 1. `RemoveUnusedTypes::run(Module* module)`

The pass method does three things:

1. return if the module has no GC features,
2. fatally reject `!module->closedWorld`,
3. run `GlobalTypeRewriter(*module).update()`.

The older dossier's custom scanner / private builder / whole-rec-group loop does not exist in the pass file.

### 2. `pass.cpp` registration and scheduling

`pass.cpp` registers the public pass name `remove-unused-types` with the short summary `remove unused types`.

The same file also supplies the default scheduling context.
That is where the broader optimization-level and closed-world GC-cluster placement lives.
So when teaching this pass, keep the layers separate:

- standalone pass body: correctness gates and helper dispatch,
- pass runner: whether an optimization preset includes the pass.

### 3. `GlobalTypeRewriter::update()`

This is the core implementation surface.
Its responsibilities include:

- collecting heap-type info with used-IR inclusion,
- identifying public groups,
- deriving private predecessor constraints,
- sorting surviving private types,
- rebuilding those private types through a mapper,
- preserving public groups as anchors,
- remapping type names and type indices,
- rewriting all surviving module type uses.

### 4. `module-utils.h`

The helper reading still matters, but not in the older pass-local way.
`module-utils.h` provides the shared type-info and visibility machinery that lets `GlobalTypeRewriter` know which heap types are used by IR and which type groups are public.

## Why the owner file is deceptively small

`RemoveUnusedTypes.cpp` looks almost trivial because Binaryen has factored the hard work into reusable type-rewriting infrastructure.

That is important for future Starshine work:

- implementing only a small pass wrapper would not be enough,
- a faithful port needs a reusable module-wide type-graph rewrite surface.

## What the dedicated lit file proves

`test/lit/passes/remove-unused-types.wast` is the shipped contract surface.
The file exercises several important families.

### 1. Private unused types can disappear

Private heap types with no remaining use in the module can be dropped from the rewritten type graph.

### 2. Used private types stay and are remapped

A private heap type that still appears in an IR-facing type position survives, but it may move into the new private group layout.
The important proof is semantic use preservation, not old type-index or old-rec-group preservation.

### 3. Public groups stay anchored

The test surface includes public/exported type cases.
Those prove public visibility is a real boundary.

### 4. Old private group boundaries can change

The corrected helper behavior means the pass may rebuild private survivors into a fresh group rather than preserving old private rec-group boundaries wholesale.
The lit file is the best compact proof that `remove-unused-types` is a type-graph rewrite pass, not just a text deletion pass.

### 5. Closed-world usage matters

Open-world execution is not the supported context for this pass.
Default scheduling reaches it only in a closed-world GC/type optimization neighborhood, and explicit pass execution must respect that constraint.

## There is only one dedicated lit file, so helper reading matters

Unlike larger passes, `remove-unused-types` does not have a large lit family roster.
That means the dedicated test file is important, but it cannot teach the entire implementation alone.

The missing context comes from:

- `type-updating.h` for `GlobalTypeRewriter`,
- `module-utils.h` for type-info / visibility collection,
- neighboring closed-world GC/type pass docs for scheduler meaning.

## Freshness note

A narrow 2026-04-24 current-`main` check on:

- `src/passes/RemoveUnusedTypes.cpp`,
- `src/passes/pass.cpp`,
- `src/ir/type-updating.h`,
- `src/ir/module-utils.h`,
- `test/lit/passes/remove-unused-types.wast`,

found no teaching-relevant drift from the corrected `version_129` story.
This is intentionally narrow.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- boundary-only-to-module-pass registry transition,
- closed-world and GC feature gates,
- public type/group discovery,
- used private heap-type discovery across declarations and code,
- private predecessor graph from private supertypes and described-type dependencies,
- deterministic private survivor ordering,
- fresh private type-group rebuilding,
- module-wide type-use remapping,
- post-rewrite validation.

Any port that implements only the tiny `RemoveUnusedTypes.cpp` wrapper without `GlobalTypeRewriter`-equivalent machinery will not match Binaryen.

## Bottom line

For `remove-unused-types`, the real implementation structure is:

- **tiny pass file + scheduler placement + shared type-info collection + `GlobalTypeRewriter` + one focused lit file**.

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for the corrected file map: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
