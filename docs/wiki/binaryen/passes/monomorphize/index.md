---
kind: entity
status: working
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md
  - ../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md
  - ../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md
  - ../../../raw/research/0302-2026-04-24-monomorphize-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/cli/cli.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./call-context-benefit-and-boundaries.md
  - ./clone-construction-signature-rebuild-and-dropped-call-rewrites.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../monomorphize-always/index.md
  - ../inlining/index.md
  - ../inline-main/index.md
  - ../tracker.md
---

# `monomorphize`

## Role

- `monomorphize` is a real public Binaryen pass.
- It is currently **unimplemented** in Starshine's active optimizer and still lives in the local **boundary-only** registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- It is **not** part of the repo's current canonical no-DWARF `-O` / `-Os` optimize path.
- `agent-todo.md` currently has **no dedicated `monomorphize` slice**.
- Official Binaryen also exposes a testing-oriented sibling pass, `monomorphize-always`, which reuses the same core machinery but disables the usefulness gate.

## Why this pass matters

- The original no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first widened upstream-only dossier wave are already covered, so this folder is an explicit tracker expansion for another real local registry pass.
- `monomorphize` sits near already-documented neighbors like `inlining`, `inline-main`, and the GC/type passes, but it solves a different problem.
- It is easy to misread as “just inlining constants into callees.” The real pass is broader and more interesting: it builds **callsite contexts**, clones new specialized functions, rebuilds their signatures from the transformed context IR, repairs locals and dropped-result boundaries, runs nested optimization, and keeps the clone only if measured benefit clears a threshold.
- It is a plausible future parity target for more aggressive or specialized optimization profiles even though it is outside the repo's current default no-DWARF path.

## Beginner summary

A good beginner mental model is:

- a call tells Binaryen something extra about a callee
- maybe an argument is constant
- maybe a reference argument is more specific than the declared param type
- maybe the call result is immediately dropped
- Binaryen clones the callee into a specialized version that bakes in that context
- then it runs more optimization on the specialized copy
- if the specialized copy gets meaningfully smaller or simpler, the call is retargeted to it

So this pass is best taught as:

- **empirical callsite-driven specialization**
- not normal inlining
- not exact-type-only monomorphization
- not simple constant propagation

## Pass contract

### Inputs and outputs

- Input: a whole Binaryen module with defined functions and direct callsites that may expose extra callee context.
- Output: the same module with some direct calls retargeted to newly cloned specialized functions, or no change when the context is unsafe, trivial, too wide, or not useful enough.
- The pass may add specialized functions, reduce call operands, change a specialized clone's result to `none` for dropped-call contexts, and remove the caller-side `drop` wrapper only when the clone's result was deliberately killed.
- It does not specialize imported targets, indirect calls, recursive self-calls, or newly created clones during the same run.

### Core invariants and correctness constraints

- Context extraction must preserve side-effect order; movable operand IR may cross nonmoved operand IR only when the `EffectAnalyzer` proof says the movement is safe.
- Function signatures must be rebuilt from the dynamic inputs that survive in the context IR, not from the old parameter list by position alone.
- Old params converted to locals, shifted local indexes, local names, explicit returns, and caller-side dropped-result rewrites must stay validation-correct after cloning.
- Return-call-sensitive callees must not absorb an outer dropped-result context when that would break tail-call behavior.
- The ordinary `monomorphize` pass must keep the empirical usefulness gate; `monomorphize-always` removes usefulness rejection but keeps the legality and triviality gates.

### Validation expectations

- Upstream validation starts from the official lit families listed in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md): constants, richer call contexts, dropped results, refined reference types, hard parameter limits, MVP usefulness, and `no-inline` interaction.
- A future Starshine port should add reduced tests for each positive and bailout family in [`./wat-shapes.md`](./wat-shapes.md), then compare `--monomorphize` and `--monomorphize-always` against Binaryen before using wider artifact fuzzing.
- Any local implementation must also validate the option bridge in [`./starshine-strategy.md`](./starshine-strategy.md): `--monomorphize-min-benefit` is currently parsed and stored, but does not run a transform until the pass exists.

