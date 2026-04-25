---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
  - ../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `strip-target-features` implementation structure and validation surface

## Owner files

### `src/passes/StripTargetFeatures.cpp`

This is the whole pass owner in Binaryen `version_129`.
It is intentionally small:

- declares the `StripTargetFeatures` pass;
- reports `modifiesBinaryenIR() == false`;
- runs by setting `runner->options.emitTargetFeatures = false`.

There is no walker, no child localizer, no refinalization, no effect analysis, and no helper rewrite.

### `src/passes/pass.cpp`

This file registers the public pass name:

- `strip-target-features`

The public description is about stripping the target-features section from output.
That description matches the owner file's output-option behavior.

### `src/passes/passes.h`

This file declares the constructor:

- `createStripTargetFeaturesPass()`

The pass is part of the normal public pass-constructor roster even though its implementation is option-only.

## Test and validation notes

The strongest durable oracle for this dossier is the owner file plus registration because the pass's behavior is smaller than most Binaryen transformations.
A faithful validation should prove two facts:

1. output with target-feature emission enabled contains the feature metadata before the pass;
2. equivalent output after `strip-target-features` omits that metadata while preserving the executable module.

This dossier does not treat a specific test filename as canonical for `version_129` because the source-tagged test surface should be rechecked before implementation signoff.
Future Starshine implementation work should cite the exact upstream fixture revision it uses.

## What tests should not assert

Do not write tests that expect any of the following from Binaryen's `strip-target-features`:

- instruction removal;
- feature lowering;
- validation repair;
- removal of arbitrary custom sections;
- removal of Binaryen toolchain annotations;
- changes to the in-memory module after the pass, before output is emitted.

## Practical source-reading checklist

When reviewing future drift, check these questions in order:

1. Does `StripTargetFeatures.cpp` still return `modifiesBinaryenIR() == false`?
2. Does `run(...)` still only toggle `emitTargetFeatures`?
3. Does `pass.cpp` still register the public name `strip-target-features`?
4. Does `passes.h` still expose `createStripTargetFeaturesPass()`?
5. If tests moved, do they still prove whole-section omission without semantic module changes?

If any answer changes, update this page and [`binaryen-strategy.md`](binaryen-strategy.md) together.
