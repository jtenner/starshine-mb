---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./effects-loops-and-hoisting-rules.md
  - ./wat-shapes.md
---

# Upstream implementation structure and tests for `loop-invariant-code-motion`

## Main source files

## `src/passes/LoopInvariantCodeMotion.cpp`

This is the real contract source.
It owns:

- loop discovery
- per-loop side-effect collection
- candidate-interest filtering
- recursive hoistability checks
- temp-local materialization
- fixed-point iteration

If a future port diverges from upstream behavior, this file is the first place to compare.

## `src/passes/pass.cpp`

This file proves two important public-interface facts:

- upstream public pass name: `licm`
- the pass is registered as a normal public Binaryen pass rather than a hidden helper mode

This is also the main proof that the local Starshine registry name is an aliasing mismatch rather than the official upstream spelling.

## `src/passes/pass.h`

This file matters less semantically, but it confirms the normal pass integration surface and helps separate “real public pass” from “local wiki nickname.”

## Important helper headers

## `src/ir/effects.h`

This is the semantic safety backbone.
LICM depends on effect reasoning to avoid moving expressions earlier when that would change memory/call/trap behavior.

## `src/ir/find_all.h`

Used for loop discovery.
This is the clean source-level clue that LICM begins with explicit loop collection rather than trying to infer loops incidentally during a generic walk.

## `src/ir/parents.h`

Used to track or repair structural context during rewriting.
That matters because hoisting is not just a value proof; it also edits the actual tree shape.

## What the official lit file proves

## `test/lit/passes/licm.wast`

This is the main shipped behavior surface for the pass.
It is especially valuable because it shows what upstream considers part of LICM's public contract, not just what happens to fall out of one implementation revision.

From the reviewed lit coverage, the durable things to look for are:

- simple loop-invariant arithmetic positives
- cases where one round of hoisting enables another
- temp-local style rewrites rather than expression duplication
- side-effect or trap-sensitive non-moves
- loop-carried or memory-sensitive bailout families

The lit file should be treated as the canonical beginner-facing oracle for positive and negative shape families.

## File responsibility map

| File | Why it matters |
| --- | --- |
| `LoopInvariantCodeMotion.cpp` | Main algorithm, legality proof, rewrite strategy, fixed-point behavior |
| `pass.cpp` | Official public registration name `licm` |
| `pass.h` | Public pass integration surface |
| `effects.h` | Effect and trap-safety reasoning backbone |
| `find_all.h` | Explicit loop discovery helper |
| `parents.h` | Structural context and rewrite support |
| `test/lit/passes/licm.wast` | Shipped positive/bailout public behavior surface |

## Current-main spot check

A narrow current-main comparison showed:

- the same public registration name `licm`
- materially the same main implementation structure in `LoopInvariantCodeMotion.cpp`

So for the surfaces reviewed in this dossier, `version_129` still looks like a trustworthy oracle.

## What is easy to misunderstand from the file list alone

## 1. LICM is not mostly about loop analysis infrastructure

The helper files matter, but the pass is still very much a semantic motion pass.
The hard part is not finding loops.
The hard part is proving early evaluation is safe.

## 2. The effect header matters more than a beginner might expect

A common first guess is that LICM is mostly about syntactic invariance.
The source layout says otherwise: effect reasoning is central.

## 3. The test file is more important than the pass name

The public name `licm` sounds like a generic compiler textbook pass.
The shipped lit file shows the actual Binaryen contract is smaller and more conservative.

## Future porting checklist

Before implementing this pass in Starshine, re-check at least:

- `LoopInvariantCodeMotion.cpp`
- `pass.cpp`
- `effects.h`
- `test/lit/passes/licm.wast`

That is the smallest review surface that still preserves the real contract.

## Sources

- [`../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md`](../../../raw/research/0173-2026-04-21-loop-invariant-code-motion-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LoopInvariantCodeMotion.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/parents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/licm.wast>
