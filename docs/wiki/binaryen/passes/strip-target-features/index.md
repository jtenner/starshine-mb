---
kind: entity
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
  - ../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/binary/encode.mbt
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
  - ../late-pipeline-dispatch.md
---

# `strip-target-features`

## Role

`strip-target-features` is a public Binaryen pass that suppresses emission of the `target_features` custom section in later output.
It is currently **upstream-only** in Starshine:

- it is not listed as active, boundary-only, or removed in `src/passes/optimize.mbt`;
- explicit local pass requests fail as `unknown pass flag strip-target-features`;
- it is outside the canonical no-DWARF `-O` / `-Os` path and the saved generated-artifact `-O4z` queue;
- `agent-todo.md` has no dedicated slice for it today.

This folder exists because the late-pass chronology already mentioned `strip-target-features`, but the wiki still treated it as a catalog-level name rather than a pass with a source-backed contract, shape guide, and Starshine status map.

## Beginner summary

A good beginner mental model is:

- WebAssembly binaries may contain custom sections that do not execute as wasm instructions.
- Binaryen can emit a `target_features` custom section so downstream tools know which wasm features the module expects or uses.
- `strip-target-features` turns that emission off.
- It does **not** rewrite functions, instructions, types, imports, exports, memories, tables, globals, or data.

So this pass is best taught as:

- **output metadata cleanup**;
- not an optimizer;
- not a validator repair pass;
- not a feature-lowering pass;
- not the same pass as [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md) or [`remove-relaxed-simd`](../remove-relaxed-simd/index.md).

## Inputs and outputs

### Input

The input is any module being processed by Binaryen while `PassOptions::emitTargetFeatures` would otherwise cause a target-features custom section to be emitted.
The in-memory module may use many features, but those feature uses are not changed by this pass.

### Output

The in-memory Binaryen IR remains the same.
The later written output omits the target-features custom section because the pass sets the runner option `emitTargetFeatures` to `false`.

## Correctness constraints

- **No IR mutation:** Binaryen's owner file returns `modifiesBinaryenIR() == false`; a port should not silently turn this into an instruction rewrite.
- **Whole-section policy:** the pass suppresses target-feature metadata emission. It is not a per-feature filter.
- **Explicit user/product choice:** target-feature metadata is non-executing, but downstream tools can still rely on it.
- **Do not lower features:** if a module uses relaxed SIMD, GC, memory64, or other features, this pass does not make the module compatible with engines that lack them.
- **Keep neighboring names separate:** `strip-toolchain-annotations` removes Binaryen annotation metadata; `remove-relaxed-simd` rewrites relaxed-SIMD instructions to traps.

## Notable edge cases

- Running the pass can make two binary outputs differ even though the Binaryen IR is unchanged.
- A concrete section-deletion implementation over a decoded module would be architecturally different from Binaryen's output-option pass.
- Starshine currently stores arbitrary custom sections as opaque `CustomSec` records; it does not have a semantic target-features section model.
- The reviewed changelog pages did not give a clean release-note provenance line for this pass, so the dossier anchors on source-level presence in Binaryen `version_129` and current `main`.

## Validation strategy

For Binaryen parity research:

1. build or load a module whose output would include a `target_features` custom section;
2. run Binaryen with and without `--strip-target-features` while keeping other options the same;
3. confirm the executable module body and sections other than target-feature metadata are stable;
4. confirm the target-features custom section is absent from the stripped output.

For a future Starshine port, add tests in this order:

1. explicit `--pass strip-target-features` status is deliberately chosen instead of accidentally unknown;
2. arbitrary non-target custom sections are preserved;
3. a `target_features` custom section, if modeled concretely, is removed from output;
4. functions, instructions, types, imports, exports, data, and names remain unchanged;
5. optimize/shrink presets do not pick up the pass unless product policy explicitly wants it.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and validation surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after output metadata shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.

## Sources

- [`../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md`](../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md)
- [`../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md`](../../../raw/research/0334-2026-04-25-strip-target-features-primary-sources-and-starshine-followup.md)
- Binaryen `StripTargetFeatures.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
