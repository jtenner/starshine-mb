---
kind: concept
status: supported
last_reviewed: 2026-06-07
sources:
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-06-04-local-cse-version-130-current-audit-refresh.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0495-2026-05-06-local-cse-current-main-line-anchor-refresh.md
  - ../../../raw/binaryen/2026-04-25-local-cse-current-main-code-map.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0119-2026-04-20-local-cse-binaryen-research.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../raw/research/0710-2026-06-04-local-cse-o4z-final-pass-audit.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
---

# `local-cse` Basic-Block Windows And Barriers

This page exists because the most common beginner mistake is to hear “common subexpression elimination inside basic blocks” and imagine a much simpler pass than Binaryen actually implements.

The real `version_129` rule is:

- **mostly one linear window at a time**
- with a small cheap adjacent-block extension
- plus several effect and determinism barriers

This page was rechecked against the 2026-04-22 raw primary-source capture at [`../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md`](../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md), which records that the reviewed official Binaryen `version_129` release page showed publish date **2026-04-01**, and the 2026-05-05 current-main recheck at [`../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md), which found no teaching-relevant drift on the checked owner/helper/test surfaces.

## The shortest honest summary

`local-cse` does **not** ask:

- “is this expression repeated anywhere nearby?”

It asks:

- “is this exact whole tree repeated inside the current reuse window, and did nothing in between make the earlier value unsafe or unhelpful to reuse?”

## What “inside basic blocks” means here

Binaryen implements the pass with `LinearExecutionWalker` and sets:

- `connectAdjacentBlocks = true`

That means the reuse window is **not** just a raw block-list segment.
It is a small approximation of linear control flow.

## Connected cases

The window can stay connected across some cheap adjacent dominance cases.

### Case 1: before an `if`, into the `then` arm

The shipped `dominance` test shows this exact family.

If Binaryen sees:

- a repeated original before the `if`
- and the repeated copy inside the `then` arm

then that is still considered one valid reuse window. A 2026-06-04 Starshine audit initially found this as a missed optimization, and the follow-up fix now covers it in the raw/module `local-cse` implementation while preserving after-`if` and else-arm boundary negatives.

### Case 2: across a normal direct call boundary

With `connectAdjacentBlocks = true`, the walker does not force a window reset at calls.

So a pure local-fed arithmetic tree can still be reused after a call **if** the checker later decides the call’s effects do not invalidate it.

This is why the shipped `basics` test can reuse `(i32.add (local.get $x) (local.get $y))` across a call.

## Disconnected cases

The same helper still resets at many boundaries.

### Case 1: code after an `if`

The shipped `basics` test proves this one.

A repeated tree before an `if` does **not** automatically stay visible after the `if` finishes.

So the model is not “whole structured region dominance.”

### Case 2: the `else` arm

The `then` arm can inherit the pre-`if` window, but the `else` arm is separated.

This is why the shipped `dominance` test optimizes the `then` copy and leaves the `else` copy alone.

### Case 3: loops

Loops reset the linear window.

So `local-cse` is not a loop-aware global dataflow pass. Starshine has direct regression coverage proving an expression computed before a loop is not reused inside the loop body.

### Case 4: switches, returns, throws, and other hard control boundaries

`LinearExecutionWalker` also resets at hard boundaries like:

- switches / `br_table`
- returns
- throws / rethrows
- unreachable

Starshine now has focused coverage for plain `br`, switch-like `br_table`, `return`, `throw`, and top-level `unreachable` boundaries: expressions before those terminators are not materialized and reused in their unreachable continuations. A 2026-06-04 spot check showed that legacy `rethrow` follows this hard-boundary shape in Binaryen, but Starshine records it as a focused deferral because the current local raw instruction surface has no distinct `Rethrow` variant; valid WAST `rethrow` lowers to `unreachable` before `local-cse`. A simple straight-line named block is **not** one of these negatives in Binaryen: Binaryen can reuse a before-block expression inside such a block body. A later spot check showed the same for a straight-line `try_table` body with a catch target: the body can inherit the pre-`try_table` expression window. Other spot checks showed that `return_call`, `return_call_indirect`, `return_call_ref`, and `throw_ref` are operand-taking exceptions, and `br_on_null` / `br_on_non_null` / `br_on_cast` / `br_on_cast_fail` are reference-control continuation exceptions, not the same as plain `return` / `throw` / `br` boundaries: Binaryen can materialize an expression before these operations and reuse it in the continuation. Starshine now implements and tests those narrow positives while still treating loops, plain hard terminators, non-idempotent indirect-call roots, and throwing roots conservatively, including an `unreachable` inside a `try_table` body that clears borrowed outer reuse before later body code. That is why a faithful port needs the same window model, not just a vague “scan expressions in order” loop.

## Whole-tree equality is a barrier too

Even when two expressions *look related*, `local-cse` only optimizes **whole repeated trees**.

It does not pull out arbitrary common subtrees from different parents.

## Positive version

If the entire tree repeats:

```wat
(drop
  (i32.eqz
    (i32.add (local.get $x) (local.get $y))
  )
)
(drop
  (i32.eqz
    (i32.add (local.get $x) (local.get $y))
  )
)
```

then the whole `i32.eqz(...)` tree can be the candidate.

## Negative version

If only part of the tree matches:

```wat
(drop
  (foo
    (i32.add (local.get $x) (local.get $y))
    (i32.const 1)
  )
)
(drop
  (foo
    (i32.add (local.get $x) (local.get $y))
    (i32.const 2)
  )
)
```

then current `local-cse` does **not** extract only the shared add.

That is why the `pass.cpp` comment says the pass is especially useful after `flatten`: flatten can turn some “partial subtree” situations into repeated whole-tree situations.

## Parent beats child when both repeat

The scanner does another non-obvious thing.

If a larger parent tree repeats and the pass plans to reuse that whole parent, Binaryen cancels child-level reuse requests inside it.

In plain English:

- if we can reuse the whole parent,
- we do not also need to create another temp for the child.

That is why the file header spends time on the `eqz(A)` example.

## Barrier family 1: shallow non-trap side effects

The scanner rejects roots whose shallow effects include non-trap side effects.

That means roots like ordinary calls are usually out.

A good beginner rule is:

- if the root visibly writes, throws, synchronizes, or otherwise changes state, it is not a `local-cse` root candidate

## Barrier family 2: shallow generativity / nondeterminism

Some roots are unsafe even when they do not look side-effectful enough for the first barrier.

From `properties.cpp`, Binaryen treats roots like these as shallowly generative:

- non-idempotent direct `call`
- `call_indirect`
- `call_ref`
- `struct.new`
- `array.new*`
- `cont.new`

The key idea is:

- if the root can produce a fresh or otherwise different value each time,
- then replacing the second one with the first is wrong.

This is the main GC-era “sounds pure, still not reusable” rule. Starshine now has direct regression coverage for ordinary/imported/multi-result direct-call roots, `call_indirect`, core-fixture `call_ref`, `struct.new`, `struct.new_default`, descriptor `struct.new_desc` / `struct.new_default_desc`, and core-fixture `array.new` / `array.new_default` / `array.new_fixed` / `array.new_data` / `array.new_elem` members of this family: repeated call roots and repeated allocations remain separate and no temp local is introduced. Local-only arithmetic can still cross those operations when Binaryen proves that boundary positive, but the operation root itself remains non-reusable.

## Barrier family 3: intervening invalidation

Even if a root is allowed initially, later code between the original and the repeat can kill the request.

Examples include:

- a `local.set` that changes a local the original depends on
- a store between two loads from the same memory location
- a write to the same mutable global between two candidate `global.get`s, if they were otherwise profitable enough to matter

This later invalidation happens in the checker, not in the scanner. The invalidation is effect/state-sensitive, not a blanket "any write kills everything" rule: 2026-06-04 Starshine slices confirmed Binaryen reuses a local-only arithmetic tree across intervening `struct.set`, `array.set`, `array.fill`, `array.copy`, `array.init_data`, `array.init_elem`, `memory.copy`, `memory.fill`, `memory.init`, `memory.grow`, `memory.size`, `table.get`, `table.copy`, `table.fill`, `table.init`, `table.set`, `table.grow`, `table.size`, and `global.set` operations plus `data.drop` / `elem.drop` segment-drop effects, because the repeated tree reads locals rather than the mutated GC field, array element, filled/copied array range, memory size, linear-memory range, table range, table size, or global value. Starshine now models those operations narrowly as operand-taking side effects or stack reads for this case without treating the write/drop/size instructions themselves as arbitrary reusable roots; `memory.grow` and `table.grow` have explicit no-reuse root guards despite their stack results, memory-size expressions across `memory.grow` stay unmaterialized, repeated `memory.size` roots without intervening growth are covered as a narrow state-read case, `table.size`-dependent roots stay unmaterialized, and global-dependent expressions across `global.set` stay unmaterialized. The same audit stream confirmed `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` mirror `br_on_null` as narrow reference-control continuation cases for local-only repeated trees; Starshine models the operands/fallthrough stack without making the branch operations reusable. The 2026-06-07 conservative-lanes reopening applies the same local-only precision to ordinary/imported/indirect/reference-call boundaries, string/reference tiny roots, string array/encode roots, GC/descriptor allocation roots, and linear-memory/GC atomic roots, while keeping call-dependent, memory/table-dependent, allocation-root, string-root, and atomic-root CSE disabled unless there is separate Binaryen-positive and semantic-safety evidence.

## Why loads are okay even though they may trap

This is one of the easiest rules to misstate.

Binaryen does **not** say loads are side-effect-free in the strong sense.

Instead it uses this narrower reasoning:

- if the retained first load traps, execution never reaches the later repeated load anyway
- so trap differences alone do not make reuse invalid

That is why repeated `i32.load` is a positive case in the shipped lit test.

## Why calls are usually not okay even when they “look identical”

Calls are different because the issue is not just trapping.

Ordinary direct calls can:

- have side effects
- return different results each time
- or both

So repeated call roots stay as separate calls, and expressions that depend on call results do not become reusable parent roots just because the surrounding arithmetic matches. A pure local-only tree may cross an ordinary/imported/indirect/reference call boundary, but that is boundary precision, not call CSE.

## Narrow exception: idempotent direct calls

There is one source-level carveout.

If the callee annotations say `idempotent`, Binaryen allows that direct call as a candidate and also avoids letting a later shallowly-equal idempotent call invalidate the earlier one. Starshine now has a direct regression fixture for this narrow case: `@binaryen.idempotent` WAT annotations lower into `FuncAnnotationSec`, the raw/module `local-cse` path consults only that callee metadata, and repeated single-result direct calls can be materialized with a temp local. Ordinary non-annotated calls, imported calls, multi-result calls, indirect calls, and reference calls remain root/dependent barriers; `call_ref` has a core-built no-reuse fixture paired with the `call_indirect` WAT fixture, and annotated idempotent calls are still invalidated by ordinary calls, local writes, and memory writes in Starshine's focused coverage.

## Barrier family 4: tiny roots are intentionally skipped

Not every safe repeat is worth a temp local.

Binaryen deliberately skips tiny roots such as repeated size-1 `global.get`.

That is a profitability decision, not a correctness restriction.

The shipped `global` test exists to make that distinction obvious.

## Metadata is not a barrier

The expression comparer explicitly ignores metadata differences.

So two semantically equal trees can still fold even if their metadata differs.

This is a good example of a rule that many ports accidentally change if they compare too much structure instead of the same structure Binaryen compares.

## Why the early `flatten` slot exists

The early aggressive slot in `pass.cpp` is:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

That tells us something important about windowing and barriers:

- `local-cse` only sees repeated whole trees
- `flatten` can expose more whole-tree matches
- but flatten also adds locals that make repeated shapes look less equal
- so Binaryen first runs a light locals cleanup to remove that noise

This is a real algorithmic dependency, not just pipeline decoration.

## Why the late `coalesce-locals` neighborhood exists

The ordinary no-DWARF slot is:

- `coalesce-locals`
- `local-cse`
- `simplify-locals`

That placement means:

- `coalesce-locals` may unify local traffic enough to expose clearer repeated trees
- `local-cse` then adds temp-local reuse for those clearer trees
- `simplify-locals` can clean up the resulting local traffic further

So the pass lives in a deliberate local-cleanup conversation with its neighbors.

## What a future Starshine port must preserve

If Starshine grows this pass later, it should preserve all of these rules together:

- limited linear windows, not whole-function GVN
- the cheap adjacent-block extension
- whole-tree matching only
- parent-over-child request cancellation
- early shallow impossibility filtering
- later invalidation filtering
- trap-ignoring load-style reasoning
- generative-root rejection
- the idempotent-call exception
- the profitability thresholds
- the early flatten slot and the late coalesce-locals slot

## One good rule of thumb

When a beginner asks what `local-cse` really does, a good answer is:

> It is a temp-local reuse pass for repeated whole trees in one small execution window, with strict effect and determinism barriers.

That description is much closer to the real `version_129` pass than either:

- “just CSE inside blocks”
- or
- “generic GVN for locals”
