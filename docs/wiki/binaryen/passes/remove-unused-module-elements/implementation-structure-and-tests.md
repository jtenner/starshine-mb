---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/FunctionTypeUtils.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-eh-old.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-module-elements-refs.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/remove-unused-nonfunction-module-elements_all-features.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./roots-reference-only-and-nullification.md
  - ./wat-shapes.md
---

# Upstream implementation structure and test map for `remove-unused-module-elements`

## Why this page exists

The old RUME folder had the high-level idea, but it did not have one compact page answering these practical questions together:

- which upstream files really matter
- which helpers are part of the algorithm instead of incidental utility use
- what the public sibling pass surface is
- which official lit files teach the real behavior best

This page is that file-and-test map.

## File map

| File | Why it matters | Durable lesson |
| --- | --- | --- |
| `src/passes/RemoveUnusedModuleElements.cpp` | Core implementation | The pass is a whole-module graph-and-rewrite algorithm with `used` / `usedReferenced` state and a real sibling non-function mode. |
| `src/passes/pass.cpp` | Registration and scheduler placement | Binaryen publicly exposes both `remove-unused-module-elements` and `remove-unused-nonfunction-module-elements`, and the full pass appears multiple times in the optimize pipeline. |
| `src/ir/module-utils.h` | Module traversal helpers | Roots do not come only from function bodies; module code and defined-function iteration are official parts of the algorithm. |
| `src/ir/element-utils.h` | Elem-content function rooting | Live elem segments can keep functions alive through their payloads. |
| `src/ir/gc-type-utils.h` | Heap-type reachability | `call_ref` and GC field types are real liveness edges here. |
| `src/ir/table-utils.h` | `FlatTable` support | Statically known table contents can keep functions referenced or live. |
| `src/passes/FunctionTypeUtils.cpp` | Type cleanup after function deletion | Unused function-type removal is part of the real pass behavior, not a separate unrelated cleanup. |
| `src/ir/type-updating.h` | Kind-specific weakening helpers | Some reference-only non-function elements are replaced with inert definitions instead of being removed outright. |

## The core C++ shape

`RemoveUnusedModuleElements.cpp` defines one pass class parameterized by `bool nonFunction`.
That single parameter explains the two public pass names:

- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`

The same file therefore owns both:

- the full module cleanup
- the non-function-only cleanup variant

The main state is small but conceptually important:

- `all`
- `used`
- `usedReferenced`
- `module`
- `flatTable`
- `nonFunction`

That state alone already teaches the most important point:

- Binaryen needs more than one liveness strength
- and it needs helper-backed table/type views, not just raw declaration arrays

## The still-disabled `prepare()` shortcut matters

The source still carries a disabled `prepare()` helper behind `#if 0`.
The comment says it misses things hidden inside unreachable code.

That is a real implementation lesson, not trivia.
It means the shipped `version_129` pass intentionally keeps the broader conservative scan because the narrower shortcut is not yet trustworthy enough.

A future explanation that treats the disabled prepass as the real algorithm would be misleading.

## The real helper dependency story

The important correction here is not that the pass uses many helpers.
It is **which helpers** it uses.

### Helpers that are part of the real algorithm

- `ModuleUtils::iterDefinedFunctions`
- `ModuleUtils::iterModuleCode`
- `ElementUtils::iterAllElementFunctionNames`
- `GCTypeUtils::collectHeapTypes`
- `TableUtils::FlatTable`
- `FunctionTypeUtils::removeUnusedTypes`
- `NullifyRemovableElement`

### Helpers it notably does not rely on as the core proof

The pass is **not** built around:

- CFG
- dominance
- liveness analysis in the local-variable sense
- SSA
- effect-analysis-heavy AST simplification

That absence is part of the source story.
The pass is graph-heavy, but not in the same way as a function CFG pass.

## Exact public pass surface in `pass.cpp`

`pass.cpp` explicitly registers both names:

- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`

The optimize-pipeline placement is also visible there.
That matters because the public meaning of RUME includes repeated runs, not a one-shot “final cleanup” interpretation.

## Official lit families and what they prove

The official test surface is more instructive than the pass name.

## `remove-unused-module-elements_all-features.wast`

This is the broadest surface file.
It shows that the pass really covers:

- functions
- globals
- tables
- memories
- tags
- elem segments
- data segments
- active versus passive segment users
- all-features index rewrite surfaces

A beginner reading only the pass name would not infer that much scope.

## `remove-unused-module-elements-refs.wast`

This is the most useful file for understanding why the pass needed a richer dossier.
It demonstrates the official importance of:

- `ref.func`
- `call_ref`
- heap-type reachability
- reference-only versus strong-use distinctions

If a future explanation of RUME never mentions those, it is probably too shallow.

## `remove-unused-module-elements-eh-old.wast`

This file proves that tags and old EH edges are part of the official retained surface.
The pass is not just about call/data/table cleanup.

## `remove-unused-nonfunction-module-elements_all-features.wast`

This file is the clearest proof that the sibling pass name is real and important.
It teaches the boundary:

- same graph style
- functions intentionally preserved
- non-function cleanup still applied

## What the official test files do **not** mean

The tests do **not** mean Binaryen is only interested in those exact printed module layouts.
They are teaching files for the deeper rules:

- root seeding
- strong versus reference-only reachability
- segment-parent retention
- non-function weakening
- and broad index-rewrite honesty

## Narrow source-trust rule for this dossier

This dossier is anchored on `version_129`.
The main file, scheduler registration, and the big helper surfaces above were the authoritative sources for this refresh.

The campaign work here did **not** try to prove a whole-repo current-main equivalence claim.
So the safe maintenance rule is:

- keep `version_129` as the explicit release oracle
- record any later current-main drift only in a future deliberate follow-up

## Most important implementation takeaway

The upstream implementation is not hard to understand because it is huge.
It is hard to understand because several different edge sources all feed the same graph:

- function bodies
- exports and start
- module code
- element contents
- flat tables
- heap types
- active/passive segment relations

The file-and-test map above is the shortest honest way to keep that whole story in view.
