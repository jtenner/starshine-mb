---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0123-2026-04-20-duplicate-import-elimination-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./identity-and-rewrite-surface.md
---

# `duplicate-import-elimination` WAT and module shape guide

This page is the beginner-friendly shape catalog for Binaryen `duplicate-import-elimination`.

The main question to keep asking is:

- “are these two imported declarations really the same boundary request, and if so, did Binaryen rewrite every later internal user to the first import name?”

## Quick orientation

The pass has three broad shape zones:

| Zone | Typical shape | Main safety idea |
| --- | --- | --- |
| Duplicate detection | two imports with same kind + module + field + helper-defined type metadata | they are alias declarations for the same boundary object |
| User retargeting | instructions/exports/start/module-code expressions mention the later alias name | later users can point at the first canonical import instead |
| Removal | later duplicate import declaration deleted | one declaration is enough once all users point at it |

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

- same import kind
- same module/base
- same function type metadata
- Binaryen keeps the first import name `$foo`

## 2. Duplicate imported function used by `ref.func`

Before:

```wat
(import "mod" "foo" (func $foo (result i32)))
(import "mod" "foo" (func $bar (result i32)))
(func
  (drop (ref.func $bar))
)
```

After conceptually:

```wat
(import "mod" "foo" (func $foo (result i32)))
(func
  (drop (ref.func $foo))
)
```

Why it matters:

