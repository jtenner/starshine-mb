---
kind: concept
status: supported
last_reviewed: 2026-09-11
sources:
  - ./index.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/simplify_locals_dew_conditional_order_test.mbt
  - ../../../../../src/ir/hot_builders.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./wat-shapes.md
---

# `simplify-locals` Effect Ordering And Barriers

The v131 renewal did not weaken this barrier model. New direct carrier rewrites are limited to inert prefixes, exact adjacent ownership, dead later reads, and either dupable values or a structured producer whose whole result is forwarded; focused branch-exit and nondefaultable-local tests guard those boundaries.

## Why This Page Exists

- Nearly every serious simplify-locals bug in this repo has been an ordering bug disguised as a local-traffic cleanup.
- "Can replace `local.get` with the earlier value" is only correct if the intervening code cannot change what that replacement means.
- This page is the durable barrier model for the Starshine port.

## Core Rule

- Pending local values are not timeless equalities.
- They are only valid along the current linear trace until some later code:
  - observes the local
  - mutates the local
  - mutates a source the value depends on
  - mutates observable state in a way that changes the meaning or order of the value
  - crosses a control boundary that invalidates the trace model

## Source order after carrier removal

A synthetic local write that captures an existing value must retain the value's
source position. SimplifyLocals now uses `hot_build_local_set_from_value` for
result-producing control wrappers, local-write replacements, and flat carrier
cleanup. Ordinary node allocation gives these writes a later order, which can
make lowering treat a later dependent conditional as an older pending value.
The root list alone does not protect the write/read order.

The reduced Dew JSON shape has three conditionals. The first computes an i64
hash, the second reads that hash to compute an i32 bucket, and the third reads
both. Carrier cleanup previously changed `run(1)` from 84 to 0; the native
regression now checks 84 for both positive and negative true conditions, 0 for
false, and exactly one hash call followed by one bucket call with argument 42.
This protects executed behavior and call order, rather than a local-numbering
layout. The pass still removes the temporary carriers.

Nine reduced CLI variants, including a loop wrapper and a condition copied to a
body local, pass external validation and execution in Node and Wago. Their
stripped outputs are 11..17 bytes smaller than the inputs and 7..10 bytes smaller
than Binaryen 131. These size results are not a runtime-speed claim.

The complete Dew replay improves from 931/1000 to 936/1000, with no new
failures, and the exact optimize-level-4/shrink-level-1 JSON inlining case now
passes both engines. The native family is now 282/282. Three stale exact-reference assertions now
check the actual ordinary typed function reference and matching null arm; they
still require removal of the call_ref local carrier. The pending-effects unit
fixture builds its intended expression tree directly, keeping the checks for
reads of locals 0/3 and writes of locals 2/3. Lifting that tree inserts a capture
root, so the earlier first-root assumption tested a different expression. The release
CLI SHA-256 is `145b9829bc4d468cc54a3038da3a4e987fea0e4b28b61b196ebcd46eac1ef18e`;
its build takes 254.423 seconds, an open compiler-work performance bug. Large
generated gates and whole-pipeline speed selection remain open.

## The Main Barrier Buckets

### 1. Direct Local Conflicts

- Any later read of the pending local may consume the candidate.
- Any later write of the pending local kills the earlier pending candidate.
- Any later write of a source local used by the producer kills moves that would otherwise substitute that source later.

### 2. Local-Only Traffic That Should *Not* Kill The Candidate

- One of the repo's important parity lessons is that not all local traffic is a barrier.
- If a later instruction reads or writes unrelated locals only, the pass may still commute the pending value.
- This is why the implementation now distinguishes:
  - true local conflicts
  - local-state-only traffic that is disjoint from the producer and target locals

### 3. Memory And Table Writes

- Memory and table writes are hard barriers for many pending values.
- This matters especially for trapping producers such as loads:
  - a later store can change the meaning of reordering the load
  - even when both sides are "local-looking" at the consumer level, the producer may still be reading memory

