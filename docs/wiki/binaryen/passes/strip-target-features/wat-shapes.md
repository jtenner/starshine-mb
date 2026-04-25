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
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ../strip-toolchain-annotations/wat-shapes.md
  - ../remove-relaxed-simd/wat-shapes.md
---

# `strip-target-features` output and module shapes

This pass is unusual for the pass wiki: the important before/after shape is output metadata, not a WAT instruction rewrite.
The snippets below are schematic.
They teach the shape of the transformation rather than exact byte encoding.

## 1. Target-features metadata is omitted from output

Before output policy:

```text
Binaryen output options:
  emitTargetFeatures = true

Emitted wasm:
  custom section "target_features"
  type/function/code/data/etc. sections
```

After `strip-target-features`:

```text
Binaryen output options:
  emitTargetFeatures = false

Emitted wasm:
  type/function/code/data/etc. sections
```

The pass changes whether Binaryen emits the custom section.
It does not need to edit function bodies.

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

Removing target-feature metadata is not the same as lowering or deleting feature-using instructions.
Use pages like [`remove-relaxed-simd`](../remove-relaxed-simd/index.md), `memory64-lowering`, or `i64-to-i32-lowering` for actual feature/code transformations.

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

A future concrete Starshine implementation over `Module.custom_secs` must be careful not to turn this into generic custom-section stripping.

## 5. Already-absent target-features metadata is a no-op

Before:

```text
Binaryen output options:
  emitTargetFeatures = false
```

After:

```text
Binaryen output options:
  emitTargetFeatures = false
```

Running the pass when emission is already disabled should be harmless.

## 6. Explicit non-goals

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
- docs distinguish output-option parity from IR mutation parity.