- this pass rewrites function references too, not just direct calls

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
(import "mod" "foo" (func $foo (result i32)))
(import "mod" "foo" (func $bar (result i32)))
(export "ex1" (func $bar))
```

After conceptually:

```wat
(import "mod" "foo" (func $foo (result i32)))
(export "ex1" (func $foo))
```

Why it matters:

- export names stay the same
- internal targets collapse

## 5. Duplicate imported global used by `global.get` / `global.set`

Before:

```wat
(import "mod" "bar" (global $x (mut i32)))
(import "mod" "bar" (global $y (mut i32)))
(func
  (drop (global.get $y))
  (global.set $y (i32.const 0))
)
```

After conceptually:

```wat
(import "mod" "bar" (global $x (mut i32)))
(func
  (drop (global.get $x))
  (global.set $x (i32.const 0))
)
```

Why it works:

- same global type and mutability
- same module/base
- later alias `$y` is redirected to `$x`

## 6. Duplicate imported global behind an export alias

Before:

```wat
(import "mod" "bar" (global $x i32))
(import "mod" "bar" (global $y i32))
(export "ex2" (global $y))
```

After conceptually:

```wat
(import "mod" "bar" (global $x i32))
(export "ex2" (global $x))
```

## 7. Duplicate imported table used by ordinary and bulk table ops

Before:

```wat
(import "mod" "baz" (table $p 1 1 funcref))
(import "mod" "baz" (table $q 1 1 funcref))
(func
  (drop (table.size $q))
  (table.set $q (i32.const 0) (ref.null func))
  (table.copy $q $q (i32.const 0) (i32.const 0) (i32.const 1))
  (table.fill $q (i32.const 0) (ref.null func) (i32.const 1))
  (table.init $q $e (i32.const 0) (i32.const 0) (i32.const 1))
)
```

After conceptually:

```wat
(import "mod" "baz" (table $p 1 1 funcref))
(func
  (drop (table.size $p))
  (table.set $p (i32.const 0) (ref.null func))
  (table.copy $p $p (i32.const 0) (i32.const 0) (i32.const 1))
  (table.fill $p (i32.const 0) (ref.null func) (i32.const 1))
  (table.init $p $e (i32.const 0) (i32.const 0) (i32.const 1))
)
```

Why it matters:

- Binaryen rewrites a broad table user surface, not just one instruction family

## 8. Duplicate imported table behind an export alias

Before:

```wat
(import "mod" "baz" (table $p 1 1 funcref))
(import "mod" "baz" (table $q 1 1 funcref))
(export "ex3" (table $q))
```

After conceptually:

```wat
(import "mod" "baz" (table $p 1 1 funcref))
(export "ex3" (table $p))
```

## 9. Duplicate imported memory used by ordinary and bulk memory ops

Before:

```wat
(import "mod" "qux" (memory $m 1 2 shared))
(import "mod" "qux" (memory $n 1 2 shared))
(func
  (drop (memory.size $n))
  (drop (memory.grow $n (i32.const 1)))
  (memory.fill $n (i32.const 0) (i32.const 0) (i32.const 1))
  (memory.copy $n $n (i32.const 0) (i32.const 0) (i32.const 1))
  (memory.init $n $d (i32.const 0) (i32.const 0) (i32.const 1))
)
```

After conceptually:

```wat
(import "mod" "qux" (memory $m 1 2 shared))
(func
  (drop (memory.size $m))
  (drop (memory.grow $m (i32.const 1)))
  (memory.fill $m (i32.const 0) (i32.const 0) (i32.const 1))
  (memory.copy $m $m (i32.const 0) (i32.const 0) (i32.const 1))
  (memory.init $m $d (i32.const 0) (i32.const 0) (i32.const 1))
)
```

Why it matters:

- Binaryen rewrites many memory instruction families, not only section metadata

## 10. Duplicate imported memory behind an export alias

Before:

```wat
(import "mod" "qux" (memory $m 1 2 shared))
(import "mod" "qux" (memory $n 1 2 shared))
(export "ex4" (memory $n))
```

After conceptually:

```wat
(import "mod" "qux" (memory $m 1 2 shared))
(export "ex4" (memory $m))
```

## Negative or preserved shapes Binaryen deliberately keeps

## 1. Same module/base but different function signature

Before:

```wat
(import "mod" "foo" (func $foo (result i32)))
(import "mod" "foo" (func $quux))
```

Preserved because:

- function import type metadata differs

## 2. Same module/base but different global type

Before:

```wat
(import "mod" "bar" (global $x i32))
(import "mod" "bar" (global $z i64))
```

Preserved because:

- global type metadata differs

## 3. Same module/base but different table metadata

Before:

```wat
(import "mod" "baz" (table $p 1 1 funcref))
(import "mod" "baz" (table $r 1 1 externref))
```

Preserved because:

- Binaryen’s table identity helper sees different table metadata

## 4. Same module/base but different memory metadata

Before:

```wat
(import "mod" "qux" (memory $m 1 2 shared))
(import "mod" "qux" (memory $o 3 4 shared))
```

Preserved because:

- memory import metadata differs

## 5. Different module or different field/base name

Before:

```wat
(import "modA" "foo" (func $a))
(import "modB" "foo" (func $b))
;; or
(import "mod" "foo" (func $a))
(import "mod" "bar" (func $b))
```

Preserved because:

- Binaryen requires exact module/base string equality too

## 6. Imported tags are currently untouched

Conceptual shape:

```wat
(import "mod" "tag" (tag $t1 (param i32)))
(import "mod" "tag" (tag $t2 (param i32)))
```

Current `version_129` takeaway:

- the pass source does not scan imported tags
- so do not assume these merge today

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

## 2. Module-code expressions are part of the contract

Beginner shorthand:

- if the duplicate imported name appears in a global initializer, segment offset, or element payload expression, Binaryen intends to retarget that too through `runOnModuleCode(...)`

## 3. But non-expression active segment target-name handling is an open reading caveat

I did not verify an explicit rewrite in this pass’s traced helper path for:

- `ElementSegment.table`
- `DataSegment.memory`

So treat those as a source-reading caution, not as a settled claim.

## Easy mental checklist for future Starshine work

When deciding whether a shape should rewrite, ask:

1. Are the two imports the same handled kind?
2. Do module string and field/base string match exactly?
3. Does the kind-specific import metadata match exactly enough for this helper?
4. Is the use one of the real rewritten surfaces, not just the most obvious one?
5. After retargeting, can the later declaration be removed entirely?

That checklist matches the real `version_129` source much better than “unused duplicate imports disappear.”