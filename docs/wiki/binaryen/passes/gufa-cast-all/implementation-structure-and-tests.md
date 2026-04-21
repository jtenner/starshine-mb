---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0190-2026-04-21-gufa-cast-all-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cast-insertion-exactness-and-boundaries.md
  - ./wat-shapes.md
  - ../gufa/index.md
  - ../gufa-optimizing/index.md
---

# `gufa-cast-all` implementation structure and tests

## Upstream source rule

Use Binaryen `version_129` as the main source oracle for this page.

Primary sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>

## File map

| File | Why it matters for this exact pass |
| --- | --- |
| `src/passes/GUFA.cpp` | Defines the shared pass engine and the exact cast-all-only branch in `visitFunction` that runs `addNewCasts(func)` |
| `src/passes/pass.cpp` | Registers the public pass name `gufa-cast-all` and its one-line public description |
| `src/ir/possible-contents.h` | Defines `ContentOracle`, the whole-program lattice/oracle the sibling still depends on |
| `test/lit/passes/gufa-cast-all.wast` | Dedicated proof that this sibling owns a real cast-insertion contract rather than being a cosmetic alias |
| `test/lit/passes/gufa.wast` | Baseline comparison surface for what plain GUFA already rewrites before the cast-all difference |
| `test/lit/passes/gufa-optimizing.wast` | Helpful contrast file proving that the other public sibling changes cleanup scheduling instead of cast insertion |

## Public registration

`pass.cpp` exposes:

- `gufa`
- `gufa-cast-all`
- `gufa-optimizing`

That registration fact alone is already important:

- `gufa-cast-all` is a real public surface
- it is not a hidden tuning flag

## Shared-engine construction

The bottom of `GUFA.cpp` exposes three factories:

- `createGUFAPass()` => `new GUFAPass(false, false)`
- `createGUFAOptimizingPass()` => `new GUFAPass(true, false)`
- `createGUFACastAllPass()` => `new GUFAPass(false, true)`

This is the simplest exact source proof that `gufa-cast-all` is a shared-engine variant, not a separate implementation file.

## Where the exact sibling behavior lives

The important pieces are split across a few small source regions.

### 1. Shared visitor and family state in `GUFA.cpp`

The shared visitor stores:

- `ContentOracle& oracle`
- `bool optimizing`
- `bool castAll`
- function-level change state

For this sibling, the key flags are:

- `optimizing = false`
- `castAll = true`

### 2. `visitFunction(Function* func)`

This is the central source region for the sibling.
It performs, in order:

1. `ReFinalize()` if the common GUFA phase changed anything
2. optionally `addNewCasts(func)` if `castAll`
3. `EHUtils::handleBlockNestedPops(...)` after any real rewrite
4. optionally run nested `dce` and `vacuum` if `optimizing`

For `gufa-cast-all`, step 2 is the sibling identity and step 4 is intentionally skipped.

### 3. `possible-contents.h`

This file matters because it confirms that the sibling does **not** have a separate inference engine.
The same `PossibleContents` / `ContentOracle` machinery is used across the family.

### 4. `gufa-cast-all.wast`

This is the dedicated public behavior surface.
Without it, it would be too easy to collapse the sibling into a footnote inside `gufa`.

## What `possible-contents.h` contributes here

`gufa-cast-all` does not get new cast-specific analysis.
It still relies on the same `ContentOracle` result kinds as plain `gufa`:

- `None`
- `Literal`
- `GlobalInfo`
- `ConeType`
- `Many`

That is important because it means the sibling split is **not** in the analysis file.
It is in the post-rewrite phase in `GUFA.cpp`.

## What the dedicated lit file proves

## `gufa-cast-all.wast`

This file is the strongest direct proof that the sibling has its own public contract.
It exercises the exact families a beginner might otherwise lose:

- adding new casts where plain GUFA would stop
- exact-versus-inexact cast-target behavior
- castability and feature boundaries
- preserved no-op cases where the oracle knows more but Binaryen still leaves the IR alone

### What this proves about the pass

The file proves at least four durable facts:

1. `gufa-cast-all` is not just “plain GUFA, maybe with better cleanup.”
2. the sibling's visible effect is new cast insertion
3. exactness is still constrained by feature/legality rules
4. some candidate expressions remain intentionally unchanged

## Why `gufa.wast` still matters

The dedicated cast-all file is small on purpose.
To understand what the sibling is building on, you still need the broader plain-GUFA surface in `gufa.wast`:

- constant propagation through calls/locals/globals
- unreachable proofs
- `ref.eq` intersection reasoning
- `ref.test` cone reasoning
- existing `ref.cast` refinement

So the exact implementation story is:

- `gufa.wast` teaches what the shared engine can prove and rewrite directly
- `gufa-cast-all.wast` teaches what this sibling does **after** those proofs become rewrites

## Why `gufa-optimizing.wast` is still relevant

That other sibling file makes the contrast sharper.
It proves that the alternate public variant changes cleanup scheduling instead of cast insertion.

That is useful because a reader could otherwise wrongly assume the two siblings are just different “aggressiveness” modes.
They are not.
They change different phases.

## Current-main spot check

For this dossier, the following public surfaces were checked as freshness guards:

- `src/passes/GUFA.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/gufa-cast-all.wast`

On the reviewed surfaces, current `main` still matched the `version_129` behavior this dossier teaches closely enough that the tagged release remains a stable oracle for the sibling.
That is a reviewed-surface inference, not a full-file identity proof.

## Porting checklist this page suggests

Before calling a future port “done,” verify that it preserves:

- the exact public pass name
- the shared analysis and first rewrite engine with plain `gufa`
- the `castAll` gate as the sibling identity
- refinalization before new-cast insertion
- feature-sensitive exactness behavior
- EH nested-pop repair after real rewrites
- the deliberate absence of nested `dce` + `vacuum`
- the explicit split from both `gufa` and `gufa-optimizing`
