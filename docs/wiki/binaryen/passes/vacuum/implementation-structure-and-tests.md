---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md
  - ../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused-func.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc-atomics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-desc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-pop.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-legacy.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-intrinsics.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh-mvp.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum_all-features.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./effect-pruning-and-traps-never-happen.md
  - ./wat-shapes.md
  - ./starshine-hot-ir-strategy.md
---

# Upstream implementation structure and test map for `vacuum`

This page is the compact file/test map for the real Binaryen `version_129` `vacuum` contract.

## Main implementation file

## `src/passes/Vacuum.cpp`

This is the real pass file.
It owns almost all of the behavior that matters:

- the `WalkerPass<ExpressionStackWalker<Vacuum>>` pass body
- `isFunctionParallel() == true`
- the tiny `doWalkFunction(...)` driver
- the mandatory post-walk `ReFinalize().walkFunctionInModule(...)`
- the generic `optimize(curr, resultUsed, typeMatters)` helper
- `mustKeepUnusedParent(...)`
- the dedicated visitors for:
  - `block`
  - `if`
  - `loop`
  - `drop`
  - `try`
  - `try_table`
  - the function body itself
- the TNH backward trap-path cleanup inside blocks
- whole-function no-oping when nothing observable remains
- and the explicit `FindAll<Unreachable>` safeguard that preserves explicit `unreachable`

That file layout proves the most important beginner fact:

- `vacuum` is not a generic cleanup family spread across many pass files
- it is one concentrated function-parallel AST pass with a few visible helper dependencies

## Direct helper ownership that affects visible behavior

## `src/ir/branch-hints.h`

This helper file matters because `vacuum` sometimes flips an `if` condition rather than deleting an empty arm in place.
It proves that the pass's metadata repair story is real:

- when `then` is `nop` and `else` is live, Binaryen can move the old `else` into `then`
- it wraps the condition in `eqz`
- and it must also flip branch-hint metadata

If you want to understand why `vacuum` is not “just structural cleanup,” this file is one of the clearest clues.
The pass also owns metadata-preserving rewrites.

## `src/ir/drop.h`

This helper file owns an equally important boundary.
It proves that Binaryen's unused-result pruning is broader than:

- delete everything, or
- keep only one effectful child

`vacuum` can also keep multiple effectful children while deleting their now-useless parent wrapper, rebuilding a dropped-children sequence and appending a dummy value when the type permits it.
That helper-backed behavior is why `vacuum` can teach “preserve effects, lose the wrapper” rather than behaving like a tiny peephole cleaner.

## Registration and scheduler files

## `src/passes/pass.cpp`

This file proves three durable things:

- `vacuum` is a real public pass name
- the public summary is only `removes obviously unneeded code`
- the canonical optimize pipeline uses it repeatedly, not once

That keeps the pass's public identity and repeated-cleanup role honest.
It also matters because the default no-DWARF path in this repo uses `vacuum` in four visible top-level slots.

## `src/passes/passes.h`

This header proves constructor identity:

- `createVacuumPass()`

That matters because it shows `vacuum` is its own public pass surface rather than a hidden mode of another cleanup pass.

## `src/passes/opt-utils.h`

This file does not own the local rewrite logic, but it does own an important scheduler truth:

- optimizing boundary passes rerun the default function-cleanup bundle on changed functions

So the most accurate teaching split is:

- `Vacuum.cpp` owns the real mechanics
- `pass.cpp` and `passes.h` own identity and visible top-level placement
- `opt-utils.h` explains why real optimize runs execute `vacuum` many more times than the top-level slot list suggests

## Official lit files and what each one proves

## `test/lit/passes/vacuum-func.wast`

This is the compact proof surface for whole-function cleanup.
It directly proves:

- `Type::none` functions with no observable effects can be reduced to `nop`
- this whole-body cleanup is broader than explicit `nop` trimming
- result-returning functions stay out of that strongest cleanup path

## `test/lit/passes/vacuum-removable-if-unused.wast`
## `test/lit/passes/vacuum-removable-if-unused-func.wast`
## `test/lit/passes/vacuum-intrinsics.wast`

These files directly prove the pass's unused-result and type-preservation core:

- calls marked `removableIfUnused` can disappear when dropped
- the same call families stay when the result is used
- defaultable dummy-zero replacement is real
- type correctness is part of the contract, not an afterthought

If you want one compact test group for “`vacuum` is really unused-result pruning,” these are the key files.

## `test/lit/passes/vacuum-branch-hints.wast`

This file directly proves:

