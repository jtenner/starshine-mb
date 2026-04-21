---
kind: concept
status: supported
last_reviewed: 2026-04-20
sources:
  - ../../../raw/research/0145-2026-04-20-remove-unused-module-elements-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RemoveUnusedModuleElements.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/element-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/gc-type-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
---

# Roots, reference-only reachability, and nullification in Binaryen RUME

## Why this page exists

This is the easiest part of `remove-unused-module-elements` to misunderstand.
The pass does **not** treat every surviving mention of an element the same way.

The central source idea is:

- some elements are **used**
- some are only **referenced**
- and those two states can lead to different final actions

That is why the pass sometimes keeps a declaration, sometimes deletes it, and sometimes weakens it.

## The shortest honest summary

Use this mental model:

- **used** = the original declaration still has to stay semantically live
- **usedReferenced** = the declaration still matters somehow, but Binaryen may be able to replace it with a weaker inert form or otherwise treat it more conservatively than a strong use

If you flatten those two states into one “live” bit, you lose one of the pass's main ideas.

## Strong roots

These are the easiest to understand.
They make an element strongly used.

Examples from the official source include:

- exports
- the start function
- direct `call`
- strong table operations like `table.get`, `table.set`, `table.init`, `table.copy`, `table.fill`, `call_indirect`
- strong memory operations like loads, stores, atomics, `memory.init`, `memory.copy`, `memory.fill`
- tag operations like `throw` and catch surfaces
- elem/data operations like `elem.drop`, `data.drop`, `array.new_elem`, `array.init_elem`, `array.new_data`, `array.init_data`
- active parent tables or memories when the active segment is semantically meaningful

These are the “must keep the real thing” roots.

## Reference-style roots

The pass also tracks weaker mention styles.
These are still important, but they are not all the same as a direct execution root.

Examples include:

- `ref.func`
- `call_ref` heap-type reachability
- functions discovered from `FlatTable`
- functions named inside live elem segments
- heap types discovered from `struct.get` field types
- type-carried references to globals, tables, memories, or tags

This is where `usedReferenced` starts to matter.
The pass is careful not to overclaim that every such mention forces the original declaration to stay unchanged forever.

## Why active parent retention is not automatic

A table or memory named by an active segment is not always kept alive just because the syntax mentions it.
The pass first asks whether the segment is meaningfully doing anything.

### Active elem parent retention

A parent table can be kept alive by an active elem segment when the elem payload still matters.
But a null-only active elem payload can become a no-op and stop retaining the table.

### Active data parent retention

A parent memory can be kept alive by an active data segment when the data bytes still matter.
But zero-byte active data can become a no-op and stop retaining the memory.

That is why the pass is more precise than “active segment mentions parent, so parent is live.”

## Why `call_ref` matters so much here

`call_ref` is one of the easiest places to underestimate the pass.
Binaryen does not only look at immediate local syntax.
It collects relevant heap types and then finds functions whose types are compatible with those heap-type roots.

So the beginner-safe rule is:

- `call_ref` can keep functions relevant even when there is no direct named `call`

That is a real whole-module reachability edge.

## Why GC field types matter here

`struct.get` can also trigger heap-type collection.
That means RUME is not only about executable uses.
It also follows declaration/type structure when that structure still references functions, tables, memories, or tags.

This is one more reason the pass is bigger than the name suggests.

## Functions are not identical to non-function elements

The pass handles functions differently from globals/tables/memories/tags in an important way.

A safe beginner summary is:

- functions mainly participate in keep-versus-remove plus function-type cleanup
- non-function elements also participate in keep-versus-remove-versus-weaken decisions

That is why the source has special nullification support for non-function elements.

## What “nullification” means here

For some reference-only non-function elements, Binaryen can replace the original declaration with a weaker inert declaration instead of keeping the original live one.

The page does **not** try to restate every kind-specific legality rule in prose.
The durable rule is simpler:

- reference-only does not automatically mean delete
- and it does not automatically mean keep the original declaration either
- sometimes it means “replace with the weakest still-valid declaration”

That weakening goes through `NullifyRemovableElement` in the official source.

## The three-way decision table

| State | Beginner-safe reading | Typical outcome |
| --- | --- | --- |
| strongly used | the original declaration still matters semantically | keep it |
| not referenced at all | nothing still points at it in a meaningful way | remove it |
| referenced-only | some surface still names or types it, but not as a strong use | maybe keep, maybe weaken, depending on kind and removability |

This table is the main idea the old folder was missing.

## The sibling pass changes only the deletion boundary

`remove-unused-nonfunction-module-elements` still uses the same graph logic.
What changes is the final rule:

- do not delete functions
- still apply the rest of the non-function cleanup

So the root/reference-only model matters to both public pass names, not just to the full variant.

## Easy mistakes to avoid

### Mistake 1: treating `ref.func` like `call`

They both matter, but they do not teach the same thing about strength of use.

### Mistake 2: assuming all active segments keep parents alive forever

No-op active segments are one of the official precision points of the pass.

### Mistake 3: assuming the pass only follows explicit instruction indices

It also follows flat tables, elem contents, and heap-type structure.

### Mistake 4: assuming reference-only means delete later

For non-function elements, reference-only can instead mean nullify or otherwise weaken.

## Bottom line

If you remember only one thing from this page, remember this:

- Binaryen RUME is built around the difference between **strong use** and **mere reference**

That difference is what explains:

- why the pass needs helper-heavy graph building
- why some parents survive and others do not
- and why some declarations are weakened instead of simply removed
