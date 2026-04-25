---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md
  - ../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md
  - ../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0271-2026-04-23-inlining-optimizing-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0121-2026-04-20-inlining-optimizing-binaryen-research.md
  - ../inlining/implementation-structure-and-tests.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./planning-partial-inlining-and-reruns.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../inlining/index.md
  - ../inlining/implementation-structure-and-tests.md
  - ../precompute-propagate/index.md
  - ../dae-optimizing/index.md
---

# `inlining-optimizing`: implementation structure and tests

This page is the file-and-test map for Binaryen `inlining-optimizing`.
Use it when you need to follow the upstream source from pass name to implementation to proof surface, or when planning where a future Starshine port must plug in.

## One-line map

`inlining-optimizing` is the shared Binaryen `Inlining.cpp` inliner with optimizing mode enabled; the unique suffix is the `opt-utils.h` post-inline rerun that prepends `precompute-propagate` and reruns the default function pipeline on touched functions.

## Source freshness

- Tagged oracle: Binaryen `version_129`.
- Current-main bridge: [`../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md).
- Narrow result: no teaching-relevant drift was found from the 2026-04-23 dossier; the new value is owner/test-map precision and current-main provenance.

## Core owner files

### `src/passes/Inlining.cpp`

This is the implementation owner for both public pass names:

- `inlining`
- `inlining-optimizing`

Important implementation pieces to read in this file:

- `FunctionInfoScanner`
  - builds whole-module callee facts: size, refs, roots/global uses, loops, calls, `try_delegate`, and trivial-instruction class
- `worthFullInlining(...)`
  - applies the layered heuristic: tiny helpers, one-use helpers, shrinking trivial wrappers, size caps, loop/call policy, and speed-vs-shrink mode
- `Planner::visitCall(...)`
  - discovers the source-backed chosen-action surface: reachable direct `call` / `return_call` sites in the reviewed contract
- `FunctionSplitter`
  - provides the narrow Pattern A / Pattern B partial-inlining helper route
- `doCodeInlining(...)`
  - copies the callee body into the caller and remaps callee locals onto fresh caller locals
- `Updater`
  - repairs copied returns, labels, locals, and nested `return_call*` shapes
- `updateAfterInlining(...)`
  - repairs labels, nested EH pop structure, nondefaultable locals, and final types after an inline iteration
- `Inlining::run(...)`
  - orchestrates scan, action choice, rewrite, callee cleanup, and the optional optimizing rerun

Beginner note: do not look for a separate `InliningOptimizing.cpp` file. The public pass is a mode of the shared inliner.

### `src/passes/pass.cpp`

This file proves the public pass-family split and scheduler role.
It registers or schedules:

- `inlining`
- `inlining-optimizing`
- `inline-main`
- `no-inline`
- `no-full-inline`
- `no-partial-inline`

For this folder, the important facts are:

- `inlining-optimizing` is a public pass name, not just an internal option.
- The default late post-pass path uses the optimizing variant rather than plain `inlining`.
- The no-inline controls are separate helper passes that set policy before the inliner acts.

### `src/passes/opt-utils.h`

This is the key file that makes `inlining-optimizing` different from plain `inlining`.

The relevant helper family:

- adds `precompute-propagate` first
- then reruns the default function optimization pipeline
- filters the work to functions changed by inlining

This means a future Starshine port that only rewrites callsites is not a complete `inlining-optimizing` port.
It is at most the plain inliner core plus a missing optimizing suffix.

### `src/pass.h`

This file owns default heuristic knobs used by the shared inliner.
The durable defaults to keep in mind are:

- `alwaysInlineMaxSize = 2`
- `oneCallerInlineMaxSize = -1`
- `flexibleInlineMaxSize = 20`
- `maxCombinedBinarySize = 400 * 1024`
- `allowFunctionsWithLoops = false`
- `partialInliningIfs = 0`

These are policy defaults, not validation rules.
They explain why the same module may inline differently under different optimize/shrink settings.

### `src/passes/NoInline.cpp`

This file implements Binaryen's explicit inline-suppression passes.
It matters for `inlining-optimizing` because the optimizing variant must respect the same flags before it can create any changed-function set.

The helper passes set:

- full-inline suppression
- partial-inline suppression
- both at once

The living [`../inlining/implementation-structure-and-tests.md`](../inlining/implementation-structure-and-tests.md) page has the broader no-inline / inline-hints discussion.
This page only needs the optimizing-specific takeaway: no-inline policy is an input to the shared inliner, not a post-inline cleanup concern.

### `src/ir/module-utils.cpp`

This file is part of the proof surface for clone survival.
Cloned functions preserve inline policy flags, so monomorphization or other function-copying work can still affect later inlining eligibility.
That is why the `no-inline-monomorphize-inlining.wast` test belongs in this dossier's source map even though it is not named after `inlining-optimizing`.

## Helper surfaces that explain correctness constraints

The inliner uses several helper families that are easy to miss if you only read the pass name.
The plain [`../inlining/implementation-structure-and-tests.md`](../inlining/implementation-structure-and-tests.md) page gives the broadest map; the optimizing variant inherits those correctness dependencies.

Most important inherited surfaces:

- branch-target collection / collision checks
- branch-hint preservation when splitting guard branches
- zero-value detection for copied locals
- metadata copying
- return analysis for partial-inlining candidates
- nondefaultable-local repair for GC/reference locals
- EH nested-pop repair after rewrite
- localizing children during repaired `return_call*` handling
- final refinalization after the copied-body rewrite

Advanced takeaway: the optimizing suffix can only be safe after the shared rewrite has already repaired control, locals, labels, EH, and types. The nested rerun is an optimizer, not the thing that makes malformed inlined code valid.

## Official tests and what they prove

Most visible tests are shared with plain `inlining` because the core rewrite is shared.
For the optimizing variant, read them as proof of the rewritten shapes that the nested rerun may then simplify.

### `test/lit/passes/inlining.wast`

Broad general coverage for basic inline behavior.
Useful for beginner orientation, but the more focused files below are better for specific contracts.

### `test/lit/passes/inlining_optimize-level=3.wast`

Broad high-optimization proof surface.
It exercises:

- tiny always-inline cases
- one-use helpers
- root/export/table-survivor cases
- recursive-growth conservatism
- flexible high-opt-level inlining

### `test/lit/passes/inlining_enable-tail-call.wast`

Main tail-call-sensitive proof surface.
It covers copied-local creation and `return_call` repair, both of which matter before the optimizing rerun can safely run.

### `test/lit/passes/inlining_splitting.wast`

Main partial-inlining stress file.
It proves Pattern A / Pattern B style splitting, helper creation, naming, and root interactions.

### `test/lit/passes/inlining_splitting_basics.wast`

Clean proof that partial inlining is opt-in via the partial-inlining option rather than the ordinary default plain inlining behavior.

### `test/lit/passes/inlining-trivial-instructions.wast`

Proof surface for trivial-instruction classification:

- always-shrinking wrappers
- maybe-growing wrappers
- shrink-vs-speed differences

### `test/lit/passes/inlining-trivial-calls-1.wast`

Focused proof for trivial calls that shrink enough to inline even in size-aware contexts.

### `test/lit/passes/inlining-unreachable.wast`

Proof that inlining preserves unreachable/trapping caller semantics rather than accidentally making a typed wrapper reachable.

### `test/lit/passes/inlining-gc.wast`

Proof for GC/reference-local repair and nondefaultable local handling around copied functions.

### `test/lit/passes/no-inline.wast`

Proof that explicit `no-inline`, `no-full-inline`, and `no-partial-inline` controls are real policy inputs.

### `test/lit/passes/no-inline-monomorphize-inlining.wast`

Proof that no-inline flags survive through function cloning and still block later inlining.

### `test/lit/passes/inline-main.wast`

Proof for the small `inline-main` special-case wrapper that reuses low-level inlining machinery but has a different public scope.

## Where the optimizing suffix is proven

There is no single small WAT file that should be treated as the whole proof of `inlining-optimizing`.
The proof is split:

- shared rewrite proof: the `inlining*` lit files
- policy proof: the `no-inline*` files plus `NoInline.cpp` / `module-utils.cpp`
- optimizing suffix proof: `opt-utils.h` and saved debug evidence that nested useful passes run after top-level `inlining-optimizing`
- local scheduler context: [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)

That split is important for future Starshine work: a local test suite should include both reduced inline-shape fixtures and scheduler tests for touched-function nested reruns.

## Current Starshine code-map touchpoints

The pass is not implemented locally yet, but the current exact status is visible in source:

- [`src/passes/optimize.mbt#L127-L141`](../../../../../src/passes/optimize.mbt#L127-L141)
  - `pass_registry_boundary_only_names()` includes `inlining-optimizing`.
- [`src/passes/optimize.mbt#L458-L468`](../../../../../src/passes/optimize.mbt#L458-L468)
  - active pass expansion rejects boundary-only pass requests with an explicit error.
- [`agent-todo.md#L513-L521`](../../../../../agent-todo.md#L513-L521)
  - backlog slice `INL` starts with heuristics, rewrite, and touched-function tracking.
- [`../../no-dwarf-default-optimize-path.md#L35-L40`](../../no-dwarf-default-optimize-path.md#L35-L40)
  - canonical late post-pass placement and shared nested-rerun rule.

Use [`./starshine-strategy.md`](./starshine-strategy.md) for the fuller local port map.

## Validation guidance for a future port

A faithful Starshine port should validate four layers:

1. shared inliner rewrite shapes
   - tiny helpers
   - one-caller helpers
   - exported/root survivors
   - tail-call repair
   - unreachable/trapping repair
   - GC/nondefaultable local repair
2. partial inlining
   - Pattern A
   - Pattern B
   - disabled-by-default behavior
3. policy inputs
   - no-inline
   - no-full-inline
   - no-partial-inline
   - clone-survival policy
4. optimizing suffix
   - touched-function set
   - prepended `precompute-propagate`
   - default function pipeline rerun on touched functions only
   - late-tail interaction with `dae-optimizing` and `duplicate-function-elimination`

## Sources

- [`../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md`](../../../raw/binaryen/2026-04-25-inlining-optimizing-current-main-implementation-test-map.md)
- [`../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md`](../../../raw/binaryen/2026-04-23-inlining-optimizing-primary-sources.md)
- [`../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md`](../../../raw/research/0361-2026-04-25-inlining-optimizing-current-main-and-test-map.md)
- [`../inlining/implementation-structure-and-tests.md`](../inlining/implementation-structure-and-tests.md)
- Official Binaryen sources:
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/NoInline.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/ir/module-utils.cpp>
