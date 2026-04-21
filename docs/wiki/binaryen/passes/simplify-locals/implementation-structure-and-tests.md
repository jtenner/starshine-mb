---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0148-2026-04-21-simplify-locals-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./variant-matrix-and-scheduler.md
  - ./wat-shapes.md
  - ../../no-dwarf-default-optimize-path.md
---

# Binaryen `simplify-locals` implementation structure and tests

## Why this page exists

The main landing and strategy pages explain what `simplify-locals` means.
This page answers a narrower question:

- which official Binaryen files and tests actually define that meaning?

That matters because `simplify-locals` is easy to misremember as one vague locals pass.
In `version_129`, the real contract is spread across:

- one core implementation file
- a few helper headers
- pass registration and scheduler placement
- a pass-runner postcondition
- a broad but very interpretable lit roster

## Upstream file map

## 1. `src/passes/SimplifyLocals.cpp`

This is the owning implementation.
It defines:

- the templated `SimplifyLocals<allowTee, allowStructure, allowNesting>` family
- main-cycle linear-trace sinking
- structure rewrites for blocks / ifs / loops
- enlargement queues and retry cycles
- the late `EquivalentOptimizer`
- the final call to `UnneededSetRemover`
- the public pass constructors for all five variants

If you need the answer to “does upstream Binaryen actually do this inside the pass itself?”, this is the first file to inspect.

## 2. `src/ir/linear-execution.h`

This file explains the cheap execution model the pass is built on.
It provides:

- straight-line trace traversal
- notifications when control becomes nonlinear
- optional adjacent-dominator connection through `connectAdjacentBlocks`

This is the file that explains why `simplify-locals` can get useful motion and copy-cleanup behavior without building a full CFG.
It also explains the deliberate limits around branches, loops, and more complex control merges.

## 3. `src/ir/effects.h`

This file provides `EffectAnalyzer`.
For `simplify-locals`, that means:

- `orderedAfter(...)` invalidation checks
- may-throw barriers for `try` / `try_table`
- trap, memory, table, global, and atomic ordering decisions
- `danglingPop` rejection for sinkable values under EH

If a beginner asks “why didn't Binaryen move this local write?”, the true answer usually lives here.

## 4. `src/ir/equivalent_sets.h`

This is the tiny but important helper behind the late equal-local phase.
It owns:

- equivalence-class storage
- class reset on new writes
- symmetric equivalence addition
- cheap equivalence queries

It is small, but it explains why the late phase is not just ad hoc copy deletion.

## 5. `src/ir/local-utils.h`

This file contributes two helpers that are part of the real pass boundary.

### `LocalGetCounter`

Used for:

- first-cycle single-use decisions
- late equal-local representative choice

### `UnneededSetRemover`

Used for the final cleanup pass after equivalent-local rewriting.
It owns the final “dead tee -> value / dead effectful set -> drop / dead pure set -> nop” surface.

## 6. `src/passes/pass.cpp`

This file defines the public contract in two ways.

### Public names

It registers all five user-facing variants:

- `simplify-locals`
- `simplify-locals-nonesting`
- `simplify-locals-notee`
- `simplify-locals-nostructure`
- `simplify-locals-notee-nostructure`

### Scheduler placement

It places:

- `simplify-locals-notee-nostructure` in the aggressive `flatten` prelude
- `simplify-locals-nostructure` in the early no-DWARF local-cleanup slot
- full `simplify-locals` in the later structured local-cleanup slot

That scheduler surface is part of the meaning of the pass family, not just packaging.

## 7. `src/passes/opt-utils.h`

This file matters because it decides what nested reruns do.
`optimizeAfterInlining(...)` calls:

- `addUsefulPassesAfterInlining(...)`
- which prepends `precompute-propagate`
- then reuses `addDefaultFunctionOptimizationPasses()`

So the `simplify-locals` family may reappear in nested optimizing reruns, not just at the visible top-level slots.

## 8. `src/pass.h`

This is the easiest file to forget and one of the most important.

Why it matters:

- `Pass::requiresNonNullableLocalFixups()` defaults to `true`
- `PassRunner::handleAfterEffects(...)` therefore runs `TypeUpdating::handleNonDefaultableLocals(...)` after `simplify-locals`

So the real validation contract is split across:

- `SimplifyLocals.cpp`
- `ReFinalize`
- pass-runner nondefaultable-local fixups

A port that copies only `SimplifyLocals.cpp` logic would miss part of Binaryen's actual postcondition.

## File-to-responsibility map

| File | Main responsibility for this dossier |
| --- | --- |
| `src/passes/SimplifyLocals.cpp` | core algorithm, public variant constructors, structure rewrites, late equal-local cleanup |
| `src/ir/linear-execution.h` | cheap straight-line trace model and adjacent-dominator option |
| `src/ir/effects.h` | ordering, throw, trap, memory, table, global, and atomic barriers |
| `src/ir/equivalent_sets.h` | late equal-local classes |
| `src/ir/local-utils.h` | get counting and final dead-set cleanup |
| `src/passes/pass.cpp` | public names and top-level scheduler placement |
| `src/passes/opt-utils.h` | nested rerun placement after inlining |
| `src/pass.h` | automatic nondefaultable-local fixup contract |

