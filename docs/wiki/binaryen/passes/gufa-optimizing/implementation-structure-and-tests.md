---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md
  - ../../../raw/research/0311-2026-04-24-gufa-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0189-2026-04-21-gufa-optimizing-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./cleanup-rerun-contract.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../gufa/index.md
---

# `gufa-optimizing` implementation structure and tests

## Upstream source rule

Use Binaryen `version_129` as the main source oracle for this page. The captured source set lives in [`../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-24-gufa-optimizing-primary-sources.md).

Primary online sources:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GUFA.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/possible-contents.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-optimizing.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gufa-cast-all.wast>

## File map

| File | Why it matters for this exact pass |
| --- | --- |
| `src/passes/GUFA.cpp` | Defines the shared GUFA pass engine, the `optimizing` / `castAll` flags, and the exact optimizing-only branch in `visitFunction` that runs nested `dce` and `vacuum`. |
| `src/passes/pass.cpp` | Registers public pass names `gufa`, `gufa-cast-all`, and `gufa-optimizing`, with `gufa-optimizing` described as GUFA plus local optimizations in modified functions. |
| `src/ir/possible-contents.h` | Defines `ContentOracle` and the possible-content lattice the sibling still depends on. |
| `test/lit/passes/gufa-optimizing.wast` | Dedicated proof that this sibling owns a real cleanup contract rather than a cosmetic alias. |
| `test/lit/passes/gufa.wast` | Baseline comparison surface for what plain GUFA already rewrites before the optimizing cleanup difference. |
| `test/lit/passes/gufa-cast-all.wast` | Contrast file proving that the other public sibling changes cast insertion instead of cleanup scheduling. |

## Public registration

`pass.cpp` exposes all three public family names:

- `gufa`,
- `gufa-cast-all`,
- `gufa-optimizing`.

That registration matters because the sibling is not an internal test-only mode. It is a public pass whose identity is GUFA plus local cleanup in functions it modified.

## Shared-engine construction

The bottom of `GUFA.cpp` exposes separate factories that instantiate the same class with different flags:

- plain `gufa`: not optimizing, not cast-all;
- `gufa-optimizing`: optimizing, not cast-all;
- `gufa-cast-all`: not optimizing, cast-all.

This is the simplest exact source proof that `gufa-optimizing` is a shared-engine variant, not a separate implementation file.

## Where the exact sibling behavior lives

The central source region is `visitFunction(Function* func)` in `GUFA.cpp`.

For a changed function, the important sequence is:

1. refinalize;
2. skip `addNewCasts` because this sibling has `castAll = false`;
3. repair EH nested pops;
4. create a nested pass runner;
5. add `dce`;
6. add `vacuum`;
7. run those passes on the changed function.

For an unchanged function, the cleanup branch is not reached.

## What `possible-contents.h` contributes here

`gufa-optimizing` does not get new cleanup-specific analysis. It still relies on the same `ContentOracle` result families as plain GUFA:

- impossible / no contents,
- one materializable value,
- known global or function identity,
- cone-like reference-type information,
- many / unknown fallback.

That means the sibling split is not in the oracle. It is in `GUFA.cpp` after rewriting.

## What the dedicated lit file proves

`gufa-optimizing.wast` runs both:

- `wasm-opt --gufa`,
- `wasm-opt --gufa-optimizing`.

The test compares plain-GUFA output with optimizing output. The core shape is a helper returning a known `i32` through nested result blocks.

Plain `gufa` proves the value but can leave nested drop/block residue. `gufa-optimizing` reduces the same function to the effect-preserving call drop plus the known constant. That proves the semantic difference comes from post-rewrite cleanup, not extra inference power.

## Why the sibling tests still matter

- `gufa.wast` teaches the larger shared rewrite surface: constants, globals, unreachable, `ref.eq`, `ref.test`, and existing `ref.cast` refinement.
- `gufa-cast-all.wast` proves the separate fresh-cast insertion story that this sibling intentionally does not own.

Read the three lit files together when porting the family.

## Current-main spot check

The 2026-04-24 source capture rechecked current `main` on the owner-file, registration, oracle, and dedicated lit-test surfaces. No teaching-relevant drift was found against the `version_129` story on those reviewed surfaces.

## Porting checklist this page suggests

Before calling a future Starshine port done, verify that it preserves:

- public pass-name handling;
- shared analysis and first-phase rewrite behavior with plain `gufa`;
- the mutation gate;
- refinalization / validation before cleanup;
- EH or equivalent control-stack repair before cleanup;
- nested cleanup order: `dead-code-elimination`, then `vacuum`;
- changed-functions-only cleanup scope;
- the explicit split from `gufa-cast-all`.
