---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h
  - https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-functions-fallthrough-and-boundaries.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `de-nan` / `denan` WAT shape catalog

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md), the focused current-main recheck in [`../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md), and the current Starshine status bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

This page catalogs the main source-backed shapes that Binaryen `denan` rewrites, preserves, or refuses to express through helper calls.

## Reading guide

- **Positive** = `denan` actively rewrites the shape.
- **Preserved** = the shape stays structurally the same on purpose.
- **Boundary / bailout** = the pass has a hard scope or legality limit there.

## Positive shape 1: NaN scalar global constant becomes zero

### Before

```wat
(module
  (global (mut f32) (f32.const nan))
)
```

### After

```wat
(module
  (global (mut f32) (f32.const 0))
)
```

### Why

- constant rewrite is legal outside function context
- helper-call insertion is not needed

## Positive shape 2: floating parameter is sanitized on entry

### Before

```wat
(func $foo32 (param $x f32) (result f32)
  (call $foo32 (local.get $x))
)
```

### After

```wat
(func $foo32 (param $x f32) (result f32)
  (local.set $x
    (call $deNan32
      (local.get $x)
    )
  )
  (call $deNan32
    (call $foo32
      (local.get $x)
    )
  )
)
```

### Why

- param-entry repair happens for defined functions
- the recursive call result is also a nonconstant `f32` producer, so it is wrapped too

## Positive shape 3: nonconstant float producer in a `drop`

### Before

```wat
(drop
  (f32.abs
    (local.get $f)
  )
)
```

### After

```wat
(drop
  (call $deNan32
    (f32.abs
      (local.get $f)
    )
  )
)
```

### Why

- `f32.abs` is a nonconstant producer of `f32`
- `drop` itself is not the thing being repaired

## Positive shape 4: nonconstant float producer stored back to a local

### Before

```wat
(local.set $f
  (f32.abs
    (local.get $f)
  )
)
```

### After

```wat
(local.set $f
  (call $deNan32
    (f32.abs
      (local.get $f)
    )
  )
)
```

### Why

- the child producer is wrapped
- the outer `local.set` shell is a result-fallthrough node and is not wrapped again

## Positive shape 5: NaN constant inside a function body becomes zero

### Before

```wat
(func
  (drop (f64.const nan))
)
```

### After

```wat
(func
  (drop (f64.const 0))
)
```

### Why

- compile-time replacement is cheaper and legal everywhere a constant is legal

## Positive shape 6: collision-safe helper-name generation

### Before

```wat
(module
  (func $deNan32)
  (func $deNan64)
  (func $foo32 (param $x f32) (result f32)
    (call $foo32 (local.get $x))
  )
)
```

### After shape

```wat
(module
  (func $deNan32)
  (func $deNan64)
  ...
  (func $deNan32_4 (param $0 f32) (result f32) ...)
  (func $deNan64_4 (param $0 f64) (result f64) ...)
)
```

### Why

- helper names are chosen with `Names::getValidFunctionName(...)`
- existing user-defined helper-like names are not overwritten

## Preserved shape 1: plain `local.get`

### Before

```wat
(drop (local.get $f))
```

### After

```wat
(drop (local.get $f))
```

### Why preserved

- `local.get` is explicitly skipped
- the pass expects defining flows or entry repair to sanitize the value already

## Preserved shape 2: pass-through `local.set (local.get ...)`

### Before

```wat
(local.set $f (local.get $f))
```

### After

```wat
(local.set $f (local.get $f))
```

### Why preserved

- `local.get` is skipped
- the outer `local.set` is a fallthrough shell

## Preserved shape 3: tee ladder over a local read

### Before

```wat
(func $tees (param $x f32) (result f32)
  (local.tee $x
    (local.tee $x
      (local.tee $x
        (local.tee $x
          (local.get $x)
        )
      )
    )
  )
)
```

### After shape

- Binaryen inserts the entry-param fixup for `$x`
- but the tee ladder itself stays structurally the same

### Why preserved

- the innermost `local.get` is skipped
- the surrounding tee/fallthrough shells do not trigger extra wrapping

## Preserved shape 4: `select` shell

### Before

```wat
(func $select (param $x f32) (result f32)
  (select
    (local.get $x)
    (local.get $x)
    (i32.const 1)
  )
)
```

### After shape

- Binaryen inserts the entry-param fixup for `$x`
- the `select` body remains a `select`

### Why preserved

- `select` is treated as a result-fallthrough shell

## Boundary shape 1: imported function has no entry fixup

### Before

```wat
(func $imp (import "m" "f") (param f32))
```

### After

- unchanged by the `visitFunction` entry-repair phase

### Why boundary

- imported functions are skipped in `visitFunction`
- the 2026-04-25 current-main recheck keeps this source-backed rather than lit-file-led, because the dedicated test file still focuses on defined-function entry repair rather than an isolated imported-function fixture

## Boundary shape 2: nonconstant repair outside function context is illegal

### Conceptual before

```wat
;; imagine a nonconstant float-producing expression in a nonfunction context
```

### After

- no helper-call rewrite is applied there
- the pass warns instead when it cannot legally de-NaN outside function context

### Why boundary

- helper calls are illegal in those contexts
- only constant replacement can be expressed there

## Boundary shape 3: nonfloat nonvector producers

### Before

```wat
(i32.add (i32.const 1) (i32.const 2))
```

### After

- unchanged

### Why boundary

- the pass only cares about results of type `f32`, `f64`, or `v128`

## Boundary shape 4: SIMD helper is feature-gated

### Before

```wat
(module
  ;; no SIMD feature enabled
)
```

### After

- no `deNan128` helper is emitted

### Why boundary

- the helper is added only when `module->features.hasSIMD()` is true

## Boundary shape 5: result-fallthrough shell is not a positive rewrite target

### Before

```wat
(block (result f32)
  (call $foo)
)
```

### After shape

- Binaryen repairs the inner producer if needed
- but does not wrap the outer `block` just because it also has result type `f32`

### Why boundary

- the outer shell is a fallthrough container, not a distinct value producer

## Summary table

| Shape family | Outcome | Main reason |
| --- | --- | --- |
| scalar NaN constant | rewrite to zero constant | compile-time repair |
| nonconstant `f32`/`f64` producer | wrap with helper call | runtime sanitization |
| function param `f32`/`f64`/`v128` | entry `local.set(call helper ...)` | ABI-entry sanitization |
| `local.get` | preserve | anti-self-instrumentation |
| fallthrough `block` / `if` / `select` / `local.set` shells | preserve shell | child result already carries the real value |
| imported function | skip entry repair | no body to rewrite |
| nonconstant nonfunction context | no helper-call rewrite | legality boundary |
| `v128` helper | only with SIMD | feature gate |

## Sources

- [`../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md)
- [`../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md`](../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md)
- [`../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md`](../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md`](../../../raw/research/0184-2026-04-21-de-nan-binaryen-research.md)
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/DeNaN.cpp>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/properties.h>
- <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/denan.wast>
