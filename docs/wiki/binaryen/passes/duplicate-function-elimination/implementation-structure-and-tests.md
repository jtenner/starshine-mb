---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-duplicate-function-elimination-primary-sources.md
  - ../../../raw/research/0242-2026-04-22-duplicate-function-elimination-primary-sources-and-code-map-followup.md
  - ../../../raw/research/0147-2026-04-20-duplicate-function-elimination-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DuplicateFunctionElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/function-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/hashed.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_all-features.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_annotations.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_branch-hints.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=1.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/duplicate-function-elimination_optimize-level=2.wast
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/DuplicateFunctionElimination.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
---

# `duplicate-function-elimination` implementation structure and tests

This page is the “show me the real source surface” companion to the main strategy page.

## Upstream file map

## `src/passes/DuplicateFunctionElimination.cpp`

This is the owning pass file.
It teaches the core algorithm directly:

- option-dependent iteration budget
- parallel hashing
- defined-function bucketing
- exact equality within each bucket
- stable first-survivor-wins replacement
- deletion plus `replaceFunctions(...)`

The file is intentionally small.
That smallness is itself a teaching point: official Binaryen DFE is not secretly doing a long list of extra cleanup transforms.

## `src/ir/function-utils.h`

This file teaches the real equality contract.
It is where Binaryen decides which differences matter semantically.

Important lessons from the helper:

- function type and local types matter
- semantics-altering annotations matter
- ordinary metadata does not block merging
- body equality is the final proof

This file is why the annotation and branch-hint tests behave so differently.

## `src/ir/hashed.h`

This file teaches the prefilter contract.
It explains why DFE can be fast enough to run twice in the default optimizer:

- hashing is function-parallel
- only likely-equal functions get the expensive exact comparison

It also records a useful subtlety:

- metadata is not hashed here
- so hash buckets can over-approximate equality
- exact comparison still decides safety later

## `src/passes/opt-utils.h`

This file teaches the real rewrite surface.
It answers the practical question:

- “after DFE deletes a function, what users get updated?”

The answer is narrower and more source-backed than many old summaries:

- direct call targets
- `ref.func` users in function code and module code
- `start`
- function exports

## `src/passes/pass.cpp`

This file teaches two things the core pass file does not.

### 1. Public pass description

`pass.cpp` registers DFE as:

- `removes duplicate functions`

That description is short, but the shortness is honest.

### 2. Real scheduler placement

The same file schedules DFE:

- at the start of global pre-passes
- and again in global post-passes after bigger transforms

So `pass.cpp` is the source-backed reason the pass matters twice in the no-DWARF optimizer.

## Official test map

## `duplicate-function-elimination_all-features.wast`

Use this file for the baseline rewrite surface.
It demonstrates:

- deduplication must not lose liveness through `ref.func`
- globals initialized by `ref.func` must be retargeted correctly
- later `call_ref` users then keep working
- function deduplication must not accidentally rename unrelated entities such as a global or memory that happen to share text names with a function

This is the best “what actually gets rewritten?” file.

## `duplicate-function-elimination_annotations.wast`

Use this file for the semantic-annotation boundary.
It demonstrates that merging is blocked when annotations differ in semantics, including:

- `@binaryen.js.called`
- `@binaryen.removable.if.unused`
- `@binaryen.idempotent`

And it also shows the positive case:

- when both functions carry the same semantics-altering annotation, merging becomes legal again

## `duplicate-function-elimination_branch-hints.wast`

Use this file for the non-semantic-metadata boundary.
It demonstrates that merging still happens when functions differ only in:

- branch hints
- missing-vs-present branch hints
- source file location / debug comments

It also makes the survivor rule easy to see:

- the earlier function's metadata stays because the earlier function survives

## `duplicate-function-elimination_optimize-level=1.wast`

Use this file for the one-round behavior.
It demonstrates that low/default settings may stop before transitive caller duplication is fully exhausted.

This is the file that prevents a beginner from assuming:

- “DFE always iterates to a full fixpoint.”

## `duplicate-function-elimination_optimize-level=2.wast`

Use this file for the higher-budget behavior.
It demonstrates that stronger optimize settings can continue far enough to remove second-order duplicates that appear only after earlier rewrites.

Taken together, the `optimize-level=1` and `optimize-level=2` files are the official proof that:

- iteration budget is part of the public behavior of this pass

not an invisible implementation detail.

## Current-main freshness note

A narrow 2026-05-13 source check found only the same tiny non-semantic code drift in the owning pass file:

- `std::set<Name>` became `std::unordered_set<Name>` for the duplicate-name set

The dedicated lit files are unchanged.

So the durable reading is:

- current `main` still teaches the same DFE contract as released `version_129`

## Easy misunderstandings this file map clears up

## “The hash decides equality.”

No.
`hashed.h` only gives the cheap candidate buckets.
`function-utils.h` still decides whether merging is actually safe.

## “DFE merges anything that prints the same.”

No.
Semantic annotations still matter.
The annotations lit file exists to prove that.

## “DFE normalizes all metadata after a merge.”

No.
The branch-hints file shows the opposite teaching story:

- Binaryen is happy to merge despite metadata differences
- and then it simply keeps the survivor's metadata surface

## “DFE always iterates to completion.”

No.
The optimize-level lit pair exists specifically to prove that option-dependent iteration is observable behavior.

## “Type compaction must be part of official DFE because the local pass does it.”

No.
None of the owning upstream files or dedicated DFE lit tests teach that as part of DFE proper.
That is a local-extra topic, which belongs on the separate `type-compaction-and-metadata.md` page.
