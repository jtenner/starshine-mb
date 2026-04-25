---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-flatten-primary-sources.md
  - ../../../raw/research/0360-2026-04-25-flatten-current-main-and-test-map.md
  - ../../../raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0127-2026-04-20-flatten-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-ir-contract-and-preludes.md
  - ./starshine-strategy.md
---

# `flatten` WAT shapes

Use this page together with the tagged raw primary-source manifest in [`../../../raw/binaryen/2026-04-23-flatten-primary-sources.md`](../../../raw/binaryen/2026-04-23-flatten-primary-sources.md), the current-main owner/test-map bridge in [`../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-flatten-current-main-implementation-test-map.md), and the proof-surface map in [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

This page is a beginner-friendly shape catalog for the main `flatten` rewrite families. The broad direct upstream proof surface is `flatten_all-features.wast`; `flatten.wast` is only a small smoke file, and `flatten-eh-legacy.wast` carries the EH-specific proof lane.

The key question to ask in every case is:

- “does this child shape violate Flat IR?”

If yes, Binaryen tries to:

- compute it earlier,
- store it in a temp local,
- and leave behind a `local.get` or placeholder `unreachable`.

## Shape 1: simple nested arithmetic becomes a temp local

## Before

```wat
(func (result i32)
  (i32.add
    (i32.const 0)
    (i32.const 1)
  )
)
```

## After

```wat
(func (result i32)
  (local $tmp i32)
  (local.set $tmp
    (i32.add
      (i32.const 0)
      (i32.const 1)
    )
  )
  (return
    (local.get $tmp)
  )
)
```

## Why

- the function body itself cannot remain a concrete value expression in Flat IR
- so Binaryen computes the value first and returns a local read instead

## Shape 2: already-simple children stay simple

## Before

```wat
(i32.add
  (local.get $x)
  (i32.const 1)
)
```

## After

```wat
(i32.add
  (local.get $x)
  (i32.const 1)
)
```

## Why

- `local.get` and constants are already legal flat children
- flatten is aggressive, but not pointless

## Shape 3: value-carrying `block` becomes prelude block plus `local.get`

## Before

```wat
(i32.add
  (i32.const 0)
  (block (result i32)
    (i32.const 1)
  )
)
```

## After

```wat
(block
  (local.set $tmp0
    (i32.const 1)
  )
)
(local.set $tmp1
  (i32.add
    (i32.const 0)
    (local.get $tmp0)
  )
)
(local.get $tmp1)
```

## Why

- a value-carrying `block` cannot remain as a child
- flatten runs the block earlier as a prelude
- the outer consumer reads the temp instead

## Shape 4: `if (result ...)` writes arm values into a temp

## Before

```wat
(drop
  (if (result i32)
    (i32.const 0)
    (then (i32.const 1))
    (else (i32.const 2))
  )
)
```

## After

```wat
(if
  (i32.const 0)
  (then
    (local.set $tmp
      (i32.const 1)
    )
  )
  (else
    (local.set $tmp
      (i32.const 2)
    )
  )
)
(drop
  (local.get $tmp)
)
```

## Why

- value-carrying `if` is forbidden in Flat IR
- both arms store into the same temp
- the outer use sees only `local.get`

## Shape 5: condition preludes go before the whole `if`, arm preludes stay inside the arms

## Before

```wat
(if
  (call $cond)
  (then
    (drop (call $left))
  )
  (else
    (drop (call $right))
  )
)
```

## After shape

```wat
(local.set $condTmp
  (call $cond)
)
(if
  (local.get $condTmp)
  (then
    (local.set $leftTmp
      (call $left)
    )
    (drop (local.get $leftTmp))
  )
  (else
    (local.set $rightTmp
      (call $right)
    )
    (drop (local.get $rightTmp))
  )
)
```

## Why

- the condition executes before branch choice, so its preludes go outside
- arm-specific work must stay in the corresponding arm

## Shape 6: `local.tee` becomes set-prelude plus get

## Before

```wat
(i32.add
  (block (result i32)
    (local.tee $x
      (i32.const 0)
    )
  )
  (block (result i32)
    (local.tee $x
      (i32.const 1)
    )
  )
)
```

## After shape

```wat
(block
  (local.set $x
    (i32.const 0)
  )
  (local.set $tmp0
    (local.get $x)
  )
)
(block
  (local.set $x
    (i32.const 1)
  )
  (local.set $tmp1
    (local.get $x)
  )
)
(local.set $tmp2
  (i32.add
    (local.get $tmp0)
    (local.get $tmp1)
  )
)
(local.get $tmp2)
```

## Why

- Flat IR forbids `local.tee`
- flatten makes the write explicit and re-reads the value later
- this is one reason flatten creates many locals quickly

## Shape 7: `local.tee` with unreachable value collapses to unreachable

## Before

```wat
(drop
  (local.tee $x
    (unreachable)
  )
)
```

## After

```wat
(unreachable)
```

## Why

- if the value is already unreachable, the set never actually happens
- flatten drops the tee wrapper and keeps the real control effect

## Shape 8: carried `br_if` values go through explicit temps

## Before

```wat
(block $outer (result i32)
  (drop
    (br_if $outer
      (i32.const 4)
      (i32.const 1)
    )
  )
  (br $outer
    (i32.const 8)
  )
)
```

## After shape

```wat
(block $outer
  (local.set $targetTmp
    (i32.const 4)
  )
  (br_if $outer
    (i32.const 1)
  )
  ...
  (local.set $targetTmp
    (i32.const 8)
  )
  (br $outer)
)
(local.get $targetTmp)
```

## Why

- Flat IR does not want branches to carry arbitrary nested value trees directly
- the target temp becomes the explicit payload channel

## Shape 9: `br_if` may need two temps when target type and flowing-out type differ

## Source-derived family

Binaryen documents a case like:

```wat
(block $any (result anyref)
  (block (result funcref)
    (local.tee $0
      (br_if $any
        (ref.null func)
        (i32.const 0)
      )
    )
  )
)
```

## Why it is tricky

- if the branch is taken, the carried value must match `$any`’s target type
- if the branch is not taken, the value may still flow out through the inner block’s type
- those types may differ

## Binaryen strategy

- one temp for the target block
- possibly one second temp for the still-flowing-out value

This is a very important correctness rule for a future port.

## Shape 10: `switch` / `br_table` value is copied to all unique targets

## Before

```wat
(br_table $a $b $c
  (i32.const 7)
  (local.get $index)
)
```

## After shape

```wat
(local.set $valueTmp
  (i32.const 7)
)
(local.set $tempForA
  (local.get $valueTmp)
)
(local.set $tempForB
  (local.get $valueTmp)
)
(local.set $tempForC
  (local.get $valueTmp)
)
(br_table $a $b $c
  (local.get $index)
)
```

## Why

- flatten does not know which target will be taken
- so it makes every target payload channel explicit

## Shape 11: value-carrying `try` is flattened through a shared temp

## Before

```wat
(try (result i32)
  (do
    (i32.const 0)
  )
  (catch $e
    (pop i32)
  )
)
```

## After shape

```wat
(try
  (do
    (local.set $tmp
      (i32.const 0)
    )
  )
  (catch $e
    (local.set $popTmp
      (pop i32)
    )
    (local.set $tmp
      (local.get $popTmp)
    )
  )
)
(local.get $tmp)
```

## Why

- Flat IR forbids `try` from carrying a value directly
- flatten routes both the main body and catch body values through a temp

## Shape 12: flatten may create blocks inside `catch`, so EH pop fixup is required

## Before

```wat
(block $l0
  (try
    (do)
    (catch $e-i32
      (drop (pop i32))
      (br $l0)
    )
  )
)
```

## After shape

The exact output is verbose, but the key source-backed facts are:

- flatten inserts extra block structure in the catch body
- the `pop` is rewritten through locals
- then Binaryen repairs the nested-pop placement afterwards with `EHUtils::handleBlockNestedPops(...)`

## Why

- without that repair step, the resulting EH structure would be invalid

## Shape 13: real control effects become preludes plus placeholder `unreachable`

## Before

```wat
(select
  (i32.const 0)
  (i32.const 1)
  (br_table 0 (i32.const 7) (i32.const 1))
)
```

## After shape

```wat
(block
  (local.set $targetTmp
    (i32.const 7)
  )
  (br_table 0
    (i32.const 1)
  )
  (select
    (i32.const 0)
    (i32.const 1)
    (unreachable)
  )
  (unreachable)
)
(local.get $targetTmp)
```

## Why

- the real control effect must still happen
- but Flat IR cannot keep that control effect nested in the old child slot
- so Binaryen keeps the real effect in earlier code and leaves a placeholder `unreachable`

## Shape 14: selective non-null support is real

## Before

```wat
(func (param $0 (ref $simplefunc)) (result (ref $simplefunc))
  (local.get $0)
)
```

## After

```wat
(func (param $0 (ref $simplefunc)) (result (ref $simplefunc))
  (local $1 (ref $simplefunc))
  (local.set $1
    (local.get $0)
  )
  (return
    (local.get $1)
  )
)
```

and also:

```wat
(func (result funcref)
  (ref.as_non_null
    (ref.null $none_=>_none)
  )
)
```

becoming a temp-local-returned shape in `flatten_all-features.wast`.

## Why

- some non-null families already work in shipped tests
- that means the open non-nullability TODO is narrower than a blanket “all non-null values are unsupported” claim

## Shape 15: unsupported `BrOn*` and `TryTable` are hard stop families

## Family

- `br_on_null`
- `br_on_non_null`
- `br_on_cast`
- `br_on_cast_fail`
- `try_table`

## Current `version_129` behavior

- `Flatten.cpp` fatals with `Unsupported instruction for Flatten`

## Why this matters

- this is not a soft bailout that leaves the function unchanged
- it is a real unsupported-instruction boundary in current upstream source

## Bottom line

The simplest pattern summary is:

- simple children stay simple
- rich value-producing children become temp locals
- control-flow results become explicit local channels
- tee and branch payloads become explicit local traffic
- real control effects survive as preludes plus placeholder `unreachable`
- and some feature families are still a hard unsupported boundary
