---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../../../raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md
  - ../../../raw/binaryen/2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/research/0483-2026-05-05-strip-target-features-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-strip-target-features-port-readiness-primary-sources.md
  - ../../../raw/research/0429-2026-04-27-strip-target-features-port-readiness.md
  - ../../../raw/binaryen/2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/research/0390-2026-04-26-strip-target-features-source-correction.md
  - ../../../raw/binaryen/2026-04-25-strip-target-features-primary-sources.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../strip-toolchain-annotations/wat-shapes.md
  - ../remove-relaxed-simd/wat-shapes.md
---

# `strip-target-features` output and module shapes

This pass is unusual for the pass wiki: the important before/after shape is module/output metadata, not a WAT instruction rewrite. The snippets below are schematic. They teach the shape of the transformation rather than exact byte encoding. The 2026-05-05 current-main recheck preserved these shapes.

## 1. Target-features metadata is omitted from output

Before:

```text
Binaryen module metadata:
  hasFeaturesSection = true

Emitted wasm:
  custom section "target_features"
  type/function/code/data/etc. sections
```

After `strip-target-features`:

```text
Binaryen module metadata:
  hasFeaturesSection = false

Emitted wasm:
  type/function/code/data/etc. sections
```

The pass clears Binaryen's module metadata flag through the shared strip/emit owner. It does not need to edit function bodies.

## 2. Function bodies are unchanged

Before:

```wat
(module
  (func $f (result i32)
    (i32.const 1))
  (export "f" (func $f)))
```

After:

```wat
(module
  (func $f (result i32)
    (i32.const 1))
  (export "f" (func $f)))
```

If these differ after a `strip-target-features` run, some other pass or output option changed the module.

## 3. Feature use remains feature use

Before:

```wat
(module
  ;; Example: a module may use a proposal feature.
  ;; The exact feature does not matter for this pass.
  (func $uses_feature
    ;; feature-specific instructions or types live here
  ))
```

After:

```wat
(module
  (func $uses_feature
    ;; same feature-specific instructions or types still live here
  ))
```

Removing target-feature metadata is not the same as lowering or deleting feature-using instructions. Use pages like [`remove-relaxed-simd`](../remove-relaxed-simd/index.md), `memory64-lowering`, or `i64-to-i32-lowering` for actual feature/code transformations.

## 4. Non-target custom sections should not be deleted by accident

Before:

```text
custom section "producers"
custom section "name"
custom section "target_features"
code sections
```

After the intended Binaryen policy:

```text
custom section "producers"
custom section "name"
code sections
```

A future concrete Starshine implementation over `Module.custom_secs` must be careful not to turn this into generic custom-section stripping. The shared binary metadata guide records why `producers` stays provenance-only and why `name` stays structured metadata: [`../../../binary/custom-and-name-sections.md`](../../../binary/custom-and-name-sections.md).

## 5. Already-absent target-features metadata is a no-op

Before:

```text
Binaryen module metadata:
  hasFeaturesSection = false
```

After:

```text
Binaryen module metadata:
  hasFeaturesSection = false
```

Running the pass when the metadata flag is already false should be harmless.

## 6. The sibling `emit-target-features` shape is the inverse

Before:

```text
Binaryen module metadata:
  hasFeaturesSection = false
```

After `emit-target-features`:

```text
Binaryen module metadata:
  hasFeaturesSection = true
```

Starshine does not currently register either public pass name. A future local implementation should decide both names deliberately because Binaryen implements them as two modes of the same owner.

## 7. Explicit non-goals

These should not be described as `strip-target-features` shapes:

- removing `@binaryen.idempotent` or `@binaryen.removable.if.unused` annotations;
- deleting function annotations from Starshine's `FuncAnnotationSec`;
- rewriting relaxed SIMD instructions;
- lowering memory64/table64 declarations;
- changing imports, exports, locals, globals, element segments, or data segments;
- filtering individual target-feature entries while keeping the section.

## Validation checklist

A correct future Starshine port should prove at least:

- target-feature metadata is absent after the pass when the chosen local representation can model it;
- arbitrary non-target custom sections are preserved;
- all executable sections remain byte- or structure-equivalent;
- the pass status is explicit in the registry instead of being accidentally unknown;
- docs distinguish Binaryen module-metadata mutation from executable IR mutation;
- [`starshine-port-readiness-and-validation.md`](starshine-port-readiness-and-validation.md) is refreshed if the local representation changes.
