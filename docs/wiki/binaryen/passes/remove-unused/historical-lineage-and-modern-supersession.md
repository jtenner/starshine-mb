---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-remove-unused-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md
  - ../../../raw/research/0494-2026-05-06-remove-unused-shape-catalog-and-current-main-recheck.md
  - ../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md
  - ../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md
  - ../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/index.md
---

# `remove-unused`: historical lineage and modern supersession

This is the easiest part of the local registry name to misread.

## The one fact to remember

`remove-unused` is **not** a current public Binaryen pass spelling.

The most useful source-backed interpretation, refreshed against immutable 2026-04-25, 2026-04-27, and 2026-05-06 raw-source manifests plus current-`main` registration spot checks, is:

- historical upstream pass: `remove-unused-functions`
- modern upstream replacement: `remove-unused-module-elements`
- local Starshine short name: `remove-unused`

## Why the short local name is dangerous

The short local name sounds broader than the historical upstream pass actually was.

A beginner might hear `remove-unused` and imagine:

- remove any kind of unused thing from the module

But the historical upstream implementation only removed:

- unreachable **functions**

That gap between the short name and the real old contract is why this page exists.

## Old upstream contract

Historical `remove-unused-functions`:

- rooted start
- rooted exported functions
- rooted all functions named in table segments
- followed direct calls
- deleted unreachable functions

That is all.

No globals.
No tables.
No memories.
No tags.
No function-type cleanup.
No reference-only reachability distinctions.

## Modern upstream contract

Modern `remove-unused-module-elements` is broader.

Even without repeating the entire RUME dossier, the key difference is enough:

- the modern pass works on multiple module declaration kinds
- it can prune or weaken more than just functions
- it has a much larger rewrite and index-remap surface

So the modern pass is a **replacement**, not just a rename in the trivial sense.

## Safe documentation rule

When a future page mentions local `remove-unused`, it should say one of these explicitly:

- “legacy alias of historical upstream `remove-unused-functions`”
- “superseded by modern `remove-unused-module-elements`”

And it should **not** simply say:

- “same as `remove-unused-module-elements`”

That shortcut is too lossy.

## Practical guidance for Starshine contributors

If your real goal is:

### current Binaryen parity

Then read:

- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md)

### historical registry cleanup or old-name archaeology

Then read this folder.

### non-function or GC-type cleanup

Then read:

- [`../remove-unused-non-function-elements/index.md`](../remove-unused-non-function-elements/index.md)
- [`../remove-unused-types/index.md`](../remove-unused-types/index.md)

## Best beginner summary

If someone remembers only one sentence from this page, it should be this:

> Local `remove-unused` is a legacy registry alias whose real upstream lineage is old function-only `remove-unused-functions`, later superseded by the broader `remove-unused-module-elements` pass.

## Sources

- [`../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-remove-unused-port-readiness-primary-sources.md)
- [`../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md`](../../../raw/binaryen/2026-04-25-remove-unused-primary-sources.md)
- [`../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md`](../../../raw/research/0420-2026-04-27-remove-unused-port-readiness.md)
- [`../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md`](../../../raw/research/0339-2026-04-25-remove-unused-source-bridge.md)
- [`../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md`](../../../raw/research/0195-2026-04-21-remove-unused-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