## Official test roster

The simplify-locals lit surface looks large, but it is very structured.

## Global and call-effect precision

### `simplify-locals-global.wast`

Teaches:

- immutable `global.get` can move across a call
- mutable `global.get` cannot

This is the simplest official proof that the pass is effect-sensitive, not purely syntactic.

### `global-effects_simplify-locals.wast`

Teaches:

- with `--generate-global-effects`, Binaryen may distinguish a call that only reads a global from one that writes it
- that extra effect precision unlocks extra motion

This file is important because it proves the pass is meant to benefit from global-effects metadata, not just raw instruction classes.

## EH and try-boundary behavior

### `simplify-locals-eh.wast`
### `simplify-locals-eh-legacy.wast`

Teach:

- values that may throw cannot be sunk into `try` / `try_table`
- values that cannot throw still can be sunk there
- the late equal-local phase may still reason across adjacent dominated code even under EH

These files also keep the old-vs-new EH surface honest.

## GC, type sharpening, and nondefaultable-local validation

### `simplify-locals-gc.wast`

Teaches several important families in one file:

- heap read/write ordering
- immutable-field reordering wins
- `unreachable` GC corner cases left for other passes
- `br_on_*` blocking block-return synthesis
- one-armed `if` defaultable-local versus nondefaultable-local behavior
- direct-sink type sharpening that can require refinalization

### `simplify-locals-gc-nn.wast`

Teaches:

- nondefaultable-local structural dominance issues under EH
- when fixups such as `ref.as_non_null` are required to keep the new placement valid

### `simplify-locals-gc-validation.wast`

Teaches:

- sinking into a deeper block may require nondefaultable-local validation repair afterward
- the pass runner's automatic fixup story is part of the real contract

## Strings, tables, atomics, and TNH

### `simplify-locals-strings.wast`

Teaches:

- `string.new_*_array` behaves like a GC-array read for motion purposes
- `string.encode_*_array` behaves like a GC-array write for motion purposes
- not every string-looking op is interchangeable in effect terms

### `simplify-locals-table_copy.wast`

Teaches:

- `table.get` may move across inert code like `nop`
- `table.get` may not move across `table.init`

### `simplify-locals-atomic-effects.wast`

Teaches:

- shared vs unshared memory matters
- shared vs unshared GC heaps matter
- acquire/release asymmetry matters
- `trapsNeverHappen` can interact with motion, but does not erase the synchronization model

This is one of the strongest demonstrations that `simplify-locals` is really driven by effect ordering.

### `simplify-locals-tnh.wast`

Teaches:

- TNH opens some extra trap-commuting motion opportunities
- but the pass still stays within its straight-line-trace scope and does not become a general control-flow mover

## Cross-pass and combo files

### `simplify-locals_rse_fallthrough.wast`

Teaches:

- a tee that looks redundant can still be semantically required once branch fallthrough semantics and later `rse` behavior are considered together

This file is valuable because it prevents an overly aggressive "remove obviously redundant tee" reading.

### `flatten_simplify-locals-nonesting_dfo_O3.wast`
### `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
### `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

These are combo tests rather than pure isolated pass tests.
They teach two important things anyway:

- the nonesting variant is part of a real aggressive pipeline surface, not dead API clutter
- the flatten-era local cleanup story is intentionally different from the later structured `simplify-locals` slot

## Test-to-behavior map

| Test file | Main lesson |
| --- | --- |
| `simplify-locals-global.wast` | immutable vs mutable global motion |
| `global-effects_simplify-locals.wast` | call-summary precision with generated global effects |
| `simplify-locals-eh.wast` | may-throw values cannot sink into `try` / `try_table` |
| `simplify-locals-eh-legacy.wast` | same story on legacy EH surface |
| `simplify-locals-gc.wast` | GC barriers, `br_on` bailouts, one-armed-if limits, type sharpening |
| `simplify-locals-gc-nn.wast` | nondefaultable-local fixes under EH |
| `simplify-locals-gc-validation.wast` | pass-runner local fixups after sinking |
| `simplify-locals-strings.wast` | string read/write ordering |
| `simplify-locals-table_copy.wast` | table read/write ordering |
| `simplify-locals-atomic-effects.wast` | shared/unshared and acquire/release ordering |
| `simplify-locals-tnh.wast` | TNH-specific trap-commuting motion |
| `simplify-locals_rse_fallthrough.wast` | preserve required tees in branchy fallthrough shapes |
| `flatten_simplify-locals-nonesting_*` | aggressive flat/nonesting scheduler surface |

## Narrow freshness note

A 2026-04-21 current-main check found:

- only tiny container cleanup in `SimplifyLocals.cpp`
- no checked semantic drift in the major dedicated lit files used for this page

So the practical rule for this dossier is:

- teach the `version_129` file/test structure as the authoritative released contract
- add a drift note only if future checked surfaces show more than that container cleanup
