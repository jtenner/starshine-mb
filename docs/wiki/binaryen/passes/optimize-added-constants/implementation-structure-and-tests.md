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
  - ../optimize-added-constants-propagate/index.md
---

# `optimize-added-constants` implementation structure and tests

This page is the file-and-test map for Binaryen `version_129` plain `optimize-added-constants`.

## Core source files

## `src/passes/OptimizeAddedConstants.cpp`

This is the shared implementation file for both public pass names:

- `optimize-added-constants`
- `optimize-added-constants-propagate`

For the plain pass, the important thing is what **does not** get enabled:

- no `LazyLocalGraph` propagation phase,
- no helper-local insertion for propagated address locals,
- and no iterate-after-propagation loop driven by changed local rewrites.

The direct load/store-address fold and constant-pointer normalization are still the real core.

## `src/passes/pass.cpp`

This file matters because it proves:

- plain `optimize-added-constants` is a public Binaryen pass name in `version_129`,
- its public description is about **optimizing added constants into load/store offsets**,
- and it is deliberately separate from the propagate sibling.

## `src/pass.h`

This file matters because it defines `PassOptions::LowMemoryBound = 1024`, which explains the main threshold visible in the shared official tests.

## Official tests and what they prove

## `test/passes/optimize-added-constants_low-memory-unused.wast`

This is the best behavior file for plain mode.

It proves the real positive and negative families:

- direct `load/store(base + const)` folds,
- commuted add forms,
- offset accumulation,
- negative-constant bailouts,
- `1023` versus `1024` threshold behavior,
- and constant-pointer normalization.

## `test/passes/optimize-added-constants_low-memory-unused.txt`

This is the checked output oracle for the plain pass.

It is especially useful because it makes the real contract visible:

- many direct memory ops gain offsets,
- large or negative families stay in add form,
- and constant-pointer-plus-offset shapes may collapse into one constant pointer instead.

## Shared lit files

### `test/lit/passes/optimize-added-constants-memory64.wast`

This proves the overflow-aware constant-pointer normalization story for memory64.

### `test/lit/passes/optimize-added-constants-nomemory.wast`

This proves the pass is a no-op on modules with no memory instead of a fatal error.

## Relationship to the propagate tests

The propagate tests are still useful as a contrast surface.

They prove what the plain pass does **not** own:

- chasing local address carriers,
- helper-local insertion,
- and iterative cleanup after propagation.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/OptimizeAddedConstants.cpp` | Core algorithm | Plain mode is the direct-address half of a shared load/store-offset optimizer |
| `src/passes/pass.cpp` | Public registration | Plain mode is a real public pass, not an internal helper mode |
| `src/pass.h` | Option constant | `LowMemoryBound = 1024` is a real part of the safety contract |
| `test/passes/optimize-added-constants_low-memory-unused.wast` | Behavior oracle | Direct address folding and threshold behavior are the real public surface |
| `test/passes/optimize-added-constants_low-memory-unused.txt` | Output oracle | Existing-offset accumulation and constant-pointer normalization are intentional visible results |
| `test/lit/passes/optimize-added-constants-memory64.wast` | Overflow oracle | Constant-pointer normalization is overflow-aware |
| `test/lit/passes/optimize-added-constants-nomemory.wast` | Empty-surface oracle | No-memory modules are valid no-op inputs |
| `test/passes/optimize-added-constants-propagate_*` | Contrast oracle | The sibling's local-pair propagation is extra behavior, not part of plain mode |

## What this source map says about helper dependencies

The plain pass is intentionally small.

It relies mostly on:

- direct node inspection,
- memory metadata such as `offset` and memory64-ness,
- the low-memory option boundary,
- and `Builder` for replacement nodes.

It does **not** need the sibling's `LazyLocalGraph` machinery to justify its main contract.

## What the test map says about the real public contract

The test surface prevents two teaching mistakes.

### Mistake 1: treating the pass as too broad

The tests keep the focus on memory addresses, not on arbitrary arithmetic trees.

### Mistake 2: treating the pass as too trivial

The tests also show the pass is not just a pretty-printer for offsets. It has real safety boundaries:

- low-memory requirement,
- large-constant cutoff,
- negative-constant bailouts,
- and overflow-sensitive constant-pointer preservation.

## Porting takeaway

If Starshine ever ports this pass, the source/test map suggests a clean design target:

- start with direct load/store-address folding only,
- preserve the low-memory and overflow boundaries exactly,
- and treat local-pair propagation as an explicit later step from the sibling pass rather than silently rolling both contracts together.

## Recommended local teaching rule

When this pass is cited elsewhere in the wiki:

- describe it as the plain direct-address variant,
- point to the propagate sibling for the extra local-pair behavior,
- and avoid describing either pass as arithmetic reassociation.
