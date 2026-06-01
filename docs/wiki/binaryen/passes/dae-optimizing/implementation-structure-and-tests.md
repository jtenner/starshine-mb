---
kind: concept
status: supported
last_reviewed: 2026-05-27
sources:
  - ../../../raw/research/0687-2026-05-27-dae004-closeout-evidence.md
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0120-2026-04-20-dae-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/implementation-structure-and-tests.md
  - ../precompute-propagate/implementation-structure-and-tests.md
  - ../inlining-optimizing/implementation-structure-and-tests.md
---

# `dae-optimizing` implementation structure and tests

## Why this page exists

`dae-optimizing` is easy to misfile mentally as either:

- “plain DAE but in a late slot”,
- or “just another test file near DAE”.

This page keeps the source roles explicit so future work does not blur:

- what belongs to the shared `dae` / `dae-optimizing` engine,
- what belongs to the optimizing-only nested rerun suffix,
- and what the unusually wide `dae-optimizing.wast` family is actually proving.

## Upstream file map

The 2026-05-05 current-main recheck did not find teaching-relevant drift from this map, and the 2026-05-27 DAE004 closeout evidence in note `0687` keeps the same owner/test surface authoritative while closing the current DAE004 breadth slice. The page still keeps the local first-slice / validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) and leaves the earlier 2026-04-25 bridge as the detailed implementation-readiness companion.

| File | What it contributes | Why it matters for a port |
| --- | --- | --- |
| `src/passes/DeadArgumentElimination.cpp` | The entire `dae-optimizing` engine: analysis data structures, graph-building walk, reverse-graph prep, fixed point, optimizer, type updater, replacement-type generation, and stats hooks | This is the real oracle for `dae-optimizing` semantics; see the 2026-04-25 manifest for reviewed owner locations |
| `src/passes/pass.cpp` | Registers `dae-optimizing` as a public pass next to `dae` | Proves the sibling is public and separate, not hidden |
| `src/passes/opt-utils.h` | The optimizing-only cleanup suffix called on changed functions | Critical because the optimizer replay is part of the pass contract |
| `test/lit/passes/dae-optimizing.wast` | The canonical behavior surface for direct positives, refinement positives, dropped-return repairs, and optimizing cleanup examples | The file is big because the pass surface is big |
| `test/lit/passes/dae-refine-params-and-optimize.wast` | Shared proof that optimizing cleanup immediately follows boundary refinement | Connects signature changes to scheduler behavior |
| `test/lit/passes/dae-gc.wast` | Shared GC/reference-typed boundary behavior | Proves the refinement side of the pass |
| `test/lit/passes/dae-gc-refine-params.wast` | Focused param-refinement proof | Proves the live-param narrowing family |
| `test/lit/passes/dae-gc-refine-return.wast` | Focused result-refinement proof | Proves the outgoing-side narrowing family |
| `test/lit/passes/dae_tnh.wast` | Sharp control/value corner cases | Proves dropped-return and `call; unreachable` repair behavior |

## Exact source anchors

- [`../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md`](../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md) keeps the reviewed upstream file pages and the current-main recheck together.
- `DeadArgumentElimination.cpp` is the main contract surface for the shared boundary rewrite engine.
- `pass.cpp` is the public registration proof that `dae-optimizing` is a separate pass name.
- `opt-utils.h` is the optimizing-only nested rerun suffix.
- `dae-optimizing.wast` is the canonical behavior surface for positives, bailouts, and nested-cleanup-visible output.

## What `DeadArgumentElimination.cpp` contributes

Unlike plain `dae`, the `dae-optimizing` implementation does not lean on a separate helper family for its core algorithmic story.
Most of the real logic is in this one file.

## Header comment

The file starts by stating its intended algorithm and its current non-goals.
That comment is worth treating as part of the contract because it clearly says:

- backward fixed point over used params is in scope,
- result optimization is not yet,
- constant and type propagation are not yet.

## `DAEFunctionInfo`

Per-function analysis state:

