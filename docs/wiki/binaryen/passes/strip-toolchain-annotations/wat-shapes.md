---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-strip-toolchain-annotations-port-readiness-primary-sources.md
  - ../../../raw/binaryen/2026-04-24-strip-toolchain-annotations-primary-sources.md
  - ../../../raw/research/0504-2026-05-06-strip-toolchain-annotations-current-main-recheck.md
  - ../../../raw/research/0394-2026-04-26-strip-toolchain-annotations-port-readiness.md
  - ../../../raw/research/0324-2026-04-24-strip-toolchain-annotations-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
---

# `strip-toolchain-annotations` WAT and annotation shapes

This page uses WAT-like snippets to teach what changes and what must not change.
A 2026-05-06 current-main recheck kept the shapes unchanged; exact printed syntax can vary, but the before/after intent is source-backed by the Binaryen owner file and dedicated lit file.

## 1. `@binaryen.removable.if.unused` is removed

Before:

```wat
(func $f (result i32)
  (@binaryen.removable.if.unused
    (i32.const 1)))
```

After:

```wat
(func $f (result i32)
  (i32.const 1))
```

The expression remains.
Only the Binaryen-owned annotation bit disappears.

## 2. `@binaryen.idempotent` is removed

Before:

```wat
(func $g (result i32)
  (@binaryen.idempotent
    (call $pureish)))
```

After:

```wat
(func $g (result i32)
  (call $pureish))
```

The pass does not try to prove whether the call is idempotent.
It only removes the toolchain annotation after the toolchain is done using it.

## 3. `@metadata.code.inline` is preserved

Before:

```wat
(func $h (result i32)
  (@metadata.code.inline "\00"
    (i32.const 10)))
```

After:

```wat
(func $h (result i32)
  (@metadata.code.inline "\00"
    (i32.const 10)))
```

This is the most important negative example.
A port that deletes all annotations would be wrong.

## 4. Mixed removed and preserved annotations keep the preserved half

Before:

```wat
(func $mixed (result i32)
  (@binaryen.removable.if.unused
    (@metadata.code.inline "\00"
      (i32.const 20))))
```

After:

```wat
(func $mixed (result i32)
  (@metadata.code.inline "\00"
    (i32.const 20)))
```

Binaryen's implementation clears selected fields from a `CodeAnnotation` and erases the entry only if the remaining annotation record is empty.

## 5. `@binaryen.js.called` is source-backed as removed

Before:

```wat
(@binaryen.js.called)
(func $called_from_js)
```

After:

```wat
(func $called_from_js)
```

Caveat: the reviewed dedicated lit file does not isolate this exact spelling.
The removal is backed by the `remove(CodeAnnotation&)` source and by the `version_126` changelog.

## 6. Non-annotation module contents stay stable

Before:

```wat
(module
  (type $t (func (result i32)))
  (func $f (type $t) (i32.const 1))
  (export "f" (func $f)))
```

After:

```wat
(module
  (type $t (func (result i32)))
  (func $f (type $t) (i32.const 1))
  (export "f" (func $f)))
```

The pass has no reason to touch function order, type declarations, names, exports, imports, locals, or expression bodies.

## 7. Starshine first-slice function-annotation shape

Starshine's current local annotation surface is function/function-import metadata lowered into `FuncAnnotationSec`.
A future first slice can therefore handle this module shape even before expression annotations exist:

Before:

```wat
(@binaryen.idempotent)
(@metadata.code.inline "\00")
(func $local)

(@binaryen.js.called)
(import "env" "host" (func $host))
```

After:

```wat
(@metadata.code.inline "\00")
(func $local)

(import "env" "host" (func $host))
```

Caveat: this is a Starshine subset shape, not the full Binaryen per-expression `codeAnnotations` contract.

## 8. Explicit non-goals

These should not be described as `strip-toolchain-annotations` shapes:

- removing the wasm name section;
- removing producers metadata;
- removing target-feature metadata;
- deleting dead functions;
- changing `@metadata.code.inline` policy;
- optimizing calls marked idempotent;
- treating Binaryen function annotations as a substitute for the WebAssembly custom annotation proposal.

## Validation checklist

A correct Starshine port should prove at least:

- removed Binaryen annotation families disappear;
- preserved metadata remains;
- mixed annotations are partially stripped, not all-or-nothing deleted;
- code and module sections stay unchanged except for supported annotation storage;
- unknown or unsupported annotation surfaces have an explicit policy instead of silent best-effort deletion;
- a first Starshine subset says clearly whether expression-level annotation wrappers are unsupported, preserved, or represented in a new side table.
