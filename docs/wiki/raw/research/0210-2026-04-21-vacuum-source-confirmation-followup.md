# 0210 - `vacuum` source-confirmation follow-up

## Status

- Date: 2026-04-21
- Type: Source-confirmation follow-up
- Scope: add one compact, source-confirmed owner/test-map page for the existing Binaryen `version_129` `vacuum` dossier, and tighten the living pages so future campaign threads can see that this deep folder no longer lacks a dedicated implementation/test-map home.

## Why this follow-up was justified

The tracker no longer had obvious `none` targets, and `vacuum` was still an eligible pass under this thread's exclusion rules.
The existing `vacuum` dossier was already strong on strategy, trap semantics, and beginner-facing WAT shapes, but it still lacked one compact page answering a narrower recurring question:

- which upstream files actually own the pass contract, and
- which shipped lit files directly prove each visible rewrite family?

That gap mattered because `vacuum` is easy to mis-teach in two opposite directions:

- too small: “just a nop sweeper”
- too large: “generic dead-code elimination”

A compact owner/test-map page is the best antidote to both mistakes.

## Repo and local sources re-read first

Per repo rules, I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the existing `docs/wiki/binaryen/passes/vacuum/` folder

`agent-todo.md` **does** have a dedicated slice for this pass:

- `#### VQ - Vacuum`
- `[VQ]001 - Cleanup Semantics Audit`
- `[VQ]002 - Repeated-Slot Regression Matrix`

So unlike some upstream-only expansions, this follow-up lands directly on an already-live local parity slice.

## Official Binaryen `version_129` sources reviewed

### Main implementation / registration / scheduler

- `src/passes/Vacuum.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/passes/opt-utils.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>

### Direct helper ownership reviewed because `Vacuum.cpp` relies on them explicitly

- `src/ir/branch-hints.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- `src/ir/drop.h`
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>

### Shipped test surface reviewed

- `test/lit/passes/vacuum-func.wast`
- `test/lit/passes/vacuum-removable-if-unused.wast`
- `test/lit/passes/vacuum-removable-if-unused-func.wast`
- `test/lit/passes/vacuum-branch-hints.wast`
- `test/lit/passes/vacuum-global-effects.wast`
- `test/lit/passes/vacuum-gc.wast`
- `test/lit/passes/vacuum-gc-atomics.wast`
- `test/lit/passes/vacuum-strings.wast`
- `test/lit/passes/vacuum-desc.wast`
- `test/lit/passes/vacuum-eh.wast`
- `test/lit/passes/vacuum-eh-pop.wast`
- `test/lit/passes/vacuum-eh-legacy.wast`
- `test/lit/passes/vacuum-intrinsics.wast`
- `test/lit/passes/vacuum-tnh.wast`
- `test/lit/passes/vacuum-tnh-mvp.wast`
- `test/lit/passes/vacuum_all-features.wast`

Representative URLs:

- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-branch-hints.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc-atomics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-desc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-intrinsics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum_all-features.wast>

## Source-confirmed ownership map

## 1. `Vacuum.cpp` really is the whole pass core

The compact owner answer is now clear:

- `src/passes/Vacuum.cpp` owns essentially the whole behavioral contract.

More specifically, it owns:

- the `WalkerPass<ExpressionStackWalker<Vacuum>>` pass body
- `isFunctionParallel() == true`
- the `doWalkFunction(...)` driver
- the mandatory post-walk `ReFinalize().walkFunctionInModule(...)`
- the generic `optimize(curr, resultUsed, typeMatters)` helper
- `mustKeepUnusedParent(...)`
- the dedicated visitors for:
  - `Block`
  - `If`
  - `Loop`
  - `Drop`
  - `Try`
  - `TryTable`
  - `Function`
- the TNH backward scan inside blocks
- whole-function no-oping with the explicit `FindAll<Unreachable>` safeguard

That means the pass is **not** split across many implementation files the way `directize`, `memory-packing`, or `gufa` are.
Its helper footprint matters, but the rewrite logic itself is concentrated.

## 2. `branch-hints.h` is not optional background; it owns one real rewrite obligation

`Vacuum.cpp` flips branch hints when it rewrites:

- `if (cond) (then nop) (else body)`

into:

- `if (eqz cond) (then body)`

That behavior is not cosmetic.
It is an observable metadata contract, and `src/ir/branch-hints.h` is the supporting owner surface for it.

So the compact owner map should teach:

- `Vacuum.cpp` owns the decision to flip
- `branch-hints.h` owns how metadata is repaired

## 3. `drop.h` is the helper-backed reason multi-child pruning works at all

The pass's most important nontrivial generic helper story is:

- if a wrapper result is unused,
- but multiple effectful children must stay,
- Binaryen may rebuild a sequence of dropped children and append a dummy zero/default value when the type allows it.

That behavior is source-backed through `src/ir/drop.h`.
Without that helper, it would be easy to misread the pass as only supporting:

- delete everything, or
- keep one child.

But the real pass also supports the “keep several children, lose the wrapper” case.

## 4. `pass.cpp` and `passes.h` prove identity and scheduling, not mechanics

`src/passes/pass.cpp` proves:

- the public pass name is `vacuum`
- the public summary string is `removes obviously unneeded code`
- the canonical no-DWARF pipeline runs it repeatedly, not once

`src/passes/passes.h` proves:

- the constructor identity is `createVacuumPass()`

These files do **not** own the rewrite mechanics, but they are the canonical sources for public identity and slot placement.

## 5. `opt-utils.h` matters because the scheduler story is larger than the visible top-level slots

The no-DWARF page already records four top-level `vacuum` uses.
The follow-up source check confirms that `opt-utils.h` still matters because optimizing boundary passes rerun the default function cleanup bundle on touched functions.

