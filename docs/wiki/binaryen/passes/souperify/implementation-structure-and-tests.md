---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-25-souperify-primary-sources.md
  - ../../../raw/research/0338-2026-04-25-souperify-source-bridge.md
  - ../../../raw/research/0219-2026-04-21-souperify-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./flat-dataflow-traces-and-single-use-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
---

# Binaryen `souperify` implementation structure and tests

The source map below is now anchored to the committed raw manifest [`../../../raw/binaryen/2026-04-25-souperify-primary-sources.md`](../../../raw/binaryen/2026-04-25-souperify-primary-sources.md), so future pages should cite that manifest before falling back to direct online URLs.

## Core file map

## `src/passes/Souperify.cpp`

This is the real owner file for both public passes:

- `souperify`
- `souperify-single-use`

The file contains four important layers:

1. `UseFinder`
   - finds real uses of a set value through `LocalGraph`, including copy chains and non-set external uses
2. `Trace`
   - builds a bounded backwards dependency slice for one inferable root
3. `Printer`
   - emits Souper-style text for nodes, phis, blocks, path conditions, and annotations
4. `Souperify`
   - the actual pass wrapper that verifies flatness, builds graphs, configures single-use exclusions, and prints traces

If a future reader wants the real algorithm, this file is the first place to read.

## `src/passes/pass.cpp`

This is the public registration surface.
It proves that Binaryen exposes two public pass names here:

- `souperify`
- `souperify-single-use`

That matters because the sibling split is part of the official CLI surface, not just a local helper flag.

## `src/dataflow/node.h`

This file defines the DataFlow IR node vocabulary the pass prints:

- `Var`
- `Expr`
- `Phi`
- `Cond`
- `Block`
- `Zext`
- `Bad`

It also explains why `Zext` exists at all:

- Souper comparisons return `i1`, while wasm integer computations often need `i32` / `i64` again.

## `src/dataflow/graph.h`

This file is the main supporting source for extraction semantics.
It proves the pass's graph-builder behavior around:

- `if` merge conditions,
- local-state merges,
- `phi` creation,
- loop-phi avoidance,
- expression / node parent tracking,
- and `blockpc` support.

This file is especially important for understanding why `souperify` can emit phis and path conditions even though the main AST has neither form.

## `src/dataflow/utils.h`

This helper file is part of the same DataFlow layer.
It matters mainly because `Souperify.cpp` uses the shared dump / utility surface for debugging and graph inspection.

## `src/ir/flat.h`

This file proves the hard input-shape contract.
It is the canonical source for what “flat IR” means here.
Without it, it is easy to mis-teach `souperify` as a generic extractor that can start from arbitrary nested Binaryen ASTs.

## `src/ir/local-graph.h`

This file is the public helper surface for use discovery.
It proves that the pass is not guessing about local traffic by hand.
Instead it relies on real `set` / `get` influence information.

## Official test map

## There is no standalone `souperify.wast` oracle in `version_129`

That absence is worth stating explicitly.
The reviewed `version_129` official proof surface for this family is the pair of combo tests:

- `flatten_simplify-locals-nonesting_souperify_enable-threads.wast`
- `flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

That test layout is part of the pass's real teaching story:

- Binaryen expects `souperify` to be used after flatness-creating and locals-cleanup preparation.

## `test/lit/passes/flatten_simplify-locals-nonesting_souperify_enable-threads.wast`

This is the main direct oracle for plain `souperify`.
The file proves several important families:

- straight-line paper-style examples like `figure-1a`
- path-conditioned `if` extraction like `figure-1b`
- `select` support
- merged-value / phi families
- bad-phi and bad-type bailouts
- unreachable-region robustness
- deep-trace truncation behavior
- multiple path-condition examples
- loop-related conservative handling

Because the file is run through:

- `--flatten --simplify-locals-nonesting --souperify --enable-threads`

it also directly proves the real preparation contract.

## `test/lit/passes/flatten_simplify-locals-nonesting_souperify-single-use_enable-threads.wast`

This is the direct oracle for the public sibling `souperify-single-use`.
It is largely parallel to the plain test, but it proves the sibling split:

- the pass still extracts traces from the same overall source families,
- while multi-use child slices are summarized more aggressively.

That is the strongest official proof that single-use is a real pass variant, not just an undocumented debug knob.

## Supporting proof from source shape

The tiny lit roster does **not** isolate every internal design fact on its own.
Several important teaching points are therefore source-derived but still strong:

- loop phis are intentionally avoided in `dataflow/graph.h`
- path conditions are `if`-only in `Souperify.cpp`
- external-use annotation comes from `UseFinder` + `Printer`
- depth and total bounds are real env-configurable limits in `Trace`
- single-use mode excludes nodes as children, not as roots

Those are good examples of facts that belong in the living dossier even when the shipped lit files do not each isolate them with tiny standalone checks.

## Current-main drift check

Reviewed current-main status:

- `src/passes/Souperify.cpp` differs from `version_129` only by a typo fix in one unreachable-string literal
- both reviewed lit files match `version_129` on the relevant surfaces

So the owner-file and test-map story documented here is still current on the reviewed surfaces as of 2026-04-25. The local Starshine follow-along map is separate in [`./starshine-strategy.md`](./starshine-strategy.md) because current Starshine has no `souperify` registry entry, owner file, or trace-output lane.

## Practical reading order

For future work, the most efficient source reading order is:

1. `src/passes/pass.cpp`
   - confirm public names and sibling split
2. `src/ir/flat.h`
   - confirm input precondition
3. `src/dataflow/node.h`
   - learn the node vocabulary
4. `src/dataflow/graph.h`
   - learn merge / phi / loop / path-condition construction
5. `src/ir/local-graph.h`
   - learn influence queries
6. `src/passes/Souperify.cpp`
   - read `UseFinder`, `Trace`, `Printer`, and `Souperify`
7. the two combo lit files
   - map the source-backed behavior onto real examples

## What this page corrects

The biggest easy mistake is to assume `souperify` must have:

- a standalone `souperify.wast` test,
- and a generic direct-AST emitter implementation.

The reviewed `version_129` sources show the real story instead:

- the official tests are flatten-plus-cleanup combo files,
- and the pass is centered on DataFlow IR plus `LocalGraph`, not direct AST printing.
