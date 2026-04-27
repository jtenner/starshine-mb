---
kind: entity
status: supported
last_reviewed: 2026-04-27
sources:
  - ../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md
  - ../../../raw/research/0419-2026-04-27-type-refining-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md
  - ../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../tracker.md
  - ../index.md
  - ../global-refining/binaryen-strategy.md
  - ../remove-unused-types/binaryen-strategy.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./normal-vs-gufa-and-fixups.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../tracker.md
  - ../index.md
  - ../global-refining/index.md
  - ../remove-unused-types/index.md
---

# `type-refining`

## Role

- `type-refining` is an upstream Binaryen **module pass**.
- It is currently **unimplemented** in Starshine and still lives in the boundary-only registry in [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt).
- The exact local status and future port map live in [`./starshine-strategy.md`](./starshine-strategy.md): no owner file, no active preset role, no active backlog slice, and no separately registered `type-refining-gufa` sibling today.
- The implementation-readiness ladder now lives in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md): analyzer-first scope, first mutating slice, shape-to-validation checklist, Binaryen oracle lanes, and local code surfaces.
- In Binaryen `version_129`, the public pass summary in `pass.cpp` is:
  - `apply more specific subtypes to type fields where possible`

That summary is true, but too vague.

A better beginner summary is:

- Binaryen looks at what values are actually written into **private struct fields**,
- tightens those field types when the whole closed-world module proves a narrower type is enough,
- and then repairs the affected reads and writes so the rewritten module still validates.

So this is not generic type optimization.
It is **closed-world private struct-field refinement plus read/write repair**.

## Why this pass matters

- The main no-DWARF / saved-`-O4z` parity queue is now fully dossier-covered, so this campaign needs another eligible pass from the tracker's upstream-only registry table.
- `type-refining` is already named in the local boundary-only registry, so this is a real Starshine-facing pass name.
- The current `global-refining` dossier already records it as the first closed-world GC/type-tightening neighbor before `signature-pruning`, `signature-refining`, and `global-refining`.
- The pass already had a living dossier and Starshine status bridge; the 2026-04-27 refresh adds the missing implementation-readiness bridge so future work can start from a safe analyzer-first plan instead of a one-shot type-section rewrite.
- The official implementation hides several teaching traps that deserve a stable wiki home:
  - upstream ships both `type-refining` and `type-refining-gufa`
  - the pass body itself requires `--closed-world`
  - the normal variant infers only from direct struct traffic plus limited fallthrough copies
  - reads do not constrain inference, so fixups are mandatory later
  - public types are frozen
  - arrays are still TODO here

## Most important durable takeaways

- `type-refining` is **not** part of the repo's main open-world no-DWARF `-O` / `-Os` path.
- The default scheduler places it only in the **closed-world GC/type cluster** before `global-refining`.
- The pass body itself checks only:
  - GC features enabled
  - `--closed-world`
- The base pass refines **struct fields**, not arrays.
- Ordinary reads do **not** constrain the inferred field type here.
- The normal pass and the upstream companion pass `type-refining-gufa` share the same rewrite/fixup back end, but they use different inference front ends.
- Public struct types stay unchanged in this pass.
- The repair steps are part of the real contract:
  - explicit `struct.get` repair
  - `GlobalTypeRewriter` type rewriting
  - `ReFinalize`
  - `struct.new` / `struct.set` / RMW / cmpxchg cast or trap repair

## Beginner warning: what the name hides

The easy wrong mental model is:

- Binaryen looks at types in general and makes them narrower where it can.

The safer mental model is:

- Binaryen infers what gets written into **private struct fields**,
- preserves subtype legality across the struct hierarchy,
- refuses to edit public types,
- rewrites the private type declarations,
- then repairs reads and writes that the new field types would otherwise invalidate.

That difference matters a lot.

## What the pass sounds like versus what it actually does

What it sounds like:

- a broad type-tightening cleanup pass

What it actually is in `version_129`:

- a closed-world, GC-only module pass with:
  - a normal direct-struct-traffic inference mode
  - an upstream GUFA-backed whole-program inference mode
  - public/private legality handling
  - hierarchy-aware field-LUB propagation
  - explicit read invalidation handling
  - `GlobalTypeRewriter`-based struct-type rewriting
  - `ReFinalize` plus write-site cast/null/unreachable repair

## Page map

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
  - Deep dive into the actual Binaryen `version_129` implementation, helper dependencies, scheduler placement, main phases, and the exact rewrite/fixup contract.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
  - File map for `TypeRefining.cpp`, `pass.cpp`, `struct-utils.h`, `lubs.h`, `possible-contents.h`, `type-updating.h`, and the dedicated lit family, plus the narrow current-`main` freshness note.
- [`./normal-vs-gufa-and-fixups.md`](./normal-vs-gufa-and-fixups.md)
  - Focused guide to the most easy-to-misread parts of the pass: normal vs GUFA inference, tee-vs-block fallthrough behavior, exactness and continuation restrictions, and why read/write fixups are mandatory.
- [`./wat-shapes.md`](./wat-shapes.md)
  - Beginner-friendly WAT-shape catalog covering direct subtype positives, nullability and copy families, tee-vs-block bailouts, public-type freezes, unreachable replacements, and GUFA-only wins.
- [`./starshine-strategy.md`](./starshine-strategy.md)
  - Current Starshine status and port map: boundary-only registry entry, honest request rejection, no owner file, no active backlog slice, local type/validation/binary surfaces, and the open `type-refining-gufa` naming question.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
  - Implementation-readiness bridge: no-rewrite analyzer first, narrow closed-world private-struct first mutation, shape-to-validation ladder, exact local code surfaces, Binaryen oracle lanes, and health guardrails.

## Current maintenance rule

- Treat this folder as the canonical home for future `type-refining` research in this repo.
- Keep this dossier clearly labeled as an **upstream-only boundary-only** pass for Starshine today.
- Keep the page honest about scheduler scope:
  - it belongs to Binaryen's closed-world GC/type cluster
  - it does **not** belong to the repo's current open-world no-DWARF optimize path
- Keep the distinction between `type-refining` and `type-refining-gufa` explicit.
- Keep any future current-`main` drift notes explicit instead of silently rewriting the `version_129` contract.
- Keep the analyzer-first sequencing and WAT `struct.set` fixture caveat from [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) visible until implementation work resolves them.

## Sources

- [`../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-type-refining-port-readiness-primary-sources.md)
- [`../../../raw/research/0419-2026-04-27-type-refining-port-readiness.md`](../../../raw/research/0419-2026-04-27-type-refining-port-readiness.md)
- [`../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md`](../../../raw/binaryen/2026-04-24-type-refining-primary-sources.md)
- [`../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md`](../../../raw/research/0303-2026-04-24-type-refining-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md`](../../../raw/research/0150-2026-04-21-type-refining-binaryen-research.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../tracker.md`](../tracker.md)
- [`../index.md`](../index.md)
- [`../global-refining/binaryen-strategy.md`](../global-refining/binaryen-strategy.md)
- [`../remove-unused-types/binaryen-strategy.md`](../remove-unused-types/binaryen-strategy.md)
- Binaryen `version_129` sources:
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
- Narrow freshness-check sources:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeRefining.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-exact.wast>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-refining-gufa-rmw.wast>
