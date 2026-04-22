---
kind: concept
status: supported
last_reviewed: 2026-04-22
sources:
  - ../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md
  - ../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md
  - ../../../raw/research/0256-2026-04-22-once-reduction-primary-sources-and-code-map-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./dominance-propagation-and-cycle-safety.md
  - ./wat-shapes.md
  - ./parity.md
---

# `once-reduction`: implementation structure and tests

This page is the compact file/test map for the real Binaryen `version_129` `once-reduction` contract.

## Core implementation files

### `src/passes/OnceReduction.cpp`

What it proves:

- `OptInfo` is the true shared state of the pass, separating:
  - candidate once-globals
  - function-to-once-global bindings
  - current fixed-point summaries
  - next-iteration summaries
- `Scanner` owns exact once-shape recognition and candidacy invalidation:
  - it counts `GlobalGet`s
  - rejects zero or non-constant integer writes
  - recognizes the exact `if (global.get) return; global.set nonzero` top-of-function pattern
  - ignores only the one guard read at the start of a matched once function
- `Optimizer` is a CFG/dominator pass over only two relevant expression kinds:
  - `GlobalSet`
  - `Call`
- local optimization and global summary propagation are intentionally mixed:
  - block facts are seeded from the immediate dominator
  - redundant direct calls and redundant `global.set`s are both nopped by the same “already-known once-bit” helper
  - non-once callees still contribute summary facts through `onceGlobalsSetInFuncs`
- the fixed-point loop stops when the total number of summary entries stops growing
- `optimizeOnceBodies(...)` is the separate final cleanup phase:
  - size-`2` wrappers become `nop`
  - size-`3` wrappers whose entire payload is a call to another once function can lose their own early-exit logic
  - deterministic cycle guarding happens through `removedExitLogic`

### `src/passes/pass.cpp`

What it proves:

- `once-reduction` is a real public pass name
- the public description is only “reduces calls to code that only runs once,” which understates the real scanner + fixed-point + cleanup structure
- Binaryen's default optimize pipeline inserts the pass in the early module-prepass cluster, not in the function pass lane or in a nested post-inlining helper slot

### `src/ir/intrinsics.h`

What it proves:

- `Intrinsics::getAnnotations(...)` is the official source of the `idempotent` annotation that `OnceReduction.cpp` consumes
- the upstream idempotent path is not folklore or a comment-only idea; it is wired through the same code-annotation surface that other Binaryen passes use

## Helper/context ownership that matters

### `cfg/domtree.h`

What it proves:

- `Optimizer` relies on an explicit dominator tree
- current Binaryen propagation is immediate-dominator based, not an all-predecessor merge/intersection solver

### `support/unique_deferring_queue.h`

What it proves indirectly:

- `OnceReduction.cpp` sits in the same broader Binaryen infrastructure style as other CFG/dataflow passes, even though this particular pass keeps its own summary loop quite small
- for practical porting, the key lesson is still the source-level algorithm, not that this helper changes the public contract directly

### `ir/names.h`

What it proves:

- fake once-globals for `@binaryen.idempotent` functions are generated through ordinary valid-name creation, not through a hidden side table or an unnameable sentinel

## Official test surface

### `test/lit/passes/once-reduction.wast`

What it proves:

- minimal once wrappers can be reduced so repeated dominated calls turn into `nop`
- a wrapper with no payload can lose its body entirely
- nonzero initializer and nonzero later-write cases are still valid optimization inputs
- shape mismatches really block recognition:
  - code before the guard
  - code between guard and set
  - `else` arm
  - different globals in `get` and `set`
  - non-`Block` bodies
  - bodies that are too short
- bad global behavior blocks optimization:
  - zero writes
  - non-constant later writes
  - extra reads of the once global
  - imported mutable globals
  - exported mutable globals
  - non-integer globals
- params/results on the once function are real no-op boundaries
- self-recursion is safe to optimize in the narrow source-backed way
- long CFG chains and try/catch shapes are intentionally covered, showing this is not only a trivial straight-line peephole pass
- whole-program propagation through call chains is part of the intended contract
- once-to-once loops and the dangerous triple-loop family are explicitly covered, so cycle and side-effect-order conservatism are not accidental side notes

## What the lit file does **not** foreground by itself

The dedicated lit surface is rich, but one source-backed behavior is easier to miss if you only skim test headings:

- the upstream `@binaryen.idempotent` path is definitely present in `OnceReduction.cpp`
- but the dedicated `once-reduction.wast` file is dominated by explicit once-global cases rather than an obvious named annotation section

So a future port should treat the idempotent path as part of the source contract even if it is easier to notice in implementation than in the lit roster.

## Current Starshine-facing port checklist

If Starshine eventually tightens or re-ports `once-reduction`, the local port should preserve all of the following upstream-observable facts:

- module pass, not hot pass
- early module-prepass scheduler slot
- imported and exported global boundary filtering at the top level
- exact once-shape matching, not approximate “close enough” wrappers
- zero/non-constant write invalidation
- extra-read invalidation
- no-param/no-result restriction for direct once-call elimination
- `@binaryen.idempotent` reuse of the same once-global framework through fake global names
- CFG facts copied from the immediate dominator only
- local redundant `global.set` and redundant direct-call removal through the same “already set” proof
- fixed-point convergence measured by monotonic summary-cardinality growth
- final wrapper cleanup restricted to tiny real-global wrappers with deterministic cycle protection

## Freshness note

The 2026-04-22 raw primary-source capture rechecked the official release page, `OnceReduction.cpp`, `intrinsics.h`, `pass.cpp`, and the dedicated `once-reduction.wast` file, and did not surface a new teaching-relevant implementation or test-map drift beyond this page's current claims.

## Sources

- [`../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md`](../../../raw/binaryen/2026-04-22-once-reduction-primary-sources.md)
- [`../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md`](../../../raw/research/0202-2026-04-21-once-reduction-implementation-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/OnceReduction.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/intrinsics.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/once-reduction.wast>
