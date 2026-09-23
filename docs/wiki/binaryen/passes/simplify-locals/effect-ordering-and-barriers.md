---
kind: concept
status: supported
last_reviewed: 2026-09-22
sources:
  - ./index.md
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_test.mbt
  - ../../../../../src/passes/simplify_locals_dew_conditional_order_test.mbt
  - ../../../../../src/passes/simplify_locals_continuation_handler_test.mbt
  - ../../../../../src/cmd/simplify_locals_continuation_handler_wbtest.mbt
  - ../../../../../src/ir/hot_builders.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./starshine-hot-ir-strategy.md
  - ./implementation-map.md
  - ./wat-shapes.md
---

# `simplify-locals` Effect Ordering And Barriers

> **Comparison baseline — September 10, 2026:** new comparisons use [Binaryen 132](../../release-horizon-and-oracles.md). This supersedes older current/latest-baseline wording below. Recorded v131 sources, commands, artifacts and results retain their historical version and do not establish v132 signoff.

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
- Continuation `resume` handlers with `on_label` targets are exits too. Structure-result lifting must keep a preceding local write before a handler that can leave the rewritten region; otherwise the handler path skips the rehomed write and observes the local's old value. The HOT legality checks use stable targets from `hot_continuation_targets`, including targets that are outside the candidate subtree.

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

## A carried array read below another operand

The array-pop shape has two separate times: read an element before a mutation
call, then write that saved value into a local after the call. When replacing
set/get traffic with a tee, retain the original set's write order with
`hot_build_local_tee_from_set` and `preserve_value_order=true`. Forwarding a
single-use value also retains its original order.

Correct source order then exposes a lowering requirement. A saved array value
may already be on the Wasm stack when a tag constant is pushed above it for a
struct constructor. Checking only the top stack value misses the saved read.
The old emitter ran `array.get` a second time after the mutation, returning 99
instead of the saved 42. Lowering now moves an existing buried single-result
value through typed scratch locals, retains the values above it in order, and
reuses that value. Pure values can still be rematerialized cheaply.

`src/passes/simplify_locals_dew_array_order_test.mbt` executes empty and nonempty
arrays, checks the returned payload, exact read/mutation order, and final array
contents, and requires the conditional to produce its result directly. The
shared regression in `src/ir/hot_lower_pending_effect_test.mbt` simulates tee
formation around a carried call and requires call order `[0, 1]`; the old lowerer
emitted `[0, 1, 0]`. Both regressions were red before repair. All 664 native IR
and SimplifyLocals tests pass (75.734 s). Twelve CLI variants validate and run in
Node and Wago, each two canonical bytes smaller than input and Binaryen 131.

The saved replay improves to 942/1000 with 58 failures and no regression
(144.042 s). O4z hash-evaluation-once now passes. The array fixture passes the
formerly bad SimplifyLocals prefix and has a later, separate inlining failure.
Generated renewal and whole-pipeline speed selection remain open. Evidence is
in Dewdrop's `.tmp/starshine-pass-repairs/sl-array-order-variants/report.json`,
`sl-and-ir-native-wave19.log`, `buried-pending-value-native-red.log`,
`full-replay-regression-wave19/report.json`, and `array-runtime-wave19/report.json`.

The rebuilt release CLI passes the twelve variants and exact O4z
hash-evaluation-once fixture in both engines. Debug build takes 22.626 s;
scoped interfaces 5.084 s; release build 261.278 s. Work over 30 s remains a
performance bug. Release SHA-256 is
`d5a68233c5402e62af7aa6a1b6dc12d4cb0591033608a046221344148edac1f8`;
exact fixture evidence is `sl-release-hash-evaluation-once.json` in the same
Dewdrop evidence directory.

## Global storage aliasing

Different indices do not establish independent storage for imported globals. The
[WebAssembly JavaScript import algorithm](https://webassembly.github.io/spec/js-api/#read-the-imports)
uses the supplied `WebAssembly.Global` object's global address, so two imports may
share that address. Defined globals receive fresh storage.

`globals_are_provably_disjoint` in
[pass_common.mbt](../../../../../src/passes/pass_common.mbt) centralizes the rule:
equal or invalid indices, missing module context, and two imports cannot prove
disjointness; distinct valid indices with at least one definition can. Code
Pushing, all SimplifyLocals variants, Heap Store Optimization, and Optimize
Instructions consecutive-input interference use this rule. SimplifyLocals carries the
module context explicitly through each sinkable collection, including nested
regions. Read/write and write/write conflicts use storage aliasing; read/read
ordering and other effect checks are unchanged.

See [regressions](../../../../../src/passes/simplify_locals_audit_test.mbt) and the
[host-alias runtime lane](../../../../../tests/optimizer/regressions/imported-global-alias.test.ts).
The no-nesting variants retain their existing restrictions on global-read sinking.
