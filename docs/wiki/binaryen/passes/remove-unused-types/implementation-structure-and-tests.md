---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./wat-shapes.md
---

# `remove-unused-types`: implementation structure and tests

This page exists because `RemoveUnusedTypes.cpp` is much smaller than the real pass contract.
If you only read the pass file, you will miss most of the behavior.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/RemoveUnusedTypes.cpp` | Thin orchestrator: gates the pass, collects public and used types, copies used private rec groups, and calls `GlobalTypeRewriter` |
| `src/passes/pass.cpp` | Registers the CLI pass name `remove-unused-types` and places it in the broader closed-world GC/type optimization neighborhood |
| `src/ir/module-utils.h` | Provides `ModuleUtils::getPublicHeapTypes`, `ModuleUtils::CodeScanner`, and `ModuleUtils::iterModuleCode`, which define what counts as public visibility and what module uses are scanned |
| `src/ir/type-updating.h` | Holds `GlobalTypeRewriter`, which performs the real heap-type graph rewrite and full-module remapping |
| `test/lit/passes/remove-unused-types.wast` | Dedicated lit surface for positive and negative module-shape cases |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `RemoveUnusedTypes::run(Module* module)`

This pass method does five things:

1. check `optimizeLevel >= 2`
2. require `closedWorld`
3. require GC features
4. collect `publicTypes`
5. collect `usedTypes`, filter out public types, build a new private type builder, and hand off to `GlobalTypeRewriter`

### 2. `ModuleUtils::getPublicHeapTypes(*module)`

This helper answers:

- which heap types are externally visible and must therefore remain stable?

That means the pass does not invent its own visibility rules.
It reuses Binaryen's shared visibility analysis.

### 3. `ModuleUtils::iterModuleCode(*module, scanner)`

This shared scanner is the reason `usedTypes` is broader than “heap types mentioned in function instructions.”
The scanner covers declaration-level and initializer-level sites too.

### 4. private builder loop in `RemoveUnusedTypes.cpp`

The pass copies whole rec groups of used private types into `Builder newTypeBuilder(*module)` in original order.
This is the exact place where the pass turns “used private type” into “keep that whole private group.”

### 5. `GlobalTypeRewriter(...).update()`

This helper rewrites the module's heap-type graph and updates all surviving uses.
It is the real reason the pass is safe and whole-module in scope.

## Why `RemoveUnusedTypes.cpp` is deceptively small

If you skim the pass file, it looks almost trivial.
That is misleading.

The source is tiny because Binaryen has already pushed the hard parts into reusable helpers:

- visibility analysis in `module-utils.h`
- module-code type scanning in `ModuleUtils::CodeScanner`
- heap-type remapping in `GlobalTypeRewriter`

So the correct teaching model is:

- `RemoveUnusedTypes.cpp` defines policy and sequence
- the helpers define most of the mechanics

## What the dedicated lit file proves

`test/lit/passes/remove-unused-types.wast` is the main shipped contract surface.
The file exercises several important families.

## 1. Unused private types can disappear

The simplest cases show that private heap types with no remaining uses are dropped from the rewritten type graph.

## 2. Public types stay even if they look locally unused

The test file includes explicit `export type` cases.
Those prove the visibility rule is real, not inferred.

## 3. Used private types keep their whole rec groups

Recursive and subtype-oriented examples show that Binaryen does not peel out only one used member and discard the rest of that rec group carelessly.

## 4. Public groups are not polluted unnecessarily

The file also checks the subtler helper rule that a live public group should not absorb unrelated rewritten private groups unless that is actually needed.

That case is one of the best reasons to read `type-updating.h` together with the test file.

## 5. The pass is a no-op when only public structure remains relevant

Some cases are really about what the pass refuses to do.
That negative surface is just as important as the positive deletions.

## There is only one dedicated lit file, so helper reading matters

Unlike some larger passes, `remove-unused-types` does not have a huge lit family roster.
That means the dedicated test file is important, but it does not teach the whole story by itself.

The missing context comes from:

- `module-utils.h` for visibility and scanning
- `type-updating.h` for the actual rewrite shape
- neighboring closed-world GC/type pass docs for scheduler meaning

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/RemoveUnusedTypes.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/remove-unused-types.wast`

Durable result:

- the checked core pass structure and dedicated lit surface still match `version_129` on the important reviewed surfaces

That is a narrow freshness note, not a proof that every helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module pass entry point, not a HOT pass
- visibility analysis for public heap types
- declaration-level plus code-level heap-type use scanning
- rec-group-aware private type retention
- whole-module heap-type rewriting and remapping

Any port that implements only the small orchestration file without helper-equivalent machinery will not match Binaryen's real behavior.

## Bottom line

For `remove-unused-types`, the real implementation structure is:

- **small pass file + shared visibility scanner + shared type rewriter + one focused lit file**

That is exactly why this pass is easy to underestimate.

## Sources

- [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/remove-unused-types.wast>
