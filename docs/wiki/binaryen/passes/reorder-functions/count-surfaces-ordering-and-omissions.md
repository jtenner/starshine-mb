---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0179-2026-04-21-reorder-functions-binaryen-research.md
  - ../../../raw/research/0211-2026-04-21-reorder-functions-source-confirmation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/ReorderFunctions.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReorderFunctions.cpp
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./module-shapes.md
  - ../reorder-functions-by-name/index.md
---

# `reorder-functions` count surfaces, ordering, and omissions

This page focuses on the part of `reorder-functions` that is easiest to mis-teach:

- what Binaryen actually counts,
- how those counts are assembled,
- what ordering rule it really uses,
- and what it explicitly does **not** count yet.

## The whole pass is smaller than its name suggests

A faithful source-backed summary of Binaryen `version_129` is:

1. create one counter per function,
2. count direct `call` targets in parallel,
3. add start/export/element-segment bumps,
4. sort functions by descending count,
5. break ties by descending name.

That is basically the whole algorithm.

## Step 1: seed one counter for every function already in the module

`ReorderFunctions.cpp` creates a `NameCountMap` and pre-populates it from `module->functions` before scanning any bodies.

That is not just bookkeeping.
It is part of the real contract because the later direct-call walker assumes the target already exists in the map.

### Why the pre-seed matters

The direct-call walker runs in parallel, so the source avoids concurrent insertion by doing all map growth up front.

That means a faithful port should think of the counting domain as:

- **exactly the function names already present in `module->functions`**

not an open-ended set discovered while walking.

## Step 2: count direct `call` targets, and only direct `call` targets

The helper `CallCountScanner` is a function-parallel `PostWalker` whose only visit hook is `visitCall(Call* curr)`.

So the body-side count model is exactly:

- direct `call`

and not:

- `call_ref`
- `call_indirect`
- `ref.func`
- guessed runtime targets
- general callgraph reachability

## Step 3: add three serial module-level count surfaces

After the direct-call scan, Binaryen adds three more sources.

### 1. Start function

If `module->start` is present, it gets one extra count.

### 2. Function exports

Each export whose kind is `Function` gives one extra count to the exported internal function.

### 3. Element-segment function names

The pass calls `ElementUtils::iterAllElementFunctionNames(...)` and increments every named function it finds there.

## Count surface summary table

| Surface | Counted in `version_129`? | Where it happens |
| --- | --- | --- |
| direct `call` | yes | `CallCountScanner::visitCall(...)` |
| start function | yes | serial step in `ReorderFunctions::run(...)` |
| function export | yes | serial step in `ReorderFunctions::run(...)` |
| element-segment function names | yes | `ElementUtils::iterAllElementFunctionNames(...)` |
| `ref.func` | **no, still TODO** | explicit source TODO |
| declaration-section mention | **no, still TODO** | explicit source TODO |
| `call_ref` / `call_indirect` target inference | no | not implemented here |

## The omission boundary is explicit, not inferred

The release-oracle file still contains explicit TODO comments saying Binaryen should someday count:

- all `RefFunc`
- declaration-section mentions

That means those missing surfaces are part of the current contract.
A faithful `version_129` port should not silently add them while still claiming exact release parity.

## Ordering rule: descending count, then descending name

Once the counts are ready, Binaryen sorts `module->functions` with a tiny comparator.

### Primary key

- larger count first

### Tie-breaker

- lexicographically larger function name first

That second rule is easy to miss.
The pass is deterministic, but it is **not** stable by original declaration order.

## Why descending-name ties matter in practice

Suppose three functions all end with count `0`.
Binaryen does **not** preserve their original order.
It sorts them by internal name descending.

So a beginner-friendly mental model is:

- “cold functions are alphabetized backwards”

That sounds funny, but it is much closer to the real comparator than saying “ties stay as-is.”

## Why the pass is still declaration-only despite reordering the module

Both `ReorderFunctions` and `ReorderFunctionsByName` override `requiresNonNullableLocalFixups()` and return `false`.

That is a useful compact signal from the source:

- these passes reorder function declarations,
- they do not rewrite function bodies,
- and they are not expected to create new local-type repair work.

So if a future port starts needing label repair, local remapping, or nondefaultable-local fixups, it has probably stopped being a faithful port of this tiny pass.

## Why upstream frames this as a size pass, not a speed pass

The top-of-file comment says the goal is to reduce wasm binary size because heavily referenced functions can get lower indices.

But the same comment also warns that gzip size can get worse.

That gives the honest optimization story:

- likely better **raw** wasm encoding size,
- possible worse **compressed** size,
- no claim about runtime speed.

## Split from the lexical sibling

This page also helps preserve the main difference from [`../reorder-functions-by-name/index.md`](../reorder-functions-by-name/index.md):

- `reorder-functions-by-name` ignores all count surfaces and just sorts ascending by name,
- `reorder-functions` uses a tiny mixed count model and then sorts descending by count and descending by name.

The shared file does not make them the same pass.

## Common beginner mistakes to avoid

- **Mistake:** “This counts every function reference Binaryen can see.”
  - No. `ref.func` and declaration mentions are still explicit TODOs.
- **Mistake:** “This is profile-guided hotness.”
  - No. It is a small static count model.
- **Mistake:** “Ties keep declaration order.”
  - No. Ties sort by descending name.
- **Mistake:** “Reordering probably needs local or label fixups.”
  - Not in the real `version_129` pass; it explicitly says otherwise.
- **Mistake:** “This is guaranteed to help compressed size.”
  - No. The source warns about possible gzip regressions.

## Porting checklist

If a future Starshine implementation disagrees with Binaryen, check these first:

1. Did it pre-seed one counter per function before parallel scanning?
2. Did it count only direct `call` targets in the walker?
3. Did it add start, function-export, and element-segment bumps afterwards?
4. Did it leave `ref.func` and declaration mentions uncounted, as `version_129` still does?
5. Did it sort by descending count and descending name?
6. Did it keep the pass declaration-only, with no invented repair phase?
