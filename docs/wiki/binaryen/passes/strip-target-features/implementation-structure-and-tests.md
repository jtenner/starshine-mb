---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# `strip-target-features` implementation structure and validation surface

## Owner files

### `src/passes/StripTargetFeatures.cpp`

This is the whole pass owner in Binaryen `version_129` and current `main`. It is intentionally small:

- declares the `StripTargetFeatures` pass;
- reports `modifiesBinaryenIR() == true`;
- runs by setting `module->hasFeaturesSection = false`.

There is no walker, no child localizer, no refinalization, no effect analysis, and no helper rewrite.

The 2026-04-26 source correction is important: older wiki text said this pass reported `modifiesBinaryenIR() == false` and toggled `runner->options.emitTargetFeatures`. That was wrong for the checked official tag and current head.

### `src/passes/pass.cpp`

This file registers the public pass name:

- `strip-target-features`

The public description is about stripping the target-features section from output. That description matches the owner file's module-flag behavior.

### `src/passes/passes.h`

This file declares the constructor:

- `createStripTargetFeaturesPass()`

The pass is part of the normal public pass-constructor roster even though its implementation is much smaller than an expression transform.

### `src/wasm/wasm.h`

The module definition contains the `hasFeaturesSection` state that the pass clears. This state is more precise than a generic custom-section array: it records Binaryen's target-features metadata policy directly on the module.

## Test and validation notes

The strongest durable oracle for this dossier is the owner file plus registration because the pass behavior is smaller than most Binaryen transformations. A faithful validation should prove two facts:

1. output with target-feature metadata enabled contains the feature metadata before the pass;
2. equivalent output after `strip-target-features` omits that metadata while preserving executable sections.

A future implementation signoff should also explicitly prove the corrected internal contract: the observed output difference comes from clearing target-feature metadata, not from instruction, type, import, export, data, or arbitrary custom-section rewrites.

## What tests should not assert

Do not write tests that expect any of the following from Binaryen's `strip-target-features`:

- instruction removal;
- feature lowering;
- validation repair;
- removal of arbitrary custom sections;
- removal of Binaryen toolchain annotations;
- per-feature filtering inside a kept target-features section;
- `modifiesBinaryenIR() == false`.

## Practical source-reading checklist

When reviewing future drift, check these questions in order:

1. Does `StripTargetFeatures.cpp` still return `modifiesBinaryenIR() == true`?
2. Does `run(...)` still clear `module->hasFeaturesSection`?
3. Does `pass.cpp` still register the public name `strip-target-features`?
4. Does `passes.h` still expose `createStripTargetFeaturesPass()`?
5. If tests moved, do they still prove whole-section omission without semantic program changes?

If any answer changes, update this page, [`binaryen-strategy.md`](binaryen-strategy.md), and [`starshine-strategy.md`](starshine-strategy.md) together.
