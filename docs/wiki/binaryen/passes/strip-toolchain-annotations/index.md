---
kind: entity
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md
  - ../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/wast/parser.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../instrument-locals/index.md
  - ../global-effects/index.md
  - ../duplicate-function-elimination/index.md
  - ../strip-target-features/index.md
  - ../late-pipeline-dispatch.md
---

# `strip-toolchain-annotations`

## Role

`strip-toolchain-annotations` is a real public Binaryen pass that removes Binaryen/toolchain-specific code annotations after the toolchain has finished using them.
It is currently **upstream-only** in Starshine:

- it is not listed as active, boundary-only, or removed in `src/passes/optimize.mbt`;
- explicit local pass requests fail as `unknown pass flag strip-toolchain-annotations`;
- it is outside the canonical no-DWARF `-O` / `-Os` path and the saved generated-artifact `-O4z` queue;
- `agent-todo.md` has no dedicated slice for it today.

This folder exists because the late-pass chronology already mentioned `--strip-toolchain-annotations` as a newer upstream addition, but the wiki had no beginner-facing explanation, no transformed-shape catalog, no immutable primary-source manifest, and no precise Starshine status page.
The 2026-04-26 port-readiness update found no teaching-relevant Binaryen `main` drift from the earlier source contract and now makes the safe Starshine first slice explicit: a module pass over local `FuncAnnotationSec`, while full Binaryen parity remains blocked on an expression-annotation model.

## Beginner summary

A good beginner mental model is:

- Binaryen can attach extra annotations that help Binaryen or a producer toolchain optimize or reason about a module.
- Those annotations are not wasm execution semantics.
- `strip-toolchain-annotations` removes the Binaryen-owned annotation families that VMs do not need.
- It deliberately preserves unrelated metadata annotations such as `@metadata.code.inline`.

So this pass is best taught as:

- **toolchain metadata cleanup**;
- not a code optimizer;
- not a name/custom-section stripper in general;
- not the same thing as `strip-debug`, `strip-producers`, or [`strip-target-features`](../strip-target-features/index.md).

## Inputs and outputs

### Input

The input may contain Binaryen code annotations such as:

- `@binaryen.removable.if.unused`
- `@binaryen.idempotent`
- `@binaryen.js.called`

The input may also contain non-toolchain metadata annotations such as `@metadata.code.inline`.

### Output

The output keeps the same functions and expressions, but toolchain-specific annotation bits are cleared.
If an expression annotation entry becomes empty after the cleared bits are removed, Binaryen erases that annotation entry.
Non-toolchain metadata annotations remain.

## Correctness constraints

- **No expression semantics change:** the pass should not alter instructions, control flow, locals, globals, imports, or exports.
- **Only Binaryen/toolchain annotations:** do not strip arbitrary annotations just because they are metadata.
- **Preserve `@metadata.code.inline`:** the official lit file uses this as a direct negative check.
- **Clean empty entries:** if all removed bits disappear from an expression annotation entry, the empty wrapper should go too.
- **Run late:** stripping too early would remove information that earlier Binaryen passes may still consume.

## Notable edge cases

- A single annotation entry can contain both removed and preserved bits.
- `@binaryen.js.called` is source-backed as removed, but the reviewed dedicated lit file does not isolate it directly.
- Starshine stores function/import annotations in `FuncAnnotationSec`, but it does not currently expose Binaryen's full per-expression `codeAnnotations` model.
- A first local implementation should strip only supported function/import annotation entries and must call that out as a subset until expression annotations exist.
- Binary output support for the same annotation surface should be source-confirmed locally before a future port promises binary-roundtrip parity.

## Validation strategy

For Binaryen parity research, start with the official lit file:

- `test/lit/passes/strip-toolchain-annotations.wast`

For a future Starshine port, add tests in this order:

1. `@binaryen.removable.if.unused` is removed from an annotated expression or function surface supported locally;
2. `@binaryen.idempotent` is removed;
3. `@binaryen.js.called` is removed if the local surface models it;
4. `@metadata.code.inline` is preserved;
5. mixed removed-plus-preserved annotation entries keep only the preserved payload;
6. an empty annotation entry disappears;
7. the pass remains absent from optimize/shrink presets unless there is a deliberate product decision to expose it;
8. function-import and function-definition annotation indices remain correct when neighboring module passes rewrite imports/functions.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and official test surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after annotation-shape catalog.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) - future Starshine first slice, validation ladder, and full-parity blockers.

## Sources

- [`../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md`](../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md)
- [`../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md`](../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md)
- [`../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md`](../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md)
- Binaryen `StripToolchainAnnotations.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripToolchainAnnotations.cpp>
- Binaryen lit file: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/strip-toolchain-annotations.wast>
