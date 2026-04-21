---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
---

# `remove-unused-types` WAT shapes

This page is the beginner-friendly module-shape catalog for Binaryen `remove-unused-types`.

## Read this page with one mental model

Binaryen is usually trying to do one of three things:

1. keep public heap types unchanged
2. keep only the private heap types that are still used
3. preserve whole rec groups for the private types that survive

So the pass is not mainly about individual instructions.
It is about the **module's type section and heap-type graph**.

## Important note about the examples

These examples are conceptual.
Real Binaryen output may:

- renumber type indices
- merge rewritten private types around public groups
- keep exact pretty-printing different from the sketches below

So read the shapes as semantic before/after families, not exact final text templates.

## Shape 1: unused private singleton type disappears

Before, conceptually:

```wat
(module
  (type $unused (struct (field i32)))
  (func (result i32)
    (i32.const 0)))
```

After, conceptually:

```wat
(module
  (func (result i32)
    (i32.const 0)))
```

Why:

- the module is closed-world + GC-enabled
- `$unused` is private
- nothing in the surviving module still uses it

This is the simplest positive family.

## Shape 2: used private singleton type stays

Before, conceptually:

```wat
(module
  (type $box (struct (field i32)))
  (func (result (ref null $box))
    (ref.null $box)))
```

After, conceptually:

```wat
(module
  (type $box (struct (field i32)))
  (func (result (ref null $box))
    (ref.null $box)))
```

Why:

- the function signature and body still use `$box`
- `ModuleUtils::CodeScanner` sees those type uses

Important lesson:

- declaration-level and code-level uses both count

## Shape 3: one used private member keeps the whole private rec group

Before, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref null $B))))
    (type $B (struct (field i32))))
  (func (result (ref null $A))
    (ref.null $A)))
```

After, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref null $B))))
    (type $B (struct (field i32))))
  (func (result (ref null $A))
    (ref.null $A)))
```

Why:

- `$A` is used privately
- Binaryen therefore keeps the whole old rec group, including `$B`

This is the main structural rule of the pass.

## Shape 4: unused private rec group disappears together

Before, conceptually:

```wat
(module
  (rec
    (type $A (struct (field (ref null $B))))
    (type $B (struct (field i32))))
  (func (result i32)
    (i32.const 0)))
```

After, conceptually:

```wat
(module
  (func (result i32)
    (i32.const 0)))
```

Why:

- no member of the private rec group is still used
- Binaryen does not keep private recursive groups speculatively

## Shape 5: public type stays even if local code does not use it

Before, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (func (result i32)
    (i32.const 0)))
```

After, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (func (result i32)
    (i32.const 0)))
```

Why:

- `$pub` is part of the external boundary
- public visibility is itself a keep reason

This is the most important difference between public and private types.

## Shape 6: public boundary does not automatically keep every private subtype group

Before, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (type $private-sub (sub $pub (struct)))
  (func (result i32)
    (i32.const 0)))
```

After, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (func (result i32)
    (i32.const 0)))
```

Why:

- the public supertype stays
- the private subtype still has to earn its place by actual use

Important lesson:

- public reachability is not the same as “keep the whole private subtype forest”

## Shape 7: a used private group is threaded around public structure only when needed

Before, conceptually:

```wat
(module
  (rec
    (type $pub (sub (struct)))
    (type $pub-child (sub $pub (struct))))
  (rec
    (type $private-unused (struct))
    (type $private-used (struct (field i32))))
  (export "T" (type $pub))
  (func (result (ref null $private-used))
    (ref.null $private-used)))
```

After, conceptually:

```wat
(module
  ;; public group remains the anchor
  ;; only the needed private rewritten group is retained
  (export "T" (type ...))
  (func (result (ref null ...))
    (ref.null ...)))
```

Why:

- Binaryen keeps public group structure stable first
- it retains only the private group that is actually still used
- it does not copy unrelated private groups into the public group just because they existed nearby in the old numbering

This is one of the most important helper-driven families in the dedicated lit file.

## Shape 8: declaration-level uses keep types alive even when bodies look trivial

Before, conceptually:

```wat
(module
  (type $sig (func (param (ref null eq))))
  (func $f (type $sig)
    (nop)))
```

After, conceptually:

```wat
(module
  (type $sig (func (param (ref null eq))))
  (func $f (type $sig)
    (nop)))
```

Why:

- `ModuleUtils::CodeScanner` visits function signatures too
- a type used by a surviving declaration is still used

This is a good beginner correction because the pass is broader than function-body scanning.

## Shape 9: no-GC modules are a whole-pass no-op

Before:

```wat
(module
  (func (result i32)
    (i32.const 0)))
```

After:

```wat
(module
  (func (result i32)
    (i32.const 0)))
```

Why:

- the pass exits immediately when `!module->features.hasGC()`

So `remove-unused-types` is not a generic MVP function-type cleanup pass.

## Shape 10: open-world modules are also a whole-pass no-op

Before, conceptually:

```wat
(module
  ;; module is not closed-world
  (type $box (struct (field i32)))
  ...)
```

After:

```wat
(module
  ;; unchanged
  (type $box (struct (field i32)))
  ...)
```

Why:

- Binaryen requires `closedWorld`
- public type identity and subtype visibility are part of the proof boundary

This is one of the biggest non-obvious rules in the pass.

## Shape 11: optimize level below `2` is another whole-pass no-op

Before and after stay the same in the important part.

Why:

- the pass is gated by `optimizeLevel >= 2`

So a future Starshine scheduler must treat it as an optimization-stage pass, not an always-on cleanup pass.

## Negative / bailout families

These are just as important as the positive removals.

## Public types are never treated like disposable private types

If a type is public, the pass does not remove it just because local code no longer mentions it.

## Unused private group members are not peeled away one by one from a kept rec group

If one member of a private rec group is needed, the group survives as a group.

## Open world and no-GC are hard no-run boundaries

The pass does not attempt a weaker best-effort version there.
It simply does not run.

## The pass is not declaration GC

A surviving function/global/tag/table set can still be followed by type cleanup.
That is why this pass is adjacent to `remove-unused-module-elements`, not identical to it.

## Bottom line

The most useful beginner question is not:

- is this individual type node dead?

It is:

- is this type public, and if not, which whole private rec group still has to survive after module cleanup?

That is the real `remove-unused-types` shape logic.

## Sources

- [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
