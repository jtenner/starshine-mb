---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-dae2-current-main-recheck.md
  - ../../../raw/research/0452-2026-05-05-dae2-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-dae2-port-readiness-primary-sources.md
  - ../../../raw/research/0410-2026-04-26-dae2-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-dae2-primary-sources.md
  - ../../../raw/research/0337-2026-04-25-dae2-source-bridge.md
  - ../../../raw/research/0218-2026-04-21-dae2-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./fixed-point-forwarding-type-trees-and-expression-removal.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/index.md
---

# `dae2`: implementation structure and tests

## Why this page exists

`dae2` is easy to misfile mentally as either:

- “plain DAE but experimental”,
- or “just another test file near DAE”.

This page keeps the source roles explicit so future work does not blur:

- what belongs to the separate `dae2` engine,
- what belongs to the original DAE family,
- and what the unusually large `dae2.wast` file is actually proving.

## Upstream file map

The 2026-05-05 current-main recheck did not find teaching-relevant drift from this map; it keeps the local first-slice / validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) and leaves the older 2026-04-26 bridge as the detailed implementation-readiness companion.

| File | What it contributes | Why it matters for a port |
| --- | --- | --- |
| `src/passes/DeadArgumentElimination2.cpp` | The entire `dae2` engine: analysis data structures, graph-building walk, reverse-graph prep, fixed point, optimizer, type updater, replacement-type generation, and stats hooks | This is the real oracle for `dae2` semantics; see the 2026-04-25 manifest for reviewed owner locations |
| `src/passes/pass.cpp` | Registers `dae2` as a public pass next to `dae` and `dae-optimizing` | Proves the sibling is public and separate, not hidden |
| `test/lit/passes/dae2.wast` | The canonical proof surface for trivial positives, forwarding cycles, indirect/reference cases, public-type boundaries, replacement-type regressions, control/effect preservation, and nondefaultable-local ordering | The file is big because the pass surface is big |
| `src/ir/local-graph.h` | Backing machinery for deciding whether a `local.get` still reads the incoming param value | Explains why slot reuse does not confuse the analysis |
| `src/ir/module-utils.h` | Provides public-heap-type discovery used to protect unrewritable referenced type trees | Important for the closed-world + public-type boundary |
| `src/ir/type-updating.h` | Global type rewriting and holder repair helpers | Critical for the referenced-function half of the pass |
| `src/ir/intrinsics.h` | Detects `call.without.effects` and JS-called functions | Explains two major conservative bailout families |
| `src/ir/effects.h` | Effect analysis for deciding whether forwarding wrappers are removable | Explains why expression-tree removal is semantics-safe |
| `src/ir/eh-utils.h` | Continuation/tag-related helper context | Important for the “do not rewrite this root type tree” boundary |
| `src/wasm-type-shape.h` | Type-shape and rec-group context used by replacement-type creation | Important for brand/conflict and rec-group correctness |

## What lives in `DeadArgumentElimination2.cpp`

Unlike plain `dae`, the `dae2` implementation does not lean on a shared helper family for its core algorithmic story.
Most of the real logic is in this one file.

## Header comment

The file starts by stating its intended algorithm and its current non-goals.
That comment is worth treating as part of the contract because it clearly says:

- backward fixed point over used params is in scope,
- result optimization is not yet,
- constant and type propagation are not yet.

## `FunctionInfo`

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

This is the easiest source clue that `dae2` is not only a direct-call pass.

## `DAE2`

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
  - runs body optimization and, if enabled, the global type-rewrite half;
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

## The plain-vs-`dae2` split is intentionally large

This matters for future readers.

Plain `dae` / `dae-optimizing` live in:

- `DeadArgumentElimination.cpp`
- `param-utils.h`
- `return-utils.h`
- `lubs.h`
- `opt-utils.h`

`dae2` lives primarily in:

- `DeadArgumentElimination2.cpp`

with a very different analysis structure.

So if future docs ever say “DAE does X”, they should specify which family they mean.

## What the helper headers actually contribute

## `local-graph.h`

Essential because parameter-slot reads must be tied back to the incoming boundary value, not just the numeric local index.

## `module-utils.h`

