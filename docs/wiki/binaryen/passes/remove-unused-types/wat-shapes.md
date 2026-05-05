---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md
  - ../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md
  - ../../../raw/binaryen/2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0477-2026-05-05-remove-unused-types-current-main-recheck.md
  - ../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./closed-world-visibility-and-rec-group-rewrite.md
  - ./starshine-strategy.md
---

# `remove-unused-types` WAT shapes

This page is the beginner-friendly module-shape catalog for Binaryen `remove-unused-types`.
A 2026-05-05 current-main recheck still teaches these same families.

## Read this page with one mental model

Binaryen is usually trying to do three things:

1. keep public type groups as anchors,
2. delete private heap types that are not used by the surviving IR,
3. rebuild and remap the surviving private type graph.

So the pass is not mainly about individual instructions.
It is about the **module's type section and heap-type graph**.

## Important note about the examples

These examples are conceptual.
Real Binaryen output may:

- renumber type indices,
- rewrite names,
- merge surviving private types into a fresh private group,
- keep public group structure as an anchor,
- and print different text than the sketches below.

Read the shapes as semantic before/after families, not exact output templates.

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

- the module is closed-world and GC-enabled,
- `$unused` is private,
- nothing in the surviving IR still uses it.

This is the simplest positive family.

## Shape 2: used private singleton type stays, possibly under a new identity

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
  (type $box-or-renumbered (struct (field i32)))
  (func (result (ref null $box-or-renumbered))
    (ref.null $box-or-renumbered)))
```

Why:

- the function signature and body still use the private heap type,
- the pass keeps the semantic type use,
- but the printed name/index/group may change during the rebuild.

Important lesson:

- use preservation is required; old index and old grouping preservation is not.

## Shape 3: unused member of an old private group can disappear

Before, conceptually:

```wat
(module
  (rec
    (type $live (struct (field i32)))
    (type $dead (struct (field i64))))
  (func (result (ref null $live))
    (ref.null $live)))
```

After, conceptually:

```wat
(module
  (rec
    (type $live-or-renumbered (struct (field i32))))
  (func (result (ref null $live-or-renumbered))
    (ref.null $live-or-renumbered)))
```

Why:

- `$live` is used,
- `$dead` is not used,
- the old private rec-group boundary is not automatically preserved whole.

This is the central correction from the older dossier.

## Shape 4: private field dependency keeps another private type alive

Before, conceptually:

```wat
(module
  (rec
    (type $node (struct (field (ref null $payload))))
    (type $payload (struct (field i32))))
  (func (result (ref null $node))
    (ref.null $node)))
```

After, conceptually:

```wat
(module
  (rec
    (type $payload-or-renumbered (struct (field i32)))
    (type $node-or-renumbered (struct (field (ref null $payload-or-renumbered)))))
  (func (result (ref null $node-or-renumbered))
    (ref.null $node-or-renumbered)))
```

Why:

- `$node` is used,
- `$node`'s field type references `$payload`,
- the rebuilt graph must keep the referenced private type and order it safely.

Important lesson:

- old group retention is not the rule, but real private dependencies still keep referenced types alive.

## Shape 5: unused private rec group disappears together

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

- no member of the private group is still used by the surviving IR,
- Binaryen does not keep private recursive groups speculatively.

## Shape 6: public type stays even if local code does not use it

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

- `$pub` is part of the public boundary,
- public visibility is itself a keep reason.

This is the most important difference between public and private types.

## Shape 7: public boundary does not keep every private subtype

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

- the public supertype stays,
- the private subtype still has to be used to survive.

Important lesson:

- public reachability is not “keep the whole private subtype forest.”

## Shape 8: used private subtype of public type survives around the public anchor

Before, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (type $private-sub (sub $pub (struct (field i32))))
  (func (result (ref null $private-sub))
    (ref.null $private-sub)))
```

After, conceptually:

```wat
(module
  (type $pub (sub (struct)))
  (export "T" (type $pub))
  (rec
    (type $private-sub-or-renumbered (sub $pub (struct (field i32)))))
  (func (result (ref null $private-sub-or-renumbered))
    (ref.null $private-sub-or-renumbered)))
```

