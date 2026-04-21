---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
---

# `type-refining`: implementation structure and tests

This page exists because `TypeRefining.cpp` is not a self-contained pass.
If you read only that one file, you will miss where most of the real behavior comes from.

## File map

| File | Why it matters |
| --- | --- |
| `src/passes/TypeRefining.cpp` | Core pass logic: gates the pass, splits normal vs GUFA inference, computes field LUBs, freezes public types, repairs reads, rewrites struct types, and repairs writes |
| `src/passes/pass.cpp` | Registers `type-refining` and `type-refining-gufa`, and places `type-refining` in the closed-world GC/type prepass cluster before `global-refining` |
| `src/ir/struct-utils.h` | Supplies `StructScanner`, exactness-aware `StructValuesMap`, and the hierarchy propagator used by the normal inference mode |
| `src/ir/lubs.h` | Defines `LUBFinder`, the tiny summary object used for per-field inferred contents |
| `src/ir/possible-contents.h` | Supplies `ContentOracle`, the whole-program inference engine used by `type-refining-gufa` |
| `src/ir/type-updating.h` | Holds `GlobalTypeRewriter` and `TypeUpdater` support, which make safe module-wide heap-type rewriting possible |
| `src/ir/module-utils.h` | Provides `ModuleUtils::getPublicHeapTypes` and heap-type collection helpers used for public/private legality decisions |
| `test/lit/passes/type-refining.wast` | Main contract surface for the normal pass |
| `test/lit/passes/type-refining-gufa.wast` | Main contract surface for the GUFA companion pass |
| `test/lit/passes/type-refining-gufa-exact.wast` | Exactness, custom-descriptor, and continuation restrictions for GUFA |
| `test/lit/passes/type-refining-gufa-rmw.wast` | Conservative behavior around RMW / cmpxchg and nearby array-adjacent surfaces |

## The real call graph

The core flow in `version_129` is short but layered.

### 1. `TypeRefining::run(Module* module)`

This pass method does four big things:

1. require GC and closed world
2. choose normal or GUFA inference to fill `finalInfos`
3. enforce public/private and hierarchy legality in `useFinalInfos(...)`
4. repair reads and writes if any struct field actually changed

### 2. `FieldInfoScanner` through `StructUtils::StructScanner`

The normal mode is mostly a specialized configuration of shared scanner infrastructure.
That shared scanner decides:

- which struct ops are seen
- how exactness is tracked
- how fallthrough wrappers are interpreted
- how per-function results are combined later

### 3. `ContentOracle`

The GUFA mode delegates inference to `ContentOracle` and then only adapts that oracle's answers into the same `finalInfos` structure the normal mode uses.

### 4. `GlobalTypeRewriter`

The pass does not rewrite private struct declarations manually.
It hands the final field decisions to a `GlobalTypeRewriter` subclass and lets shared type-rewrite logic rebuild the private heap-type graph consistently.

### 5. `ReFinalize` plus `WriteUpdater`

The pass depends on `ReFinalize` twice:

- once after changing struct declarations
- once more in certain functions if write repair had to introduce bottom/unreachable fixes

That is the main reason this pass is more than “change the field type declarations.”

## Why `TypeRefining.cpp` is deceptively small

The file is sizable, but still smaller than the behavior it owns.
That is because Binaryen has already pushed the hard reusable parts into helpers:

- shared struct-op scanning in `struct-utils.h`
- shared type rewriting in `type-updating.h`
- shared whole-program contents reasoning in `possible-contents.h`
- shared visibility analysis in `module-utils.h`

So the correct teaching model is:

- `TypeRefining.cpp` defines pass policy, phase order, and the final repair decisions
- the helper headers define most of the mechanics

## What the dedicated lit files prove

## 1. `type-refining.wast`

This is the main normal-pass contract.
It proves several important families:

- direct struct-set and struct-new subtype narrowing
- default-value nullability preservation
- copy families that do not block optimization
- tee / `br_if` fallthrough families that deliberately do block some optimization
- control-flow families that still optimize after refinalization
- explicit `struct.get` type repair and unreachable replacements
- public-type freezes and mutable-supertype equality
- bottom-type and uninhabited-field regressions

If you want to understand the base pass, this is the first test file to read.

## 2. `type-refining-gufa.wast`

This file exists because the GUFA companion is not just a spelling alias.
It proves that GUFA can refine through whole-program flows the normal pass misses, including:

- locals
- globals
- cross-function cycles
- situations where repeated ordinary optimization passes still do not converge to the same result

It also contains important regression families around globals, packed reads, continuations, and null/uninhabited repair.

## 3. `type-refining-gufa-exact.wast`

This file proves the exactness boundary story:

- GUFA may refine to exact field types when later casts are valid
- disabling custom descriptors can force it to stay inexact instead
- already-exact fields must remain exact
- continuation fields must not be pushed into invalid exact-cast territory

Without this file it would be very easy to overstate how aggressively GUFA can refine.

## 4. `type-refining-gufa-rmw.wast`

This file proves conservatism around atomic RMW / cmpxchg surfaces and nearby array-adjacent families.
That matters because `TypeRefining.cpp` itself still says:

- `TODO: handle arrays and not just structs`

So the pass today is still about struct fields, not generic aggregate refinement.

## The tests teach three especially important misconceptions to avoid

### Misconception 1: reads constrain inference

They do not.
The tests instead show that Binaryen repairs invalidated reads afterward.

### Misconception 2: GUFA and normal mode are the same pass with a different cost model

They are not.
The GUFA test file includes real optimization wins that normal mode cannot reproduce from direct scanning alone.

### Misconception 3: declaration rewriting is the whole job

It is not.
The lit output repeatedly shows:

- inserted `ref.cast`
- explicit `drop + unreachable`
- `ref.null bottom`-style repair
- updated `struct.get` result types

Those are part of the algorithm, not optional polish.

## Freshness note

I did a narrow current-`main` check on:

- `src/passes/TypeRefining.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/type-refining.wast`
- `test/lit/passes/type-refining-gufa.wast`
- `test/lit/passes/type-refining-gufa-exact.wast`
- `test/lit/passes/type-refining-gufa-rmw.wast`

Durable result:

- the checked core pass structure and dedicated lit surfaces still match `version_129` on the important reviewed surfaces

That is a narrow freshness note, not a proof that every neighboring helper file is identical.

## Porting checklist

A future Starshine port would need to mirror at least these file-level responsibilities:

- a boundary-only module-pass entry point, not a hot pass
- closed-world and GC gating
- a normal direct-struct-traffic inference path
- a clear decision on whether to also expose the GUFA companion surface
- hierarchy-aware field LUB propagation
- public/private heap-type legality handling
- explicit `struct.get` repair
- module-wide private-type rewriting
- post-rewrite refinalization
- post-rewrite write-site cast/null/unreachable repair

Any port that implements only the declaration rewrite without the helper-equivalent infrastructure will not match Binaryen's real behavior.

## Bottom line

For `type-refining`, the real implementation structure is:

- **two inference fronts + shared hierarchy legality + shared type rewriting + shared refinalization + dedicated lit family**

That is exactly why this pass is easy to underestimate from the name alone.

## Sources

- [`../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/struct-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/lubs.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/possible-contents.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/type-refining-gufa-rmw.wast>
- Narrow freshness check:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>
