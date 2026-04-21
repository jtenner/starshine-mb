---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0126-2026-04-20-directize-binaryen-research.md
  - ../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./table-info-and-immutability.md
  - ./wat-shapes.md
  - ../reorder-globals/index.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `directize` strategy

This page is the strategy view of the dossier.
For the compact owner/test map, use [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md).

## Upstream source rule

- Use Binaryen `version_129` as the current source oracle for this pass.
- The core implementation lives in `src/passes/Directize.cpp`.
- Scheduler placement comes from `src/passes/pass.cpp`.
- Pass construction is declared in `src/passes/passes.h`.
- The `select`-to-`if` helper lives in `src/passes/call-utils.h`.
- The table-facts prepass lives in `src/ir/table-utils.{h,cpp}`.
- The “batch edits may need type repair” rule comes from `src/ir/type-updating.h`.
- The main shipped behavior examples come from:
  - `test/lit/passes/directize_all-features.wast`
  - `test/lit/passes/directize-gc.wast`
  - `test/lit/passes/directize-wasm64.wast`

Primary source URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>

## High-level intent

Binaryen uses `directize` to remove some late indirect-call overhead after the module’s table/global shape has mostly settled.

That sentence is true but incomplete.

The actual implementation is a late **table-facts + constant-target classification + narrow control rewrite** pass.

A good mental model is:

| Stage | What Binaryen does | Why it exists |
| --- | --- | --- |
| Precompute | Build per-table facts about flat initial contents and mutation risk | Know whether an entry-level table answer is sound |
| Filter | Skip the whole pass if no table has usable entry-level information | Keep the pass tiny when nothing can fire |
| Classify | For each constant target, answer `Known`, `Trap`, or `Unknown` | Avoid false certainty |
| Rewrite | Turn a `call_indirect` into a direct call, `unreachable`, or an `if` over those | Remove dispatch only when the answer is safe |
| Repair | Re-finalize function types if result refinement or fresh locals changed typing | Keep Binaryen IR valid after edits |

That means this pass is not:

- a general `call_ref` optimizer
- a broad constant-propagation pass
- a whole-function dataflow pass
- a profitability heuristic pass
- a nested optimize-after-rewrite pass in `Directize.cpp` itself

## Pass name and scheduler placement

`pass.cpp` exposes one relevant public name here:

- `directize`

Its registration summary is:

- “turns indirect calls into direct ones”

That summary is directionally right, but it hides the two equally important other outcomes:

- some sites become `unreachable`
- some sites remain indirect because Binaryen still knows too little

## Late-tail placement

In the canonical no-DWARF `-O` / `-Os` path tracked in this repo, `directize` appears:

- after `string-gathering`
- after `reorder-globals`
- as the very last top-level pass in the tail

The most important scheduler comment is immediately above that final addition in `pass.cpp`:

- `directize` may allow more `inlining` / `dae` / related work
- but you need `--converge` for that

So the intended late-tail story is:

- Binaryen first settles late module/global cleanup and layout
- then it directizes what it safely can
- and only a converging optimizer run comes back to exploit any newly opened boundary opportunities

## Important public pass-arg fact

`Directize.cpp` has one important optional mode:

- `--pass-arg=directize-initial-contents-immutable`

This does **not** mean:

- “tables cannot change at all”

It means:

- “the initial contents we see are not overwritten, even if the table may still be modified or appended later”

That distinction is crucial for imported/exported/mutated tables.

## Stage 1: compute whole-module table facts first

`Directize::run(Module*)` starts by:

- returning immediately if there are no tables
- reading the optional immutable-initial-contents flag
- calling `TableUtils::computeTableInfo(*module, initialContentsImmutable)`

The pass is therefore boundary-shaped even though the actual body edits happen inside functions.

## What `TableInfo` contains

The important fields are:

- `mayBeModified`
- `initialContentsImmutable`
- `flatTable`

and the important predicate is:

- `canOptimizeByEntry()`

Binaryen can optimize by entry only when:

- either the table cannot be modified at all, **or** its initial contents are declared immutable,
- and the table flattened successfully into a known entry map.

