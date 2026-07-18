---
kind: entity
status: supported
last_reviewed: 2026-07-18
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp
  - https://webassembly.github.io/spec/core/appendix/custom.html
  - https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md
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
  - ./fuzzing.md
  - ../strip-toolchain-annotations/index.md
  - ../remove-relaxed-simd/index.md
  - ../late-pipeline-dispatch.md
---

# `strip-target-features`

## Role

`strip-target-features` is a public Binaryen pass that removes the module-level target-features metadata from later output. It is **not** a code optimizer and **not** a feature-lowering pass.

The 2026-04-26 source recheck corrected an important stale wiki claim: Binaryen does **not** implement this as `runner->options.emitTargetFeatures = false`, and it does **not** report `modifiesBinaryenIR() == false`. The 2026-04-27 recheck refined that correction: in `version_129` and current `main`, `strip-target-features` shares an owner with the sibling `emit-target-features` pass, inherits the base `Pass::modifiesBinaryenIR()` default of true, and clears `module->hasFeaturesSection` by constructing the shared owner in stripping mode. The 2026-07-11 current-main recheck again found no behavior-bearing drift in the reviewed owner, registration, or default-scheduler surface. The [WebAssembly linking convention](https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md) establishes the missing payload boundary: `target_features` is a custom section whose prefixed feature names are linker compatibility metadata, while [Core custom sections](https://webassembly.github.io/spec/core/appendix/custom.html) remain non-semantic. An opaque-section first Starshine slice may remove `CustomSec("target_features", ...)`, but that is still metadata suppression—not feature lowering, Core-validation repair, or a faithful first-class Binaryen representation.

It is currently **upstream-only** in Starshine:

- neither `strip-target-features` nor sibling `emit-target-features` is listed as active, boundary-only, or removed in `src/passes/optimize.mbt`;
- explicit local pass requests fail as `unknown pass flag strip-target-features` / `unknown pass flag emit-target-features`;
- it is outside the canonical no-DWARF `-O` / `-Os` path and the saved generated-artifact `-O4z` queue;
- `agent-todo.md` has no dedicated slice for it today.

## Beginner summary

A good beginner mental model is:

- WebAssembly binaries may contain custom sections that do not execute as wasm instructions.
- The WebAssembly linking convention uses the `target_features` custom-section payload to communicate `+` used and `-` disallowed feature names to link-time tooling; Core validation may still ignore that metadata.
- Binaryen can remember that a module should emit this `target_features` custom section.
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
- **Explicit user/product choice:** target-feature metadata is non-executing Core metadata, but a linking tool can still use its convention payload as a compatibility constraint.
- **Keep neighboring names separate:** `strip-toolchain-annotations` removes Binaryen annotation metadata; `remove-relaxed-simd` rewrites relaxed-SIMD instructions to traps.

## Notable edge cases

- Running the pass can make binary output differ even when every executable section is unchanged.
- The old wiki wording that called this “option-only” is stale and superseded by the 2026-04-26 source-correction manifest.
- A Starshine implementation over decoded `Module.custom_secs` would be architecturally different from Binaryen's `hasFeaturesSection` flag unless Starshine first adds first-class target-feature metadata. It can suppress already-present bytes, but it cannot faithfully implement `emit-target-features` until it has a source of feature facts and a payload policy.
- The local port-readiness bridge keeps the safe first slices explicit: registry honesty, narrow opaque `target_features` custom-section deletion, then a larger first-class target-feature metadata model.
- Starshine currently stores arbitrary custom sections as opaque `CustomSec` records and has no semantic target-features section model.
- The neighboring `producers` tool-conventions section should be preserved by any future target-feature pass; it is provenance metadata, not an input to pass scheduling or feature validation.

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
- [`fuzzing.md`](fuzzing.md) - planned-only comparison status: the current unknown registry name and absent harness flag make a `compare-pass` command invalid; it also lists the future metadata-fixture admission gates.

## Sources

- Binaryen current-main owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StripTargetFeatures.cpp>
- Core custom-section appendix: <https://webassembly.github.io/spec/core/appendix/custom.html>
- WebAssembly linking convention: <https://github.com/WebAssembly/tool-conventions/blob/main/Linking.md>
- [`../../../binary/custom-and-name-sections.md`](../../../binary/custom-and-name-sections.md)
- research note 0429
- Binaryen `StripTargetFeatures.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StripTargetFeatures.cpp>
- Binaryen pass registry: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
