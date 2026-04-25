---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
  - ../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
---

# Binaryen strategy for `strip-target-features`

## Source-backed contract

Binaryen's `strip-target-features` is a tiny output-option pass.
The owner file's teaching-level contract is:

- `modifiesBinaryenIR() == false`;
- `run(PassRunner*, Module*)` does not inspect or mutate the `Module`;
- the pass sets `runner->options.emitTargetFeatures = false`.

That is the whole strategy.
It is deliberately not an AST walker, not a module graph analysis, and not a post-lowering feature rewrite.

## Why the pass is option state, not IR state

The `target_features` section is emitted metadata.
Binaryen can decide at write time whether to include it, so stripping it does not require touching functions, expressions, type definitions, or imports.

This explains why `modifiesBinaryenIR() == false` is not a minor optimization detail.
It is the correctness boundary:

1. the in-memory module remains unchanged;
2. later output sees `emitTargetFeatures = false`;
3. the target-features custom section is omitted from emitted binary output.

## What is preserved

A correct reading of the pass preserves all actual wasm semantics:

- instruction bodies;
- function signatures and locals;
- type, import, table, memory, global, tag, element, data, export, and start sections;
- ordinary custom sections other than the target-feature emission controlled by Binaryen;
- proposal feature uses in the code.

If the module contains relaxed SIMD, GC, memory64, exception handling, strings, or any other feature, this pass does not remove those uses.
It only removes the metadata that advertises features.

## Pipeline role

The file header frames the pass as size-oriented cleanup for tools that already know their target and do not need the feature metadata in the final artifact.
That implies two practical rules:

- run it late, near output production;
- do not put it in an optimization pipeline as if it makes the code smaller through IR simplification.

The byte-size win is only the removed metadata section.

## What this pass is not

Do not teach `strip-target-features` as any of these:

- **not [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md):** it does not clear Binaryen code annotations such as `removableIfUnused` or `idempotent`;
- **not [`remove-relaxed-simd`](../remove-relaxed-simd/index.md):** it does not rewrite feature-using opcodes to traps;
- **not memory64/table64 lowering:** it does not repair index widths;
- **not validation repair:** removing the metadata cannot make an unsupported feature valid on an older engine;
- **not a generic custom-section stripper:** the source-backed behavior is specifically `emitTargetFeatures = false`.

## Main caveat

The source-level contract is clearer than the release-note provenance.
The reviewed `version_129` and current-`main` source files expose the pass and its behavior, but the reviewed changelog pages did not provide a clean `strip-target-features` addition note.
Use the owner file and pass registration as the oracle until a future source-confirmation run finds the exact introductory commit or release note.