### 4. Trap And Throw Boundaries

- Values that may trap are not freely movable across arbitrary later code.
- The pass now includes a narrow read-only trap commutation rule, but the default posture remains conservative.
- Important distinction:
  - read-only trap versus read-only trap may commute in a narrow case
  - trap versus memory write does not
  - may-throw values are still special at `try` and `try_table` boundaries

### 5. Control-Flow Boundaries

- Control transfers break the linear-trace model.
- The pass treats the following as strong barriers unless a more specific rewrite owns the whole shape:
  - branches
  - branch payloads
  - early terminators
  - nonlinear control merges
  - structured barriers on the raw lane

### 6. Sibling Evaluation Order

- Several artifact bugs came from forgetting that a call's sibling arguments still have a defined order.
- A value-producing `if (result ...)` is not safe to sink into a later argument if it writes a local that an earlier sibling argument reads.
- The reduced `moonbit.malloc` family is the canonical proof that this is real wrong code, not just output-shape preference.

### 7. Loop Boundaries

- Loops are not just structured blocks with a backedge.
- A pending outer producer cannot simply be treated as available at every loop iteration.
- The reduced `StringView.make_init_no_rc` family showed the failure mode directly:
  - pre-loop initializer
  - sunk into loop header
  - repeated every iteration

## The Repo's Current Barrier Vocabulary

- The current lifted pass materially relies on:
  - `simplify_locals_collect_region_local_effects`
  - `simplify_locals_collect_subtree_local_effects`
  - `simplify_locals_effects_for_pending_local_set`
  - `simplify_locals_effects_ordered_before`
  - `simplify_locals_invalidate_sinkables`
- These helpers encode a pass-local policy rather than a generic repo-wide optimizer theorem.
- That is intentional. The pass needs Binaryen-shaped directional behavior, not merely the broadest generic "has side effects" classification.

## Positive Commutation Cases The Repo Now Supports

### Unrelated Local-Only Traffic

- Pending values now survive later local-only traffic when that traffic does not touch:
  - the target local
  - the producer's source locals

### Read-Only Trap Commutation

- Pending trapping values can commute past later read-only traps in the narrow case the pass marks as read-only trap commutable.
- This was needed for Binaryen parity in load-heavy tee folds.

### Pure Prefix Barriers On The Raw Lane

- The raw lane can now sink some temps across a pure prefix or pure local-copy barrier when the barrier local is provably disjoint.

## Negative Cases The Repo Explicitly Protects

### Sibling Call-Argument Reordering

- Do not sink an effectful result into a later argument if an earlier sibling argument reads a local the result writes.

### Memory-Write Barrier After Trapping Read

- Do not move loads or load-like values across a later store.

### Loop-Header Reinitialization

- Do not let outer pending values flow into repeated loop headers.

### Broad Structured Barrier Rewrites

- Do not treat arbitrary `if` bodies or cleanup blocks as transparent just because they are "small."
- The repo only admits narrowly-reduced barrier cases with dedicated proofs.

### Broad `if (result) -> select` Cleanup

- The repo investigated a broad selectification cleanup and rejected it.
- Reduced Binaryen probes showed Binaryen does *not* perform the obvious direct-result or call-argument select rewrites in the simple cases Starshine could cheaply do.

## Why Raw And HOT Barriers Are Not Identical

- HOT IR sees structured region shape, typed control, and detached-node state.
- The raw lane sees exact instruction arrays.
- So the same conceptual barrier appears differently:
  - HOT IR can reason about nested control ownership directly
  - the raw lane must approximate from exact instruction shape and validation state
- This is why the raw lane only owns narrow barrier exceptions instead of trying to reimplement full lifted semantics.

## Maintenance Rule

- Add a new barrier rule here only when it has one of:
  - a reduced wrong-code proof
  - a stable Binaryen parity family
  - a reusable exact/HOT design consequence
- Do not add temporary frontier notes here if they only describe "which function number is currently red."