## Why this matters

A direct-call rewrite is only sound if Binaryen can say something strong about the indexed entry:

- this index definitely names function `$f`
- or this index definitely traps
- or we still do not know enough

Without the table-info step, that answer would be too easy to get wrong.

## Stage 2: `FlatTable` is intentionally conservative

`FlatTable` tries to materialize a table as a simple vector of function names.

It only succeeds when the relevant element segments are boring enough:

- constant offsets
- function-typed segment contents
- no overflow or initial-size violation while laying out the entries

If any of those fail, `flatTable.valid` becomes false.

That means Binaryen intentionally refuses entry-level directization when table layout is not easy to flatten.

Practical beginner takeaway:

- “I can imagine a proof” is not enough
- Binaryen wants a very cheap and explicit table-layout proof here

## Stage 3: mutation barriers are broader than they sound

`table-utils.cpp` marks a table as modifiable if it is:

- imported
- exported
- written by `table.set`
- written by `table.fill`
- written by `table.copy` as the destination table
- written by `table.init`

This is why the tests distinguish:

- normal mode
- immutable-initial-contents mode

without pretending imports or exports are harmless by default.

## Stage 4: fast stop if nothing is optimizable

After computing table info, `Directize.cpp` checks whether **any** table reports `canOptimizeByEntry()`.

If none do, the pass returns without even walking functions.

That is a useful portability lesson:

- the pass is supposed to be cheap when the table surface is hostile

## Stage 5: function-parallel walk over `CallIndirect` only

If at least one table is promising, Binaryen runs `FunctionDirectizer`, which is:

- a `WalkerPass<PostWalker<...>>`
- function-parallel
- and only implements `visitCallIndirect(...)`

This is one of the most important “what it is not” facts:

- the pass does **not** inspect `call_ref`
- the pass does **not** do a general call-target analysis over arbitrary indirect-call mechanisms

The tail-call form is still handled, but only because `CallIndirect` carries an `isReturn` bit.

## Stage 6: classify constant targets as `Known`, `Trap`, or `Unknown`

The core helper is `getTargetInfo(...)`.

Given a target expression, relevant table info, and the original indirect call, it returns one of three outcomes.

### `Unknown`

Binaryen returns `Unknown` when:

- the target expression is not a constant
- or the constant index is beyond the flattened known-prefix size and the table may still be modified later

### `Trap`

Binaryen returns `Trap` when:

- the constant index names a known-null hole within the known flattened prefix
- or the constant index names a function whose type is **not** a subtype of the required indirect-call heap type
- or the index is out of bounds for a table whose relevant range cannot later become valid

### `Known`

Binaryen returns `Known{name}` when:

- the index lands on a known function name
- and that function’s type is a subtype of the indirect-call type

## Important subtlety: hole vs beyond-known-prefix

This is one of the easiest facts to miss.

Binaryen treats these differently on mutable-but-immutable-initial-contents tables:

- a **hole inside the known flattened prefix** is a known trap
- an **index beyond the known flattened prefix** is still unknown, because later appends may populate it

That is exactly why one of the imported-table tests can rewrite some indices to `unreachable`, some to direct calls, and still leave a later constant index indirect.

## Stage 7: direct constant rewrites

For a constant target, `visitCallIndirect(...)` copies the operands and calls `makeDirectCall(...)`.

That helper then applies the three-way result:

### `Unknown`

- leave the original `call_indirect` unchanged

### `Trap`

- replace the site with dropped children as needed plus `unreachable`
- mark that function types may need repair

### `Known`

- replace the site with `call $target` or `return_call $target`
- use the target function’s actual results
- mark that function types may need repair if the results became more refined

## Trap semantics matter

`Directize.cpp` explicitly documents the trap policy:

- replacing a trap with another trap is okay during optimization
- silently removing the trap is not the goal here

That is why side-effectful operands are preserved and dropped first rather than erased.

## Stage 8: narrow `select` lowering via `CallUtils`

If the target is not a constant, `Directize.cpp` tries one more helper path:

- `CallUtils::convertToDirectCalls(...)`

This helper only handles:

