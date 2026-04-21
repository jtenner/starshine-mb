---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0165-2026-04-21-optimize-added-constants-propagate-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ../optimize-added-constants/index.md
---

# `optimize-added-constants-propagate`: implementation structure and tests

This page is the file-and-test map for Binaryen `version_129` `optimize-added-constants-propagate`.

## Core source files

## `src/passes/OptimizeAddedConstants.cpp`

This is the real implementation for **both** public pass names:

- `optimize-added-constants`
- `optimize-added-constants-propagate`

The durable structure visible from the reviewed file is:

- direct load/store pointer folding into offsets,
- constant-pointer normalization,
- optional `LazyLocalGraph` propagation across local pairs,
- helper-local creation when direct SSA reuse is unsafe,
- and iterative cleanup after each changed pass.

That shared implementation detail is why the sibling relationship matters so much.

## `src/passes/pass.cpp`

This file matters because it proves:

- `optimize-added-constants-propagate` is a public pass name in Binaryen `version_129`,
- the public description is explicitly about **load/store offsets propagated across locals**,
- and the pass is distinct from plain `optimize-added-constants`.

## `src/pass.h`

This file matters because it defines `PassOptions::LowMemoryBound = 1024`.

That constant explains the most visible threshold in the tests and is part of the real safety contract, not a minor detail.

## Official tests and what they prove

## `test/passes/optimize-added-constants-propagate_low-memory-unused.wast`

This is the most useful behavior file for the chosen pass.

It proves the real positive and negative families:

- direct `base + const` folds still happen,
- propagation across `local.set` / `local.get` is a real extra feature,
- commuted adds still work,
- helper locals can appear,
- non-SSA or extra-use cases can block propagation,
- and realistic repeated stack-pointer style address locals can collapse into direct offseted loads/stores.

## `test/passes/optimize-added-constants-propagate_low-memory-unused.txt`

This is the checked output oracle for the propagate behavior.

It is especially useful because it shows the exact visible consequences beginners tend to miss:

- `nop` placeholders where the old set became dead,
- helper locals when reuse is unsafe,
- and preserved non-propagated shapes when the safety proof fails.

## Shared family: `test/passes/optimize-added-constants_low-memory-unused.{wast,txt}`

These still matter for the propagate dossier because they prove the direct-address core shared with plain mode:

- direct offset folding,
- existing-offset accumulation,
- negative-constant bailouts,
- constant-pointer normalization,
- and the `1023` vs `1024` low-memory boundary.

## Shared lit files

### `test/lit/passes/optimize-added-constants-memory64.wast`

This proves the overflow-aware constant-pointer normalization story for memory64.

### `test/lit/passes/optimize-added-constants-nomemory.wast`

This proves the pass is a no-op on modules with no memory instead of a fatal error.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/OptimizeAddedConstants.cpp` | Core algorithm | The pass family is a memory-address offset optimizer, not generic arithmetic simplification |
| `src/passes/pass.cpp` | Public registration | The propagate variant is a real separate public pass with a local-propagation contract |
| `src/pass.h` | Option constant | `LowMemoryBound = 1024` is part of the safety boundary |
| `test/passes/optimize-added-constants-propagate_low-memory-unused.wast` | Behavior oracle | Propagation across locals is real, conservative, and shape-driven |
| `test/passes/optimize-added-constants-propagate_low-memory-unused.txt` | Output oracle | Helper locals, `nop`s, and preserved bailouts are intentional visible results |
| `test/passes/optimize-added-constants_low-memory-unused.{wast,txt}` | Shared core oracle | Direct fold behavior and low-memory threshold are shared with the plain sibling |
| `test/lit/passes/optimize-added-constants-memory64.wast` | Overflow oracle | Constant-pointer normalization is overflow-aware |
| `test/lit/passes/optimize-added-constants-nomemory.wast` | Empty-surface oracle | The pass cleanly returns on no-memory modules |

## What this source map says about helper dependencies

Compared with many optimization passes, the propagate variant is still lightweight.

It relies mostly on:

- `LazyLocalGraph`
- `ExpressionStackWalker`
- local cleanup helpers like `UnneededSetRemover`
- `Builder`

It does **not** look like a pass whose identity depends on:

- CFG-wide branch reasoning,
- liveness as a user-visible contract,
- heavy type repair,
- or module-wide whole-program analysis.

The hard part is not breadth; it is preserving the exact safety boundaries around local reuse.

## What the test map says about the real public contract

The test surface prevents two teaching mistakes.

### Mistake 1: treating the pass as too broad

The tests keep the focus on load/store addresses and address-carrying locals, not on arbitrary arithmetic or generic constant propagation.

### Mistake 2: treating the pass as too small

The propagate tests prove this is not just “plain optimize-added-constants with a different name.”
It really can:

- chase local address carriers,
- insert helper locals,
- and iterate after cleanup.

## Porting takeaway

If Starshine ever ports this pass, the source/test map suggests a clean design target:

- start from the plain load/store-address fold,
- add a conservative local use/def layer,
- preserve the low-memory threshold and helper-local fallback exactly,
- and test with both direct and propagated address families.

## Recommended local teaching rule

When this pass is cited elsewhere in the wiki:

- link here for the propagate-specific local-pair contract,
- link to the plain sibling for the smaller direct-address-only story,
- and avoid describing either pass as generic constant folding.
