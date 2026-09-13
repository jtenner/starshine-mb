---
kind: concept
status: supported
last_reviewed: 2026-09-12
sources:
  - ./test-matrix.md
  - ./local-ssa-policy.md
  - https://doi.org/10.1145/115372.115320
  - ../../../src/ir/README.md
  - ../../../src/ir/architecture.mbt
  - ../../../src/ir/hot_core.mbt
  - ../../../src/ir/analysis_cache.mbt
  - ../../../src/passes/pass_common.mbt
  - ../../../src/passes/apply_compiler_facts.mbt
  - ../../../src/passes/dead_argument_elimination2.mbt
  - ../../../tests/optimizer/regressions/try-table-cleanup.test.ts
  - ../../../tests/optimizer/regressions/compiler-fact-stack.test.ts
  - ../../../tests/optimizer/regressions/dae2-function-label.test.ts
related:
  - ./cfg-contract.md
  - ./local-ssa-policy.md
  - ./test-matrix.md
  - ./pass-porting-checklist.md
  - ./execution-plan.md
  - ../../../src/ir/README.md
  - ../../../src/ir/hot_lift.mbt
  - ../../../src/ir/hot_verify.mbt
  - ../../../src/ir/hot_lower.mbt
---

# IR2 Architecture Rules

## Overview

IR2 is Starshine's optimizer-internal architecture for working on WebAssembly function bodies. Its central rule is intentionally small: **`HotFunc` is the only owned optimizer body representation.** Everything else is either a boundary WebAssembly module/expression, a derived analysis overlay, or a pass-facing helper around that one owned body.

A beginner-friendly flow is:

```text
raw @lib.Module / @lib.Expr
  -> lift one function body into HotFunc
  -> verify the HOT body
  -> build revision-keyed overlays such as CFG, dominators, effects, or local SSA
  -> mutate through HOT mutation helpers
  -> verify again
  -> lower back to raw @lib instructions/function body
  -> validate the resulting module
```

The local `src/ir` and `src/passes` files and their tests are authoritative for HOT ownership, revisioning, side tables, descriptors, and cache behavior. Official WebAssembly material supplies only the boundary-language context: it does not prescribe Starshine's optimizer-local representation.

## The Three Layers

| Layer | Owned by | What it is for | What it must not do |
| --- | --- | --- | --- |
| Boundary module/expression | `src/lib`, WAT/binary parser, validator, command pipeline | Decode, encode, validate, print, run spec/static harnesses, and carry whole-module resources. | Do not become a pass-private recursive optimizer body. |
| HOT body | One [`HotFunc`](../../../src/ir/hot_core.mbt) per lifted function body | Dense function-body storage for optimizer rewrites, with stable ids, side tables, labels, locals, types, roots, tombstones, and a revision counter. | Do not skip verification/lowering/validation; do not mutate storage behind the public APIs. |
| Analysis overlays | CFG, dominance, post-dominance, loop info, use-def, liveness, effects, local SSA, traversal orders | Reusable facts derived from a `HotFunc` at a specific revision. | Do not own body state, persist across revisions, or patch themselves after mutation. |

This separation prevents a common compiler failure mode: building several half-owned IRs that disagree about control flow, locals, side effects, or validation state. If a pass needs a fact, it should request or build an overlay. If it needs to change semantics, it should mutate `HotFunc` and let revision-based invalidation force fresh overlays.

## `HotFunc` Ownership Shape

[`HotFunc`](../../../src/ir/hot_core.mbt) owns the function-body data that optimizer passes are allowed to rewrite:

- dense `nodes`, `children`, and `roots` arrays;
- `HotLocals` for parameter/body-local metadata;
- interned result/type records;
- labels with owner and branch-arity metadata;
- typed side tables for constants, memory arguments, branch tables, catches, call signatures, and exact boundary-instruction payloads;
- body result and optional function type metadata;
- tombstone/free-node tracking for deleted nodes;
- `revision`, the cache key for every derived overlay.

Important practical consequences:

1. **Node ids are HOT-local ids.** They are not raw `@lib.Instruction` pointers and are not stable after lowering/re-lifting a function.
2. **Side tables preserve exact boundary details.** Generic HOT families such as heap/reference/string/SIMD/atomic forms may carry exact instruction payloads so lift/lower can preserve opcode identity that a pass does not understand deeply yet.
3. **Deleted nodes are tombstones, not an alternate body.** Tombstones keep ids stable during a pass, but later queries must check liveness instead of assuming every allocated node is semantically present.
4. **Revision is part of correctness.** Any semantic mutation that changes roots, children, nodes, locals, labels, types, or lowered meaning must bump the revision through the public mutation surface.

## Revision-Keyed Overlays