## Most important durable takeaways

- The reviewed implementation only handles **direct calls**.
- Imported targets, recursive self-calls, unreachable calls, and many context shapes are rejected early.
- The core algorithm is a **call-context builder** that tries to reverse-inline movable operand code into a specialized callee.
- Safety depends on explicit **effect-order and movement** checks, not only on syntax matching.
- A context can specialize:
  - constant operands
  - more-refined reference operands
  - movable GC allocations
  - dropped-call result context
- The pass clones a new function, rebuilds its signature, remaps locals, and may change the result type to `none` for dropped calls.
- The default pass is **empirical**: it runs nested optimization and only keeps the specialization if the measured benefit exceeds a configurable threshold.
- The reviewed source defaults that threshold to `95%` and enforces a hard specialized-param cap of `20`.
- `monomorphize-always` is the same machinery with the usefulness gate disabled.

## Page map

- [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md)
  Immutable primary-source manifest for the exact official Binaryen release, source, helper-header, and lit-test URLs rechecked on 2026-04-24.
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  Deep dive into the actual Binaryen implementation, helper dependencies, algorithmic phases, and pass interactions.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  File-by-file and test-by-test map of the upstream sources that define the pass contract.
- [`./call-context-benefit-and-boundaries.md`](./call-context-benefit-and-boundaries.md)
  Focused guide to the hardest half of the pass: what Binaryen treats as movable callsite context, how the usefulness gate works, and why dropped-call and return-call boundaries matter.
- [`./clone-construction-signature-rebuild-and-dropped-call-rewrites.md`](./clone-construction-signature-rebuild-and-dropped-call-rewrites.md)
  Focused guide to the exact clone-building bridge from `CallContext` to emitted WAT: signature derivation from surviving `LocalGet`s, param-to-local conversion, local-index remap, reverse-inlined prelude `local.set`s, dropped-result return removal, and caller-side `drop` rewrite.
- [`./wat-shapes.md`](./wat-shapes.md)
  Beginner-friendly shape catalog showing the main positive, mixed, and bailout WAT families.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  Current Starshine status and future port map: exact boundary-only registry / request-guard locations, existing `monomorphize_min_benefit` option plumbing, missing owner-file/backlog-slice status, and the neighboring whole-module pass landing zone.

## Current maintenance rule

- Treat this folder as the canonical home for future `monomorphize` research and port planning.
- Keep it explicitly marked as **unimplemented** until Starshine grows a real boundary/module pass for it.
- Keep the split from `inlining` explicit: `monomorphize` clones the callee and pulls callsite context inward, while inlining clones the callee body into the caller.
- Keep the split from `monomorphize-always` explicit too: the sibling is useful test surface, but the default public pass is the empirical usefulness-gated one.
- Keep the clone-mechanics fact explicit too: the real contract is not just “specialize a callee,” but a source-backed signature-rebuild, param-to-local, local-remap, dropped-result, and caller-rewrite pipeline.
- Keep the Starshine status explicit: current local support is boundary-only name tracking plus `--monomorphize-min-benefit` option plumbing, not an implemented transform.

## Sources

- [`../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md`](../../../raw/binaryen/2026-04-24-monomorphize-primary-sources.md)
- [`../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md`](../../../raw/research/0176-2026-04-21-monomorphize-binaryen-research.md)
- [`../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md`](../../../raw/research/0233-2026-04-21-monomorphize-clone-and-rewrite-followup.md)
- [`../../../raw/research/0302-2026-04-24-monomorphize-primary-sources-and-starshine-followup.md`](../../../raw/research/0302-2026-04-24-monomorphize-primary-sources-and-starshine-followup.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
- [`../tracker.md`](../tracker.md)
- Binaryen `version_129` sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Monomorphize.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/cost.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/manipulation.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-limits.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-benefit.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-consts.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-context.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-drop.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-limits.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-mvp.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/monomorphize-types.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/no-inline-monomorphize-inlining.wast>
