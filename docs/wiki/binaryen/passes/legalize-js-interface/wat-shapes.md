---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-legalize-js-interface-port-readiness-primary-sources.md
  - ../../../raw/research/0395-2026-04-26-legalize-js-interface-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md
  - ../../../raw/research/0291-2026-04-24-legalize-js-interface-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0223-2026-04-21-legalize-js-interface-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface-exported-helpers.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-js-interface_pass-arg=legalize-js-interface-export-originals.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/legalize-and-prune-js-interface.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/LegalizeJSInterface.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./temp-ret-helpers-and-pruning-split.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `legalize-js-interface` WAT shapes

This page is a beginner-friendly catalog of the main IR shapes Binaryen rewrites.
The examples are schematic: they show the contract, not verbatim full lit output.
For the Starshine-specific first-slice order and validation matrix that corresponds to these shapes, see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## 1. Exported `i64` result -> legal wrapper returning low `i32`

Before:

```wat
(func $get_i64 (result i64)
  ...)
(export "get_i64" (func $get_i64))
```

After conceptually:

```wat
(func $get_i64 (result i64)
  ...)

(func $legalstub$get_i64 (result i32)
  (local $tmp i64)
  (local.set $tmp (call $get_i64))
  (call $setTempRet0-or-__set_temp_ret
    (i32.wrap_i64 (i64.shr_u (local.get $tmp) (i64.const 32))))
  (i32.wrap_i64 (local.get $tmp)))

(export "get_i64" (func $legalstub$get_i64))
```

The important points are:

- JS sees a legal `i32` result
- the original wasm function keeps returning `i64`
- high bits travel through the temp-ret helper

## 2. Exported `i64` params -> wrapper rebuilds the original `i64`

Before:

```wat
(func $takes_i64 (param i64) ...)
(export "takes_i64" (func $takes_i64))
```

After conceptually:

```wat
(func $legalstub$takes_i64 (param i32 i32)
  (call $takes_i64
    (i64.or
      (i64.extend_i32_u (local.get 0))
      (i64.shl
        (i64.extend_i32_u (local.get 1))
        (i64.const 32)))))
```

So exported wrappers rebuild real wasm `i64` values before calling inward.

## 3. Imported `i64` params -> wasm-facing wrapper splits them

Before:

```wat
(import "env" "imported" (func $imported (param i64)))
;; wasm code calls $imported directly
```

After conceptually:

```wat
(import "env" "imported" (func $legalimport$imported (param i32 i32)))

(func $legalfunc$imported (param i64)
  (call $legalimport$imported
    (i32.wrap_i64 (local.get 0))
    (i32.wrap_i64 (i64.shr_u (local.get 0) (i64.const 32)))))
```

Then call sites are redirected to `legalfunc$imported`.

## 4. Imported `i64` result -> wrapper rebuilds from low result + temp getter

Before:

```wat
(import "env" "imported" (func $imported (result i64)))
```

After conceptually:

```wat
(import "env" "imported" (func $legalimport$imported (result i32)))

(func $legalfunc$imported (result i64)
  (i64.or
    (i64.extend_i32_u (call $legalimport$imported))
    (i64.shl
      (i64.extend_i32_u (call $getTempRet0-or-__get_temp_ret))
      (i64.const 32))))
```

So imported wrappers rebuild real wasm `i64` values after calling outward.

## 5. `ref.func` repair for illegal imports

Before:

```wat
(ref.func $imported)
```

After conceptually:

```wat
(ref.func $legalfunc$imported)
```

This is important because plain call-target rewrites are not enough when the imported function is referenced as a funcref.

## 6. `export-originals` mode keeps both views

Conceptually, Binaryen can end up with:

```wat
(export "foo" (func $legalstub$foo))
(export "orig$foo" (func $foo))
```

That keeps:

- a JS-legal export, and
- an extra original wasm-ABI export

for the allowed cases.

## 7. `exported-helpers` mode reuses existing helper exports

When the module already exports:

```wat
(export "__set_temp_ret" (func $__set_temp_ret))
(export "__get_temp_ret" (func $__get_temp_ret))
```

the legalized wrappers use those helpers instead of importing `setTempRet0` / `getTempRet0` from `env`.

## 8. Prune sibling removes or stubs still-illegal boundary items

### Imported unsupported boundary function

Conceptually before:

```wat
(import "env" "bad" (func $bad (result (ref null $nondefaultable))))
```

After prune conceptually:

```wat
(func $bad (result (ref null $nondefaultable))
  unreachable)
```

Or, for defaultable results, Binaryen can emit a zero/default constant instead.

### Exported unsupported boundary function

Before:

```wat
(func $bad_export ...)
(export "bad_export" (func $bad_export))
```

After prune:

- the function may remain in the module
- but the JS-visible export is removed

### Exported unsupported global

Before:

```wat
(global $g (mut v128) ...)
(export "g" (global $g))
```

After prune:

- the export is removed

## 9. Important no-op boundaries

Plain `legalize-js-interface` does **not** rewrite everything.
In reviewed `version_129`, the main no-op families are:

- functions whose boundary signatures have no `i64`
- non-function exports in plain mode
- internal arithmetic, locals, and memory ops
- whole-module internal `i64` traffic
- unsupported JS-surface features unless the prune sibling is used

## Beginner rule of thumb

If the shape is:

- exported function with `i64` boundary -> expect `legalstub$...`
- imported function with `i64` boundary -> expect `legalimport$...` plus `legalfunc$...`
- imported call or `ref.func` to an illegal boundary import -> expect retargeting
- unsupported JS-surface feature under the prune sibling -> expect export removal or trivial stub replacement

The reviewed source/test URL set for these shapes is now captured in [`../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md`](../../../raw/binaryen/2026-04-24-legalize-js-interface-primary-sources.md).
Current Starshine does not rewrite these shapes yet; see [`./starshine-strategy.md`](./starshine-strategy.md) for the exact local status and future code-map.
