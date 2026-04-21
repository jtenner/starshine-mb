---
kind: concept
status: working
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md
  - ../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp
related:
  - ./index.md
  - ./implementation-structure-and-tests.md
  - ./count-surfaces-ordering-and-omissions.md
  - ./module-shapes.md
  - ../reorder-globals/index.md
  - ../reorder-locals/index.md
  - ../reorder-types/index.md
---

# Binaryen `reorder-functions` strategy

## Why this pass is easy to misread

The name sounds like a broad whole-module optimizer.
The actual `version_129` implementation is tiny.

It does **not** optimize function bodies.
It does **not** compute dynamic hotness.
It does **not** use heavyweight analyses.

Instead, it uses a small set of static references to choose a new order for the module's function declarations.

## Public surface

`pass.cpp` exposes two public passes from the same source file:

- `reorder-functions-by-name`
- `reorder-functions`

The descriptions already tell the honest story:

- `reorder-functions-by-name` is for debugging
- `reorder-functions` sorts by access frequency

That “access frequency” is still **static**, not profile-guided.

For the most compact owner/boundary recap, see [`./count-surfaces-ordering-and-omissions.md`](./count-surfaces-ordering-and-omissions.md).

## Phase 1: seed every function with count `0`

The pass begins by creating a `NameCountMap` keyed by function name.
Every function already present in `module->functions` gets an entry with count `0` before any parallel scanning starts.

That pre-seeding matters because the parallel walker only increments existing entries.
The code even asserts that a direct-call target must already exist in the map before incrementing.

So the pass's counting domain is exactly:

- the module's defined/imported function list as seen in `module->functions`

## Phase 2: count direct calls in parallel

The helper walker `CallCountScanner` is a function-parallel `PostWalker`.
It visits only one expression kind:

- `Call`

For every direct call, it increments the target function's count.

Important boundary:

- this is **direct-call-only** counting

The pass does not try to infer possible indirect-call targets.
It does not inspect `call_ref` tables or run callgraph analysis.

## Phase 3: add non-body function references

After the direct-call walk, the pass manually adds three more sources of static use:

### Start function

If `module->start` is present, that function gets one extra count.

This means a module entrypoint can move earlier even when there are no direct callers in function bodies.

### Function exports

Every export whose kind is `Function` gives one extra count to the exported internal function.

This matters for beginner understanding because exported APIs may be important even when the internal module never calls them directly.

### Element segment contents

The pass calls `ElementUtils::iterAllElementFunctionNames(...)` and increments each referenced function.

That means table-initialization usage counts too.
A function can move earlier just because it is stored into a table by an element segment.

## Phase 4: explicit non-goals left as TODOs

The source leaves two explicit TODO comments:

- count all `ref.func` as well
- count the declaration section as well, which adds another mention

These TODOs are not side trivia.
They define the current real boundary.

So when teaching or porting `version_129`, do **not** silently pretend those counts already exist.
A faithful port should preserve the same undercounting unless it deliberately targets a newer or intentionally different behavior.

## Phase 5: sort by descending count, then descending name

The comparator is short but important.

### Primary key

- higher count first

That is the whole point of the pass.
Frequently referenced functions get lower indices earlier in the section.

### Tie breaker

- if counts are equal, compare names and put the lexicographically larger name first

This is easy to miss.
The pass is **not** stable by original source order.
It makes a deterministic secondary ordering choice based on names.

That tie rule is important for byte-for-byte parity.

## Why Binaryen thinks this can help size

The top-of-file comment explains the intended benefit:

- functions with lower indices can be referenced with fewer bytes in binary encodings

So the optimization target is:

- **encoded wasm binary size through index locality**

not:

- runtime speed
- compile-time simplification
- semantics

## Why Binaryen warns about gzip regressions

The same comment also says the reordered output can increase gzip size.
The explanation given there is that original nearby functions may compress better together, while pure frequency order may separate mutually compressible functions.

That makes this pass a good example of a subtle size tradeoff:

- smaller raw wasm bytes
- possibly worse compressed bytes

A future Starshine port should preserve that framing instead of overselling the pass as pure size win.

## The sibling pass matters

`reorder-functions-by-name` helps define the boundaries of the main pass.
It shares the same module-order rewrite shape but swaps in a different comparator:

- ascending function name

So the shared essence is:

- reorder the module's function list only

The variant-specific essence is:

- how to choose the order

That is why these two public pass names belong in one teaching cluster.

## What the pass depends on

The real dependency surface is tiny:

- `PostWalker` / pass infrastructure for the direct-call scan
- `ElementUtils::iterAllElementFunctionNames(...)` for table initializer references
- ordinary module export/start metadata
- standard vector sorting over `module->functions`

Notably absent from the source contract:

- CFG reasoning
- effect analysis
- liveness
- dominance
- SSA
- type refinalization
- local repair
- label repair

The source reinforces that absence directly: both reorder-functions siblings return `false` from `requiresNonNullableLocalFixups()` because they only reorder declarations.

That absence is part of the strategy.
This is a declaration-order pass, not a body-transform pass.

## Interactions with nearby passes

### With `reorder-globals`

They are conceptually similar because both reorder declarations by static usage.
But `reorder-globals` has dependency ordering and a size model about index-width thresholds.
`reorder-functions` is simpler: count first, then sort.

### With `reorder-locals`

They are also conceptually similar because both use access counts.
But `reorder-locals` must rewrite body-local indices and names.
`reorder-functions` leaves bodies untouched and relies on module-level function-order machinery.

### With `reorder-types`

`reorder-types` has legality constraints around type graphs and rec groups.
`reorder-functions` has no comparable legality logic in this file.

## What a future Starshine port must preserve

At minimum:

1. direct-call counting only from `Call`
2. extra count bumps for start, function exports, and element segment function names
3. no body mutation
4. descending-count primary sort
5. descending-name tie break
6. explicit separation from `reorder-functions-by-name`
7. explicit TODO boundaries around missing `ref.func` and declaration counting

## Common beginner mistakes to avoid

- **Mistake:** “This uses runtime frequency.”
  - No. It uses static module references.
- **Mistake:** “This rewrites call targets.”
  - Not in this file; it only reorders function declarations.
- **Mistake:** “Table uses do not count.”
  - They do, through element segment contents.
- **Mistake:** “Exported but uncalled functions stay cold.”
  - They still get a count bump.
- **Mistake:** “Equal-count functions stay in source order.”
  - They do not; name order breaks ties.
- **Mistake:** “The pass already counts `ref.func`.”
  - The source explicitly says that is still TODO.

## Condensed mental model

A faithful beginner summary is:

- Binaryen counts a small set of static function-reference surfaces.
- It sorts the function list so heavily referenced functions tend to get smaller indices.
- It keeps a deterministic name-based tie breaker.
- It does not touch function bodies.

That is the real `reorder-functions` contract in `version_129`.
