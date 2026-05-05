---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md
  - ../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md
  - ../../../raw/research/0380-2026-04-26-directize-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md
  - ../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-directize-primary-sources.md
  - ../../../raw/research/0126-2026-04-20-directize-binaryen-research.md
  - ../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
---

# `directize` table info and immutability

The reviewed official Binaryen `version_129` release page observed on 2026-04-22 showed publish date **2026-04-01**.
A focused 2026-05-05 current-`main` source bridge found no teaching-relevant drift in `Directize.cpp`, `table-utils.{h,cpp}`, or the dedicated `directize*` lit files.
The 2026-04-26 port-readiness bridge makes this page the source of the first Starshine slice: table facts before call rewrites.

This page is the focused guide to the part of `directize` that is easiest to misunderstand:

- when Binaryen thinks table entries are knowable enough to optimize by entry
- when a constant target becomes `Known`, `Trap`, or `Unknown`
- why “mutable table” and “immutable initial contents” are different ideas

## One mental model to keep in mind

Binaryen does **not** ask only:

- “is the call target a constant?”

It first asks:

- “do I trust what this table entry means?”

If the answer to that second question is no, then even a constant target is not enough.

## `TableInfo` in plain English

`TableUtils::computeTableInfo(...)` computes a `TableInfo` for each table.

The important fields are:

- `mayBeModified`
- `initialContentsImmutable`
- `flatTable`

The important derived question is:

- `canOptimizeByEntry()`

That answer is true only when:

- Binaryen has a valid flattened table view, and
- either the table cannot be modified, or Binaryen was explicitly told that the initial contents are immutable.

## What makes a table “flat” here

Binaryen flattens a table by walking its relevant element segments and trying to build a simple vector of function names by index.

That succeeds only when the segments are boring enough:

- the segment offset is a constant
- the segment type is function-typed
- the segment range does not overflow and does not exceed `table.initial`

If any of those fail, `flatTable.valid` becomes false.

Practical consequence:

- a non-constant element-segment offset is enough to disable entry-level directization for that table
- Binaryen does not try a speculative proof anyway

## Why imported and exported tables count as modifiable

Binaryen marks a table as modifiable when it is:

- imported
- exported
- or written by runtime table mutation instructions

That can look surprising at first:

- an export does not mutate the table by itself

But the point is not “this instruction mutated the table here.”
The point is:

- “outside code could change what future indirect calls through this table mean”

So an exported table is not safe for ordinary entry-level inference by default.

## Runtime mutation barriers Binaryen models

`table-utils.cpp` scans functions for:

- `table.set`
- `table.fill`
- `table.copy` (destination table)
- `table.init`

If any of those write to a table, `mayBeModified` becomes true.

Important note:

- the shipped `directize` lit tests clearly cover `table.set`, `table.fill`, and `table.init`
- the 2026-05-05 current-main recheck still did not find an equally explicit directize-specific test for `table.copy`
- the source still makes destination `table.copy` a real barrier, so a future port should too

## What `initialContentsImmutable` actually means

This is the most important subtlety in the dossier.

`initialContentsImmutable` means:

- the initial contents Binaryen sees in the table are not overwritten
- but later changes can still happen, especially by appending or otherwise affecting entries outside what Binaryen already knows

So this mode is weaker than:

- “the table never changes”

That is why the pass arg is useful for things like LLVM-style output or environments where initial slots stay fixed even if later growth happens.

## The three target answers

After table info is computed, `Directize.cpp` classifies a constant call target as one of:

- `Known`
- `Trap`
- `Unknown`

These are not arbitrary labels. They correspond to three genuinely different rewrite choices.

## `Known`

A constant target is `Known` when:

- it lands on a concrete function name in the flattened table view, and
- that function type is a subtype of the indirect call’s expected heap type

This becomes a direct `call` / `return_call`.

## `Trap`

A constant target is `Trap` when Binaryen can see the call will definitely fail.

The main cases are:

- the slot is a known null hole within the flattened known range
- the slot names a function with an incompatible type
- the index is out of bounds for a table that Binaryen knows cannot later change in a way that would make the entry valid

This becomes `unreachable`, with side effects preserved.

## `Unknown`

A constant target is `Unknown` when Binaryen still does not know enough to be sure.

The main cases are:

- the target is not a constant at all
- or the index is beyond the known flattened prefix on a table that may later change

This keeps the original `call_indirect`.

## The single most important nuance: hole vs beyond-known-prefix

Many people expect these two situations to behave the same way:

1. a constant index points at a slot Binaryen can see is empty
2. a constant index points past the end of the flattened known entries

