---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../dead-argument-elimination/implementation-structure-and-tests.md
  - ../precompute-propagate/implementation-structure-and-tests.md
  - ../inlining-optimizing/implementation-structure-and-tests.md
---

# `dae-optimizing` implementation structure and tests

This page is the compact owner-file and proof-surface map for Binaryen `version_129` `dae-optimizing`.

The current implementation/test-map source bridge is [`../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md). It records official tagged and current-main source URLs plus the dedicated lit files reviewed on 2026-04-25. The recheck found no teaching-relevant drift from the `version_129` contract.

## Biggest source-confirmation result

`dae-optimizing` is not a second implementation of DAE.

It is:

- the shared `DeadArgumentElimination.cpp` direct-call boundary engine,
- registered as the public optimizing sibling in `pass.cpp`,
- with an extra `OptUtils::optimizeAfterInlining(...)` cleanup replay from `opt-utils.h` when productive changes happen.

That means the implementation map has to keep two things visible at once:

1. the shared DAE boundary-rewrite engine; and
2. the optimizing-only nested function-cleanup suffix.

## Core source files

## `src/passes/DeadArgumentElimination.cpp`

This is the main owner file for both public siblings:

- plain `dae`, and
- `dae-optimizing`.

For the optimizing sibling, this file proves the shared core:

- `DAEFunctionInfo` stores per-function facts such as unused params, direct calls, dropped calls, tail-call state, and unseen-call state;
- `DAEScanner` gathers direct-call, dropped-call, tail-call, `call_ref` / indirect-call conservatism, `ref.func` escape, and used-param facts;
- module-level maps connect callees, callers, all calls, dropped calls, tail callees, localization retry targets, and functions worth later cleanup;
- the rewrite loop refines params, refines returns, applies constant actuals, removes params, removes dropped returns, and records hard calls for localization and retry;
- the `optimize` mode bit decides whether productive changes enqueue the optimizing cleanup behavior.

Read this file when the question is:

- “What does DAE actually prove before changing a signature?”
- “When are exports, imports, `ref.func`, tail calls, or indirect/call-ref flows barriers?”
- “Why can the pass refine types and materialize constants instead of only deleting params?”

## `src/passes/pass.cpp`

This file proves the public pass-name split:

- `dae`
- `dae-optimizing`
- `dae2`

For this folder, `pass.cpp` matters because it shows that `dae-optimizing` is a real public Binaryen pass name, not a local shorthand for plain DAE.

It also supports the local naming caveat in [`./starshine-strategy.md`](./starshine-strategy.md): current Starshine uses descriptive boundary-only names, while Binaryen and the saved audit use the upstream `dae-optimizing` spelling.

## `src/passes/opt-utils.h`

This file owns the optimizing-only suffix.

`dae-optimizing` calls the post-inlining cleanup helper on changed functions. That helper:

- runs only on the affected function set,
- prepends `precompute-propagate`, and
- reruns the default function optimization pipeline.

This is not polish. It is part of the public optimizing variant's behavior and explains why the saved `-O4z` debug log shows many nested function passes inside a single top-level `dae-optimizing` interval.

## Helper ownership files

## `src/passes/param-utils.h`

This is the boundary-rewrite helper center.

It owns or supports:

- finding used params,
- applying all-callers-same constant actuals,
- removing parameters from callee and call sites,
- preserving evaluation order during callsite edits,
- and localizing hard call operands before retrying parameter removal.

When future Starshine work reaches callsite repair, this helper is as important as the main pass file.

## `src/ir/return-utils.h`

This helper owns return removal in the callee body.

It matters because dropped-result cleanup is not only a caller-side `drop(call)` rewrite. The callee's body and return sites have to be made consistent with the new result type.

## `src/ir/lubs.h`

This helper owns least-upper-bound reasoning used by DAE for:

- GC reference parameter refinement from all direct-call operands,
- and result refinement from returned values.

This is the shortest source-backed proof that `dae-optimizing` is also a signature-refinement pass, not just dead-parameter deletion.

## `src/ir/type-updating.h`

This helper owns the type-repair surface after param or result changes.

It matters because changing a function type can require repairs to:

- direct call expression types,
- `local.get` / `local.set` / `local.tee` traffic in the callee,
- and surrounding expression types after refinalization.

## `src/ir/utils.h`

This helper participates in small expression and control-flow repair details around DAE's boundary rewrites. Treat it as support for preserving expression typing and unreachable behavior, not as the main optimization owner.

## Official tests and what they prove

## `test/lit/passes/dae-optimizing.wast`

This is the main public optimizing-variant proof file.

It is best used to confirm that:

- the public `dae-optimizing` pass is wired;
- core DAE boundary rewrites are visible through the optimizing pass;
- the optimizing suffix cleans up new debris enough to affect final WAT output.

It should not be read as the entire shared DAE proof surface by itself.

## `test/lit/passes/dae-refine-params-and-optimize.wast`

This file ties two facts together:

- DAE can refine parameter types; and
- the optimizing variant's nested cleanup can immediately simplify after that refinement.

It is the clearest direct test that the optimizing suffix is semantically relevant to visible output, not merely an internal performance detail.

## `test/lit/passes/dae-gc.wast`

This is broad shared-core evidence for GC and reference-typed boundary behavior.

It covers families such as:

- reference-typed parameter refinement,
- result refinement,
- constant actual materialization,
- and conservative ABI / escape bailouts.

Use it as shared-engine evidence together with the plain DAE dossier.

## `test/lit/passes/dae-gc-refine-params.wast`

This is the focused param-refinement proof.

It answers the common question:

- “Does DAE really narrow live params, or does it only remove unused ones?”

The answer is yes: reference-typed param LUB refinement is part of the shared engine and therefore part of `dae-optimizing` too.

## `test/lit/passes/dae-gc-refine-return.wast`

This is the focused result-refinement proof.

It proves the outgoing side of the boundary can tighten even when no result is fully deleted.

## `test/lit/passes/dae_tnh.wast`

This is the sharpest control/value-corner proof.

It is where readers should look for:

- dropped-return behavior,
- traps-never-happen assumptions,
- call/unreachable-style repair,
- and preservation of unreachable typing facts.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/DeadArgumentElimination.cpp` | Core owner | Shared DAE boundary engine plus optimizing-mode hook |
| `src/passes/pass.cpp` | Public registration | `dae` and `dae-optimizing` are separate public names; `dae2` is neighboring but separate |
| `src/passes/opt-utils.h` | Optimizing suffix | `dae-optimizing` reruns post-inlining cleanup on changed functions |
| `src/passes/param-utils.h` | Call/param repair | Used-param discovery, constants, safe param deletion, localization retry |
| `src/ir/return-utils.h` | Callee result repair | Dropped-return elimination rewrites returns, not only callers |
| `src/ir/lubs.h` | Type precision | Param/result LUB refinement is part of the pass |
| `src/ir/type-updating.h` | Validation repair | Signature edits require local/call/body type repair |
| `src/ir/utils.h` | Expression repair support | Small typing/control helpers around rewritten shapes |
| `test/lit/passes/dae-optimizing.wast` | Main optimizing file | Public optimizing behavior and visible cleanup |
| `test/lit/passes/dae-refine-params-and-optimize.wast` | Refinement + cleanup | Param refinement plus optimizing cleanup interaction |
| `test/lit/passes/dae-gc.wast` | Broad shared-core GC oracle | GC constants, refinement, and conservative boundaries |
| `test/lit/passes/dae-gc-refine-params.wast` | Focused param oracle | Live param narrowing is real |
| `test/lit/passes/dae-gc-refine-return.wast` | Focused result oracle | Return type narrowing is real |
| `test/lit/passes/dae_tnh.wast` | Control/value oracle | TNH and `call; unreachable` repairs are real |

## What this source map blocks

## Mistake 1: treating `dae-optimizing` as only “plain DAE but in a late slot”

Wrong. The same core engine runs, but the optimizing mode adds the targeted post-inlining cleanup replay on changed functions.

## Mistake 2: treating `dae-optimizing` as a separate algorithm from plain DAE

Wrong. The core implementation remains `DeadArgumentElimination.cpp`; the sibling split is a mode and scheduler distinction, not two independent algorithms.

## Mistake 3: treating the lit proof as one neat file

Wrong. The visible contract is split across optimizing-specific tests plus shared GC/TNH refinement tests.

## Mistake 4: crediting `dae2` evidence to this pass

Wrong. `dae2` is a separately registered experimental pass and has its own dossier. Do not use `dae2.wast` as proof for the original DAE engine or for `dae-optimizing`.

## Porting takeaway for Starshine

A faithful Starshine port needs two implementation layers:

1. a shared module-boundary DAE core mirroring `DeadArgumentElimination.cpp` and its helper dependencies; and
2. an optimizing-mode scheduler hook mirroring `OptUtils::optimizeAfterInlining(...)` for the changed-function set.

The current local status page remains the source of truth for Starshine: [`./starshine-strategy.md`](./starshine-strategy.md). As of 2026-04-25, Starshine still has only the descriptive boundary-only name `dead-argument-elimination-optimizing`; exact upstream `dae-optimizing` is not a local alias yet.
