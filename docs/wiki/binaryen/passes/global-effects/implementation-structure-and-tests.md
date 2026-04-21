---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./metadata-naming-and-consumers.md
  - ../simplify-locals/implementation-structure-and-tests.md
  - ../vacuum/effect-pruning-and-traps-never-happen.md
---

# Upstream implementation structure and tests for `global-effects`

## Main reviewed files

| File | What it proves | Why it matters |
| --- | --- | --- |
| `src/passes/GlobalEffects.cpp` | The actual pass algorithm: shallow per-function effect scan, reverse call dependency building, fixed-point propagation, and storage into `Function.effects` | This is the main implementation oracle. |
| `src/passes/pass.cpp` | Public pass registration under the upstream name `generate-global-effects`, sibling `discard-global-effects`, and the explicit note that the pass is not currently scheduled in the default optimization sequence | This is the main scheduler and naming oracle. |
| `src/ir/effects.h` | Consumer-side handoff: `EffectAnalyzer` on a direct `Call` may incorporate a callee's stored `effects` summary | This explains why the pass matters downstream. |
| `src/wasm.h` | `Function` really stores an optional `effects` pointer as explicit metadata | This proves the pass is metadata-producing, not IR-rewriting. |
| `test/lit/passes/vacuum-global-effects.wast` | A real downstream consumer case where generated summaries make later `vacuum` cleanup stronger | This is the clearest directly reviewed behavior proof for the pass's value. |

## `GlobalEffects.cpp`

This file establishes the pass contract.

The most important structural points are:

1. **parallel shallow scan first**
   - the pass uses `ModuleUtils::ParallelFunctionAnalysis<EffectAnalyzer>` with `ShallowEffectAnalyzer`
2. **reverse call dependency map next**
   - the pass remembers which callers depend on each callee
3. **deferred fixed point after that**
   - when a function's summary changes, its callers are requeued
4. **metadata writeback at the end of each update**
   - the summary lives in `Function.effects`

That is why the right high-level summary is:

- analysis pass
- metadata output
- interprocedural fixed point

not:

- peephole pass
- local tree walk
- one-shot rewrite

## `pass.cpp`

This file proves three separate facts that are all easy to blur together:

### 1. Public name

Upstream registers the pass as `generate-global-effects`.

### 2. Sibling lifecycle pass

Upstream also registers `discard-global-effects`.
That is strong evidence that Binaryen expects this metadata to have a lifecycle.

### 3. Default-pipeline policy

The registration comment says Binaryen is **not** adding `generate-global-effects` to the default optimize sequence today.
That is the key scheduler fact the landing page must keep explicit.

## `effects.h`

This file answers the most important “why” question.

The call-handling logic can consult a target function's stored `effects` summary when one exists.
So the pass is not an isolated side table.
It is directly connected to later effect reasoning.

That one fact explains why neighboring passes can gain precision without `generate-global-effects` itself changing any WAT.

## `wasm.h`

This file proves where the data lives.

A `Function` owns an optional `std::unique_ptr<EffectAnalyzer>` field named `effects`.
That matters for two reasons:

- it confirms this is official per-function metadata, not an ad hoc temporary cache hidden inside one pass
- it explains why later passes and lifecycle passes can observe, clear, or reuse the same summaries

## Reviewed upstream test surface

## `vacuum-global-effects.wast`

This is the clearest directly reviewed test surface in this thread.
Its value is not that it tests `generate-global-effects` in isolation.
Its value is that it proves the pass changes what a later consumer can safely do.

The beginner takeaway is:

- before generated summaries, some calls are treated conservatively
- after generated summaries, `vacuum` can identify some unused calls as removable

So the test is a consumer proof rather than a pretty before/after rewrite demo for the pass itself.

## Indirect but relevant neighboring test evidence

I did not directly reopen additional upstream tests in this thread, but the existing neighboring living docs already record another important consumer family:

- `global-effects_simplify-locals.wast`

That is useful context, but the current dossier keeps the directly reviewed official test evidence limited to `vacuum-global-effects.wast`.

## Beginner-friendly file map summary

If you only remember one source role per file, remember this:

- `GlobalEffects.cpp` = **how the summaries are computed**
- `pass.cpp` = **what the public pass is called and where it is scheduled**
- `effects.h` = **how later passes consume the summaries**
- `wasm.h` = **where the summaries live**
- `vacuum-global-effects.wast` = **proof that the metadata changes downstream optimization behavior**

## What a future Starshine port must preserve

A future port should preserve:

- the public-vs-local naming split
- the shallow-summary and fixed-point structure
- the metadata storage site
- the downstream consumer contract
- the explicit possibility that summaries may need later invalidation/discard

## Sources

- [`../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md`](../../../raw/research/0168-2026-04-21-global-effects-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalEffects.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
