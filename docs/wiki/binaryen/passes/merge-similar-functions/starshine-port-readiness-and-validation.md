---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-merge-similar-functions-primary-sources.md
  - ../../../raw/research/0443-2026-05-05-merge-similar-functions-current-main-recheck.md
  - ../../../raw/research/0332-2026-04-25-merge-similar-functions-primary-sources-and-starshine-followup.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./equivalence-classes-param-derivation-and-thunk-rewrites.md
  - ./profitability-indirection-and-type-barriers.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../duplicate-function-elimination/index.md
  - ../duplicate-import-elimination/index.md
  - ../inlining/index.md
---

# Starshine port-readiness and validation for `merge-similar-functions`

Use this page after the overview in [`./index.md`](./index.md), the Binaryen strategy in [`./binaryen-strategy.md`](./binaryen-strategy.md), the mechanics pages in [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md) and [`./profitability-indirection-and-type-barriers.md`](./profitability-indirection-and-type-barriers.md), the shape catalog in [`./wat-shapes.md`](./wat-shapes.md), and the current Starshine status map in [`./starshine-strategy.md`](./starshine-strategy.md).
This page answers a narrower question: **what is the safest route from today's removed-registry Starshine status to a validated future port?**

## Current local starting point

Starshine does **not** implement `merge-similar-functions` today.
The current code surfaces are still only:

- removed-name registry tracking: [`src/passes/optimize.mbt#L145-L146`](../../../../../src/passes/optimize.mbt#L145-L146)
- removed-pass request rejection: [`src/passes/optimize.mbt#L504-L523`](../../../../../src/passes/optimize.mbt#L504-L523)
- shrink preset omission: [`src/passes/optimize.mbt#L451-L459`](../../../../../src/passes/optimize.mbt#L451-L459)
- default pass synthesis: [`src/cmd/cmd.mbt#L1638-L1642`](../../../../../src/cmd/cmd.mbt#L1638-L1642)
- pass-flag expansion before execution: [`src/cmd/cmd.mbt#L3475-L3479`](../../../../../src/cmd/cmd.mbt#L3475-L3479)
- module-pass dispatcher gap: [`src/passes/pass_manager.mbt#L8912-L8940`](../../../../../src/passes/pass_manager.mbt#L8912-L8940)

There is still no `src/passes/merge_similar_functions.mbt`, no active module dispatcher case, no default preset role, and no dedicated `agent-todo.md` slice.

## Binaryen oracle lanes to preserve

The upstream pass is not a simple local peephole.
A Starshine port should preserve the source-backed lanes from [`../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-merge-similar-functions-current-main-recheck.md):

1. scan defined functions only
2. reject imported targets, signature mismatches, and total-local-count mismatches early
3. prefilter with hashing, then split real equivalence classes with exact comparison
4. derive synthetic params by lockstep expression-slot traversal
5. clone one primary body into a shared helper
6. append synthetic params after original params and repair old locals
7. rewrite originals as thunks that preserve the original names
8. keep direct-callee indirection behind the reference-types-plus-GC and callee-type gates
9. enforce the `255` synthetic-param limit
10. keep profitability explicit so tiny legal wrappers can remain unchanged

## Recommended implementation sequence

### Slice 0: registry honesty and request rejection

Before mutation, decide and test the public policy:

- keep `merge-similar-functions` removed until a real implementation exists, or
- add an explicit analyzer-only lane behind a new internal/debug registry path

Required tests:

- explicit `--merge-similar-functions` must not silently no-op under the current removed-registry state
- the request should fail with the removed-pass error before any module rewrite runs
- docs and CLI help must not imply the option is active until a pass consumes it

### Slice 1: no-rewrite candidate analyzer

Build a deterministic analyzer that reports candidate classes but returns the original module unchanged.

It should classify:

- defined functions
- imported functions
- top-level function-type mismatches
- total-local-count mismatches
- candidate classes that would exceed the `255` synthetic-param cap
- supported literal-only or call-target-only diff families

Validation:

- byte-for-byte no output change
- stable candidate counters in focused tests
- no accidental activation in presets

### Slice 2: literal-only specialization

The first mutating slice should choose the narrowest positive:

- helper clone from one primary body
- synthetic param appended after original params
- literal diff sites rewritten to `local.get`
- old non-param locals shifted upward
- original names preserved as thunks

Do not yet move effectful operand subtrees or direct-call targets across siblings.

### Slice 3: direct-callee indirection

Only after literal-only cloning is reliable, add the harder call-target family:

- `ref.func` payloads in thunks
- function-ref helper params
- `call_ref` / `return_call_ref` in the helper body
- same-function-type gating for the differing callees
- reference-types-plus-GC gating for the feature surface

### Slice 4: profitability and tail-call style

Once the basic helper/thunk rewrite is green, add the size/usefulness gate and tail-call style preservation.
That keeps tiny wrappers and tail-call families honest instead of over-merging them.

### Slice 5: validation and parity

A complete port needs both text and binary validation because the pass changes function declarations, call operands, locals, and helper names.

Use a widening ladder rather than jumping straight to artifact fuzzing:

1. removed-registry rejection tests first
2. no-rewrite candidate tests
3. literal-only helper/thunk rewrite positives and negatives
4. direct-callee indirection positives and type-barrier negatives
5. param-limit and profitability bailouts
6. Binaryen oracle comparison with `--merge-similar-functions`
7. broader pass-fuzz only after the module-level clone/retarget machinery has local validation coverage

## Read-along map

- Upstream strategy: [`./binaryen-strategy.md`](./binaryen-strategy.md)
- Source/test owner map: [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- Mechanics: [`./equivalence-classes-param-derivation-and-thunk-rewrites.md`](./equivalence-classes-param-derivation-and-thunk-rewrites.md)
- Profitability and barriers: [`./profitability-indirection-and-type-barriers.md`](./profitability-indirection-and-type-barriers.md)
- Concrete WAT shapes: [`./wat-shapes.md`](./wat-shapes.md)
- Current Starshine status: [`./starshine-strategy.md`](./starshine-strategy.md)
- Related size passes: [`../duplicate-function-elimination/index.md`](../duplicate-function-elimination/index.md), [`../duplicate-import-elimination/index.md`](../duplicate-import-elimination/index.md), [`../inlining/index.md`](../inlining/index.md)

## Open questions to keep explicit

- Which module-pass owner file should house helper/thunk synthesis once the first mutating slice lands?
- Should the first analyzer report same-hash buckets separately from real equivalence classes, or only expose the stricter class result?
- Do we want a separate debug lane for `call_ref` indirection before ordinary `merge-similar-functions` becomes publicly active?

## Bottom line

The source-backed implementation path is:

1. keep `merge-similar-functions` removed until tests drive a real owner file
2. start with narrow literal-only positives and source-backed negative gates
3. add direct-callee indirection as a separate slice
4. treat profitability and tail-call-style preservation as part of the real contract, not polish
5. validate against the official Binaryen lit families before broad artifact replay

That keeps Starshine aligned with Binaryen's actual `merge-similar-functions` contract instead of drifting into a generic duplicate-function merger.