Provides `getPublicHeapTypes(...)`, which helps define the root function-type trees that cannot be globally rewritten.

## `type-updating.h`

Owns the hard global repair work once referenced function types change.
A future port cannot stop at editing function signatures and call operands.

## `intrinsics.h`

Makes explicit that `call.without.effects` and JS-called surfaces are not just random tests; they are first-class blocker families in the source.

## `effects.h`

Explains why `dae2` can safely remove pure forwarding wrappers but must preserve effectful/control-sensitive ones.

## `wasm-type-shape.h`

Relevant for the replacement-type and rec-group correctness story, especially in the brand/conflict regressions.

## Reviewed lit file and what it proves

`dae2.wast` is very large, but the size is meaningful.
It proves at least these distinct subfamilies.

| Test cluster | What it proves |
| --- | --- |
| Basic direct-call cases | Trivial unused params, interleaved used/unused params, caller-used vs callee-unused splits |
| Recursive cycles | Self-recursive and mutually recursive forwarding cycles can be optimized out when there is no external use |
| Cycle blockers | If any value in the cycle is used elsewhere, the whole relevant forwarding chain stays live |
| `call_ref` / `call_indirect` families | Root-type-tree reasoning, indirect/reference-call operand removal, and the need for closed-world + GC referenced-function mode |
| Referenced vs unreferenced functions | Shared-type trees require global rewrite plus separate handling for referenced and unreferenced siblings |
| Replacement-type regressions | Public brands, self-recursive signatures, inhabited vs uninhabited collisions, and “do not rewrite the wrong sibling” cases |
| Public / continuation / tag boundaries | Why some referenced function-type trees must remain unrewritten |
| `call.without.effects` and JS-called surfaces | Current blocker families rather than missing tests |
| Tuple / control / effect cases | `tuple.extract` conservatism, `if`-condition use, loop preservation, and effect-order correctness |
| Expression-removal regressions | Preventing duplicated effects or broken labels when removing forwarded trees |
| Nondefaultable-local regression | The fixup/order dependency when params are removed and local indices shift |

## What I did **not** treat as the main oracle

I did not treat the plain `dae` or `dae-optimizing` lit files as the core oracle for this folder.
They are useful only for contrast.

That is the reverse of how the plain-`dae` folder treats `dae2.wast`.
Each family needs its own home.

## Source reading order for future contributors

If someone needs to re-derive `dae2` quickly, the easiest order is:

1. `pass.cpp`
   - confirm `dae2` is public and separate;
2. the top comment in `DeadArgumentElimination2.cpp`
   - learn the intended algorithm and current non-goals;
3. `FunctionInfo` and `RootFuncTypeInfo`
   - learn the real state model;
4. `GraphBuilder`
   - learn how usage and forwarding are discovered;
5. `prepareReverseGraph()` and `computeFixedPoint()`
   - learn the core analysis algorithm;
6. `optimize()` plus `Optimizer`
   - learn the visible rewrite surface;
7. `makeUnreferencedFunctionTypes(...)`
   - learn the replacement-type mechanism;
8. the main sections of `dae2.wast`
   - connect the design to concrete before/after shapes.

## Porting checklist distilled from the file map

A faithful port should not stop at “find unused params and remove them.”
It needs to preserve:

- backward fixed-point use propagation,
- forwarding through pure wrapper expressions,
- `LazyLocalGraph`-based incoming-value reasoning,
- direct vs root-type-tree indirect forwarding,
- import/export/`ref.func`/public/continuation/tag blockers,
- the `closedWorld && GC` referenced-function mode split,
- expression-tree removal that preserves effects and structure,
- global referenced-function type repair,
- replacement types for unreferenced siblings,
- and the current non-goals around results/constants/type propagation.

## Source bridge update

The 2026-04-25 source bridge adds an immutable source manifest and Starshine status page:

- [`../../../raw/binaryen/2026-04-25-dae2-primary-sources.md`](../../../raw/binaryen/2026-04-25-dae2-primary-sources.md)
- [`../../../raw/research/0337-2026-04-25-dae2-source-bridge.md`](../../../raw/research/0337-2026-04-25-dae2-source-bridge.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)

The source map above remains the same; the new files close the provenance and local-follow-along gap rather than changing the upstream algorithm.
