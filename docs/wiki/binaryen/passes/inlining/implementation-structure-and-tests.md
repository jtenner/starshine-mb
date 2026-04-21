---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0161-2026-04-21-inlining-binaryen-research.md
  - ../../../raw/research/0226-2026-04-21-inlining-inline-hints-and-no-inline-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./heuristics-splitting-and-plain-vs-optimizing.md
  - ./compilation-hints-vs-no-inline-flags-and-clone-survival.md
  - ./wat-shapes.md
---

# `inlining`: implementation structure and tests

This page is the file-and-test map for Binaryen `version_129` plain `inlining`.

## Core source files

## `src/passes/Inlining.cpp`

This is the real implementation.

Main pieces:

- `InliningMode`
  - `Unknown`, `Uninlineable`, `Full`, `SplitPatternA`, `SplitPatternB`
- `TrivialInstruction`
  - `NotTrivial`, `Shrinks`, `MayNotShrink`
- `FunctionInfo`
  - stores size, ref-count, loop/delegate/global-use flags, trivial-instruction class, and cached mode
- `FunctionInfoScanner`
  - computes the initial facts for each function
- `Planner`
  - discovers reachable direct-call inline opportunities
- `Updater`
  - repairs copied code: locals, returns, `return_call*`, and labels
- `doCodeInlining(...)`
  - performs the actual callsite rewrite
- `updateAfterInlining(...)`
  - uniquifies labels, refinalizes, fixes nondefaultable locals
- `FunctionSplitter`
  - handles partial-inlining Pattern A and Pattern B
- `Inlining`
  - orchestrates preparation, iterative planning, deterministic action choice, optional nested optimization, and dead-helper cleanup
- `InlineMainPass`
  - small special-case wrapper for `main` / `__original_main`

## `src/passes/pass.cpp`

This file matters for three reasons:

- it registers `inlining`, `inlining-optimizing`, and `inline-main`
- it also registers the separate `no-inline`, `no-full-inline`, and `no-partial-inline` helper passes
- it shows that the default no-DWARF post-pass path uses `inlining-optimizing`, not plain `inlining`

So this file defines both:

- the public pass names
- the scheduler-context difference between the plain and optimizing variants
- the fact that Binaryen's practical no-inline controls are a separate pass family, not just parser metadata

## `src/passes/opt-utils.h`

This file explains the optimizing sibling's extra behavior.

Important helper:

- `addUsefulPassesAfterInlining(...)`
  - adds `precompute-propagate`
  - then reruns the default function-optimization pipeline

For the plain pass, this file matters mostly as a **negative** source: plain `inlining` does not call this helper.

## `src/passes/NoInline.cpp`

This is the real implementation for Binaryen's user-facing do-not-inline controls.
It matters because it shows that:

- `--no-inline`, `--no-full-inline`, and `--no-partial-inline` are separate public passes,
- they match function names with `String::wildcardMatch(...)`,
- and they set the exact `Function::noFullInline` / `Function::noPartialInline` booleans that `Inlining.cpp` later reads.

This file is the main reason the dossier now teaches `@metadata.code.inline` and `no-inline*` as different mechanisms.

## `src/pass.h`

This file defines the default inlining heuristics and limits.

Important defaults reviewed in this thread:

- `alwaysInlineMaxSize = 2`
- `oneCallerInlineMaxSize = -1`
- `flexibleInlineMaxSize = 20`
- `maxCombinedBinarySize = 400 * 1024`
- `allowFunctionsWithLoops = false`
- `partialInliningIfs = 0`

This file is the best primary source for “what are the default heuristic knobs?”

## Important helper headers included by `Inlining.cpp`

## `src/ir/branch-utils.h`

Used for:

- branch-target collision checks
- branch-target name collection
- branch-presence checks during splitting and rewrite

This is why label ownership and naming are first-class parts of the inline algorithm.

## `src/ir/branch-hints.h`

Used when split Pattern A flips the guard condition and needs to preserve branch-hint meaning.

## `src/ir/literal-utils.h`

Used for zero-initializing copied callee vars only when the local type has a valid zero value.

## `src/ir/metadata.h`

Used to copy metadata between the original callee body and the copied body inserted into the caller.

## `src/ir/return-utils.h`

Used by split Pattern B to reject `if` bodies that have `none` type but still contain returns.

## `src/ir/type-updating.h`

Used for post-inline nondefaultable-local repair.
This is especially important for GC/nonnullable local shapes.

## `src/ir/eh-utils.h`

Used after each iteration to repair nested-pop structure in functions that were inlined into.
This matters most around try/tail-call-sensitive cases.

## `src/ir/find_all.h`

Used by `InlineMainPass` to locate the unique `__original_main` callsite.

## `src/ir/properties.h`

Used while classifying “trivial instruction” bodies and deciding whether a body is control flow.

## `src/ir/localize.h`

Used by the updater when children of a `return_call*` need to be localized before the control rewrite.

## `src/wasm.h`, `src/wasm/wasm.cpp`, and `src/parser/contexts.h`

These files matter for the inline-hints surface.
Together they show that Binaryen has a real `@metadata.code.inline` annotation vocabulary with:

- `CodeAnnotation::NeverInline = 0`
- `CodeAnnotation::AlwaysInline = 127`
- parser acceptance for one-byte values up to `127`

That preserved annotation surface is real, but it is separate from the actual `Function::noFullInline` / `noPartialInline` flags the inliner consults.