[`analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt) is the shared cache for derived facts. It stores each overlay with `built_at_revision` and reuses it only while `built_at_revision == hot_revision_current(func)`.

Current cache entries include:

- CFG and deterministic CFG orders;
- dominators and post-dominators;
- loop info;
- use-def and liveness;
- conservative effects summaries;
- local SSA.

The pass-facing helper layer in [`pass_common.mbt`](../../../src/passes/pass_common.mbt) turns descriptor requirements into typed `pass_require_*` calls. That means a pass should normally say what it needs through [`HotPassDescriptor`](../../../src/ir/architecture.mbt), then call shared helpers rather than constructing its own private CFG, liveness, or SSA cache.

```moonbit
HotPassDescriptor::new(
  "example-pass",
  requires=[HotAnalysis::cfg(), HotAnalysis::effects()],
  invalidates=[HotAnalysis::liveness(), HotAnalysis::ssa()],
)
```

The exact syntax above is illustrative, but the shape is locked by [`architecture.mbt`](../../../src/ir/architecture.mbt) and [`architecture_test.mbt`](../../../src/ir/architecture_test.mbt): descriptors expose `requires` and `invalidates`, while direct HOT mutations advance the revision.

## Lift / Verify / Analyze / Mutate / Lower Contract

The durable pass contract is:

```text
lift -> verify -> analyze -> mutate -> verify -> lower -> validate
```

- **Lift**: [`hot_lift.mbt`](../../../src/ir/hot_lift.mbt) reads validated boundary expressions/functions and module context into a `HotFunc`.
- **Verify before mutation**: [`hot_verify.mbt`](../../../src/ir/hot_verify.mbt) catches corrupted HOT storage, control metadata, labels, and analysis assumptions early.
- **Analyze**: request overlays through the shared cache/helper layer.
- **Mutate**: use [`hot_mutate.mbt`](../../../src/ir/hot_mutate.mbt), [`hot_region_edit.mbt`](../../../src/ir/hot_region_edit.mbt), and pass-level wrappers such as `pass_replace_node(...)` or `pass_splice_region(...)` where possible.
- **Verify after mutation**: do not trust a local rewrite just because it was small.
- **Lower**: [`hot_lower.mbt`](../../../src/ir/hot_lower.mbt) reconstructs boundary instructions/function bodies, including label-depth remapping and exact instruction recovery.
- **Validate**: module validation remains the final local semantic floor before pass-specific Binaryen oracle comparison.

The shared fixture path in [`test-matrix.md`](./test-matrix.md) describes how IR tests prove this loop with WAT fixtures, HOT verification, lowering, and module validation.

## Lift performance invariants

HOT lift is shared infrastructure, so fixed per-function or per-control work multiplies across every active hot pass. The August 28, 2026 production-artifact checkpoint establishes these implementation rules:

- module function lifting derives defined-function indices from context/code-section counts instead of rescanning imports per function;
- module function results reuse the already resolved `FuncType`, avoiding a second validation-environment build;
- validation locals retain compressed declaration runs rather than expanding and recompressing large same-typed local sets;
- initial definite-local storage uses one length-based allocation rather than one append per local;
- repeated scalar and simple block-result types use small typed caches while preserving the canonical public string-key table and verifier contract;
- validator operand stacks remain isolated during instruction typechecking, and control regions retain independent initialization storage. Attempts to share either mutable structure changed legacy-EH behavior and were rejected.

On the canonical 4,977,401-byte artifact, alternating clean-HEAD/current `tuple-optimization` runs reduce median lift from `1,067.202ms` to `595.670ms` while preserving exact output. The same source also lowers single-sample lift attribution for RemoveUnusedNames, Heap2Local, and SimplifyLocalsNoNesting, confirming that this is shared infrastructure work rather than a tuple-only bypass.

## Module Split Rule

`src/ir` has already moved beyond the original March plan's “future split” language. Treat the current package files as the ownership map:

- `architecture.mbt`: revision reads and pass-descriptor metadata.
- `hot_core.mbt`: dense HOT storage and basic ids.
- `hot_builders.mbt`, `hot_mutate.mbt`, `hot_region_edit.mbt`, `hot_query.mbt`, `hot_walk.mbt`: construction, mutation, structured edits, read-only queries, and traversals.
- `hot_types.mbt`, `hot_labels.mbt`, `hot_flags.mbt`, `hot_side_tables.mbt`, `hot_module_context.mbt`: type/label/flag/payload/module-context support.
- `hot_lift.mbt`, `hot_verify.mbt`, `hot_lower.mbt`: boundary conversion and correctness checkpoints.
- `cfg*.mbt`, `dominators.mbt`, `postdominators.mbt`, `loop_info.mbt`, `use_def.mbt`, `liveness.mbt`, `effects.mbt`, `ssa_*.mbt`, `analysis_cache.mbt`: derived overlays.
- `test_helpers.mbt`: shared IR fixture and golden helpers.
- `hot.mbt`: compatibility-free facade/glue for consumers, not permission to re-centralize logic.

When adding a new invariant, prefer a focused module or the existing focused owner. Do not rebuild a monolithic `hot.mbt`, and do not revive deleted recursive optimizer-body compatibility layers.

## Correctness Constraints

- **Loop input arity:** both `hot_control_result_type_set` and batched
  `hot_replace_child_spans_and_control_result_type` preserve a loop's own label
  branch arity while visiting its body region. Branches to that label carry
  loop inputs, even when the loop has a different result arity. The zero-input,
  one-result replacement regression in
  [`hot_mutate_test.mbt`](../../../src/ir/hot_mutate_test.mbt) verifies the child,
  both arities, HOT invariants, and lowered module validation.
- **Dead-tee value order:** callers must prove the `local.tee` write dead before
  invoking `hot_replace_local_tee_with_value`. It forwards the already evaluated
  operand with `hot_replace_node(..., preserve_value_order=true)`. An earlier
  local read must retain its source order across an intervening overwrite. The
  regression in [`hot_mutate_test.mbt`](../../../src/ir/hot_mutate_test.mbt)
  checks the dead definition's uses, opcode, local index, order, validation,
  and scalar execution (old value 7, later local value 99).

- **Single owned body:** a pass may use raw `@lib.Module` for module-level facts, but function-body optimizer mutation should converge on `HotFunc`, not on a second owned function IR.
- **Public mutation only:** direct writes to HOT storage are architecture debt unless they are inside the owning IR module. Shared mutation helpers exist so revisioning, tombstones, labels, and region membership stay consistent.
- **Analysis invalidation by revision:** never carry `BlockId`, dominance facts, liveness bitsets, effect masks, SSA value ids, or phi ids across a revision-changing mutation.
- **Overlay honesty:** local SSA is an overlay and destruction/writeback step; it must not become persistent HOT phi nodes. It is also a normal revision-keyed `HotAnalysisCache` participant requested through `HotAnalysis::ssa()` / `pass_require_ssa(...)`, so old SSA ids must not survive mutation. See [`local-ssa-policy.md`](./local-ssa-policy.md).
- **CFG honesty:** CFG blocks and edges are overlay ids and edge facts, not owned body nodes. See [`cfg-contract.md`](./cfg-contract.md).
- **Module-level passes stay explicit:** a module pass such as function reordering, global cleanup, or type-section rewriting may need module-level logic outside one `HotFunc`, but any lifted function-body rewrite still has to respect HOT verification and module validation boundaries.

## Concrete Example: Tiny Peephole Pass

For a simple peephole that deletes a pure redundant wrapper inside one function:

1. Parse and validate the input module through the normal command/pass fixture path.
2. Lift the target function into `HotFunc`.
3. Verify the HOT body.
4. Request only the overlays needed by the proof, such as effects if the rewrite depends on non-trapping/pure behavior.
5. Replace or splice the node through pass/HOT mutation helpers, causing the revision to change.
6. Let any stale overlays rebuild; do not reuse old `BlockId` or effect-summary objects.
7. Verify, lower, validate, and then run pass-specific oracle/signoff if the pass has a Binaryen equivalent.

That example is deliberately ordinary: most IR2 bugs come from skipping one boring step, such as reusing stale liveness after a mutation or preserving a side-table payload without checking the exact lowered opcode.

## September 2026 Stability Verification

On master `3dc72fd2d`, all three regressions first failed: repeated-edge phi
alignment aborted, the batched loop's input arity became 1, and the forwarded
read's order became the tee's later order. After the fixes, the two touched
test files pass 43/43. Focused wasm-gc IR, SSA, DCE, TupleOptimization and
CoalesceLocals tests pass 644/644. `moon info`, `moon fmt`, native release
builds, README/API sync, and 65 comparison-harness tests pass; no `.mbti`
changes occur.

The complete wasm-gc suite is 11,214/11,270. A detached build of untouched
master is 11,211/11,267, with the same 56 failures and diagnostics (ignoring
generated function IDs). Plain `moon test` hits the same generated-validator
engine local-count limit on both revisions. `bun validate full --profile ci
--target wasm-gc` therefore stops before its fuzz stage. These results do not
renew the earlier all-green upgrade checkpoint; active failures remain in
[`agent-todo.md`](../../../agent-todo.md).

Eight quick GenValid sweeps use verified Binaryen 132, explicit native CLI and
generator binaries, eight workers, and `--debug-serial-passes`. Each pass runs
100 aggregate-profile cases at `0x5eed` and 100 regular cases at `0x5555`.
Aggregate normalized matches/mismatches are SSA-no-merge 39/61, DCE 80/20,
TupleOptimization 0/100, and CoalesceLocals 37/63; each regular lane is 0/100.
All 800 validate, with zero generator or command failures. Re-running both
revisions on every input produces byte-identical outputs (800/800), establishing
that all 644 Binaryen output differences predate these repairs. They are not
blanket semantic-parity evidence: inspected no-op/dropped-constant cleanup
examples are smaller, but unreviewed families remain parity gaps. The separate
existing fuzz smoke lane passes all 14 suites, totaling 3,773 attempts.

Dewdrop's saved 39-case failure subset passes 1/39 after repair. The complete
1,000-case replay improves from baseline 958/1,000 to 959/1,000, repairing
`discovery/O4z/collections/binary-heap-runtime`; no previously passing case
regresses. Twelve other outputs change but still pass Node, Wago and external
validation. All 41 remaining failures reproduce on baseline: 18 runtime
mismatches, 14 optimizer command failures, seven timeouts and two validation
failures. Local evidence is retained under `.tmp/stability-dewdrop-*`,
`.tmp/stability-fuzz-*`, and `.tmp/stability-baseline-compare/report.json`.

### September 12 correctness follow-up

The clean starting master is `93f11e3b7c20c4151975db7bb9ad689c79e8d102`.
Its fresh native replay is 962/1,000; the full wasm-gc suite is 11,216/11,272
with the same 56 failing names. These replace no historical pre-rebase results.
Exact commands, input hashes, engine commands and failure logs are retained in
`.tmp/correctness-repair-20260911/` (baseline replay and baseline suite).

String-builder's first invalid prefix ends at `coalesce-locals-cfg`. The producer
is shared HOT lowering: its dead-tee read count stopped after nonfallthrough
control, although lowering retained later local reads. Deleting their initialization
made non-null locals invalid, even when those reads could never execute. Count
all emitted syntactic reads before pruning tees. The reduced HOT roundtrip and
both coalescing dispatcher variants fail before this change; 245 neighboring
IR/SimplifyLocals/coalescing tests and four independent Node execution checks
pass after the paired scope repairs. See
[`hot_lift_test.mbt`](../../../src/ir/hot_lift_test.mbt),
[`coalesce_locals_test.mbt`](../../../src/passes/coalesce_locals_test.mbt), and
[`lower-reference-scopes.test.ts`](../../../tests/optimizer/regressions/lower-reference-scopes.test.ts).
External validation of the saved string-builder output now passes. Its runtime
failure is also repaired by the heap-identity correction below; final full
verification remains open.

Derive-hash first becomes invalid at its eleventh explicit pass,
`simplify-locals-nostructure`: sinking a reference assignment into an inner
result block moves its initialization out of the lexical scope of another read.
Both SimplifyLocals cleanup exits now use the existing reference-scope repair:
nullable storage plus non-null refinements at the original read/tee positions.
The reduced test is red before the repair and green afterward; the saved
Dewdrop case now validates and preserves `derive:hash` in Node and Wago.
The execution regression covers both the full and no-structure dispatcher
variants in [`simplify-reference-scopes.test.ts`](../../../tests/optimizer/regressions/simplify-reference-scopes.test.ts).
No branch arities, defaults, or validation bypasses are introduced.

The numeric-math no-shrink replay first changes behavior at pass 19,
`redundant-set-elimination`. Float display keys conflate negative zero with
the default positive zero and conflate distinct NaN payloads. Raw and HOT value
keys now use IEEE bits, including default-value keys. The bit-pattern regression
fails before repair; all 43 RSE tests pass afterward, and the independent native
Node regression returns 1 instead of 0. The saved math case returns
`numeric:math` again. These are focused development results, not final replay
signoff. Tests: [`rse_test.mbt`](../../../src/passes/rse_test.mbt) and
[`rse-float-bits.test.ts`](../../../tests/optimizer/regressions/rse-float-bits.test.ts).

OptimizeInstructions incorrectly classified structurally equivalent canonical
heap types as disjoint when their type indices differed, replacing successful
casts by unreachable. The first bad nominal-argument nested cleanup is its third
OptimizeInstructions invocation inside optimizing inlining. HOT module context
now retains recursion groups, and OI uses the validator's existing heap matcher
with those groups intact. Flattened structural equality would be wrong for a
member of a larger recursion group. The reviewed public API change adds readonly
`HotModuleContext.type_groups`. The duplicate-array/struct cast regression fails
before repair and executes to 7 afterward; a distinct-group ref.test remains 0.
All 1,466 neighboring context/OI/RSE tests pass. A debug native replay subset
passes 14/19, leaving array-methods, defer and three trap-message differences;
this does not establish release performance or final full verification. See
[`duplicate-type-cast.test.ts`](../../../tests/optimizer/regressions/duplicate-type-cast.test.ts)
and [`optimize_instructions_test.mbt`](../../../src/passes/optimize_instructions_test.mbt).

The array-methods nested SSA pass also exposes an independent raw dispatcher
fault: the planned rewrite reused the then arm's mutable alias array when
entering the else arm. A reduced integer fixture changes 0 to 1 before repair.
Each arm now starts from a copy of incoming aliases, and the join retains the
common alias or the sole continuing arm. Multisource traffic stays canonical
under the existing LocalGraph plan. The reduced dispatcher and independent Node
regression pass; execution neighbors cover both arms, no else, nesting and early
return. The SSA/IR neighborhood is 489/539, with exactly the same 50 baseline
SSA failures. The complete array-methods and defer cases still trap later in
optimizing inlining; their owners remain open. Tests:
[`ssa-else-read.test.ts`](../../../tests/optimizer/regressions/ssa-else-read.test.ts).

Array-methods subsequently fails at MergeLocals (nested dump64). A block result
is carried across later operations; its write invalidates the candidate copy.
MergeLocals now builds both proof graphs with operand-expanded CFGs. This exposed
another shared analysis fault: LocalGraph recursively revisited operands already
listed as CFG nodes, letting a read see its own later write. `HotCfg` now records
readonly `operands_expanded`; forward/full-flow construction and local path
sequences respect the explicit execution list. The reviewed API diff adds that
field. A direct graph regression is red before repair; all48 graph/MergeLocals
tests pass afterward, including the existing across-if optimization. The reduced
Node test again observes1, not7. With the paired Flatten repair,825 IR/direct-pass
neighbors pass and the saved runtime subset is16/19. The three remaining raw
failures compare trap diagnostics; complete final release verification is pending.
See [`local_graph_test.mbt`](../../../src/ir/local_graph_test.mbt) and
[`merge-result-block-write.test.ts`](../../../tests/optimizer/regressions/merge-result-block-write.test.ts).

Defer's first bad nested pass is Flatten (dump5): it placed an extracted carried
result block after a later call. The original effects 4 then 5 became 5 then 4. Scalar
control routing now uses the same existing source-position prelude insertion as
ordinary scalar spills, retaining prerequisite operations with the extracted
value. The reduced Node regression fails 45 versus 54 before repair and passes 45
afterward; the returned 9 is checked too. The dispatcher asserts block-before-call
ordering, and the825 neighbor gate passes. Saved array-methods and defer now match
in both Node and Wago. See
[`flatten-carried-block-order.test.ts`](../../../tests/optimizer/regressions/flatten-carried-block-order.test.ts).

The remaining three runtime subset failures are diagnostic-contract differences:
nullable-ref-as-non-null (two profiles) calls a pure null producer then immediately
traps before an empty callee; fixed-array-get-oob creates a length-1 array then
reads index 1. Both optimized mains contain only unreachable. The originals have
no imports or exported state and no observable effects before the guaranteed
trap. The [core result grammar](https://webassembly.github.io/spec/core/exec/runtime.html#syntax-result)
has one trap form. This agent classification is grounded in these specific
programs; the unchanged harness continues to report their differing diagnostic
labels. No blanket trap normalization or engine-defect claim is made.

Eight optimizer aborts came from OI's stored-scalar equality/default helper asking
root-only SSA for reads inside operand-nested control. A tiny value-block select
reproduces the assertion. The helper now resolves single reaching definitions
through operand-expanded LocalGraph, shared between the two compared operands;
ambiguous definitions establish no identity. SSA assertions stay unchanged and
no default SSA values are fabricated. All 1,417 OI tests and the independent Node
regression pass. With the paired Heap2Local repair, all 12 saved abort cases now
optimize; nine pass Node/Wago and circular-buffer/deque/queue expose runtime
mismatches. Those three remain open and have no passing final signoff. See
[`oi-nested-select.test.ts`](../../../tests/optimizer/regressions/oi-nested-select.test.ts).

The other four aborts (nested-common-subexpression and nested structs, two
profiles each) came from Heap2Local cloning a field value into a read while
leaving the original wrapper alive. A later fold deleted the wrapper's child,
triggering the attached-child assertion. Direct struct and array folds now queue
the copied source wrapper after its old allocation owner for strict deletion.
The deletion assertions are unchanged. Both reduced nested-aggregate Node tests
abort before repair and return 21 afterward; all 32 Heap2Local tests pass. All
four saved cases now pass Node and Wago. See
[`heap-nested-struct.test.ts`](../../../tests/optimizer/regressions/heap-nested-struct.test.ts).

The three newly executable collection failures first diverge at expanded O4z
pass 31, SimplifyLocals. Promoting a branch-tail local assignment into a control
result moved a carried read past an intervening write. Result promotion now
retains an existing earlier root or inserts the result before the next original
effect; one-armed branch reconstruction uses the updated body rather than a
stale tail index. The reduced global-read execution changes from 7 to 9 before
repair and remains 7 afterward; one-armed and local-read neighbors also pass.
The focused SimplifyLocals suite passes 253/254 with its single unchanged
baseline constant-copy failure. All three saved collections now pass prefix 31
but fail at the following Vacuum pass, which remains open. See
[`simplify-carried-tail.test.ts`](../../../tests/optimizer/regressions/simplify-carried-tail.test.ts).

The following Vacuum failure was a shared lift/lower roundtrip defect, reduced
to a mutable struct read left on the stack across a later field write and a nop.
Lifting appended the region result after its later void roots, leaving lowering
without a later consumer to recover the carried lifetime. Reachable, unanchored
region results now retain their position before later source effects. Values
already consumed by roots (including br_if payloads) and unreachable stack debris
retain their existing representation. Direct IR and dispatcher regressions fail
before repair; three Node checks cover the struct read, composed passes and a
tuple result. Neighbor tests pass 895/896 with only the unchanged SimplifyLocals
baseline failure. All three collections now pass Node and pinned Wago. This is
a debug subset checkpoint, not final replay signoff. See
[`vacuum-carried-result.test.ts`](../../../tests/optimizer/regressions/vacuum-carried-result.test.ts).

The four large WASI timeout profiles finish Flatten itself in roughly 0.13–0.27s
on the starting release binary, then spend their time in lowering's source-order
local conflict checks. Each candidate pair allocated whole-function visited and
local arrays. Reusing sparse local-access summaries and a visitation stamp
preserves the same write-order bounds and first-access rule while removing
that allocation multiplier. A dedicated 2,048-element v128 array regression
fails its five-second subprocess bound on both starting and pre-fix release
binaries, then completes in 1.35s including validation and Node execution on the
debug build. All 788 IR/Flatten/CoalesceLocals neighboring tests pass. Full saved
timeout replay is pending the paired numeric investigation and release rebuild.
See [`flatten-wide-array.test.ts`](../../../tests/optimizer/perf/flatten-wide-array.test.ts).

The numeric timeouts came from SimplifyLocals exact cleanup repeating forever
when its fixed-point comparison encountered NaN: IEEE equality is non-reflexive.
The comparison now recursively compares literal float bits through structured
control, retaining NaN payload and signed-zero distinctions. Reduced f32/f64
branch regressions terminate and preserve Node execution; all 359 dispatcher
whitebox tests pass, and the wider neighborhood passes 612/613 with the unchanged
baseline constant-copy failure. Numeric O4z float-specials and math now pass
Node/Wago. Direct math inlining now terminates but returns FAIL, a newly exposed
runtime defect requiring isolation. WASI boundary direct Flatten passes; the
multiwindow direct output hits Wago's explicit native-frame headroom limit
(300184 > 262064 bytes), and both WASI O4z debug runs still time out. These are
open checkpoints pending release profiling and final replay. See
[`simplify-nan-termination.test.ts`](../../../tests/optimizer/regressions/simplify-nan-termination.test.ts).

The newly executable direct math mismatch first appears in nested cleanup 80,
PrecomputePropagation. Both its raw branch/loop joins and HOT reaching-definition
constant join used numeric equality, conflating positive and negative zero.
All three joins now require identical literal bits. The reduced f32 branch
returns negative-zero bits before optimization but zero bits before repair;
f32/f64 branch and loop execution checks now pass. All 62 neighboring tests pass,
and direct math inlining again prints numeric:math in Node and Wago. See
[`precompute-signed-zero-join.test.ts`](../../../tests/optimizer/regressions/precompute-signed-zero-join.test.ts).

The remaining WASI cost and frame overflow were caused by Flatten classifying
v128.const as a rich SIMD operand, although scalar constants were already simple.
Recognize that exact nullary opcode as simple. A reduced vector-store dispatcher
fixture fails with an unnecessary local before repair and needs none afterward.
The multiwindow direct output drops from 6,257 to four v128 locals and from
150,907 to 113,617 bytes; it now executes in pinned Wago. Verified Binaryen 132
Flatten has nine v128 locals (its Wago comparison is blocked by unsupported exact
reference types). All seven saved timeout cases now finish and pass Node/Wago
in the debug replay. All 389 neighboring tests pass. Dedicated wide-array tests
retain the five-second limit and check contents as well as length: literal
operands finish in 0.17s and computed operands in 2.09s, including Node and
validation. Final release replay remains pending. See
[`flatten_dew_simd_operand_test.mbt`](../../../src/passes/flatten_dew_simd_operand_test.mbt)
and [`flatten-wide-array.test.ts`](../../../tests/optimizer/perf/flatten-wide-array.test.ts).

The post-replay full suite reproduces exactly the original 56 failing names
(11,234/11,290 pass, no new failures). The four CodePushing failures are one
implementation gap: safe motion past a disjoint global write retained the read's
old source identity, so lowering hoisted it back before the branch. A moved
GlobalGet now receives a fresh evaluation node after the caller's existing motion
proofs. The reduced opcode-order regression fails before repair; all 166
CodePushing tests and a Node test covering both branch paths pass afterward.
These were optimization-contract failures, not observed runtime-result defects.
See [`code-pushing-global-motion.test.ts`](../../../tests/optimizer/regressions/code-pushing-global-motion.test.ts).

The shared default-backend compile failure is resource growth in GenValid exact
opcode counting: 403 record-copy match arms generate 162,413 locals in one
function. Partition the unchanged arms into 64-arm private helpers; the largest
function now has 25,795 locals. No counter, seed, engine limit or validation
setting changes. The reduced counter regression fails to compile before repair;
afterward all 168 GenValid whitebox and 132 binary tests pass on the default
backend. See [`gen_valid.mbt`](../../../src/validate/gen_valid.mbt) and
[`gen_valid_wbtest.mbt`](../../../src/validate/gen_valid_wbtest.mbt).

The baseline SimplifyLocals constant-copy failure is an exact-cleanup gap: an
empty void block separates a dead local.set/get pair after the block read is
removed. Permit only recursively inert void blocks and nops as separators,
retaining their roots and the producer evaluation position. A direct reduced
regression fails before repair; branching blocks remain a boundary. All 493
dispatcher/SimplifyLocals neighbors pass. See
[`simplify-empty-block.test.ts`](../../../tests/optimizer/regressions/simplify-empty-block.test.ts).

The remaining DAE assertion expected one parameter after a tail call supplied
constants 31 and 41. Existing tail-call constant specialization correctly leaves
a zero-parameter callee returning 41. Update that stale test to require both the
zero-parameter signature and the exact constant body; retain the pure, effectful
and live-parameter neighboring assertions. All 434 DAE whitebox tests pass and
Node returns 41 before and after optimization. No implementation change. See
[`dae-tail-constant.test.ts`](../../../tests/optimizer/regressions/dae-tail-constant.test.ts).

The 50 baseline SSA assertions require obsolete fresh-local/copy layouts after
liveness correctly keeps merge participants canonical. Replace those failing
expectations with exact encoded branch/local/reference fixtures; preserve all
passing cases. All 497 SSA tests and 138 bounded Node probes across the 50
families pass. Three unconditional-loop originals use finite derived execution
fixtures; timeout pairs are not counted as runtime passes. Ten measured Binaryen
132 size differences remain output-shape parity gaps, not confirmed execution
defects. See [SSA expectation resolution](../binaryen/passes/ssa-nomerge/merge-shapes-and-canonical-slots.md#september-12-baseline-expectation-resolution).


### Repair commits and regression coverage

All implementation rows below have a failing reduced regression recorded before
the change and a passing regression afterward. The DAE and canonical-merge rows correct test
contracts with inspected output and execution evidence; they change no optimizer
implementation. Development checkpoint counts in the preceding paragraphs are
historical; the subsequent verification checkpoint below records the remaining work.

| Confirmed cause | Commit | Regression / check |
| --- | --- | --- |
| Reference initialization removed before retained dead-tail reads | `630b219bc` | [Non-null initialization and external validation](../../../tests/optimizer/regressions/lower-reference-scopes.test.ts) |
| Sunk reference initialization lost lexical scope | `232cf433e` | [Nullable storage and non-null read refinements](../../../tests/optimizer/regressions/simplify-reference-scopes.test.ts) |
| RSE conflated float bits | `367d8d542` | [Signed zero and NaN payload keys](../../../tests/optimizer/regressions/rse-float-bits.test.ts) |
| OI mistook canonical equivalent heap types for disjoint types | `be2cd4fbc` | [Successful casts and distinct recursive groups](../../../tests/optimizer/regressions/duplicate-type-cast.test.ts) |
| SSA reused then-arm aliases in the else arm | `ae4e84593` | [Independent arm aliases and merge reads](../../../tests/optimizer/regressions/ssa-else-read.test.ts) |
| MergeLocals missed carried writes; LocalGraph revisited operands | `3b742bfe5` | [Expanded flow and original result 1](../../../tests/optimizer/regressions/merge-result-block-write.test.ts) |
| Flatten reordered a carried result block | `b02b17b85` | [Effect order 45 and returned value](../../../tests/optimizer/regressions/flatten-carried-block-order.test.ts) |
| OI asked root-only SSA about nested local reads | `848ef91a1` | [Reaching-definition lookup without assertion failure](../../../tests/optimizer/regressions/oi-nested-select.test.ts) |
| Heap2Local left copied field wrappers attached | `3705a1dbc` | [Strict deletion and struct/array result 21](../../../tests/optimizer/regressions/heap-nested-struct.test.ts) |
| SimplifyLocals moved carried reads during result promotion | `b88e01819` | [Two-arm, one-arm and local-read execution](../../../tests/optimizer/regressions/simplify-carried-tail.test.ts) |
| Lifting appended carried results after later effects | `8d3a74a82` | [Roundtrip and composed-pass result 7](../../../tests/optimizer/regressions/vacuum-carried-result.test.ts) |
| Lowering repeatedly allocated whole-function conflict arrays | `ff1c18b92` | [Sparse local access cache; 2,048-element bounded perf lane](../../../tests/optimizer/perf/flatten-wide-array.test.ts) |
| NaN equality prevented cleanup convergence | `75e687807` | [Bit-exact fixed point and f32/f64 termination](../../../tests/optimizer/regressions/simplify-nan-termination.test.ts) |
| PrecomputePropagation joins conflated signed zeros | `9c0d0eaed` | [Raw/HOT branch and loop bit preservation](../../../tests/optimizer/regressions/precompute-signed-zero-join.test.ts) |
| Flatten spilled simple vector literals | `f9b57a52e` | [No unnecessary vector locals; bounded literal/computed arrays](../../../tests/optimizer/regressions/flatten-vector-literals.test.ts) |
| Lowering undid proven CodePushing global-read motion | `29f42a303` | [New source identity, opcode order and both branch paths](../../../tests/optimizer/regressions/code-pushing-global-motion.test.ts) |
| Exact-opcode record copies exceeded default engine local count | `78f637e6d` | [Unchanged counter mappings; 162,413 to 25,795 generated locals](../../../src/validate/gen_valid_wbtest.mbt) |
| SimplifyLocals missed dead pairs across inert blocks | `9e5fd5a90` | [Constant 32 and retained branching boundary](../../../tests/optimizer/regressions/simplify-empty-block.test.ts) |
| DAE test expected an unspecialized tail-call parameter | `275c556d7` | [Zero parameters, exact constant body and result 41](../../../tests/optimizer/regressions/dae-tail-constant.test.ts) |
| SSA tests required obsolete merge-copy layouts | `4ccd09078` | [Exact encodings and 138 original/optimized probes](../../../tests/optimizer/regressions/ssa-canonical-merges/execution.test.ts) |
| SSA lexical aliases lost enclosing-block exit writes | `fbd1936d8` | [Loop result 3, simple exit 7, and existing arm/merge neighbors](../../../tests/optimizer/regressions/ssa-enclosing-exit.test.ts) |


### Enclosing-exit SSA follow-up

Release checkpoint `4ccd09078` passed focused tests (1,358), harness tests (65),
wasm-gc full tests (11,293), default tests (11,296), execution/performance tests
(81 tests / 169 probes), and smoke fuzzing (3,773 attempts, seed 24301).
The 1,000-case replay passed 995 cases, retaining three exact trap-message
mismatches and exposing two new iter-combinator failures. This checkpoint is
not final verification of the follow-up repair.

The first bad pass is SSA-no-merge: speed prefix 5 and optimizing-inlining
nested prefix 4. The structured rewrite's lexical alias merge loses the write
on a branch exiting an enclosing block. The LocalGraph plan already identifies
that reaching write. Use its planned fresh local when the producer was actually
freshened; preserve canonical reads for writes kept canonical. This also keeps
the earlier else-arm fix's behavior without reconstructing control flow from
lexical alias state. The reduced loop returns 3 originally and 0 before repair;
its unreachable suffix triggers the same debris-collapse replanning route.
See [execution regression](../../../tests/optimizer/regressions/ssa-enclosing-exit.test.ts)
and the direct/command tests in `ssa_nomerge_test.mbt` and `cmd.mbt`.
The repair is committed as `fbd1936d8`. The verification below was rerun after
this final code/test change; it supersedes every development checkpoint above.

### Final-source verification: fbd1936d8

Starting commit: `93f11e3b7c20c4151975db7bb9ad689c79e8d102`.
Tested code/test commit: `fbd1936d8a7c4815dfd42cdffe80bab35296df90` on master.
Subsequent verification documentation changes do not change the tested source,
tests, scripts, or binaries. No rebase occurred.

| Final check | Result |
| --- | --- |
| `moon info`, `moon fmt`, README API sync | Pass; no new API diff in the final SSA fix |
| Focused IR/direct-pass, all SSA and command tests | 2,170/2,170 pass |
| Fuzz-harness tests | 65/65 pass |
| Full `moon test --target wasm-gc --jobs 16` | 11,295/11,295 pass |
| Plain `moon test` | 11,298/11,298 pass; 532s, no local-count compile failure |
| Fresh native release CLI and fuzz build | Pass |
| Native original/optimized execution and bounded performance regressions | 83 tests / 171 probes pass; wide literal/computed arrays 113ms/715ms with unchanged 5s optimizer limit |
| Smoke, all 14 suites, seed 24301 | 3,773 attempts pass |
| Eight saved 100-case GenValid lanes, verified Binaryen 132 | 800 validate; zero generator, command, validation or property failures; 156 normalized matches / 644 output mismatches |
| Full saved Dewdrop replay, pinned Node/Wago and 30s limits | 997/1,000 pass in 39.39s; three diagnostic-contract failures below |

The generated comparison lanes have runtime execution disabled; their validating
outputs and mismatch counts are not semantic correctness evidence. Execution
claims come from the independent original/optimized regression probes and
Dewdrop replay. No byte-parity claim is made for the 644 output mismatches.

The fresh starting baseline has 38 failures: 16 result/trap mismatches, one Node
illegal-cast error, 12 aborts, seven timeouts and two validation failures. These
counts supersede the earlier historical inventory for this starting commit.
All 1,000 optimized modules pass external validation. All 962 initially passing
cases still pass. Thirteen result/trap cases, the Node error, all 12 aborts,
all seven timeouts and both validation cases now pass.
The two iter-combinator regressions exposed at the intermediate release
checkpoint also pass. All input hashes match the baseline replay.

The 56 full-suite failures are resolved: four CodePushing and one SimplifyLocals
implementation gaps; one stale DAE specialization assertion; 50 obsolete SSA
merge-copy expectations, replaced by exact encodings and execution probes.
The separate shared local-count failure came from generated record copies in
exact-opcode counting, repaired without changing seeds, counts or engine limits.

Remaining raw replay failures, confirmed in both Node and Wago with the same
settings for original and optimized execution:

| Fixture | Profile | Original diagnostic → optimized diagnostic |
| --- | --- | --- |
| `collections/fixed-array-get-oob-trap` | `O4z` | `array-out-of-bounds` → `unreachable` |
| `wasmgc/nullable-ref-as-non-null-trap` | `O4z` | `null-reference` → `unreachable` |
| `wasmgc/nullable-ref-as-non-null-trap` | `direct-inlining-optimizing` | `null-reference` → `unreachable` |

These are the inspected guaranteed-trap programs described above: no imports,
exported state, or observable effects precede their traps. This is an agent
classification of a diagnostic-contract difference, not an engine-defect claim.
The unchanged harness still reports all three as failures; no blanket trap
normalization was added. Ten measured SSA size gaps remain separate parity
follow-ups. No requested verification command is blocked, and no confirmed
implementation defect remains unresolved in the reproduced corpus. The raw
replay is not an all-green gate.

Exact commands and results are local in `.tmp/correctness-repair-20260911/`:
`verified-commands.json`, `verified-runtime-commands.json`,
`verified-generated-lanes.json`, `verified-gates.json`,
`verified-runtime-gates.json`, `verified-replay/report.json`,
`verified-replay-comparison.json`, `verified-trap-contracts.json`,
`verified-tools.json`, and `verification.md`. Original inputs remain in Dewdrop's
`.tmp/starshine-deep-logs/{discovery,ordered-screen,ordered-wave2,ordered-wave3,ordered-wave4}/`
reports and snapshot directories. The replay checks each saved input hash.

Tools remain Node v26.8.2, Bun 1.4.2, Moon 0.1.20260827 (d0aaa07), wasm-tools
1.251.0, and Binaryen 132. Release CLI SHA-256:
`4370cc62bbdfb5261cd279723ebe176658aedf204214078f2a841a14046387fa`.
Release fuzz SHA-256:
`6c50d1bfc1588dad4e2354470f0820069bfc374aa4fa2aae10cdc4055fd9543b`.
Oracle, pinned Wago and replay-runner hashes in `verified-tools.json` match the
baseline tool setup. Its source-tree hashes identify the final tested revision.


### Remaining diagnostic reductions

A continuation from clean master `12862e4ec` locates the first changed diagnostic
at top-level O4z prefix 48, `inlining-optimizing`, for both saved fixtures.
The nullable-reference direct profile changes at its sole optimizing-inlining
pass. Two single-function reductions isolate the nested producers:
`ref.null; ref.as_non_null` folds to unreachable in OptimizeInstructions;
`array.new_fixed` of length one followed by `array.get` at index one folds to
unreachable in Heap2Local. Ordinary `array.new` does not trigger this reduced
Heap2Local fold.

Verified Binaryen 132 optimizing inlining produces the same changed diagnostics
on both valid pre-prefix inputs. Existing tests explicitly require these folds:
[known-null refinement](../../../src/passes/optimize_instructions_test.mbt) and
[fixed-array out-of-bounds access](../../../src/passes/heap2local_test.mbt).
Preserving exact engine messages would change this tested optimization contract;
it is not a repair of a newly identified core execution defect. The diagnostic
contract decision remains open, with no optimizer or harness changes made.
Local reduced inputs, exact commands and observations are retained in
`.tmp/trap-diagnostics-20260912/{prefix-report.json,direct-and-oracle.json,reduced-results.json,array-fixed-results.json}`.
The final-source test results above remain applicable because this investigation
changes only documentation.

### Binaryen trap expectation correction

The user selected Binaryen behavior after the diagnostic investigation above.
Dewdrop commit `5eccd72f` corrects the experiment runner's optimized-execution
comparison, with two explicit entries in
`tools/starshine-experiments/optimized-runtime-expectations.json`. Strict source
snapshot expectations and baseline checks remain unchanged. An optimized result
must match the original result or the complete listed alternative, including
stdout. The runner retains the actual diagnostic and records
`matched_optimized_expectation`; unrelated fixtures, changed effects, other traps,
engine errors and timeouts still fail. No optimizer code or global trap
normalization changed.

Failing-first tests reproduce the three incorrect comparison assertions; all
10 harness tests pass after correction. The saved three-case replay passes in
Node and Wago, and the normal runner also passes both fixtures under both O4z
and direct optimizing inlining. The corrected starting baseline replay is
965/1,000, preserving all 35 implementation failures. The corrected current
replay passes 1,000/1,000 with no new failures and all input hashes preserved.
All 1,000 optimized output hashes are identical to the preceding strict-message
replay. Exactly six observations (three cases in Node and Wago) match an explicit
optimized expectation. Historical strict-message reports remain unchanged.

All requested gates ran again after the harness correction: focused tests
2,170/2,170; Starshine harness 65/65; Dewdrop harness 10/10; full wasm-gc
11,295/11,295; default 11,298/11,298; original/optimized execution and bounded
performance 83 tests / 171 probes; smoke 3,773 attempts at seed 24301. Info,
formatting, README API sync and the release build check pass. All eight saved
100-case GenValid lanes validate, with zero generator, command, validation or
property failures and the unchanged 156 normalized matches / 644 output
mismatches. Runtime remains off in those generated lanes; they are not semantic
proof. The ten SSA size gaps also remain separate parity work.

The Starshine source/test/script trees and release binary hashes still match
`fbd1936d8` and the preceding verification. The changed harness is Dewdrop
`5eccd72f0d65b5836e95abbdf793c712e4277979`. No rebase occurred. The paired replay
loads the corrected comparison but retains the archived snapshot parser, host
adapter, inputs, four workers and 30-second limits. Baseline and current use
the same runner and expectation-policy hashes. Replays overlapped the ordinary
suite checks; their wall times are not used as performance comparisons.

Exact evidence is in `.tmp/trap-diagnostics-20260912/`: `final-gates.json`,
`final-runtime-gates.json`, `final-generated-lanes.json`, `final-tools.json`,
`baseline-replay/report.json`, `current-replay/report.json`,
`replay-comparison.json`, and `binaryen-direct-proofs.json`. All requested checks
are complete; none is blocked and no correctness failure remains in this corpus.
The two optimized expectations replace the obsolete exact-diagnostic contract;
optimizer behavior and strict baseline expectations remain unchanged.

## Practical Rules

- Start architecture or invariant work from this page, then follow the focused pages for CFG, local SSA, test placement, and pass porting.
- Add or update tests before changing IR semantics. Use [`test-matrix.md`](./test-matrix.md) to choose the owner file.
- Add descriptor requirements and invalidations when a pass begins depending on a new overlay.
- Keep public docs clear about what is current architecture versus archived March planning context.
- If an old research note has been absorbed, cite it as provenance, not as the freshest source of truth.

## Sources

- Current test matrix: [`./test-matrix.md`](./test-matrix.md)
- Package-local ownership summary: [`../../../src/ir/README.md`](../../../src/ir/README.md)
- Cache/pass-use evidence: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt), [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt), [`../../../src/ir/architecture_test.mbt`](../../../src/ir/architecture_test.mbt), and [`../../../src/ir/analysis_cache_test.mbt`](../../../src/ir/analysis_cache_test.mbt)
- Local SSA policy and lineage: [`./local-ssa-policy.md`](./local-ssa-policy.md) and <https://doi.org/10.1145/115372.115320>
- Archived original architecture note: research note 0059
- Revision and descriptor layer: [`../../../src/ir/architecture.mbt`](../../../src/ir/architecture.mbt), [`../../../src/ir/architecture_test.mbt`](../../../src/ir/architecture_test.mbt)
- HOT storage: [`../../../src/ir/hot_core.mbt`](../../../src/ir/hot_core.mbt)
- Analysis cache: [`../../../src/ir/analysis_cache.mbt`](../../../src/ir/analysis_cache.mbt)
- Pass helper layer: [`../../../src/passes/pass_common.mbt`](../../../src/passes/pass_common.mbt)

## September 12 stack operands and label destinations

Starting master was `e53ec910e5ccc9d8f43342c2b598d29ff30d81ba`.
Three local correctness repairs preserve control destinations and actual operand
identity, without disabling validation or introducing general label remapping:

- **Try-table catch destinations** (`3967d7585`): the common branch-control scan
  recognizes every `Catch`, `CatchRef`, `CatchAll` and `CatchAllRef` target.
  Unreachable-debris cleanup retains enclosing blocks because removing them
  changes catch depths. Once reduction, duplicate-function elimination, global
  struct inference, DAE and pass-manager cleanup share the corrected guards.
  The [eight execution fixtures](../../../tests/optimizer/regressions/try-table-cleanup.test.ts)
  cover immediate/outer targets and unrelated nested blocks: all 24 checks fail
  on the baseline and pass afterward, including observable trap preservation.
- **Trusted fact operands** (`3fd6df3df`): comparison folding tracks a known
  operand-stack suffix with a distinct `ValueSite` for each result lane. Calls
  consume all parameters, plus the indirect index or reference; structured
  instructions consume declared inputs and conditions. Unknown effects clear
  producer knowledge, and nested regions do not infer their input producers.
  Zero/null checks and reference-call target queries use the same identities.
  [Execution coverage](../../../tests/optimizer/regressions/compiler-fact-stack.test.ts)
  includes direct/indirect/reference calls, multiple results, locals/globals,
  intervening consumers, control inputs/results, and equality plus signed and
  unsigned comparisons. Fifteen baseline wrong results become correct; all 54
  cases pass, including adjacent-constant Precompute neighbors (`84d2ab3bf`).
  Moon tests also distinguish two unequal lanes of one producer.
- **DAE2 function exits** (`3f3ecdc69`): one target observer handles branches,
  every branch-table entry/default, catch arms and continuation targets.
  `HOT_IMPLICIT_FUNCTION_LABEL` observes the function-result location; ordinary
  targets must be live before owner lookup. The [seven execution fixtures](../../../tests/optimizer/regressions/dae2-function-label.test.ts)
  yield 14 baseline aborts and 14 passing checks across both DAE2 variants.
  Direct tests additionally preserve a private function's result signature when
  its caller discards the result; command-dispatch tests cover void/results.

The implementation and direct regressions are in `src/passes/pass_common.mbt`,
`pass_common_test.mbt`, `apply_compiler_facts.mbt`,
`apply_compiler_facts_test.mbt`, `compiler_fact_query.mbt`,
`dead_argument_elimination2.mbt`, `dead_argument_elimination2_wbtest.mbt`, and
`src/cmd/cmd.mbt`. The same-pass/common-helper audit found no remaining
instruction-history operand guesses or unchecked DAE2 label-owner lookups.

### Verification of the combined source

Source tree `098b29fe292610f876159e9a66bcae62b5cb7fed` is unchanged between
implementation commit `3f3ecdc69` and test commit `84d2ab3bf`. Fresh release CLI
SHA-256 is `9d2681ff0c6e9ebaafcb24416dbc6b6b2c83910b96fe89764eede1eb83cfcb19`.
No rebase occurred. Tools: Moon `0.1.20260827`, Node `v26.8.2`, Bun `1.4.2`,
wasm-tools `1.251.0`, and verified Binaryen `132`.

| Check | Result |
| --- | --- |
| Focused IR/direct-pass tests | 2,253 passed |
| Full `moon test --target wasm-gc --jobs 16` | 11,300 passed |
| Full `moon test` | 11,303 passed |
| Fuzz-harness tests | 65 passed |
| Fresh release execution/performance tests | 175 passed, including all 92 new execution checks |
| Bounded smoke, all 14 suites, seed 24301 | 3,773 attempts passed |
| Eight saved 100-case GenValid lanes | 800 valid outputs; unchanged 156 normalized matches / 644 output-shape differences |
| Fresh 1,000-case Dewdrop replay | 1,000 passed on both starting and repaired binaries; identical inputs, runner/policy, and optimized output hashes |
| `moon info`, `moon fmt`, `moon check --target wasm-gc`, README/API sync, whitespace review | Passed; no public API changes |

Exact commands, stdout/stderr, tool hashes, failing-first evidence, and replay
records are under `.tmp/three-correctness-20260912/`: `final-commands.json`,
`final-gates.json`, `final-runtime-commands.json`, `final-runtime-gates.json`,
`final-tools.json`, `replay-comparison.json`, and the `*-before*.log` files.
Run execution tests with an explicit freshly built CLI:

```sh
moon build --target native --release src/cmd src/fuzz
STARSHINE_BIN=_build/native/release/build/cmd/cmd.exe bun test tests/optimizer/regressions tests/optimizer/perf
_build/native/release/build/fuzz/fuzz.exe --suite all --profile smoke --seed 24301
```

Dedicated GenValid comparisons use the documented aggregate profiles, seed
`0x5eed`, explicit native binaries and Binaryen 132, `--jobs auto`,
`--max-subprocesses 8`, and `--max-mismatch-artifacts 20`. Each baseline/current
pair uses identical generator, settings and limits. Starshine outputs are fresh;
the existing Binaryen/semantic caches remain enabled. DAE2 uses the documented
`drop-consts` and `unreachable-control-debris` normalizers.

| 10,000-case lane, on each revision | Normalized / cleanup-normalized / residual | Validation, generator, command or property failures |
| --- | --- | --- |
| `once-reduction-all`, open | 0 / 0 / 10,000 | 0 |
| `dae2`, open | 2,879 / 667 / 6,454 | 0 |
| `dae2`, closed | 0 / 100 / 9,900 | 0 |

All 30,000 per-case comparison classifications and byte sizes match the starting
baseline. The once-reduction residual is an inspected **Starshine win** (agent
judgment): redundant private once guards/calls disappear, canonical output is
120 versus Binaryen's 144 bytes, and all 100 bounded original/Starshine/Binaryen
observations agree. The DAE2 residuals remain baseline parity gaps; sampled
execution does not establish correctness for every unexecuted case or close
those shape gaps. The older 644 shape differences are likewise not confirmed
correctness bugs.

Separate 100-case three-way semantic lanes give 100/100 for once reduction and
95/100 for each DAE2 world on both revisions, with zero mismatches. The ten
blocked observations are continuation cases that default Node refuses because
stack switching is disabled. An additional paired run with
`--experimental-wasm-wasmfx` and a separate cache verifies 100/100 open and
99/100 closed on both revisions. **At that checkpoint one check remained blocked:** closed DAE2
case 15 exits with Node `SIGSEGV` while executing the original input. This is an
engine failure, not evidence of an optimizer mismatch. Across the three sampled
lanes, 299/300 cases have execution evidence with the stated engine settings;
semantic signoff at that checkpoint remained blocked for that one case. The
explicit alternate-engine verification below supersedes that blocker; the
original Node reports remain unchanged.

`dedicated-commands.json`, `dedicated-gates.json`, `dedicated-summary.json`,
`wasmfx-commands.json`, `wasmfx-gates.json`, and `wasmfx-summary.json` preserve the
exact commands and paired results. An exploratory full-size semantic run was
stopped after 3,480 repeated observations and superseded by the completed
10,000-case comparison plus bounded semantic lanes; it is not counted as a
completed gate (`partial-runtime-note.json`).

### Continuation semantic check with Binaryen 132

Starting from `1a4ba91f77a8eba87e7e4222892ccac653fe8fce`, the remaining
closed-world DAE2 sample (seed `0x5eed`, index 15, profile `dae2-continuations`)
now has execution evidence under `wasm-shell version 132 (version_132)`.
Its original binary SHA-256 is
`a5ca385f43e2248a675048ab34c32ce379366f27d29e3ea956adc101cbaa522a`.
All six saved binaries (original/Starshine/Binaryen on baseline/current)
validate with `wasm-tools validate --features all` and satisfy WAST
`assert_exception (invoke "run")`. The runner embeds the exact binary bytes;
it does not reparse or alter the input. Shell SHA-256:
`4a9affc9e6089c6a4ac5c5591198bf44a94b54492b332a68edb424eefe514108`.
Exact saved commands, hashes and results are in
`.tmp/semantic-check-repair-20260912/saved-replay.json`.

The [execution regression](../../../tests/optimizer/regressions/dae2-resume-throw.test.ts)
keeps the original binary plus readable WAT and regenerates both optimizer
outputs for plain/optimizing DAE2 in open/closed worlds. The explicit
[shell runner](../../../tests/optimizer/regressions/shell-execution.ts) verifies
version 132, validates every module, bounds subprocess execution and requires
an uncaught exception. Normal return and trap controls must fail the assertion.
Run with:

```sh
STARSHINE_BIN=_build/native/release/build/cmd/cmd.exe BINARYEN_BIN=.tmp/binaryen-version_132/bin/wasm-opt BINARYEN_SHELL=.tmp/binaryen-version_132/bin/wasm-shell bun test tests/optimizer/regressions/dae2-resume-throw.test.ts
```

The expected exception follows from throwing tag 0 into the fresh continuation:
there is no handler or observable imported state. Binaryen's
[version-132 interpreter](https://github.com/WebAssembly/binaryen/blob/version_132/src/wasm-interpreter.h)
handles this through `doResume` and `maybeThrowAfterResuming`; its
[shell assertion](https://github.com/WebAssembly/binaryen/blob/version_132/src/tools/wasm-shell.cpp)
distinguishes exceptions, traps and normal results.
This closes the bounded sample's missing execution check: all 300 sampled cases
have evidence under the explicitly recorded engines, with zero mismatches.
It does not repair Node, change the generic Node harness, provide independent
engine agreement for this particular sample, or establish a full 10,000-case
semantic campaign. No optimizer implementation changed in this follow-up.

Follow-up verification: all 11,303 default MoonBit tests, 181 execution/performance
tests (including these six), and 65 fuzz-harness tests pass. `moon info`,
`moon fmt`, README API sync and staged whitespace checks pass; no `.mbti`
changes. Logs are under `.tmp/semantic-check-repair-20260912/`. The earlier
large campaigns above remain evidence for the unchanged optimizer source;
this test-only follow-up did not rerun them.

### Separate frontend findings

These local optimizer repairs do not change two independently reproduced
frontend limitations: the WAT reader rejects numeric references to the implicit
function label, and the name-section decoder reads past its section when another
custom section follows. Direct instruction constructors and externally parsed
binaries isolate the DAE2 regressions; fact fixtures strip names before appending
metadata. The decoder reproducer is `name-followed-custom.wasm` with commands in
`separate-decoder-finding.json` in the evidence directory. Both findings remain
open outside this three-fix scope.


## September 12 five-agent optimizer audit

Five reporting-only agents reviewed every optimization-pass assignment, including
variants and supporting dispatch paths. They did not edit files or run Moon.
The review was targeted static analysis, not an exhaustive correctness proof.
Root-authored regressions precede every implementation repair. The initial campaign
has 74 bounded tests: 25 independently reported arithmetic-trap cases span all
five simplify-locals variants; the remainder cover effects, labels, types,
constant bits, and module identity. Initial red evidence is under
`.tmp/pass-audit-20260912/`; 14 tests passed and 60 failed before repairs (the
continuation fixture's initial traversal error is superseded by its focused rerun).

The active repair families are:

- Import name-pair identity and concrete function subtypes:
  `src/passes/duplicate_import_elimination_audit_test.mbt`.
- RSE operand/result tracking, descriptor and exception exits, and HOT value
  identities: `src/passes/rse_audit_test.mbt`.
- CSE producer tracking and effects: `src/passes/local_cse_audit_test.mbt`.
- Precompute loop/prologue rewrites, loop facts, and heap operand effects:
  `src/passes/precompute_audit_test.mbt` and `precompute_audit_wbtest.mbt`.
- Fixed-array operand effects: `src/passes/optimize_instructions_audit_test.mbt`.
- Once-call returns, labels, exception joins, and persistent guards:
  `src/passes/once_reduction_audit_test.mbt` and `once_reduction_audit_wbtest.mbt`.
- Globals cleanup scope, reference branches, and early returns:
  `src/passes/simplify_globals_optimizing_audit_test.mbt`.
- Heap scalarization null checks and packed fields:
  `src/passes/heap2local_audit_test.mbt`.
- Trapping arithmetic and string writes:
  `src/passes/simplify_locals_audit_test.mbt`.
- Global singleton origins and shared-type joins: global-struct-inference and
  global-refining audit tests; string subtype matching: optimize-casts audit test.
- Control owners, imported-tag aliasing, and continuation exits: code-pushing,
  coalesce-locals, merge-blocks, vacuum, remove-unused-brs, remove-unused-names,
  and inlining audit tests.
- Bit-exact floating constants: `src/passes/float_equality_audit_wbtest.mbt`.
- Trapping table initializers:
  `src/passes/remove_unused_module_elements_audit_test.mbt`.

Several public-pipeline guards prevent a lower-level finding from surfacing in
that pipeline. Green neighbor tests remain evidence of that narrower behavior;
a source finding alone is not classified as verified CLI wrong-code. In
particular, remove-unused-names currently skips stack-switching modules, while
its direct HOT label APIs still require consistent continuation bookkeeping.

**Status:** red phase recorded; implementation repairs, full tests, and final
Binaryen 132 GenValid checks remain pending. Fuzzing runs only after all repairs,
using a freshly built native CLI and documented aggregate profiles. No new
Binaryen parity or performance signoff is claimed by the static audit.


### Arithmetic trap preservation

Simplify-locals classifies integer division/remainder and trapping float-to-int
conversions from their exact opcode before deleting or moving a value. An unused
assignment becomes a drop when evaluating its right side can trap. The audit's
25 independent numeric cases cover all five variants; existing nontrapping
operations remain eligible for dead-value cleanup. See
`src/passes/simplify_locals_audit_test.mbt` and the exact effect classifier in
`src/passes/simplify_locals.mbt`.


### String-array effects

Simplify-locals records string-array encoding as a write and string construction
from arrays as a read, with their possible traps. An unused encoder result does
not make its target-array writes removable, and motion must respect conflicting
array effects. Other string operations conservatively retain possible traps.
The valid IR encoding regression is in `simplify_locals_audit_test.mbt`.


### CSE operand producer boundaries

Raw local-CSE distinguishes known resultless instructions from producers whose
result type/count it cannot model. Unknown producers clear the tracked operand
suffix and reuse window; ifs retain only the existing nested-scan window before
its normal invalidation. A global result must not expose older constants as its
operands. The audit's two-result arithmetic fixture retains `(3, 7)` instead of
reusing the unrelated value `13`. See `local_cse_audit_test.mbt`.


The public HOT local-CSE path visits operands in evaluation order, applies
barriers at each visited node, and only reuses trees with admissible effects.
Local writes and string operations are not treated as reusable expression trees.
A dropped call still clears the window when its call node is visited. The direct
HOT audit retains both effectful calls; module dispatch retains its separate raw
implementation.


Raw CSE also includes tee destinations in expression-local dependencies. A
repeated expression containing a tee cannot be replaced after another write to
that destination, including the repeated tee itself. The bounded arithmetic
tee fixture now preserves the final local value `1` instead of leaving `2`.

### Floating constant identity

Constant substitution and subtree identity compare IEEE bits, preserving signed zero and NaN payloads. Numeric equality is insufficient for DAE materialization, similar-function parameter specialization, code folding, and redundant-branch value matching. Shared private helpers in `src/passes/pass_common.mbt` provide bit equality, including materialized reference-constant blocks. The signed-zero regressions are in `src/passes/float_equality_audit_wbtest.mbt`.

### String cast subtype consistency

`optimize_casts.mbt` recognizes string as an extern subtype, matching `src/validate/match.mbt`. A non-null string `ref.test extern` must not fold to false; `optimize_casts_audit_test.mbt` exercises the dispatcher with a valid raw module.

### Self-branch block ownership

Removing a block around one self `br_if` requires proving that no other instruction targets its label, including branches in the condition. `merge_blocks.mbt` uses the shared full label scanner with only the replaced branch excluded; `merge_blocks_audit_wbtest.mbt` covers a condition that exits the owner.

### Local assignment sinking across legacy control

The raw legacy code-pushing path checks reads and writes against the complete original function before moving a constant assignment below a conditional branch. Region-only counts miss reads after an enclosing block. `code_pushing_audit_test.mbt` retains the assignment needed on that exit path.

### Vacuum legacy exception owners

Raw vacuum scans legacy try bodies and catches for owner-label references and rebases ordinary nested branches when an unused wrapper is removed. Delegate/rethrow regions conservatively retain wrappers pending a dedicated exception-depth proof. `vacuum_audit_test.mbt` covers a nested legacy branch that must exit its result block, not the function.

### Inlining continuation handler labels

Resume, resume-throw, and resume-throw-ref handler labels participate in implicit function-exit detection and outer-label rebasing. `inlining_audit_wbtest.mbt` covers all three opcodes. Handler-on-switch entries remain unchanged because they have no lexical label.

Resume instructions can return normally, so inlining must retain their reachable suffix. They are not unconditional sequence terminators. The three resume variants share a bounded regression in `inlining_audit_wbtest.mbt`; stack-switch remains a separate terminating operation.

### Name removal and continuation owners

Direct HOT name removal includes continuation handler labels in owner-use checks and retargets them when merging controls. `remove_unused_names_audit_wbtest.mbt` checks both operations on a validated continuation fixture. The dispatcher's existing stack-switching admission restriction remains separate from this helper correctness requirement.

### Trapping table initializer roots

Remove-unused-module-elements roots tables whose descriptor initializer may trap, alongside globals and element initializers. This preserves observable instantiation failure even when no function reads the table. The explicit traps-never-happen option still controls this policy. `remove_unused_module_elements_audit_test.mbt` validates the table fixture and checks retention through the dispatcher.

### Once-reduction tail-call returns

An already-executed once function's `return_call` becomes `return`, preserving the function exit inside nested controls. `once_reduction_audit_test.mbt` covers the observable post-block suffix; the existing root tail-call test still checks that dead writes are removed and now asserts the explicit return.

### Once-reduction lexical branch scopes

Both once analysis and rewriting push an if-label scope and retain local branch exits when deciding reachability. Their outermost scope represents the implicit function label and contributes to normal-return summaries. The audit's block-exit and implicit-function-return tests prevent facts from a skipped once call from leaking onto another path.

### Once wrapper eligibility

Once-body simplification requires an active once slot, not just a syntactically recognized guard. A guard read by ordinary code makes its writes observable. The inactive-wrapper audit regression retains that global write even when another unrelated once function activates the pass.