Why:

- `$pub` stays as a public anchor,
- `$private-sub` stays because the function uses it,
- the private survivor can be rebuilt separately while still referencing the public supertype.

## Shape 9: declaration-level uses keep types alive

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
  (type $sig-or-renumbered (func (param (ref null eq))))
  (func $f (type $sig-or-renumbered)
    (nop)))
```

Why:

- the function declaration still uses the function type,
- the pass must rewrite declaration references consistently.

Important lesson:

- used type discovery is broader than scanning obvious body instructions.

## Shape 10: descriptor/described dependency can constrain private rebuild order

Before, conceptually:

```wat
(module
  (rec
    (type $node
      (descriptor $node_desc)
      (struct))
    (type $node_desc
      (describes $node)
      (struct)))
  (func (result (ref null $node))
    (ref.null $node)))
```

After, conceptually:

```wat
(module
  ;; both descriptor-related private types may be rebuilt and renumbered,
  ;; but descriptor/described links must still be valid.
  (rec
    (type $node-or-renumbered
      (descriptor $node-desc-or-renumbered)
      (struct))
    (type $node-desc-or-renumbered
      (describes $node-or-renumbered)
      (struct)))
  (func (result (ref null $node-or-renumbered))
    (ref.null $node-or-renumbered)))
```

Why:

- descriptor/described links are type-graph dependencies,
- the new private group must preserve those links when the used graph requires them.

## Shape 11: no-GC module is unchanged

Before:

```wat
(module
  (type $f (func (result i32)))
  (func (type $f)
    (i32.const 1)))
```

After:

```wat
(module
  (type $f (func (result i32)))
  (func (type $f)
    (i32.const 1)))
```

Why:

- `RemoveUnusedTypes.cpp` returns immediately when GC features are absent.

## Shape 12: open-world execution is not a supported rewrite context

Conceptual command shape:

```text
wasm-opt --remove-unused-types input.wasm
```

without closed-world mode is not the intended successful rewrite case.
The pass body fatally rejects open-world execution.

The scheduled form belongs in a closed-world optimization context, conceptually:

```text
wasm-opt --closed-world --remove-unused-types input.wasm
```

Future Starshine behavior should choose an explicit API shape here:

- keep the pass boundary-only until closed-world support exists,
- then reject or skip open-world requests deliberately,
- and only rewrite when the module is known closed-world.

## Non-goals and nearby passes

`remove-unused-types` is not:

- [`../remove-unused-module-elements/index.md`](../remove-unused-module-elements/index.md), which removes unused module elements,
- [`../type-merging/index.md`](../type-merging/index.md), which merges still-used private type identities when they are unobservable,
- [`../minimize-rec-groups/index.md`](../minimize-rec-groups/index.md), which repartitions recursive groups without the same dead-private-type cleanup goal,
- [`../unsubtyping/index.md`](../unsubtyping/index.md), which removes subtype/descriptor relations rather than dead private type identities.

## Validation checklist

When testing this pass or a future Starshine port, include:

- no-GC no-op fixtures,
- open-world rejection or no-schedule fixtures,
- unused private singleton removal,
- unused private member removal from a larger old group,
- private field-dependency retention,
- public type retention,
- private subtype of public removal when unused,
- private subtype of public retention when used,
- descriptor/described link preservation,
- final module validation after type remapping,
- parity checks against Binaryen `wasm-opt --closed-world --remove-unused-types`.

## Sources

- [`../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md`](../../../raw/binaryen/2026-04-24-remove-unused-types-primary-sources.md)
- [`../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md`](../../../raw/research/0298-2026-04-24-remove-unused-types-source-correction-and-starshine-followup.md)
- Historical, superseded for old group-retention wording: [`../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md`](../../../raw/research/0149-2026-04-21-remove-unused-types-binaryen-research.md)
- Binaryen `version_129`:
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/RemoveUnusedTypes.cpp>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/remove-unused-types.wast>