- `select` as the target
- non-`unreachable` select type
- both arms classifying as either `Known` or `Trap`
- no `unreachable` call operands

If successful, it rewrites the call into:

1. fresh locals storing each original operand once
2. an `if` on the select condition
3. branch-local direct calls or `unreachable`

## Why the helper introduces locals

The helper must:

- evaluate operands only once
- preserve operand order
- move the condition before the branches
- and still reuse the operands in both branches

Fresh locals are the simplest way to do that safely.

This is also why type repair becomes part of the pass contract.

## Deliberate current limits in `CallUtils`

The helper contains source-level TODOs that matter for future ports:

- nested selects / more than two targets are not supported here
- one known arm plus one unknown arm is not lowered to a partial direct-call shape

So a faithful `version_129` port should preserve that narrow scope instead of silently widening it and calling the result “parity”.

## Stage 9: `ReFinalize()` is the chosen repair strategy

`FunctionDirectizer` tracks `changedTypes` and, after the walk, calls:

- `ReFinalize().walkFunctionInModule(func, getModule())`

`type-updating.h` documents this as the standard “do your edits, then repair types afterward” strategy.

This repair is needed because directize can:

- turn a reachable expression into `unreachable`
- refine results when a subtype callee becomes visible
- add locals for select-lowering, including non-nullable reference locals

A future port that omits this repair step will misunderstand the real pass contract.

## Analysis and helper dependencies

This pass depends on:

- `TableUtils::computeTableInfo(...)`
- `TableUtils::TableInfo::canOptimizeByEntry()`
- `CallUtils::convertToDirectCalls(...)`
- `HeapType::isSubType(...)`
- `Builder`
- `ReFinalize`
- `type-updating.h`’s documented repair contract

This pass notably does **not** depend on:

- `Effects`
- liveness
- CFG reasoning
- loop analyses
- broad constant propagation
- escape analysis
- a directize-specific nested optimize-after-rewrite helper in `Directize.cpp`

## Main interactions with nearby passes

## After `reorder-globals`

The strongest direct source fact here is scheduler adjacency:

- Binaryen finishes late global layout first
- then runs `directize`

I did not find a stronger direct code-level dependency where `directize` relies on global order specifically, so that stronger claim would be inference.

## End of the ordinary one-shot tail

`pass.cpp` makes the most important interaction explicit:

- `directize` may expose more inlining / DAE / related opportunities
- but ordinary presets stop here unless `--converge` is requested

That means a future Starshine scheduler should preserve two separate stories:

- one-shot parity tail
- converging optimizer behavior

## What this pass is not

A useful beginner correction list:

- It is not a general `call_ref` pass.
- It is not broad indirect-call solving.
- It is not exact-signature-only.
- It is not safe on mutable tables by default.
- It is not purely local; module-wide table analysis comes first.
- It is not guaranteed to emit only direct calls; some rewrites become `unreachable`.
- It is not a profitability pass; if the answer is known and sound, Binaryen rewrites.
- It is not a nested-cleanup pass by itself.

## Source-derived port checklist

A future Starshine port should preserve all of these:

- final-tail placement after `reorder-globals`
- the `--converge` implication that later boundary opportunities can open here
- the whole-module table-info prepass
- the difference between:
  - fully unmodifiable tables
  - modifiable tables with immutable initial contents
- fast no-op exits when no table is usable
- the `CallIndirect`-only scope of the current implementation
- three-way target classification: `Known`, `Trap`, `Unknown`
- subtype-based type compatibility checks
- trap-preserving rewrites with child side effects retained
- narrow `select`-to-`if` lowering with fresh locals
- post-rewrite `ReFinalize()` repair
- wasm64-correct full-width index handling
- conservative bailouts when flat-table knowledge is missing

## Sources

- [`../../../raw/research/0126-2026-04-20-directize-binaryen-research.md`](../../../raw/research/0126-2026-04-20-directize-binaryen-research.md)
- [`../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md`](../../../raw/research/0209-2026-04-21-directize-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Directize.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/call-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/table-utils.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize_all-features.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/directize-wasm64.wast>
