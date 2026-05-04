---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/research/0431-2026-05-04-string-gathering-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md
  - ../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md
  - ../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md
  - ../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./reuse-naming-and-ordering.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../../../strings/string-const-surface.md
  - ../../no-dwarf-default-optimize-path.md
---

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md), the 2026-05-04 current-main recheck in [`../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-string-gathering-current-main-recheck.md), and the local status/code-map bridge in [`./starshine-strategy.md`](./starshine-strategy.md).

# `string-gathering` WAT Shapes

This page is the beginner-friendly shape catalog for Binaryen’s `string-gathering` pass.

## Read this page with one mental model

Binaryen is looking for **literal string constants** that can all read from one canonical immutable global per distinct literal.

It is not asking:

- “can I lower string operations now?”
- “can I delete string globals?”
- “can I rewrite every string-related thing?”

It is asking:

- “where are the `string.const` nodes?”
- “does this literal already have a reusable defining global?”
- “if not, can I create one and rewrite the other uses to `global.get`?”

## Quick glossary

- **defining global**: the immutable non-null string global that actually stores the literal with a direct `string.const`
- **alias global**: another global that now reads from the defining global with `global.get`
- **reusable global**: an existing global already in the exact defining shape Binaryen wants
- **module-code user**: a string constant inside a global initializer or other module-level expression slot, not just inside a function body

## Shape 1: repeated function-body literals collapse to one defining global

Before:

```wat
(module
  (func $a
    (drop
      (string.const "bar")))
  (func $b
    (drop
      (string.const "bar"))))
```

After, conceptually:

```wat
(module
  (global $"string.const_\"bar\"" (ref string)
    (string.const "bar"))
  (func $a
    (drop
      (global.get $"string.const_\"bar\"")))
  (func $b
    (drop
      (global.get $"string.const_\"bar\""))))
```

Why it rewrites:

- both uses are direct `string.const`
- there is no reusable defining global yet
- the pass creates one defining global and redirects the uses

## Shape 2: an existing immutable `(ref string)` global can be reused directly

Before:

```wat
(module
  (global $global (ref string) (string.const "foo"))
  (func $a
    (drop
      (string.const "foo"))))
```

After:

```wat
(module
  (global $global (ref string) (string.const "foo"))
  (func $a
    (drop
      (global.get $global))))
```

Why it rewrites this way:

- `$global` is already in the exact defining shape Binaryen wants
- immutable
- defined
- non-null stringref
- direct `string.const` initializer

So Binaryen reuses it and does **not** create a second defining global.

## Shape 3: a nullable string global is not reusable, so it becomes an alias

Before:

```wat
(module
  (global $global2 (ref null string) (string.const "bar"))
  (func $a
    (drop
      (string.const "bar"))))
```

After, conceptually:

```wat
(module
  (global $"string.const_\"bar\"" (ref string)
    (string.const "bar"))
  (global $global2 (ref null string)
    (global.get $"string.const_\"bar\""))
  (func $a
    (drop
      (global.get $"string.const_\"bar\""))))
```

Why Binaryen refuses to reuse `$global2`:

- it is nullable, not the exact non-null defining type

This is a very important negative case.
“Already contains the string” is not enough.

## Shape 4: multiple reusable globals choose the first one seen

Before:

```wat
(module
  (global $global1 (ref string) (string.const "foo"))
  (global $global2 (ref string) (string.const "foo"))
  (global $global3 (ref string) (string.const "foo")))
```

After, conceptually:

```wat
(module
  (global $global1 (ref string) (string.const "foo"))
  (global $global2 (ref string) (global.get $global1))
  (global $global3 (ref string) (global.get $global1)))
```

Why it rewrites this way:

- all three are reusable defining-shape globals
- Binaryen keeps the first one it sees in module order
- later ones become aliases

This is a real source rule, not just a guess.

## Shape 5: mutable globals are not reusable defining globals

Before:

```wat
(module
  (global $global (mut (ref string)) (string.const "foo"))
  (func $a
    (drop
      (string.const "foo"))))
```

After, conceptually:

```wat
(module
  (global $"string.const_\"foo\"" (ref string)
    (string.const "foo"))
  (global $global (mut (ref string))
    (global.get $"string.const_\"foo\""))
  (func $a
    (drop
      (global.get $"string.const_\"foo\""))))
```

Why Binaryen keeps the extra defining global:

- mutable globals are not safe canonical storage for the pass’s intended shape

## Shape 6: nested module-level users can force the defining global to move earlier

Before:

```wat
(module
  (type $struct (struct (field stringref)))
  (global $struct (ref $struct)
    (struct.new $struct
      (string.const "")))
  (global $string (ref string) (string.const "")))
```

After:

```wat
(module
  (type $struct (struct (field stringref)))
  (global $string (ref string) (string.const ""))
  (global $struct (ref $struct)
    (struct.new $struct
      (global.get $string))))
```

Why it rewrites and reorders:

- the nested `string.const` becomes `global.get $string`
- that means `$string` must appear before `$struct` to keep the initializer valid
- `string-gathering` performs that minimum validity-first reorder itself

This is the best beginner example of why the pass touches module order at all.

## Shape 7: existing `global.get` users are not simplified away

Before:

```wat
(module
  (global $global (ref string) (string.const "foo"))
  (func $b
    (drop
      (global.get $global))))
```

After stays the same:

```wat
(module
  (global $global (ref string) (string.const "foo"))
  (func $b
    (drop
      (global.get $global))))
```

Why Binaryen leaves it alone:

- this pass only rewrites `StringConst` nodes
- it does not try to clean up or propagate preexisting `global.get`s

That is an easy source-level limit to miss.

## Shape 8: this pass does not lower string operations

Before and after both still contain string operations like:

```wat
(string.eq
  (string.const "foo")
  (string.const "bar"))
```

The pass only changes the literal operands to `global.get` when appropriate.
It does **not** replace `string.eq`, `string.concat`, `string.measure_*`, or other string instructions with imports.

That is `string-lowering`’s job, not `string-gathering`’s.

## Shape 9: source-derived module-code coverage is broader than the shipped examples

From `walkModuleCode(...)`, Binaryen also scans module-level expression slots such as:

- table initializer expressions
- element-segment items
- offsets in module-level code

So the most conservative source-based expectation is:

- if a legal `StringConst` appears in one of those module-expression slots,
- `string-gathering` intends to canonicalize it too.

I am marking that as a source-derived inference because the shipped `string-gathering.wast` file directly proves global-initializer coverage, but does not isolate a table/elem example in the test itself.

## What this pass deliberately does not do

- It does not remove dead globals.
- It does not run dataflow or effects.
- It does not choose the final best global layout.
- It does not simplify existing `global.get`s.
- It does not lower string instructions to imports.

If you see one of those transformations, you are probably looking at a different pass.

## Sources

- [`../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md`](../../../raw/binaryen/2026-04-25-string-gathering-current-main-and-port-readiness.md)
- [`../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md`](../../../raw/research/0377-2026-04-25-string-gathering-port-readiness.md)
- [`../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md`](../../../raw/binaryen/2026-04-23-string-gathering-primary-sources.md)
- [`../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md`](../../../raw/research/0124-2026-04-20-string-gathering-binaryen-research.md)
- [`../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md`](../../../raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-gathering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-traversal.h>
