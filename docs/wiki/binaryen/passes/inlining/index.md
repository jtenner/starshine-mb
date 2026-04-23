---
kind: entity
status: working
last_reviewed: 2026-04-23
sources:
  - ../../../raw/binaryen/2026-04-23-inlining-primary-sources.md
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
  - ../../../raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining-optimizing/index.md
  - ../dae-optimizing/index.md
  - ../duplicate-function-elimination/index.md
  - ../tracker.md
---

# `inlining`

## Role

- `inlining` is an upstream Binaryen boundary/module pass.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The pass shares its upstream implementation file with [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md).
- The key semantic split is simple but important:
  - `inlining` runs the inline planner, splitter, rewrite, cleanup, and post-inline repair only
  - `inlining-optimizing` runs that same engine **plus** a nested `precompute-propagate` + default function-optimization rerun on changed functions

## Why this pass matters

- The original campaign queue is closed, so this dossier is an explicit tracker expansion rather than a leftover parity stub.
- `inlining` is already a named local registry entry, so it is a real future port surface.
- The plain pass is easy to blur together with `inlining-optimizing`, even though the public contract is smaller.
- `agent-todo.md` currently has **no dedicated `inlining` slice**; it only has the optimizing `INL` slice.
- This pass sits in the same late boundary neighborhood as:
  - `dae-optimizing`
  - `inlining-optimizing`
  - `duplicate-function-elimination`
  - `duplicate-import-elimination`
  - `simplify-globals-optimizing`

## Beginner summary

A good beginner mental model is:

- scan the whole module to learn which functions are tiny, one-use, loop-heavy, delegate-heavy, rooted, or referenced elsewhere,
- classify each function as fully inlineable, partially inlineable, or not inlineable,
- plan only the direct reachable callsites that are worth replacing,
- rewrite those callsites by copying the callee body and repairing locals, returns, labels, and types,
- sometimes split a top-of-function `if` pattern into `inlineable` and `outlined` helper pieces first,
- delete only the now-dead private helpers,
- then stop.

That final “then stop” is the big difference from `inlining-optimizing`.

## Current durable takeaways

- `inlining` is a **whole-module planner pass**, not a local peephole.
- Binaryen `version_129` chooses actual inline actions from reachable **direct** `call` / `return_call` sites.
- Exported, start, and `ref.func`-used functions may inline into callers while still surviving as declarations.
- The heuristic is layered:
  - tiny always-inline cases
  - one-caller cases
  - trivial single-instruction wrappers
  - flexible size-policy cases
  - loop/delegate blockers
- Partial inlining is real, but only for two narrow top-of-function `if` pattern families and only under heavier speed-oriented settings.
- Binaryen's preserved `@metadata.code.inline` bytes are a separate compilation-hints surface; the actual plain-`inlining` suppression knobs are the function booleans `noFullInline` / `noPartialInline` set by the separate `no-inline*` passes.
- Those no-inline flags survive cloning through `ModuleUtils::copyFunction`, which is why the dedicated monomorphize-plus-inlining test keeps copied functions blocked too.
- Inline rewrite requires real local/label/type repair, not just replacing a node with the callee body.
- The plain pass does **not** own the nested useful-pass rerun that the optimizing sibling adds.

## Page map

- [`../../../raw/binaryen/2026-04-23-inlining-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-primary-sources.md)
  Immutable primary-source manifest for the exact official Binaryen release, source, and lit-test URLs rechecked on 2026-04-23.
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, helper dependencies, scheduler placement, and what the plain pass really owns.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./heuristics-splitting-and-plain-vs-optimizing.md`](./heuristics-splitting-and-plain-vs-optimizing.md)
  Focused guide to the easiest things to misread: direct-call-only planning, trivial-instruction classes, split-inlining patterns, no-inline controls, and the semantic split from `inlining-optimizing`.
- [`./compilation-hints-vs-no-inline-flags-and-clone-survival.md`](./compilation-hints-vs-no-inline-flags-and-clone-survival.md)
  Compact source-confirmed guide to the difference between preserved `@metadata.code.inline` bytes, Binaryen's real `no-inline` / `no-full-inline` / `no-partial-inline` function flags, and why those flags survive cloning through `ModuleUtils::copyFunction`.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misread rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: exact boundary-only registry / request-guard locations, current planning gap around a dedicated plain-`inlining` backlog slice, and the neighboring dossiers a future local port should compose with.

## Current maintenance rule

- Treat this folder as the canonical home for future `inlining` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the relationship to [`../inlining-optimizing/index.md`](../inlining-optimizing/index.md) explicit instead of silently teaching the plain pass only through the optimizing variant.

## Sources

- [`../../../raw/binaryen/2026-04-23-inlining-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-primary-sources.md)
- [`../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md`](../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md)
- [`../../../raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md`](../../../raw/research/0274-2026-04-23-inlining-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/NoInline.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/wasm-binary.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/parser/contexts.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_optimize-level=3.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_enable-tail-call.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining_splitting_basics.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-instructions.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-trivial-calls-1.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-unreachable.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inlining-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/inline-hints-func.wast>
