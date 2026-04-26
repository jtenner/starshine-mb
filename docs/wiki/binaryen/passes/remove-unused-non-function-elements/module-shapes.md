---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0194-2026-04-21-remove-unused-non-function-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/remove-unused-nonfunction-module-elements_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../remove-unused-module-elements/wat-shapes.md
---

# `remove-unused-nonfunction-module-elements` module-shape catalog

This pass is not mainly about inner expression rewrites.
The 2026-04-24 raw source manifest is [`../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md); the 2026-04-26 port-readiness recheck is [`../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md). Future local test sequencing for these shapes is in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

It is about **whole-module retention and cleanup**.
So the most honest examples are module-shape examples, not tiny isolated arithmetic snippets.

## How to read these examples

Unless noted otherwise, the shapes below are paraphrases or small reconstructions of the behavior visible in the official upstream test file and the reviewed source.

The central rule to keep in mind is:

- defined functions are force-rooted
- ordinary non-function cleanup still runs

## Positive family 1: dead defined helper chain stays

### Before

```wat
(module
  (func $live)
  (func $dead0
    (call $dead1))
  (func $dead1
    (nop))
)
```

### After

The dead chain can still remain.

### Why

The sibling roots every defined function up front.
So `$dead0` and `$dead1` are kept even though nothing else reaches them.

### Durable lesson

The pass is specifically useful when you want module cleanup without deleting dead defined code bodies.

## Positive family 2: dead defined recursion cycle stays

### Before

```wat
(module
  (func $a
    (call $b))
  (func $b
    (call $a))
)
```

### After

Both functions can stay.

### Why

The sibling does not require an outside caller once defined functions are rooted.

### Durable lesson

The pass preserves dead defined cycles too, not just acyclic helper chains.

## Positive family 3: dead memory and table can disappear entirely

### Before

```wat
(module
  (memory 256)
  (table 1 funcref)
)
```

### After

```wat
(module)
```

### Why

There are no defined functions to protect and no non-function uses to retain these declarations.

### Durable lesson

This is still a real cleanup pass, not just a keep-functions no-op.

## Positive family 4: exported non-function declarations stay

### Before

```wat
(module
  (memory 256)
  (table 1 funcref)
  (export "mem" (memory 0))
  (export "tab" (table 0))
)
```

### After

The memory and table stay.

### Why

Exports are ordinary shared roots inherited from full RUME.

### Durable lesson

The sibling keeps the full export-root semantics.

## Positive family 5: active imported-parent segments keep parents alive

### Before

```wat
(module
  (import "env" "memory" (memory 256))
  (import "env" "table" (table 1 funcref))
  (data (i32.const 1) "hello")
  (elem (i32.const 0) $waka)
  (func $waka)
)
```

### After

The imported memory, imported table, segments, and defined function stay.

### Why

The active segments are startup-visible, and the function is defined so it is also rooted.

### Durable lesson

Startup-visible non-function structure still dominates the retention decision.

## Positive family 6: real memory/table users keep parents alive

### Before

```wat
(module
  (type $0 (func))
  (import "env" "memory" (memory 256))
  (import "env" "table" (table 0 funcref))
  (export "user" (func $user))
  (func $user
    (drop (i32.load (i32.const 0)))
    (call_indirect (type $0) (i32.const 0))
  )
)
```

### After

The imported memory and imported table stay.

### Why

The ordinary shared analyzer still sees strong non-function uses.

### Durable lesson

The sibling does not weaken real uses just because functions are rooted.

## Positive family 7: dead imported function can still disappear

### Before

```wat
(module
  (import "env" "used" (func $used (param i32) (result i32)))
  (import "env" "dead" (func $dead (param i32) (result i32)))
  (func $caller
    (drop (call $used (i32.const 0))))
)
```

### After

`$used` stays, but `$dead` can disappear.

### Why

Only **defined** functions receive the sibling's special root treatment.
Imported functions still follow ordinary reachability cleanup.

### Durable lesson

This is the single most important surprise shape in the dossier.

## Positive family 8: dead imported global can disappear while defined bodies stay

### Before

```wat
(module
  (import "env" "live" (global $live i32))
  (import "env" "dead" (global $dead i32))
  (global $copy (mut i32) (global.get $live))
  (func $user
    (drop (global.get $copy)))
)
```

### After

`$live` and `$copy` stay, but `$dead` can disappear.

### Why

The sibling still aggressively cleans dead non-function declarations.

### Durable lesson

The pass is still a useful import-pruning tool even when all defined bodies survive.

## Positive family 9: dead non-exported tags can disappear

### Before

```wat
(module
  (tag $dead (param i32))
  (tag $live (param i64))
  (export "live" (tag $live))
  (func $f)
)
```

### After

`$live` stays, `$dead` can disappear, and `$f` still stays.

### Why

The ordinary shared tag cleanup still applies.

### Durable lesson

The sibling preserves defined functions while still cleaning dead module-surface control metadata.

## Positive family 10: duplicate function types can disappear

### Before

```wat
(module
  (type $0 (func))
  (type $0-dupe (func))
  (func $a (type $0))
  (func $b (type $0-dupe))
)
```

### After

The duplicate type can be folded away while both defined functions remain.

### Why

The sibling still shares the ordinary type cleanup stage.

### Durable lesson

“Keep defined functions” does not mean “freeze the entire type section.”

## Preserved family 1: no-op start metadata can disappear but the body can stay

### Before

```wat
(module
  (start $s)
  (func $s
    (nop))
)
```

### After

A plausible post-pass shape is:

```wat
(module
  (func $s)
)
```

### Why

The shared start cleanup drops a no-op start declaration before or during root seeding, then the sibling still roots the defined function.

### Durable lesson

Start metadata and function-body preservation are separate ideas here.

## Preserved family 2: TNH changes startup-trap retention, not the sibling contract

### Sketch

Out-of-bounds startup segments are normally kept because trapping during instantiation is observable.
Under `trapsNeverHappen`, some of those segments can disappear.

### Durable lesson

This is inherited shared-engine behavior, not a special sibling rule.

## Negative family 1: do not expect dead defined functions to vanish

If your goal is to actually remove dead helper bodies, use full `remove-unused-module-elements`, not this sibling.

## Negative family 2: do not expect imported functions to be protected automatically

If your mental model is “all functions stay,” you will predict the wrong output on imported-function cases.

## Negative family 3: do not expect function-type duplication to remain forever

Type compaction is still part of the ordinary shared cleanup story.

## Starshine-specific caveat

Current Starshine only implements full [`remove-unused-module-elements`](../remove-unused-module-elements/index.md), which may delete dead defined functions. The sibling shapes on this page are future-port requirements for the boundary-only local `remove-unused-non-function-elements` name; see [`./starshine-strategy.md`](./starshine-strategy.md).

## Bottom line

The best compact shape rule is:

- **defined code bodies stay, but the rest of the module still gets cleaned honestly**.

That is the right mental model for reading real outputs from this pass.
