---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md
  - ../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
  - ../../../../../agent-todo.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
  - ../signature-pruning/index.md
  - ../tracker.md
---

# `dead-argument-elimination`

## Role

- `dead-argument-elimination` is an upstream Binaryen boundary pass.
- The public upstream CLI alias is `dae`.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The current repo no-DWARF default optimize path uses the related later pass `dae-optimizing`, not this plain variant.
- The two passes share the same core engine in upstream `version_129`; `dae-optimizing` is the plain DAE algorithm plus one extra nested cleanup rerun.

## Why it matters

- Even though plain `dae` is outside the current no-DWARF parity queue, it is already a named local registry entry, so it is a real future implementation surface rather than speculative upstream trivia.
- The existing `dae-optimizing` dossier is easier to understand once plain DAE has its own home.
- This pass teaches the part that is easiest to blur together:
  - the core boundary rewrite algorithm itself,
  - versus the extra scheduler behavior that the optimizing suffix adds.
- `agent-todo.md` currently has **no dedicated `dead-argument-elimination` slice**, so this dossier is also the first durable backlog-grade explanation of the pass in this repo.

## Beginner summary

A good beginner mental model is:

- gather all direct callers of a function,
- refuse boundaries that can escape or be observed indirectly,
- tighten argument and result types when all known calls agree,
- turn always-the-same actuals into local callee constants,
- delete dead parameters and dead dropped returns,
- localize hard operands and iterate if necessary,
- then stop.

That last point is the big difference from `dae-optimizing`: **plain DAE does not do the extra post-change cleanup rerun**.

## Current durable takeaways

- Plain DAE is a **whole-module direct-call boundary pass**, not a hot local cleanup pass.
- It can do more than delete unused parameters:
  - constant actual materialization,
  - GC parameter refinement,
  - result type refinement,
  - dropped-return elimination,
  - operand localization and retry.
- Exports and `ref.func` escapes count as unseen calls, so Binaryen refuses signature-changing rewrites there.
- Tail calls and tail-callee relationships block dropped-return removal.
- The implementation is iterative and can perform a localization-only round so a later removal becomes legal.
- The plain pass shares the same upstream file and much of the same lit neighborhood as `dae-optimizing`, but it deliberately omits the final `optimizeAfterInlining(...)` rerun.
- There is no single dedicated plain `dae.wast`; the real proof surface is split across `dae_tnh.wast`, `dae-gc.wast`, `dae-gc-refine-params.wast`, and `dae-gc-refine-return.wast`, with neighboring optimizing files acting as sibling-boundary evidence rather than the main plain-pass oracle.
- The 2026-04-26 current-main port-readiness recheck found no teaching-relevant drift from the tagged source story, but it clarified the future Starshine implementation ladder: analyzer-only candidate classification first, scalar direct-call parameter deletion second, and constant actual / GC refinement / dropped-result / localization families later.

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen `version_129` implementation: phases, data structures, helper dependencies, legality gates, and the exact plain-vs-optimizing split.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  Source-confirmed file/test map for `DeadArgumentElimination.cpp`, `pass.cpp`, `opt-utils.h`, `param-utils.h`, `lubs.h`, `type-updating.h`, `return-utils.h`, and the split plain-vs-optimizing-vs-`dae2` lit surface.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly before/after shape catalog for the main positive, bailout, preserved, and easy-to-misunderstand rewrite families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future-port strategy: boundary-only descriptive registry name, no exact upstream `dae` alias yet, no active owner file, no plain-DAE backlog slice, and the module-boundary code surfaces a future port should touch.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  First-slice and validation bridge for a future Starshine port: no-rewrite analyzer, scalar direct-call parameter deletion, follow-up rewrite families, exact local code surfaces, Binaryen `--dae` oracle checks, and the guardrail that plain DAE must not run the optimizing sibling's nested cleanup replay.

## Current maintenance rule

- Treat [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md) as the immutable tagged primary-source manifest for this folder.
- Treat [`../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md) as the focused current-main / Starshine-readiness recheck.
- Treat this folder as the canonical home for future `dead-argument-elimination` / `dae` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary pass for it.
- Keep the relationship to [`../dae-optimizing/index.md`](../dae-optimizing/index.md) explicit instead of silently folding plain DAE facts into the optimizing dossier.

## Sources

- [`../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md)
- [`../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md`](../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md)
- [`../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md`](../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md`](../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md)
- [`../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md`](../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- Binaryen `version_129` implementation and test sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast>
