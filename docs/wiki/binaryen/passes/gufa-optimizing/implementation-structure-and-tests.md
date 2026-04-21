---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ../gufa/index.md
---

# `gufa-optimizing` implementation structure and tests

## Upstream source rule

Use Binaryen `version_129` as the main source oracle for this page.

Primary sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

## File map

| File | Why it matters for this exact pass |
| --- | --- |
| `src/passes/GUFA.cpp` | Defines the shared pass engine and the exact optimizing-only branch in `visitFunction` that runs nested `dce` and `vacuum` |
| `src/passes/pass.cpp` | Registers the public pass name `gufa-optimizing` and its one-line public description |
| `src/ir/possible-contents.h` | Defines `ContentOracle`, the whole-program lattice/oracle the sibling still depends on |
| `test/lit/passes/gufa-optimizing.wast` | Dedicated proof that this sibling owns a real cleanup contract rather than a cosmetic alias |
| `test/lit/passes/gufa.wast` | Baseline comparison surface for what plain GUFA already rewrites before the optimizing cleanup difference |
| `test/lit/passes/gufa-cast-all.wast` | Helpful contrast file proving that the other public sibling changes cast insertion instead of cleanup scheduling |

## Public registration

`pass.cpp` exposes:

- `gufa`
- `gufa-cast-all`
- `gufa-optimizing`

The relevant registration text describes `gufa-optimizing` as:

- GUFA plus local optimizations in functions we modified

That public wording already points at the core contract:

- same GUFA proof engine
- extra local cleanup on modified functions

## Shared-engine construction

The bottom of `GUFA.cpp` exposes three factories:

- `createGUFAPass()` => `new GUFAPass(false, false)`
- `createGUFAOptimizingPass()` => `new GUFAPass(true, false)`
- `createGUFACastAllPass()` => `new GUFAPass(false, true)`

This is the simplest exact source proof that `gufa-optimizing` is a shared-engine variant, not a separate implementation file.

## Where the exact sibling behavior lives

The important pieces are split across a few small source regions.

### 1. Top-of-file comment in `GUFA.cpp`

The file comment says plain GUFA can increase code size by adding constants and unreachability, and that the optimizing variant will run followup opts automatically in functions where it makes changes.

That comment is effectively part of the public contract.

### 2. `GUFAOptimizer` state

The shared visitor stores:

- `ContentOracle& oracle`
- `bool optimizing`
- `bool castAll`
- `bool optimized`

For this sibling, the key flags are:

- `optimizing = true`
- `castAll = false`

### 3. `visitFunction(Function* func)`

This is the central source region for the sibling.
It performs, in order:

1. `ReFinalize()` if the pass changed anything
2. optional `addNewCasts(func)` only if `castAll`
3. early return if nothing changed
4. `EHUtils::handleBlockNestedPops(...)`
5. nested `PassRunner`
6. `runner.add("dce")`
7. `runner.add("vacuum")`
8. `runner.runOnFunction(func)`

That sequence is what future readers need to remember.

## What `possible-contents.h` contributes here

`gufa-optimizing` does not get new cleanup-specific analysis.
It still relies on the same `ContentOracle` result kinds as plain GUFA:

- `None`
- `Literal`
- `GlobalInfo`
- `ConeType`
- `Many`

That is important because it means the sibling split is **not** in the analysis file.
It is in the post-rewrite phase in `GUFA.cpp`.

## What the dedicated lit file proves

## `gufa-optimizing.wast`

This file runs both:

- `wasm-opt --gufa`
- `wasm-opt --gufa-optimizing`

and compares the output with `NO_OPT` vs `DO_OPT` expectations.

The file's core test module has:

- a helper `foo` returning `i32.const 1`
- a wrapper `bar` using nested result blocks around `call $foo`

### What `NO_OPT` proves

Plain `gufa` proves the return value is `1`, but leaves nested `drop` and `block` structure in the output.
That is the cleanup debt plain GUFA is allowed to leave behind.

### What `DO_OPT` proves

The optimizing sibling reduces the same rewritten function to a much smaller result:

- `drop (call $foo)`
- `i32.const 1`

That proves two things at once:

1. `gufa-optimizing` is a real public semantic surface
2. the semantic difference comes from post-rewrite cleanup, not extra inference power

## Why `gufa.wast` still matters

The dedicated optimizing file is small on purpose.
To understand what the sibling is cleaning up, you still need the broader plain-GUFA surface in `gufa.wast`:

- constant propagation through calls/locals/globals
- unreachable proofs
- `ref.eq` intersection reasoning
- `ref.test` cone reasoning
- `ref.cast` refinement

So the exact implementation story is:

- `gufa.wast` teaches what the shared engine can prove
- `gufa-optimizing.wast` teaches what this sibling does **after** those proofs become rewrites

## Why `gufa-cast-all.wast` is still relevant

That other sibling file makes the contrast sharper.
It proves that the alternate public variant changes the cast-insertion surface instead of scheduling nested cleanup.

That is useful because a reader could otherwise wrongly assume the two siblings are just different “aggressiveness” modes.
They are not.
They change different phases.

## Current-main spot check

For this dossier, the following public surfaces were checked as freshness guards:

- `src/passes/GUFA.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/gufa-optimizing.wast`

On the reviewed surfaces, current `main` still matched the `version_129` behavior this dossier teaches.
So the tagged release remains a stable oracle for this sibling.

## Porting checklist this page suggests

Before calling a future port “done,” verify that it preserves:

- the exact public pass name
- the shared analysis and rewrite engine with plain `gufa`
- the `optimized` gate
- refinalization before cleanup
- EH nested-pop repair before cleanup
- nested `dce` then `vacuum`
- changed-functions-only cleanup scope
- the explicit split from `gufa-cast-all`
