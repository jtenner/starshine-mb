---
kind: entity
status: working
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
  - ../../../strings/string-const-surface.md
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json
  - ../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json
  - ../../../../../.artifacts/o4z-wasm-opt-debug.log
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./reuse-naming-and-ordering.md
  - ./wat-shapes.md
  - ../simplify-globals-optimizing/index.md
  - ../../../strings/string-const-surface.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
---

# `string-gathering`

## Role

- `string-gathering` is an upstream Binaryen late module / boundary-shaped cleanup pass.
- It is currently **unimplemented** in Starshine.
- In Binaryen `version_129`, it runs only when strings are enabled and the optimize level is high enough.
- Its job is very specific: hoist or reuse canonical immutable globals for `string.const` values, then replace ordinary `string.const` uses with `global.get` of those globals.

## Why it matters

- The canonical Binaryen no-DWARF `-O` / `-Os` post-pass phase runs `string-gathering` after:
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`
  - `remove-unused-module-elements`
- and before:
  - `reorder-globals`
  - `directize`
- The saved generated-artifact `-O4z` audit records one real skipped top-level upstream slot:
  - slot `54`
- The saved Binaryen debug log shows it is small but real:
  - `0.00280223` seconds in the captured generated-artifact run
- The backlog already tracks it as slice `SG` in [`../../../../../agent-todo.md`](../../../../../agent-todo.md).
- The repo’s own string-constant surface page already called this out as the next durable string follow-up after literal plumbing.

## Beginner summary

A safe beginner mental model is:

- Binaryen looks for every `string.const` in the module,
- makes sure each distinct literal has one canonical immutable string global,
- then rewrites other uses to read from that global.

That is much closer to the real pass than either:

- “lower stringref to imports”, or
- “optimize string operations”, or
- “delete duplicate globals”.

## Current durable takeaways

- `string-gathering` is a **module-wide structural rewrite**, not a function-local peephole.
- In `version_129`, the implementation lives inside `src/passes/StringLowering.cpp` as a standalone `StringGathering` pass struct.
- `StringLowering` subclasses `StringGathering` and runs it first, so this pass is also the shared first phase of full string lowering.
- The pass only rewrites `StringConst` nodes; it does not rewrite preexisting `global.get` users.
- Reusable existing globals are much narrower than many first guesses:
  - defined, not imported
  - immutable
  - exact non-null stringref type
  - direct `string.const` initializer
- Nullable, mutable, or nested users are **not** reused as canonical defining globals.
- The pass remembers exact expression-pointer locations, so replacement is a direct AST-slot rewrite rather than a second search.
- It scans function bodies in parallel and also scans module-level code, including defined global initializers and other module expression slots reached by `walkModuleCode(...)`.
- Its internal global reorder is only a validity repair: defining string globals first.
- Final global layout is intentionally left to the following `reorder-globals` pass.

## Current repo caveat

- The tracker and backlog both clearly treat `string-gathering` as a real missing late-module pass.
- But the literal name does **not** currently appear in `src/passes/optimize.mbt`’s `pass_registry_boundary_only_names()` array.
- Treat that as current repo bookkeeping debt to resolve before implementation, not as evidence that the Binaryen pass is unimportant.

That last sentence is an inference from the scheduler docs, backlog slice, and saved `-O4z` audit all agreeing that the pass matters.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: scheduler placement, phase breakdown, helper dependencies, module-code scan surface, and the real “what this is not” facts.
- [`./reuse-naming-and-ordering.md`](./reuse-naming-and-ordering.md)
  Focused guide to reusable-global detection, first-match canonicalization, generated global names, stability across repeated runs, and the validity-first reorder before `reorder-globals`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after WAT and module-shape catalog for the main positive, negative, bailout, and interaction families.

## Current maintenance rule

- Treat this folder as the canonical home for future `string-gathering` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real late module pass with the correct string scan, reuse rules, and ordering behavior.
- Keep the strategy page and the reuse/order page in sync whenever new evidence changes the answer to either:
  - “which globals can be reused?” or
  - “when must gathered globals move earlier?”

## Sources

- [`../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`](../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../../strings/string-const-surface.md`](../../../strings/string-const-surface.md)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
- [`../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/summary.json)
- [`../../../../../.artifacts/o4z-wasm-opt-debug.log`](../../../../../.artifacts/o4z-wasm-opt-debug.log)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/string-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
