---
kind: entity
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/research/0483-2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md
  - ../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md
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
  - ./starshine-port-readiness-and-validation.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
  - ../late-pipeline-dispatch.md
---

# `strip-target-features`

## Role

`strip-target-features` is a public Binaryen pass that removes the module-level target-features metadata from later output. It is **not** a code optimizer and **not** a feature-lowering pass.

The 2026-04-26 source recheck corrected an important stale wiki claim: Binaryen does **not** implement this as `runner->options.emitTargetFeatures = false`, and it does **not** report `modifiesBinaryenIR() == false`. The 2026-04-27 recheck refined that correction: in `version_129` and current `main`, `strip-target-features` shares an owner with the sibling `emit-target-features` pass, inherits the base `Pass::modifiesBinaryenIR()` default of true, and clears `module->hasFeaturesSection` by constructing the shared owner in stripping mode. The 2026-05-05 current-main recheck preserved the same contract.

It is currently **upstream-only** in Starshine:

- neither `strip-target-features` nor sibling `emit-target-features` is listed as active, boundary-only, or removed in `src/passes/optimize.mbt`;
- explicit local pass requests fail as `unknown pass flag strip-target-features` / `unknown pass flag emit-target-features`;
- it is outside the canonical no-DWARF `-O` / `-Os` path and the saved generated-artifact `-O4z` queue;
- `agent-todo.md` has no dedicated slice for it today.

## Beginner summary

A good beginner mental model is:

- WebAssembly binaries may contain custom sections that do not execute as wasm instructions.
- Binaryen can remember that a module should have a `target_features` custom section so downstream tools know which wasm features the module expects or uses.
- `strip-target-features` clears Binaryen's module-level “has target-features section” flag.
- It does **not** rewrite functions, instructions, types, imports, exports, memories, tables, globals, or data.

So this pass is best taught as:

- **module metadata cleanup** with output-size consequences;
- not an instruction optimizer;
- not a validator repair pass;
- not a feature-lowering pass;
- not the same pass as [`strip-toolchain-annotations`](../strip-toolchain-annotations/index.md) or [`remove-relaxed-simd`](../remove-relaxed-simd/index.md).

## Inputs and outputs

### Input

The input is any Binaryen module whose `hasFeaturesSection` metadata may be true. The module may use many wasm features, but those feature uses are not changed by this pass.

### Output

The executable in-memory IR is otherwise unchanged, but Binaryen's module metadata now records `hasFeaturesSection = false`. Later binary output therefore omits the target-features custom section.

## Correctness constraints

- **Only the target-features metadata flag changes:** do not silently turn this into generic custom-section stripping.
- **Whole-section policy:** the pass removes target-feature metadata as a section-level decision. It is not a per-feature filter.
- **No code lowering:** if a module uses relaxed SIMD, GC, memory64, or other features, this pass does not make the module compatible with engines that lack them.
- **Explicit user/product choice:** target-feature metadata is non-executing, but downstream tools can still rely on it.
- **Keep neighboring names separate:** `strip-toolchain-annotations` removes Binaryen annotation metadata; `remove-relaxed-simd` rewrites relaxed-SIMD instructions to traps.

## Notable edge cases

- Running the pass can make binary output differ even when every executable section is unchanged.
- The old wiki wording that called this “option-only” is stale and superseded by the 2026-04-26 source-correction manifest.
- A Starshine implementation over decoded `Module.custom_secs` would be architecturally different from Binaryen's `hasFeaturesSection` flag unless Starshine first adds first-class target-feature metadata.
- The local port-readiness bridge keeps the safe first slices explicit: registry honesty, narrow opaque `target_features` custom-section deletion, then a larger first-class target-feature metadata model.
- Starshine currently stores arbitrary custom sections as opaque `CustomSec` records and has no semantic target-features section model.

## Validation strategy

For Binaryen parity research:

1. build or load a module whose output would include a `target_features` custom section;
2. run Binaryen with and without `--strip-target-features` while keeping other options the same;
3. confirm the target-features custom section is absent after the pass;
4. confirm executable sections and feature-using instructions are preserved;
5. confirm the module-level metadata transition, not a function-body rewrite, explains the output difference.

For a future Starshine port, add tests in this order:

1. explicit `--pass strip-target-features` status is deliberately chosen instead of accidentally unknown;
2. arbitrary non-target custom sections are preserved;
3. a `target_features` custom section, if modeled concretely or opaquely, is removed/suppressed;
4. functions, instructions, types, imports, exports, data, and names remain unchanged;
5. optimize/shrink presets do not pick up the pass unless product policy explicitly wants it.

## Page map

- [`binaryen-strategy.md`](binaryen-strategy.md) - corrected source-backed Binaryen strategy.
- [`implementation-structure-and-tests.md`](implementation-structure-and-tests.md) - owner files and validation surface.
- [`wat-shapes.md`](wat-shapes.md) - before/after output metadata shapes.
- [`starshine-strategy.md`](starshine-strategy.md) - current Starshine status and future landing zones.
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) - safe first slices, validation ladder, and exact local code surfaces.

## Sources

- [`../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md)
- [`../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md`](../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md)
- [`../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md`](../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md)
- [`../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md`](../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md)
- Binaryen `StripTargetFeatures.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
