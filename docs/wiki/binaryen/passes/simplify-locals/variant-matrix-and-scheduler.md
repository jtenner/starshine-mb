---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ../../no-dwarf-default-optimize-path.md
  - ../simplify-locals-nostructure/index.md
  - ../simplify-locals-notee-nostructure/index.md
---

# Binaryen `simplify-locals` variant matrix and scheduler

## Why this page exists

One of the easiest ways to misunderstand `simplify-locals` is to talk as if Binaryen ships one pass with one fixed behavior.
That is not how `version_129` is structured.

Binaryen exposes **five** public pass names that all come from one template with **three** semantic switches.
This page is the durable answer to:

- what each public variant actually allows
- where each variant runs
- why Binaryen uses different variants in different scheduler slots

## The three semantic axes

`SimplifyLocals.cpp` defines:

- `SimplifyLocals<allowTee, allowStructure, allowNesting>`

Those template arguments mean:

### `allowTee`

- `true` means later cycles may turn a multi-use sink into `local.tee`
- `false` means the pass must avoid tee creation

### `allowStructure`

- `true` means the pass may synthesize block / `if` / loop result structure
- `false` means it must stay on the local-sinking and late-copy-cleanup surface only

### `allowNesting`

- `true` means a sink may create new nesting if the other legality checks pass
- `false` means the pass must preserve a flatter shape and reject sinks that would introduce new nesting

That third switch is important.
`nonesting` is not just shorthand for "no tees and no structure."
It is a stronger flatness rule.

## Public variant matrix

| Public pass name | Template instantiation | What it allows | What it forbids |
| --- | --- | --- | --- |
| `simplify-locals` | `<true, true, true>` | tee creation, structure rewrites, ordinary nesting | only the normal effect/control/type barriers |
| `simplify-locals-notee` | `<false, true, true>` | structure rewrites, direct single-use sinks, ordinary nesting | new tees |
| `simplify-locals-nostructure` | `<true, false, true>` | tee creation, direct sinks, ordinary nesting | block / if / loop result synthesis |
| `simplify-locals-notee-nostructure` | `<false, false, true>` | direct single-use sinks and late equal-local cleanup | both tees and structure rewrites |
| `simplify-locals-nonesting` | `<false, false, false>` | flat direct sinks that do not introduce nesting | tees, structure rewrites, and any sink that would add new nesting |

## Quick beginner summaries

### `simplify-locals`

The full variant.
Use this mental model:

- ordinary local sinking
- later tee creation when needed
- structured result synthesis
- late equivalent-copy cleanup
- final dead-set cleanup

### `simplify-locals-notee`

Mostly the same pass, but it refuses to create new tees.
That means it can still form structure, but it will not choose the "consume now, keep later" rewrite.

### `simplify-locals-nostructure`

The early no-DWARF cleanup variant.
It still tees and still nests when allowed, but it refuses to create new block/if/loop result structure.

### `simplify-locals-notee-nostructure`

The aggressive flatten-neighbor cleanup variant.
It removes the easy single-use and equal-copy noise without reintroducing structure or tees.

### `simplify-locals-nonesting`

The flattest variant.
It is not only no-tee and no-structure; it also rejects sinks that would create new nesting in the tree.

## Exact public registration surface

`pass.cpp` registers all five names explicitly.
That matters because the user-facing CLI surface and the internal preset surface are aligned here.
There is no hidden alternate spelling for the full pass family.

The registered descriptions also preserve one important distinction:

- `simplify-locals-nonesting` explicitly advertises that it preserves flatness
- the other no-tee / no-structure variants do not make that stronger promise

## Scheduler placement in `pass.cpp`

## Canonical no-DWARF `-O` / `-Os` path

For the repo's canonical no-DWARF path (`optimizeLevel=2`, `shrinkLevel=1`), the relevant top-level function slots are:

- early:
  - `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs -> ...`
- late:
  - `... -> coalesce-locals -> local-cse? -> simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum`

That means Binaryen uses:

- a **no-structure** pass first
- the **full structured** pass later

This is not accidental duplication.
The source comments explain why.

### Why the early slot is `-nostructure`

Right above the early call, `pass.cpp` says not to create if/block return values yet because coalescing may remove copies that structure creation would inhibit.

So the early slot is intentionally conservative:

- clean local traffic first
- delay control-result synthesis until the local-copy landscape is simpler

### Why the late slot is full `simplify-locals`

Later, after `coalesce-locals` and optional `local-cse`, Binaryen runs the full variant because the function is now cleaner and the structured result rewrites can pay off without blocking earlier copy cleanup.

The nearby source comment says:

- `simplify-locals opens opportunities for optimizations`

That is the official reason the family runs again later.

## Aggressive flatten path

When `optimizeLevel >= 4`, `pass.cpp` adds:

- `flatten`
- `simplify-locals-notee-nostructure`
- `local-cse`

The source comment right there explains the motivation:

- flatten introduces many new and redundant locals
- LocalCSE is especially useful afterwards
- but Binaryen wants some simplify-locals cleanup first so those new locals stop making equivalent expressions look artificially different

This is why the aggressive prelude uses the stricter no-tee/no-structure variant instead of full `simplify-locals`.

## Nested reruns

`opt-utils.h` uses `addDefaultFunctionOptimizationPasses()` inside `optimizeAfterInlining(...)`.
So whatever variant mix the current optimize settings would normally schedule may reappear in nested cleanup reruns after inlining-related work.

The key practical lesson is:

- do not treat the top-level no-DWARF slots as the entire `simplify-locals` story

## Easy misunderstandings to avoid

## Mistake 1: `-nostructure` means "no tee"

Wrong.
`-nostructure` still allows tees.
It forbids only the control-result synthesis layer.

## Mistake 2: `-notee-nostructure` means "flat"

Not quite.
It still allows ordinary nesting unless `allowNesting` is also false.
That is why `-nonesting` has its own public pass name.

## Mistake 3: the full pass and the early pass are redundant

Wrong.
The source comments in `pass.cpp` are explicit that the early slot intentionally avoids structure formation, and that the later full slot is expected to create more opportunities after other local passes have already simplified the function.

## Mistake 4: the aggressive flatten slot proves full `simplify-locals` belongs there too

No.
The whole reason Binaryen picked `simplify-locals-notee-nostructure` for that neighborhood is that flatten just created a lot of local noise and Binaryen wants a flatter, cheaper cleanup there before `local-cse`, not immediate full structure synthesis.

## Practical future-port rules

A future honest Starshine scheduler model should preserve these source-backed facts:

- top-level no-DWARF `-O` / `-Os` uses `simplify-locals-nostructure` early and full `simplify-locals` later
- aggressive flatten-era cleanup uses `simplify-locals-notee-nostructure`, not the full pass
- `nonesting` is a genuinely stronger promise than the other reduced variants
- nested optimizing reruns may reintroduce the family according to the current optimize settings
- understanding the public variant matrix is part of understanding the pass contract itself, not optional documentation polish