Binaryen treats them differently.

### In-range known hole

If the index is inside `flatTable.names.size()` and the stored name is empty, Binaryen treats that as a known null slot.

Result:

- `Trap`
- rewrite to `unreachable`

### Beyond the known flattened prefix

If the index is `>= flatTable.names.size()`, Binaryen asks whether the table may still change.

- if the table cannot later change in the relevant way, the answer can be `Trap`
- if the table may still be modified and Binaryen is only assuming immutable initial contents, the answer is `Unknown`

Result:

- keep the indirect call

## Why this distinction exists

A known hole inside the flattened prefix is part of the known initial layout.
A later index beyond the known prefix might still be populated by later growth.

So Binaryen is effectively saying:

- “I know this known initial slot is null”
- versus
- “I do not know whether this later slot might exist later”

## The best shipped example of that nuance

The imported non-contiguous table test demonstrates all three outcomes at once.

Binaryen can see known initial entries at:

- `1`
- `3`

That means:

- `0` and `2` are known holes inside the known prefix -> `Trap`
- `1` and `3` are known functions -> `Known`
- `4` is beyond the known prefix on a mutable imported table -> `Unknown`

That is why the rewritten function becomes a mix of:

- `unreachable`
- direct calls
- preserved indirect call

This is one of the strongest beginner-friendly examples in the whole pass.

## Why bad element layouts often become a no-op instead of a trap

The tests with negative or otherwise weird element offsets are also instructive.

A beginner might expect:

- “the call obviously traps, so rewrite to unreachable”

But Binaryen often leaves those cases alone.

Why?

Because the pass refuses to claim strong entry-level knowledge when the flattening step itself failed.
It does not try to turn every suspicious table-layout case into a stronger semantic proof.

That is a deliberate conservatism rule, not a missed optimization by accident.

## Mutation barriers and immutable mode together

The best way to think about the two modes is this table:

| Table state | Ordinary mode | `directize-initial-contents-immutable` mode |
| --- | --- | --- |
| Unmodified, flat table | known entries can optimize | same |
| Imported/exported flat table | do not optimize by entry | known initial entries can optimize |
| `table.set` / `fill` / `init` / `copy` seen | do not optimize by entry | known initial entries can optimize |
| Non-flat table | do not optimize | do not optimize |

That last row matters. The pass arg is **not** a “please optimize anything anyway” override.
It only relaxes the mutation story, not the flat-table proof requirement.

## Type compatibility is part of table knowledge too

Even if a slot names a function, that is not enough.
Binaryen also requires:

- the callee function type is a subtype of the indirect call’s heap type

So a slot can be “known function” but still classify as `Trap` for this particular call site.

The GC tests are the best examples of that.

## Easy misunderstandings to avoid

- “Imported table” does **not** always mean “never optimizable.”
  - immutable-initial-contents mode can change the answer.
- “Constant index” does **not** always mean “direct call.”
  - it may mean `Trap` or `Unknown` instead.
- “Within declared table size” does **not** always mean “known forever.”
  - beyond-known-prefix can still be `Unknown`.
- “Bad-looking element layout” does **not** always mean directize will prove a trap.
  - often the flattening step simply bails out.
- “Known function” does **not** always mean safe call.
  - subtype compatibility still matters.

## Port checklist for this part specifically

A faithful Starshine port should preserve:

- the `TableInfo` split between mutation knowledge and flat-table knowledge
- imports and exports counting as mutation barriers in ordinary mode
- `table.set`, `table.fill`, `table.copy`, and `table.init` as mutation barriers
- the separate `initial-contents-immutable` concept
- constant-offset and function-typed flat-table requirements
- known-hole versus beyond-known-prefix behavior
- subtype compatibility checks before classifying a slot as `Known`
- conservative no-op behavior when flat-table construction fails

## Sources

- [`../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-directize-current-main-recheck.md)
- [`../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md`](../../../raw/research/0476-2026-05-05-directize-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-directize-port-readiness-primary-sources.md)
- [`../../../raw/research/0380-2026-04-26-directize-port-readiness.md`](../../../raw/research/0380-2026-04-26-directize-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md`](../../../raw/binaryen/2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md`](../../../raw/research/0350-2026-04-25-directize-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-22-directize-primary-sources.md`](../../../raw/binaryen/2026-04-22-directize-primary-sources.md)
- [`../../../raw/research/0126-2026-04-20-directize-binaryen-research.md`](../../../raw/research/0126-2026-04-20-directize-binaryen-research.md)
- [`../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md`](../../../raw/research/0265-2026-04-22-directize-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
