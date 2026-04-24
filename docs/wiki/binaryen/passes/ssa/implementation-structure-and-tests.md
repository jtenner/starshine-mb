---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0207-2026-04-21-ssa-binaryen-research.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-graph.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/LocalGraph.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/ReFinalize.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/ssa.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/gtest/local-graph.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/ssa.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ../ssa-nomerge/index.md
---

# `ssa` implementation structure and tests

This page is the compact "show me the real source surface" companion for the full-`ssa` sibling.

## Upstream file map

## `src/passes/SSAify.cpp`

This is the owning pass file for **both** `ssa` and `ssa-nomerge`.
For full `ssa`, it proves the most important facts directly:

- one shared implementation with `allowMerges`
- whole-function `LocalGraph` analysis
- fresh-local creation for non-SSA writes
- single-source get retargeting
- multi-source get handling through merge locals
- explicit incoming `local.tee` rewriting
- parameter-entry prepends
- narrow `ReFinalize` after more-refined default ref/null replacement

This file is the main reason `ssa` deserves its own sibling dossier instead of living only as a caveat inside `ssa-nomerge`.

## `src/passes/pass.cpp`

This file proves two practical points:

### 1. Public identity

Binaryen registers `ssa` as:

- `ssa-ify variables so that they have a single assignment`

So this is a real public pass, not merely an internal mode.

### 2. Default-pipeline split from `ssa-nomerge`

The same file schedules only `ssa-nomerge` in the early default no-DWARF function pipeline described in this repo.
That means full `ssa` is public and real, but not the default sibling used in that optimizer path.

## `src/passes/passes.h`

This file proves the two-constructor public surface:

- `createSSAifyPass()`
- `createSSAifyNoMergePass()`

That small detail matters because it confirms the sibling split is intentional public API, not just one unnamed internal flag.

## `src/ir/local-graph.h`

This file teaches the helper contract the pass relies on:

- `LocalGraph` and `LazyLocalGraph` share the same basic data model
- `nullptr` in the reaching-set map means an implicit entry value
- already-SSA checks are helper-level concepts, not ad hoc pass-local guesses
- helper comments already warn that unreachable-code precision is conservative

This file is why the pass can reason about merges without inventing its own CFG model.

## `src/ir/LocalGraph.cpp`

This file teaches how the helper actually computes the facts `ssa` consumes:

- backward flow through predecessor blocks
- obstacle-sensitive local traffic
- tracking of get/set locations for safe mutation
- conservative inclusion of implicit entry values in some unreachable shapes
- explicit `computeSetInfluences()` and `computeSSAIndexes()` support for the pass

This file is especially useful when explaining why full `ssa` can trust multi-source get detection well enough to materialize merge locals.

## `src/ir/ReFinalize.cpp`

This file is not the owner of the pass, but it proves the narrow repair story.
`ssa` only relies on it when replacing a reference-typed default local read with a more refined null/default value changes what a parent expression observes.

That means refinalization is part of the contract, but it is a narrow correctness tail, not a second hidden optimization algorithm.

## Official test map

## `test/lit/passes/ssa.wast`

This is the dedicated official lit file for the public `ssa` pass.
It directly proves:

- parameter overwrites create fresh locals so each one is assigned once
- default ref/null replacement can sharpen the type seen by parent nodes and therefore needs refinalization
- tuple default replacement works too

This file is the direct public regression surface and should be treated as the first oracle for the pass.

## `test/gtest/local-graph.cpp`

This is helper coverage rather than a pass golden.
It is still important because it validates the LocalGraph behavior the pass depends on:

- obstacle-sensitive flow
- multi-block and multi-set cases
- unreachable-code conservatism
- structured-control and GC-aware obstacle families

So this file is part of the real source map even though it does not invoke `--ssa` directly.

## Neighboring sibling surface: `test/passes/ssa-nomerge_enable-simd.wast`

This is not a full-`ssa` test, but it is still useful context.
Because both siblings share `SSAify.cpp`, the no-merge golden makes the public difference easier to teach:

- `ssa-nomerge` refuses merge-local materialization
- full `ssa` uses the same helper and same owner file, but takes the multi-source-get path instead of stopping there

## Directly tested versus source-derived behavior

This distinction matters for the living docs.

## Directly tested in `ssa.wast`

- repeated non-nullable param writes
- ref-typed default replacement and refinalization
- tuple default replacement

## Source-derived from `SSAify.cpp` + LocalGraph helper contracts

- merge-local creation for multi-source gets
- explicit incoming `local.tee` insertion
- parameter-entry prepends
- default-entry no-prepend behavior for defaultable non-param locals

Those latter behaviors are explicit in the owner file, but the shipped lit file does not isolate them in tiny dedicated examples.
So the dossier should teach them confidently, while also saying they are source-derived rather than directly golden-locked in the small lit surface.

## Current-main freshness note

A narrow 2026-04-21 check found:

- `SSAify.cpp` on current upstream `main` matches `version_129`
- `test/lit/passes/ssa.wast` on current upstream `main` matches `version_129`

So the durable reading is:

- current `main` still teaches the same full-`ssa` contract as released `version_129`

## Easy misunderstandings this file map clears up

## "Full `ssa` must have its own separate pass file."

No.
The same `SSAify.cpp` file owns both public siblings.

## "The lit file covers every interesting full-merge shape directly."

No.
The lit file is real and important, but small.
Some merge-local behavior is source-derived from the owner file and helper contracts.

## "Refinalization means the pass broadly retypes everything."

No.
`ReFinalize` is a narrow repair tail after specific reference-default replacements.

## "Because `ssa` is public, it must be in the default optimize path here."

No.
`pass.cpp` registers it publicly, but the default no-DWARF function pipeline documented in this repo uses `ssa-nomerge` instead.
