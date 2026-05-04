---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../../../raw/research/0435-2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md
  - ../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
  - ../dae2/index.md
---

# `dead-argument-elimination` implementation structure and tests

This page is the compact owner-file and proof-surface map for Binaryen `version_129` plain `dead-argument-elimination` / `dae`.

The current tagged source manifest is [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md). It records the 2026-04-24 official release-page recheck, the reviewed `version_129` source/test URLs, and a narrow current-`main` no-teaching-drift spot check. The later 2026-05-04 current-main freshness layer is [`../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md); the 2026-04-26 Starshine-readiness bridge remains in [`../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md), and the local validation ladder is [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Biggest source-confirmation result

The real owner split is smaller and cleaner than the folder previously implied:

- `src/passes/DeadArgumentElimination.cpp` owns the **shared core algorithm** for both plain `dae` and `dae-optimizing`;
- `src/passes/pass.cpp` owns the public registration split;
- `src/passes/opt-utils.h` owns only the optimizing variant's extra nested cleanup replay.

So plain `dae` should be taught as:

- the shared `DeadArgumentElimination.cpp` engine in non-optimizing mode,
- not as a separate standalone implementation file,
- and not as a tiny wrapper around the optimizing pass.

## Core source files

## `src/passes/DeadArgumentElimination.cpp`

This is the main implementation file.

It owns the real plain-pass contract:

- `DAEFunctionInfo` and the module-wide direct-call bookkeeping,
- `DAEScanner` and the initial direct-call / dropped-call / tail-call / `ref.func` scan,
- the `refineArgumentTypes(...)` and `refineReturnTypes(...)` phases,
- constant-actual materialization,
- dead-parameter removal,
- dropped-return elimination,
- localization-driven iteration,
- and the `optimize` boolean that decides whether the optimizing rerun happens.

This file therefore proves the most important relationship in the folder:

- plain `dae` and `dae-optimizing` are the same boundary-rewrite engine with one scheduler-changing flag difference.

## `src/passes/pass.cpp`

This file matters because it proves the public naming and split:

- `dae`
- `dae-optimizing`
- `dae2`

For the first two, `pass.cpp` confirms that both names are real public passes in `version_129` and that the plain-vs-optimizing distinction is deliberate public API, not a local wiki invention.

It also prevents a common teaching mistake:

- `dae2` is a separately registered experimental pass,
- not a hidden extra mode or test bucket for the original DAE engine.

## `src/passes/opt-utils.h`

This file matters for one very specific reason:

- it owns the `OptUtils::optimizeAfterInlining(...)` helper that only `dae-optimizing` runs after productive iterations.

That means `opt-utils.h` is evidence for the sibling split, not for the plain boundary algorithm itself.

## Helper ownership files

## `src/passes/param-utils.h`

This helper file owns most of the hard boundary-rewrite plumbing that the main DAE file delegates:

- `getUsedParams(...)`
- constant-actual application
- parameter removal
- call-operand localization

So if a reader wants the exact “how do calls and callee params get rewritten safely?” surface, this is the most important helper after the main pass file.

## `src/ir/lubs.h`

This file matters because it owns the least-upper-bound logic for:

- GC parameter refinement from direct-call operands,
- and result refinement from actual returned values.

That helper is the compact proof that plain DAE is also a type-tightening pass, not only a delete-unused-params pass.

## `src/ir/type-updating.h`

This file matters because param/result refinement is not just signature editing.

It owns the follow-up repair surface that keeps rewritten function signatures and direct call sites valid after type changes.

## `src/ir/return-utils.h`

This file matters because dropped-return elimination changes the callee body too, not just the callers.

It owns the return-rewrite helper used once DAE has proved that a function result can disappear.

## Official tests and what they prove

## There is no single dedicated plain-`dae` file

This is the most important test-map correction.

Binaryen `version_129` does **not** give plain `dae` one neat dedicated `dae.wast` file.
Instead, the real plain-pass proof surface is spread across a small family of files.

That is why this page exists.

## `test/lit/passes/dae_tnh.wast`

This is the sharpest plain-pass file for the tricky control/value corner cases.

It proves plain DAE behavior around:

- dropped-return removal with traps-never-happen assumptions,
- `call(unreachable)` and related caller repair,
- and the fact that removing a dead boundary input or dead result must still preserve unreachable typing information.

## `test/lit/passes/dae-gc.wast`

This is the broad GC/reference-family oracle for the shared DAE core.

It proves families such as:

- reference-typed parameter refinement,
- result refinement,
- constant actual materialization in GC-heavy cases,
- and conservative bailouts around exported or escaping boundaries.

## `test/lit/passes/dae-gc-refine-params.wast`

This is the clearest focused oracle for one specific plain-pass subtopic:

- GC parameter LUB refinement.

It is the best short answer when someone asks whether plain DAE really narrows still-live params.

## `test/lit/passes/dae-gc-refine-return.wast`

This is the corresponding focused oracle for:

- result-type refinement.

It proves that the pass is not only about shrinking the incoming side of the boundary.

## `test/lit/passes/dae-optimizing.wast`

This file still matters, but it should be taught carefully.

It is best used as:

- shared-core evidence for the underlying DAE engine,
- plus proof that the optimizing wrapper exposes extra visible cleanup after the same boundary rewrites.

It is **not** the main plain-pass oracle.

## `test/lit/passes/dae-refine-params-and-optimize.wast`

This is another shared-core-plus-optimizing-boundary file.

It is useful because it shows the interaction between:

- param refinement,
- and the optimizing rerun.

Again, that makes it good sibling-boundary evidence, not the main plain-pass proof file.

## `test/lit/passes/dae2.wast`

This file is important mostly as a negative attribution rule.

It belongs to the separately registered experimental `dae2` pass.
So the `dead-argument-elimination` dossier should explicitly **not** use it as evidence for the original DAE engine.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/DeadArgumentElimination.cpp` | Core algorithm | Plain `dae` and `dae-optimizing` share one boundary-rewrite engine |
| `src/passes/pass.cpp` | Public registration | `dae`, `dae-optimizing`, and `dae2` are separate public pass names |
| `src/passes/opt-utils.h` | Optimizing-only helper | The nested cleanup replay belongs only to `dae-optimizing` |
| `src/passes/param-utils.h` | Boundary rewrite helpers | Used-param discovery, constant actuals, param removal, and localization are helper-owned |
| `src/ir/lubs.h` | Refinement helper | Param/result narrowing is part of plain DAE |
| `src/ir/type-updating.h` | Type repair helper | Signature refinement needs explicit repair work |
| `src/ir/return-utils.h` | Return rewrite helper | Dropped-return elimination also rewrites callee returns |
| `test/lit/passes/dae_tnh.wast` | Control/value oracle | TNH and `call; unreachable` repairs are part of the real contract |
| `test/lit/passes/dae-gc.wast` | Broad shared-core oracle | GC refinement, constant actuals, and conservative bailouts are real plain-pass behavior |
| `test/lit/passes/dae-gc-refine-params.wast` | Focused plain oracle | Param refinement is real and separate from deletion |
| `test/lit/passes/dae-gc-refine-return.wast` | Focused plain oracle | Result refinement is real and separate from dropped-return removal |
| `test/lit/passes/dae-optimizing.wast` | Sibling-boundary oracle | The optimizing pass adds visible cleanup after the same core rewrites |
| `test/lit/passes/dae-refine-params-and-optimize.wast` | Sibling-boundary oracle | Param refinement plus optimizing cleanup belong together only in the optimizing variant |
| `test/lit/passes/dae2.wast` | Negative attribution oracle | `dae2` evidence should not be silently credited to plain `dae` |

## What this source map says about the real public contract

The source/test map blocks three common mistakes.

## Mistake 1: teaching plain `dae` as “a tiny wrapper over helpers”

Wrong.
The core boundary algorithm still lives in `DeadArgumentElimination.cpp`.
The helpers support it, but do not replace the main owner file.

## Mistake 2: teaching plain `dae` as if it had one neat dedicated golden file

Wrong.
The real proof surface is the combined `dae_tnh` + `dae-gc*` family, with optimizing files used only as contrast.

## Mistake 3: teaching `dae2` as more evidence for the original DAE engine

Wrong.
`dae2` is a separately registered experimental pass and should stay in its own dossier.

## Porting takeaway

For the exact current local registry, request-rejection, and future shared-core plan, read [`./starshine-strategy.md`](./starshine-strategy.md).

If Starshine ever ports plain DAE, the clean source-backed implementation target is:

- one shared direct-call boundary engine,
- helper-backed param/result/call rewriting,
- no optimizing cleanup rerun in the plain variant,
- and tests drawn from the real distributed plain-pass proof family instead of a fictional single `dae.wast` contract.

## Recommended local teaching rule

When plain `dead-argument-elimination` is cited elsewhere in the wiki:

- point here for the owner/test split,
- point to `dae-optimizing` only for the nested-rerun difference,
- and keep `dae2` explicitly marked as neighboring-but-separate.