- condition flipping is part of the pass
- branch metadata must flip with it

That is the cleanest source-confirmed test for the `branch-hints.h` helper dependency.

## `test/lit/passes/vacuum-global-effects.wast`

This file directly proves:

- `vacuum` can become stronger after effect metadata is generated
- some behavior is intentionally downstream of analysis rather than hardcoded special cases

It is the clearest compact test backing for the dossier's “effect-aware cleanup crew” framing.

## `test/lit/passes/vacuum-gc.wast`
## `test/lit/passes/vacuum-gc-atomics.wast`
## `test/lit/passes/vacuum-desc.wast`
## `test/lit/passes/vacuum_all-features.wast`

These files directly prove the pass's modern reference-typed surface:

- dropped GC operations are filtered by trap/effect semantics, not by family name alone
- synchronization-visible atomic traffic can stay even when its result is dropped
- descriptor and cast forms are option-sensitive
- the pass is not merely an MVP integer cleanup

Together they keep the folder honest about the size of the real Binaryen surface.

## `test/lit/passes/vacuum-strings.wast`

This file directly proves one of the easiest beginner contrasts:

- some dropped string ops disappear because they are effect-safe when unused
- others stay because they may trap

That is the compact test-backed reason the dossier teaches `vacuum` as semantics-driven rather than opcode-category-driven.

## `test/lit/passes/vacuum-eh.wast`
## `test/lit/passes/vacuum-eh-pop.wast`
## `test/lit/passes/vacuum-eh-legacy.wast`

These files directly prove:

- non-throwing `try` and `try_table` wrappers can collapse to their body
- `try` and `try_table` are intentionally not treated identically in every cleanup family
- EH / `pop` correctness depends on the post-edit refinalization story

They are also the easiest compact proof that `vacuum` is broader than dead dropped values and trivial `if`s.

## `test/lit/passes/vacuum-tnh.wast`
## `test/lit/passes/vacuum-tnh-mvp.wast`

These files directly prove the TNH half of the contract:

- trap-path cleanup is real
- it is conservative rather than global
- calls, may-not-return behavior, control transfer, and related barriers still stop it
- explicit `unreachable` retention remains part of the real contract

## What the official tests do not isolate cleanly by themselves

The lit suite is broad, but some important facts are still easier to confirm from the source layout than from testcase headings:

- `Vacuum.cpp` is the single dominant owner file
- the exact helper split between `Vacuum.cpp`, `branch-hints.h`, and `drop.h`
- why `opt-utils.h` matters for rerun frequency rather than local legality
- the concrete `FindAll<Unreachable>` implementation detail behind whole-function explicit-`unreachable` preservation

So the safest teaching split is:

- source files for ownership and helper responsibilities
- lit files for observable rewrite families

## Practical reading order for future Starshine port work

1. `src/passes/Vacuum.cpp`
   - understand the pass structure and the generic `optimize(...)` helper
2. `src/ir/drop.h`
   - understand the dropped-children rebuilding story
3. `src/ir/branch-hints.h`
   - keep condition-flip metadata repair honest
4. `src/passes/pass.cpp`
   - confirm public identity and repeated top-level placement
5. `src/passes/opt-utils.h`
   - confirm nested rerun behavior
6. `src/passes/passes.h`
   - confirm constructor identity
7. the `vacuum-*` lit family
   - map each major rewrite subtopic back to a shipped test

## Porting checklist that falls out of this file map

Before calling a future Starshine port faithful, verify all of these against the official files:

- the pass is function-parallel and tree-shaped, not CFG-shaped
- post-edit refinalization is mandatory
- generic unused-result pruning exists
- dedicated visitors for `Block` / `If` / `Loop` / `Drop` / `Try` / `TryTable` / `Function` exist
- branch-hint flips are preserved when `if` conditions are inverted
- multi-child effect preservation works, not only single-child collapse
- whole-function cleanup preserves explicit `unreachable`
- the scheduler models repeated visible slots and nested reruns separately
- parity signoff uses the relevant `vacuum-*` lit families for each rewrite topic instead of treating one file as the whole pass

## Sources

- [`../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md`](../../../raw/research/0130-2026-04-20-vacuum-binaryen-research.md)
- [`../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md`](../../../raw/research/0210-2026-04-21-vacuum-source-confirmation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Vacuum.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-hints.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/drop.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-func.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-removable-if-unused-func.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-branch-hints.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-global-effects.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-gc-atomics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-strings.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-desc.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-pop.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-eh-legacy.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-intrinsics.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum-tnh-mvp.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/vacuum_all-features.wast>
