---
kind: entity
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md
  - ../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./special-case-contract-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/index.md
  - ../monomorphize/index.md
  - ../tracker.md
---

# `inline-main`

## Role

- `inline-main` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `inline-main` slice**.
- Official Binaryen implements it in the same source file as ordinary `inlining`, but as a distinct public pass with a much narrower contract.
- The current source manifest is [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md), and the Starshine status bridge is [`./starshine-strategy.md`](./starshine-strategy.md).

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is another explicit tracker expansion for a real local registry pass that still lacked its own canonical home.
- `inline-main` is easy to blur together with plain `inlining`, because both reuse the same low-level inlining helper.
- But the chooser logic is very different:
  - `inlining` is a heuristic whole-module planner,
  - while `inline-main` is a tiny wrapper-cleanup pass for one exact `main` / `__original_main` relation.
- It also sits conceptually beside `monomorphize`, which makes a three-way distinction worth preserving:
  - `inline-main` = exact wrapper special case,
  - `inlining` = general direct-call inliner,
  - `monomorphize` = callsite-context-specializing clone pass.

## Beginner summary

A good beginner mental model is:

- some toolchains make `main` a wrapper,
- the real user body lives in `__original_main`,
- Binaryen checks whether `main` directly calls `__original_main` exactly once,
- if yes, it inlines that one call using the ordinary inline-body rewriter,
- otherwise it leaves the module alone.

So this pass is best taught as:

- **wrapper cleanup for one historical toolchain pattern**
- not heuristic general inlining
- not a scheduler alias
- not multi-call optimization

## Most important durable takeaways

- The pass is a distinct public CLI name registered in upstream `pass.cpp`.
- It does **not** appear in Binaryen's default no-DWARF `-O` / `-Os` preset.
- The implementation only succeeds when both `main` and `__original_main` exist as **defined** functions.
- The search surface is intentionally narrow: it scans only direct `Call` nodes inside `main`.
- It bails out unless there is **exactly one** direct call to `__original_main`.
- On success it reuses the same low-level `doInlining(...)` helper as ordinary `inlining`.
- Because of that shared helper, successful rewrites still inherit real inline fixups:
  - copied-body insertion
  - return-to-branch rewriting
  - label-uniqueness repair
  - refinalization
  - nondefaultable-local handling
- The dedicated lit file proves that imported endpoints, missing endpoints, already-inlined bodies, and multi-call wrappers are all intentional no-op families.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, helper dependencies, algorithmic phases, and neighboring-pass interaction story.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./special-case-contract-and-boundaries.md`](./special-case-contract-and-boundaries.md)
  Focused guide to the real teaching problem here: why `inline-main` is separate from plain `inlining`, what the exact-one-call rule means, and which parts of the rewrite are inherited from the shared helper.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, preserved, and bailout WAT families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Exact local code-map and future-port plan showing that current Starshine keeps `inline-main` as a boundary-only name with request rejection, no owner file, no active preset role, and no backlog slice.

## Current maintenance rule

- Treat this folder as the canonical home for future `inline-main` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from [`../inlining/index.md`](../inlining/index.md) explicit: plain `inlining` owns heuristic planning, while `inline-main` owns the one exact wrapper pattern.
- Keep the split from [`../monomorphize/index.md`](../monomorphize/index.md) explicit too: `monomorphize` clones a specialized callee, while `inline-main` just inlines one wrapper call.

## Sources

- [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md)
- [`../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/cmd/cmd.mbt`](../../../../../src/cmd/cmd.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/metadata.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
  - current-main spot check: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