So a compact owner/test-map page should keep this distinction explicit:

- `pass.cpp` proves the visible top-level scheduler slots
- `opt-utils.h` proves why `vacuum` also reappears in nested optimizing reruns

## Shipped test map: what each lit family directly proves

## Core function-cleanup and whole-body behavior

### `vacuum-func.wast`

Directly proves:

- whole-function cleanup for `Type::none` bodies with no observable effects
- that this whole-body no-oping is broader than mere `nop` trimming
- that result-returning functions stay out of this strongest cleanup path

## Call-annotation and intrinsic-driven unused-result pruning

### `vacuum-removable-if-unused.wast`
### `vacuum-removable-if-unused-func.wast`
### `vacuum-intrinsics.wast`

Together these directly prove:

- `removableIfUnused` calls can disappear when dropped
- the same family does **not** disappear when the result is still used
- defaultable dummy-zero replacement is real
- type preservation is part of the contract, not just dead-wrapper deletion

These files are the cleanest direct proof that `vacuum` is really an unused-result + type-preservation pass.

## Metadata and downstream-analysis-sensitive cleanup

### `vacuum-branch-hints.wast`

Directly proves:

- condition flipping is real
- branch metadata must flip with it

### `vacuum-global-effects.wast`

Directly proves:

- `vacuum` can become stronger after effect metadata is generated
- some cleanup behavior is intentionally downstream of other analysis passes

## GC, descriptor, and synchronization-sensitive surfaces

### `vacuum-gc.wast`
### `vacuum-gc-atomics.wast`
### `vacuum-desc.wast`
### `vacuum_all-features.wast`

Together these directly prove:

- dropped GC operations are filtered by real effect/trap semantics, not by a blanket “GC op stays” or “GC op disappears” rule
- synchronization-visible atomic traffic may remain even when its result is dropped
- descriptor and cast forms are option-sensitive
- the pass's visible surface spans the modern all-features corpus, not only MVP integer wrappers

## String-specific trap vs non-trap distinction

### `vacuum-strings.wast`

Directly proves the beginner-important split between dropped string ops that:

- can disappear because they are effect-safe when unused
- versus ones that stay because they may trap

This file is the easiest compact evidence that `vacuum`'s semantics are effect-based, not opcode-family-based.

## EH-specific asymmetries and repair surfaces

### `vacuum-eh.wast`
### `vacuum-eh-pop.wast`
### `vacuum-eh-legacy.wast`

Together these directly prove:

- non-throwing `try` / `try_table` wrappers can collapse to their body
- `try` and `try_table` are intentionally not treated identically in every cleanup family
- EH/pop correctness depends on the pass's mandatory post-edit refinalization story

These tests are also the best compact evidence that `vacuum` is not just a value-wrapper cleaner.

## `traps-never-happen` and MVP TNH behavior

### `vacuum-tnh.wast`
### `vacuum-tnh-mvp.wast`

Together these directly prove:

- the TNH backward trap-path cleanup is real
- it is conservative rather than global
- calls, may-not-return behavior, control transfer, and related barriers still stop the cleanup
- explicit `unreachable` retention remains part of the real contract

## What the test suite does not isolate as cleanly as the source does

Even with the large lit roster, some facts are still easier to teach from source ownership than from test names alone:

- `Vacuum.cpp` is the single dominant owner file rather than one small front-end over many helpers
- the exact owner split between `Vacuum.cpp`, `branch-hints.h`, and `drop.h`
- the fact that `opt-utils.h` matters mainly for nested rerun frequency, not local rewrite legality
- the whole-function `FindAll<Unreachable>` safeguard as a concrete implementation detail rather than just a user-visible outcome

So the best living-doc split is:

- strategy pages for the algorithm and semantics
- this follow-up page for file ownership and test proof surface

## Current-main drift check

I did not find a new substantive upstream drift that invalidates the `version_129` dossier.
The already-recorded freshness correction still stands:

- the explicit-`unreachable` preservation change belongs to Chromium commit `f284d54...`
- that behavior is already present in `version_129`
- the previously cited `9ee4a25...` commit is a `RemoveUnusedBrs` change, not a `Vacuum` change

So the durable story remains:

- current `main` still matches the tagged `version_129` `vacuum` contract in substance for the surfaces documented here

## Practical checklist for future Starshine parity work

A future Starshine `vacuum` port should now be checked against this compact owner/test map:

- `Vacuum.cpp`-style generic unused-result pruning exists
- the dedicated visitors for `Block` / `If` / `Loop` / `Drop` / `Try` / `TryTable` / `Function` are all accounted for
- branch-hint flipping is preserved when conditions are inverted
- multi-child effect preservation still works via dropped-child rebuilding, not only single-child collapse
- repeated scheduler slots and nested cleanup reruns are modeled separately from local pass semantics
- the whole-function explicit-`unreachable` safeguard is preserved
- parity signoff uses the right lit families for each rewrite surface instead of treating `vacuum-func.wast` as the whole pass

## Wiki filing result

This follow-up should land as:

- a new `docs/wiki/binaryen/passes/vacuum/implementation-structure-and-tests.md` page
- landing/strategy/index updates pointing at that page
- tracker/index/log updates so future threads can see that `vacuum` no longer lacks a compact owner/test-map page

## Bottom line

The source-confirmed compact answer is now:

- `vacuum` is mostly a **single-file pass** in `Vacuum.cpp`
- its most important direct helper dependencies for visible behavior are `branch-hints.h` and `drop.h`
- `pass.cpp`, `passes.h`, and `opt-utils.h` matter for public identity and repeated scheduling, not for the core rewrite legality
- the shipped `vacuum-*` lit family is broad enough to map by subtopic rather than by one “main test” file

That is the owner/test-map clarification the previous deep dossier still lacked.
