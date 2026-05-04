---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
  - ../../../raw/research/0205-2026-04-21-duplicate-import-elimination-source-confirmation-followup.md
  - ../../../raw/research/0269-2026-04-23-duplicate-import-elimination-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./identity-and-rewrite-surface.md
---

# `duplicate-import-elimination` WAT and module shape guide

This page is the beginner-friendly shape catalog for the real Binaryen `version_129` `duplicate-import-elimination` pass.
The reviewed official Binaryen GitHub `version_129` release page was rechecked on **2026-04-23** through [`../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-23-duplicate-import-elimination-primary-sources.md), and GitHub showed the release publish date as **2026-04-01**. A 2026-05-04 current-`main` recheck in [`../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-duplicate-import-elimination-current-main-recheck.md) found no teaching-relevant drift from the shapes below.

The main question to keep asking is:

- “are these two imported **functions** really the same host function request, and if so, did Binaryen rewrite every later function-name use to the first import name?”

That emphasis on **functions** is the main source-confirmed correction.

## Quick orientation

The real pass has three broad shape zones:

| Zone | Typical shape | Main safety idea |
| --- | --- | --- |
| Duplicate detection | two imported functions with same module/base and same function type | they are alias declarations for the same imported function |
| User retargeting | direct `call`, `ref.func`, start, export, or module-level function reference uses the later alias name | later users can point at the first canonical import instead |
| Removal | later duplicate imported function declaration deleted | one declaration is enough once all function-name users point at it |

## Positive shapes Binaryen really rewrites

## 1. Duplicate imported function used by direct `call`

Before:

```wat
(import "mod" "foo" (func $foo (result i32)))
(import "mod" "foo" (func $bar (result i32)))
(func $main (result i32)
  (call $bar)
)
```

After conceptually:

```wat
(import "mod" "foo" (func $foo (result i32)))
(func $main (result i32)
  (call $foo)
)
```

Why it works:

- same module/base
- same function type
- Binaryen keeps the first imported function name `$foo`

## 2. Duplicate imported function used by `ref.func`

Before:

```wat
(import "mod" "foo" (func $foo))
(import "mod" "foo" (func $bar))
(func
  (drop (ref.func $bar))
)
```

After conceptually:

```wat
(import "mod" "foo" (func $foo))
(func
  (drop (ref.func $foo))
)
```

Why it matters:

- the pass rewrites function references too, not just direct calls

## 3. Duplicate imported function used as the start function

Before:

```wat
(import "mod" "foo" (func $foo))
(import "mod" "foo" (func $bar))
(start $bar)
```

After conceptually:

```wat
(import "mod" "foo" (func $foo))
(start $foo)
```

Why it matters:

- Binaryen updates the module start name explicitly

## 4. Duplicate imported function behind an export alias

Before:

```wat
(import "mod" "foo" (func $foo))
(import "mod" "foo" (func $bar))
(export "entry" (func $bar))
```

After conceptually:

```wat
(import "mod" "foo" (func $foo))
(export "entry" (func $foo))
```

Why it matters:

- export names stay the same
- internal function targets collapse

## 5. Duplicate imported function in element contents through `ref.func`

Source-backed shipped-test shape:

Before:

```wat
(module
  (import "env" "waka" (func $foo))
  (import "env" "waka" (func $bar))
  (table 2 2 funcref)
  (elem (i32.const 0) $foo $bar)
)
```

After conceptually:

```wat
(module
  (import "env" "waka" (func $foo))
  (table 2 2 funcref)
  (elem (i32.const 0) $foo $foo)
)
```

Why it matters:

- module-code function references are part of the real contract
- this is the clearest shipped non-body rewrite family

## Negative or preserved shapes Binaryen deliberately keeps

## 1. Same module/base but different function signature

Shipped-test shape:

```wat
(import "env" "waka" (func $foo))
(import "env" "waka" (func $wrong (param i32)))
```

Preserved because:

- function types differ

This is the one explicit negative family the shipped test proves.

## 2. Different module string

```wat
(import "modA" "foo" (func $a))
(import "modB" "foo" (func $b))
```

Preserved because:

- the `(module, base)` bucket differs

## 3. Different base/field string

```wat
(import "mod" "foo" (func $a))
(import "mod" "bar" (func $b))
```

Preserved because:

- the `(module, base)` bucket differs

## 4. Imported globals, tables, memories, and tags are not current positive shapes

The older dossier treated these as current merge families with caveats.
The source-confirmed `version_129` story is simpler:

- they are outside the current implemented scope of this pass.

So do **not** teach shapes like these as current positives:

```wat
(import "mod" "g" (global $x i32))
(import "mod" "g" (global $y i32))
```

```wat
(import "mod" "t" (table $a 1 1 funcref))
(import "mod" "t" (table $b 1 1 funcref))
```

```wat
(import "mod" "m" (memory $a 1))
(import "mod" "m" (memory $b 1))
```

```wat
(import "mod" "tag" (tag $a (param i32)))
(import "mod" "tag" (tag $b (param i32)))
```

Those are possible future-expansion stories, not current `version_129` `duplicate-import-elimination` behavior.

## Interaction shapes worth remembering

## 1. Two export names can still survive while pointing at one canonical import

Before:

```wat
(import "mod" "foo" (func $foo))
(import "mod" "foo" (func $bar))
(export "a" (func $foo))
(export "b" (func $bar))
```

After conceptually:

```wat
(import "mod" "foo" (func $foo))
(export "a" (func $foo))
(export "b" (func $foo))
```

Why it matters:

- the pass removes duplicate internal declarations, not duplicate export names

## 2. Module-level function references are part of the contract

Beginner shorthand:

- if the later duplicate function name appears in element payloads or other module-level `ref.func` positions, Binaryen intends to retarget that too

## 3. This is not a generic import-cleanup pass

A useful anti-shape is anything that would require rewriting non-function import users.
Current `version_129` does not do that here.

## Easy mental checklist for future Starshine work

When deciding whether a shape should rewrite, ask:

1. Are these both imported **functions**?
2. Do module string and base string match exactly?
3. Do the imported function types match exactly?
4. Is the use one of the real rewritten function-name surfaces?
5. After retargeting, can the later imported function declaration be removed entirely?

That checklist matches the real `version_129` source much better than “duplicate imports disappear.”
