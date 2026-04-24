---
kind: concept
status: supported
last_reviewed: 2026-04-24
sources:
  - ../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md
  - ../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast
related:
  - ./binaryen-strategy.md
  - ./special-case-contract-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/implementation-structure-and-tests.md
---

# `inline-main` implementation structure and tests

This page is anchored by the 2026-04-24 immutable source manifest [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md), which records the exact official URL set and narrow current-main spot-check scope.

## Core implementation files

## `src/passes/pass.cpp`

This file proves three important public-surface facts:

1. `inline-main` is a distinct registered pass name.
2. Its public help string is specifically about inlining `__original_main` into `main`.
3. It is registered beside `inlining` and `inlining-optimizing`, not folded invisibly into them.

This is the best source for answering:

- is this a real public pass?
- what is its intended user-facing purpose?
- is it separate from plain `inlining`?

## `src/passes/Inlining.cpp`

This is the main implementation file.
For `inline-main`, it contains two different layers that matter:

### Layer A: `InlineMainPass`

This tiny pass owns the unique chooser logic:

- find `main`
- find `__original_main`
- reject imports
- scan `main` for direct calls to `__original_main`
- accept exactly one callsite
- call shared `doInlining(...)`

### Layer B: shared inlining helper machinery

The same file also provides the heavier rewrite logic that `inline-main` reuses.
That includes:

- `InliningAction`
- body-copy and local-remap logic
- return lowering and return-call handling
- branch-target collision repair
- metadata copying
- refinalization
- nondefaultable-local repair

For teaching, this file proves that `inline-main` is both:

- tiny in its chooser
- nontrivial in its inherited rewrite semantics

## Relevant helper files

## `src/pass.h`

This file is mostly more important for the broader inlining family, because it defines the ordinary inlining heuristics and limits.

For `inline-main`, the main lesson is negative:

- this pass does **not** use the broad heuristic planning surface from `pass.h`
- it only reuses the lower-level body rewrite helper

That contrast helps prevent future documentation from turning `inline-main` into a heuristic pass by accident.

## `src/passes/opt-utils.h`

This file matters mostly as a contrast surface too.
It contains `optimizeAfterInlining(...)`, which is central to `inlining-optimizing` and `dae-optimizing`.

For `inline-main`, the important point is that the dedicated special-case pass does **not** own that nested rerun contract.

So this file helps prove what `inline-main` is *not*.

## `src/ir/find_all.h`

This matters because `InlineMainPass` uses `FindAllPointers<Call>`.
That source-backed detail explains why the chooser surface is limited to direct `Call` nodes rather than broader call-like expression families.

## `src/ir/branch-utils.h`

This matters because the shared inline helper must avoid branch-label capture when it inserts a new named wrapper block around the copied callee body.

That is one of the main hidden implementation obligations inherited by `inline-main` from ordinary inlining.

## `src/ir/names.h`

This matters for the same reason as `branch-utils.h`: shared inline rewriting may need fresh valid names for the new wrapper block.

## `src/ir/metadata.h`

This matters because the shared helper copies metadata when cloning/inserting the callee body.

It is another reminder that `inline-main` is not merely a textual substitution.

## `src/ir/type-updating.h`

This matters because successful inlining can introduce or remap locals that require nondefaultable-local repair.

A future port that skips this step would under-implement the real rewrite contract.

## Dedicated official test surface

## `test/lit/passes/inline-main.wast`

This is the single most important test file for the pass.
It proves the real acceptance and bailout matrix.

### What the file proves

#### 1. Single-call positive

The first module shows the canonical success shape:

- defined `main`
- defined `__original_main`
- exactly one direct call from `main`

The check output also shows that the immediate result can still contain a named inlined block wrapper.

#### 2. Already-inlined no-op

The next module shows a body that no longer calls `__original_main`.
The pass leaves it alone.

#### 3. Missing `__original_main` no-op

A module with only `main` stays unchanged.

#### 4. Multiple-call bailout

A module where `main` calls `__original_main` twice is intentionally preserved unchanged.
This proves the exact-one-call rule.

#### 5. Missing `main` no-op

A module containing only `__original_main` stays unchanged.

#### 6. Imported `main` bailout

An imported `main` causes a no-op, even if a defined `__original_main` exists.

#### 7. Imported `__original_main` bailout

An imported `__original_main` also causes a no-op.

## Supporting neighboring test context

The broader `inlining` lit family is still relevant as background because `inline-main` reuses the same low-level helper.
But those tests do not define the chooser contract.
They mainly help interpret what shared inline-body rewriting can do after `inline-main` chooses a callsite.

So the dedicated pass contract should always anchor first in `inline-main.wast`.

## Best file-to-concept map

| Topic | Best upstream file |
| --- | --- |
| Public pass identity | `src/passes/pass.cpp` |
| Exact chooser logic | `src/passes/Inlining.cpp` (`InlineMainPass`) |
| Shared inline-body rewrite machinery | `src/passes/Inlining.cpp` (`doInlining(...)` and helpers) |
| Direct-call-only scan surface | `src/ir/find_all.h` plus `Inlining.cpp` use site |
| Label-collision repair | `src/ir/branch-utils.h` plus `Inlining.cpp` use site |
| Nondefaultable-local repair | `src/ir/type-updating.h` plus `Inlining.cpp` use site |
| Acceptance and bailout matrix | `test/lit/passes/inline-main.wast` |
| Contrast against ordinary heuristic inlining | `src/pass.h`, `src/passes/opt-utils.h`, and the broader `inlining` dossier |

## Current-main drift note

A narrow 2026-04-21 spot check of the `InlineMainPass` definition in Binaryen `main` found the reviewed section unchanged from `version_129`.

That does **not** mean all shared inlining helpers were fully re-audited on trunk here.
It only means the special-case chooser code itself appears stable in the checked section.

## What this structure means for a future Starshine port

A future port should not implement `inline-main` as only:

- a name lookup
- plus one naive body substitution

The real source-backed contract is:

- tiny chooser logic
- paired with the full inline-body repair machinery already needed by ordinary inlining

That is the smallest faithful implementation shape.

## Sources

- [`../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md`](../../../raw/binaryen/2026-04-24-inline-main-primary-sources.md)
- [`../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md`](../../../raw/research/0319-2026-04-24-inline-main-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md`](../../../raw/research/0177-2026-04-21-inline-main-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
