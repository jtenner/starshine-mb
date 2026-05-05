---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/research/0458-2026-05-05-remove-unused-non-function-elements-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-module-elements/binaryen-strategy.md
---

# Binaryen `remove-unused-nonfunction-module-elements` strategy

## Upstream source rule

Use Binaryen `version_129` as the canonical contract oracle for this sibling pass.
The 2026-05-05 current-main recheck found no teaching-relevant drift on the reviewed surfaces, so the `version_129` reading remains the right durable anchor.

Primary source files:

- `src/passes/RemoveUnusedModuleElements.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `src/ir/module-utils.h`
- the shipped `remove-unused-nonfunction-module-elements_all-features.wast` fixture
- the shared `remove-unused-module-elements*` lit files that prove inherited behavior

This page is algorithm-oriented.
Use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the exact file map and test inventory, and use [`./shared-engine-rooting-and-defined-vs-imported-functions.md`](./shared-engine-rooting-and-defined-vs-imported-functions.md) for the trickiest semantic split.

## High-level intent

Binaryen exposes `remove-unused-nonfunction-module-elements` as a **sibling mode** on the same `RemoveUnusedModuleElements.cpp` engine used by full `remove-unused-module-elements`.
It is not a separate algorithm.

The meaningful difference is one policy step:

- root every **defined** function up front
- then run the ordinary module-element liveness and rewrite pipeline

Everything else stays shared.
That includes exports, start, module-code roots, imported-parent active segments, TNH behavior, cleanup ordering, and module index rewriting.

## The pass in one table

| Stage | What Binaryen does | Why it matters |
| --- | --- | --- |
| Shared engine setup | construct `RemoveUnusedModuleElements` with `rootAllFunctions = true` | the sibling is a mode bit, not a new pass family |
| Defined-function root seeding | iterate defined functions and add them to the root set | dead helper bodies survive even when nothing else reaches them |
| Ordinary root scan | collect exports, start, globals, tables, memories, tags, elem, and data roots | the pass still has full module reachability semantics |
| Queue fixpoint | process newly strong-used elements until no new edges appear | liveness is still graph-shaped, not a one-pass filter |
| Rewrite and cleanup | remove or weaken dead module structure, remap surviving indices, compact function types | the sibling still performs real module cleanup |

## The one policy toggle that matters

The shared owner file keeps both public pass names behind one constructor flag:

- full RUME uses `rootAllFunctions = false`
- the sibling uses `rootAllFunctions = true`

That flag is the whole story for the public contract split.
If you miss it, the two pass names look far more similar than they are.

## What still counts as live

The sibling still inherits the normal RUME roots:

- exports
- start section reachability
- active imported-parent segments
- module-code expressions such as global initializers and active segment offsets
- ordinary strong users discovered during the body scan

So the sibling is not a blanket “keep every function-related thing forever” pass.
It is more precise than that.

## What the sibling adds

The sibling adds one extra root class:

- all **defined** functions

That is why dead helper bodies survive, but dead imported functions may still disappear.
Binaryen deliberately does **not** force imported functions live through the sibling policy.

## What the sibling still removes

The pass still removes or weakens ordinary dead module structure, including:

- memories
- tables
- globals
- tags
- element segments
- data segments
- unused function types after function cleanup

It also still allows no-op start metadata removal when the start body itself remains valid.

## Key edge cases

### Dead defined helper chain stays

A reachable-or-not defined helper chain can survive unchanged under the sibling policy.
That is the visible effect of the root-all step.

### Dead imported function can still disappear

Imported functions are not force-rooted by the sibling toggle.
If nothing else uses them, the shared analyzer can still prune them.

### Startup-visible parents still matter

Active element and data segments can still keep their parent table or memory alive when the segment is meaningfully observable.
The sibling inherits that shared retention rule.

### TNH and no-op-start behavior are unchanged

The sibling still follows the same startup-trap and no-op-start cleanup logic as full RUME.
That is one reason the dedicated fixture is not enough on its own: shared lit files still matter.

## Validation contract

The source-backed validation split is:

1. the dedicated sibling fixture proves the public sibling mode
2. the shared `remove-unused-module-elements*` fixtures prove inherited RUME behavior
3. the local Starshine port should compare against `--remove-unused-nonfunction-module-elements`, not against full RUME, except when the sibling split itself is the test subject

## Bottom line

Binaryen's contract is small but exact:

- same shared module-element pruner as full RUME
- one `rootAllFunctions` mode bit
- root all defined functions
- keep ordinary reachability and rewrite behavior intact
- still allow dead imported functions and dead non-function module structure to disappear