## `src/wasm/wasm-binary.cpp`

This file proves that inline hints are also written into Binaryen's binary custom annotation stream as one-byte expression hints.
That is why the `inline-hints*` tests are about roundtripping preserved metadata, not merely pretty-printing comments.

## `src/ir/module-utils.cpp`

This file matters for the dedicated `no-inline-monomorphize-inlining.wast` test.
`copyFunctionWithoutAdd(...)` explicitly copies:

- `ret->noFullInline = func->noFullInline;`
- `ret->noPartialInline = func->noPartialInline;`

So the official clone-survival behavior is directly source-confirmed.

## Official tests and what they prove

## `test/lit/passes/inlining_optimize-level=3.wast`

This is the broadest general plain-inlining surface reviewed in this thread.
It proves several important heuristic families together, including:

- tiny always-inline cases
- one-use cases
- exported and tabled survivors
- recursion-related no-delete/no-inline behavior
- higher-opt-level flexible cases

## `test/lit/passes/inlining_enable-tail-call.wast`

This is the main proof surface for tail-call-sensitive rewriting.
It is especially useful for teaching:

- copied-local creation
- `return_call` repair
- the need for special handling when return-style calls appear in copied bodies

## `test/lit/passes/inlining_splitting.wast`

This is the main stress surface for partial inlining.
It proves:

- Pattern A
- Pattern B
- start/global/root interactions
- all-features parsing for ref/null/simple-guard cases
- helper function creation and naming

## `test/lit/passes/inlining_splitting_basics.wast`

This file is the cleanest source for the public “partial inlining only when enabled” contract.
It compares normal `--inlining` against `--partial-inlining-ifs=1` directly.

## `test/lit/passes/inlining-trivial-instructions.wast`

This file is the cleanest proof surface for the `TrivialInstruction` heuristic classes.
It demonstrates the difference between:

- always-shrinking trivial wrappers
- trivial wrappers that may still grow code size
- mode-sensitive behavior under shrink and `-O3`

## `test/lit/passes/inlining-trivial-calls-1.wast`

This file focuses on the special “trivial call” family that always shrinks even in size-focused modes.

## `test/lit/passes/inlining-unreachable.wast`

This file is essential for the reachability/trap contract.
It proves that when an unreachable/trapping callee is inlined, Binaryen preserves the caller's unreachable semantics instead of accidentally making the code reachable through a typed wrapper.

## `test/lit/passes/inlining-gc.wast`

This file proves the copied-local and nondefaultable-local story for GC/reference-typed locals.
It is a key source for why `updateAfterInlining()` must run type/local repair after every inline.

## `test/lit/passes/no-inline.wast`

This file proves the public command-line controls around:

- `--no-partial-inline`
- `--no-full-inline`
- `--no-inline`

More specifically, it proves that full and partial suppression are independently real policy surfaces, not just documentation names for one hidden switch.
That matters because the pass is not purely heuristic: it also respects explicit no-inline controls.

## `test/lit/passes/no-inline-monomorphize-inlining.wast`

This file proves that no-inline metadata survives through monomorphization and still blocks later inlining of the copied function.

That is a subtle but important “future-transform inherits inline policy” contract.

## `test/lit/passes/inline-main.wast`

This is the direct proof surface for the tiny `inline-main` special case that reuses the same low-level helper.

## `test/lit/inline-hints.wast`
## `test/lit/inline-hints-func.wast`

These files are not the main inlining algorithm tests, but they are still useful here because they prove Binaryen's `@metadata.code.inline` surface is real and roundtrippable on both expression and function annotations.
They do **not** by themselves prove the actual do-not-inline policy, which instead comes from `NoInline.cpp` and the function booleans that `Inlining.cpp` reads.

## Most important file-to-concept map

| Topic | Best upstream file |
| --- | --- |
| Heuristic defaults | `src/pass.h` |
| Public pass names and scheduler placement | `src/passes/pass.cpp` |
| Shared plain/optimizing engine | `src/passes/Inlining.cpp` |
| Nested useful-pass rerun owned only by optimizing variant | `src/passes/opt-utils.h` |
| Partial-inlining patterns | `test/lit/passes/inlining_splitting*.wast` |
| Trivial-wrapper heuristics | `test/lit/passes/inlining-trivial-*.wast` |
| Reachability and trap propagation | `test/lit/passes/inlining-unreachable.wast` |
| Tail-call-sensitive rewrite | `test/lit/passes/inlining_enable-tail-call.wast` |
| GC/nondefaultable-local repair | `test/lit/passes/inlining-gc.wast` |
| Explicit no-inline controls | `src/passes/NoInline.cpp`, `src/passes/pass.cpp`, and `test/lit/passes/no-inline*.wast` |
| Preserved compilation-hint bytes | `src/wasm.h`, `src/parser/contexts.h`, `src/wasm/wasm-binary.cpp`, and `test/lit/inline-hints*.wast` |
| `main` / `__original_main` special case | `test/lit/passes/inline-main.wast` |

## What this file/test map means for a future Starshine port

A future port should not try to implement plain `inlining` as only:

- a heuristic table
- or only a callsite-rewrite helper
- or only a nested cleanup scheduler

The real port surface spans all three:

- classification and planning
- structured rewrite and repair
- module-topology cleanup

And only after that should the repo decide whether to add the optimizing wrapper.