- direct and indirect forwarding maps,
- param usage bits,
- param-reading gets,
- referenced status,
- continuation-type usage,
- intrinsic blocker flag,
- replacement type.

## `RootFuncTypeInfo`

Per-root-function-type-tree analysis state:

- tree-wide param usages,
- referenced functions in the tree,
- reverse caller-param edges for indirect/reference callers.

This is the easiest source clue that `dae-optimizing` is not only a direct-call pass.

## `DAE`

The main pass class.
Major methods include:

- `run(...)`
  - orchestrates analyze → prepare → fixed point → optimize;
- `analyzeModule()`
  - seeds direct/function-type-tree facts and blocker roots;
- `prepareReverseGraph()`
  - reverses the forwarding graph;
- `computeFixedPoint()`
  - propagates use backward through the reverse graph;
- `optimize()`
  - runs body optimization and, if enabled, the nested cleanup suffix;
- `makeUnreferencedFunctionTypes(...)`
  - manufactures or reuses replacement types for unreferenced functions.

## `GraphBuilder`

The function-parallel analysis walker.
It is where Binaryen:

- detects direct forwarding,
- detects indirect/reference forwarding,
- identifies `if`-condition uses,
- applies effect-based forwarding limits,
- records `ref.func` references,
- records continuation-type usage,
- marks `call.without.effects` users.

## `Optimizer`

The mutating walker that actually:

- renumbers params/locals,
- removes dead operands,
- removes forwarded expression trees,
- preserves surrounding structure,
- and installs replacement/original types at the right stage.

## `DAETypeUpdater`

The part that rebuilds types and computes old-to-new type maps when referenced-function optimization is enabled.

## The plain-vs-`dae-optimizing` split is intentionally large

This matters for future readers.

Plain `dae` / `dae-optimizing` live in:

- `DeadArgumentElimination.cpp`
- `param-utils.h`
- `return-utils.h`
- `lubs.h`
- `type-updating.h`

`dae-optimizing` lives primarily in:

- `DeadArgumentElimination.cpp`

with a very different analysis structure plus the optimizing replay suffix.

## What the helper headers actually contribute

## `param-utils.h`

Essential for used-param discovery, constants, safe param deletion, and localization retry.

## `return-utils.h`

Owns return removal in the callee body.

## `lubs.h`

Owns least-upper-bound reasoning used by DAE for reference-param refinement and result refinement.

## `type-updating.h`

Owns the type-repair surface after param or result changes.

## `opt-utils.h`

Owns the optimizing replay suffix.
It matters because the DAE changes are expected to feed the nested cleanup replay on touched functions.

## Official tests and what they prove

## `test/lit/passes/dae-optimizing.wast`

This is the main public optimizing-variant proof file.

It is best used to confirm that:

- the public `dae-optimizing` pass is wired;
- core DAE boundary rewrites are visible through the optimizing pass;
- the optimizing suffix cleans up new debris enough to affect final WAT output.

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
| `src/passes/pass.cpp` | Public registration | `dae` and `dae-optimizing` are separate public names |
| `src/passes/opt-utils.h` | Optimizing suffix | `dae-optimizing` reruns post-inlining cleanup on changed functions |
| `src/passes/param-utils.h` | Call/param repair | Used-param discovery, constants, safe param deletion, localization retry |
| `src/ir/return-utils.h` | Callee result repair | Dropped-return elimination rewrites returns, not only callers |
| `src/ir/lubs.h` | Type precision | Param/result LUB refinement is part of the pass |
| `src/ir/type-updating.h` | Validation repair | Signature edits require local/call/body type repair |
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
2. an optimizing-mode scheduler hook mirroring the nested cleanup suffix for the changed-function set.

The current local status page remains the source of truth for Starshine: [`./starshine-strategy.md`](./starshine-strategy.md). As of 2026-05-05, Starshine still has only the descriptive boundary-only name `dead-argument-elimination-optimizing`; exact upstream `dae-optimizing` is not a local alias yet.
