---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
related:
  - ./binaryen-strategy.md
  - ./identity-and-rewrite-surface.md
  - ./wat-shapes.md
  - ../inlining-optimizing/index.md
  - ../simplify-globals-optimizing/index.md
  - ../remove-unused-module-elements/index.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `duplicate-import-elimination`

## Role

- `duplicate-import-elimination` is an upstream Binaryen late module / boundary cleanup pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- Binaryen runs it as a very late alias-collapse step, after the late boundary/callgraph passes and before the final global/string/layout cleanup cluster.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `duplicate-import-elimination` after the second `duplicate-function-elimination` and before `simplify-globals-optimizing`.
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - top-level slot `51`
- The saved Binaryen debug log shows the pass is small but real:
  - `2.133e-05` seconds in the captured generated-artifact run
- The backlog already tracks this as slice `DIE` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- It is the first still-missing late no-DWARF tail dossier after the freshly documented neighboring passes:
  - `inlining-optimizing`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
  - `string-gathering`
  - `reorder-globals`
  - `directize`

## Beginner summary

A safe beginner mental model is:

- if the module imported the **same host object** more than once under different internal names,
- Binaryen keeps the first imported name,
- rewrites later users to point at that first name,
- then deletes the redundant import declarations.

That is much closer to the real Binaryen pass than either:

- “remove unused imports”, or
- “merge duplicate imported functions only.”

## Current durable takeaways

- `duplicate-import-elimination` is a **module / boundary** pass, not a function-local peephole.
- The pass is **structural**, not usage-based:
  - no effects
  - no CFG reasoning
  - no liveness
  - no profitability loop
  - no nested reruns
- In `version_129`, it only deduplicates these imported kinds:
  - functions
  - globals
  - tables
  - memories
- It does **not** deduplicate imported tags in the current source, even though the shared import metadata helpers already know how to describe tag imports.
- The pass picks the **first import seen** for an identity class and redirects later aliases to it.
- User rewrites are wider than many first guesses:
  - direct `call`
  - `ref.func`
  - start function name
  - exports
  - `global.get` / `global.set`
  - bulk table ops
  - bulk memory ops
  - module-level init expressions walked through `runOnModuleCode(...)`
- The pass deletes the redundant imports immediately after retargeting users.
- A future Starshine port must preserve the exact import-identity key and full rewrite surface, not replace the pass with dead-import pruning.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, one-sweep algorithm, helper dependencies, kind coverage, and the key “what this is not” facts.
- [`./identity-and-rewrite-surface.md`](./identity-and-rewrite-surface.md)
  Focused guide to the import identity key, first-import-wins canonicalization, exact per-kind user rewrite surface, and the most important source-level caveats.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the main positive, negative, bailout, and interaction families.

## Current maintenance rule

- Treat this folder as the canonical home for future `duplicate-import-elimination` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real late module pass with the correct identity key and user-remap surface.
- New findings should update both the strategy page and the identity/rewrite-surface page so the “which imports are equal?” story stays aligned with the “which users get rewritten?” story.

## Sources

- [`../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md`](../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateImportElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/import-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-import-elimination.wast>
