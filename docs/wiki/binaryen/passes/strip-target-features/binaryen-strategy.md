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
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
---

# Binaryen strategy for `strip-target-features`

## Corrected source-backed contract

Binaryen's `strip-target-features` is a tiny module-metadata pass. The owner file's `version_129` and current-`main` contract is:

- `modifiesBinaryenIR() == true`;
- `run(PassRunner*, Module*)` does not inspect functions or expressions;
- `run(...)` clears the module metadata flag: `module->hasFeaturesSection = false`.

This corrects the older 2026-04-25 dossier, which incorrectly described the pass as setting `runner->options.emitTargetFeatures = false` and leaving Binaryen IR unmodified.

## Why the pass is module metadata, not instruction rewriting

The target-features section is output metadata. Binaryen keeps a module-level flag for whether that metadata should be present. Clearing the flag is enough to make later binary output omit the `target_features` custom section.

That explains the apparent tension in this pass:

1. the pass reports that it mutates Binaryen IR/module state;
2. the executable wasm program remains unchanged;
3. the later output loses only target-feature metadata.

For readers, “IR mutation” here means “module metadata flag mutation,” not “walk every function and rewrite instructions.”

## What is preserved

A correct reading of the pass preserves actual wasm semantics:

- instruction bodies;
- function signatures and locals;
- type, import, table, memory, global, tag, element, data, export, and start sections;
- ordinary custom sections other than the target-feature metadata controlled by the Binaryen flag;
- proposal feature uses in the code.

If the module contains relaxed SIMD, GC, memory64, exception handling, strings, or any other feature, this pass does not remove those uses. It only removes the metadata that advertises target features.

## Pipeline role

The file header frames the pass as size-oriented cleanup for tools that already know their target and do not need the feature metadata in the final artifact. That implies two practical rules:

- run it late, near output production;
- do not put it in an optimization pipeline as if it simplifies code.

The byte-size win is the removed metadata section.

## What this pass is not

Do not teach `strip-target-features` as any of these:

- **not [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md):** it does not clear Binaryen code annotations such as `removableIfUnused` or `idempotent`;
- **not [`remove-relaxed-simd`](../remove-relaxed-simd/index.md):** it does not rewrite feature-using opcodes to traps;
- **not memory64/table64 lowering:** it does not repair index widths;
- **not validation repair:** removing metadata cannot make an unsupported feature valid on an older engine;
- **not a generic custom-section stripper:** the source-backed behavior is specifically the target-features flag/section.

## Main caveat

The corrected source-level contract is clear for `version_129` and current `main`, but this run did not chase the exact introductory commit for `hasFeaturesSection`. Treat the 2026-04-26 source-correction manifest as the current oracle and treat the 2026-04-25 `emitTargetFeatures` wording as superseded.
