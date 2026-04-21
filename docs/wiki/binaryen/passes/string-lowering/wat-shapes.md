---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./json-and-magic-imports.md
  - ../string-gathering/wat-shapes.md
  - ../../../strings/string-const-surface.md
---

# `string-lowering` WAT shapes

This page is the beginner-friendly before/after shape catalog for Binaryen `string-lowering`.

## One mental model first

`string-lowering` does two big things at once:

- it gathers literal strings into canonical globals,
- and it replaces the remaining supported wasm-string surface with imports and `externref`-typed operations.

So the easiest way to read the shapes is:

1. gathered literals first
2. type/ABI rewrite second
3. helper-call rewrite third

## Shape 1: repeated `string.const` sites become canonical global reads

Before:

```wat
(module
  (func $a
    (drop (string.const "foo")))
  (func $b
    (drop (string.const "foo"))))
```

After, conceptually:

```wat
(module
  (import "string.const" "0" (global $global_foo (ref extern)))
  (func $a
    (drop (global.get $global_foo)))
  (func $b
    (drop (global.get $global_foo))))
```

What changed:

- the duplicate literals were first gathered into one defining global
- that defining global was then lowered into an import
- the function-body uses stayed as `global.get`, not fresh helper calls

## Shape 2: reusable defining globals stay canonical, then become imports

Before:

```wat
(module
  (global $global (ref string) (string.const "foo"))
  (func $use
    (drop (string.const "foo"))))
```

After, conceptually:

```wat
(module
  (import "string.const" "0" (global $global (ref extern)))
  (func $use
    (drop (global.get $global))))
```

Important lesson:

- the pass reuses the good defining global shape from gathering
- then lowering changes that defining global from real initializer to import

## Shape 3: nullable string globals are still not reusable as defining globals

Before:

```wat
(module
  (global $g2 (ref null string) (string.const "bar"))
  (func $use
    (drop (string.const "bar"))))
```

After, conceptually:

```wat
(module
  (import "string.const" "0" (global $def (ref extern)))
  (global $g2 externref (global.get $def))
  (func $use
    (drop (global.get $def))))
```

Why:

- gathering still insists on a non-null immutable defining global shape
- so the old nullable global becomes an alias user, not the defining source
- lowering then rewrites both sides into externref-based forms

## Shape 4: function signatures using strings become externref signatures

Before:

```wat
(module
  (func $f (param stringref) (result (ref null string))
    ...))
```

After, conceptually:

```wat
(module
  (func $f (param externref) (result externref)
    ...))
```

Why:

- `updateTypes()` remaps `HeapType::string` to `HeapType::ext`
- nullability stays the same
- this is an ABI-visible part of the pass, not just internal cleanup

## Shape 5: `string.concat` becomes a helper import call

Before:

```wat
(module
  (func $f (param stringref stringref) (result stringref)
    (string.concat
      (local.get 0)
      (local.get 1))))
```

After, conceptually:

```wat
(module
  (import "wasm:js-string" "concat"
    (func $concat (param externref externref) (result (ref extern))))
  (func $f (param externref externref) (result (ref extern))
    (call $concat
      (local.get 0)
      (local.get 1))))
```

The important beginner idea is:

- the operation itself is not reimplemented inline
- Binaryen lowers it to an imported helper API

## Shape 6: `string.eq` families split into two helper calls

Before:

```wat
(string.eq (local.get 0) (local.get 1))
(string.compare (local.get 0) (local.get 1))
```

After, conceptually:

```wat
(call $equals  (local.get 0) (local.get 1))
(call $compare (local.get 0) (local.get 1))
```

That split matters because the source has distinct op cases for:

- equality
- comparison

and does not treat them as one generic string relation helper.

## Shape 7: array/codepoint creation lowers only on the supported current subset

Before:

```wat
(string.new_wtf16_array (local.get $arr) (local.get $start) (local.get $end))
(string.from_code_point (local.get $cp))
```

After, conceptually:

```wat
(call $fromCharCodeArray (local.get $arr) (local.get $start) (local.get $end))
(call $fromCodePoint (local.get $cp))
```

But the file also makes an equally important negative point:

- unsupported `string.new*` variants are not lowered here yet
- they still sit behind explicit upstream TODO / unreachable branches

## Shape 8: string encoding lowers only for the WTF-16-array variant

Before:

```wat
(string.encode_wtf16_array
  (local.get $s)
  (local.get $arr)
  (local.get $start))
```

After:

```wat
(call $intoCharCodeArray
  (local.get $s)
  (local.get $arr)
  (local.get $start))
```

Again, the negative lesson matters too:

- this pass does not currently lower all `string.encode*` families

## Shape 9: measure/get/slice become direct helper calls

Before:

```wat
(string.measure_wtf16 (local.get $s))
(string.wtf16.get (local.get $s) (local.get $i))
(string.slice_wtf (local.get $s) (local.get $start) (local.get $end))
```

After, conceptually:

```wat
(call $length     (local.get $s))
(call $charCodeAt (local.get $s) (local.get $i))
(call $substring  (local.get $s) (local.get $start) (local.get $end))
```

These are some of the easiest shapes for beginners to recognize in lowered output.

## Shape 10: module-level users are rewritten too

This pass is not limited to function bodies.
Because both gathering and instruction replacement also walk module code, string-bearing global initializers and similar module-expression sites are rewritten too.

So beginner rule:

- if a string operation can appear in module-level expression code that the traversal reaches, lowering is not only a function-body concern.

## Preserved shape 1: existing `global.get` users are not re-gathered into something else

If the gathered form already uses:

```wat
(global.get $some_string_global)
```

then lowering keeps that ordinary global read shape and only changes the surrounding type/import world as needed.
It does not invent a second layer of string helper calls for a plain global read.

## Preserved shape 2: unsupported string op families are not silently approximated

This is one of the most important safety rules.
Binaryen does **not** silently lower every future or adjacent string op into some "close enough" helper.
On the unsupported families, the source still marks the missing cases as TODO / unreachable.

That makes the boundary honest and easy to port incorrectly if a future implementation over-generalizes it.

## Sources

- [`../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md`](../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
