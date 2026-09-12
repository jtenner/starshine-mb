---
kind: concept
status: supported
last_reviewed: 2026-08-28
sources:
  - ./test-matrix.md
  - ./local-ssa-policy.md
  - https://doi.org/10.1145/115372.115320
  - ../../../src/ir/README.md
  - ../../../src/ir/architecture.mbt
  - ../../../src/ir/hot_core.mbt
  - ../../../src/ir/analysis_cache.mbt
  - ../../../src/passes/pass_common.mbt
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
