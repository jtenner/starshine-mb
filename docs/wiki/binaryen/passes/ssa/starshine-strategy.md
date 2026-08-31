---
kind: concept
status: supported
last_reviewed: 2026-08-30
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/SSAify.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/LocalGraph.cpp
  - ../../../../../src/passes/ssa.mbt
  - ../../../../../src/passes/ssa_test.mbt
  - ../../../../../src/passes/ssa_wbtest.mbt
  - ../../../../../src/ir/local_graph.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_ssa.mbt
  - ../../../../../src/validate/gen_valid_ssa_full_wbtest.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./merge-locals-entry-prepends-and-default-values.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../ssa-nomerge/index.md
---

# Starshine full `ssa` strategy

## Current status

Starshine implements full public `ssa` as an active hot-pass registry name and direct CLI pass.

The implementation covers the complete Binaryen v131 source-level contract:

- fresh local allocation for every write whose original local is not already SSA;
- single-source get retargeting;
- parameter-entry preservation;
- explicit numeric, vector, and nullable-reference defaults;
- fresh merge local per multi-source get;
- explicit incoming `local.tee` writes;
- parameter-entry prepends;
- ordinary default-entry no-prepend behavior;
- shared predecessor sets feeding multiple merge gets;
- loops, direct branches, `br_if`, `br_table`, typed loop control, nested value blocks, and explicit exceptional predecessors.

`ssa-nomerge` remains a separate sibling and remains the pass used by presets. Full `ssa` is direct-only unless a future scheduler decision explicitly changes that.

## Execution architecture

The public pass has three layers.

### 1. Full-flow LocalGraph

`src/ir/local_graph.mbt` exposes `local_graph_build_full_flow(...)` for full `ssa`.

It uses Binaryen-style reverse flow rather than the older all-local fixed-point matrix:

- record local get/set/tee actions per CFG block;
- scan backward inside the current block first;
- flow unresolved reads through predecessor blocks;
- include exceptional predecessors for the full pass;
- cache block-entry source queries by block and local;
- reconstruct set-to-get influence lists and already-SSA local facts.

The ordinary `local_graph_build(...)` API keeps its existing normal-flow behavior for `ssa-nomerge` and other users.

### 2. Transactional rewrite plan

`src/passes/ssa.mbt` builds one immutable `SsaFullRewritePlan` before mutation.

The plan contains:

- ordered write decisions: `Freshen` or `KeepCanonical`;
- ordered get decisions: `Retarget`, `MaterializeDefault`, `Merge`, or `KeepCanonical`;
- merge-get records with explicit-write, parameter-entry, and default-entry inputs.

Fresh write locals are allocated before merge locals, matching Binaryen v131's `createNewIndexes(...)` then `computeGetsAndPhis(...)` phase order.

The plan is validated before HOT mutation. Stale node ids, wrong local ids, wrong node kinds, bad child arity, nonsequential local ids, illegal defaults, or malformed merge inputs leave the function unchanged.

### 3. Raw stack-machine writeback

The dispatcher uses the full-flow HOT graph for analysis, then applies the plan directly to the original `@lib` instruction stream.

This preserves source stack order and avoids broad HOT lowering:

- rewrite local write indexes in raw instruction order;
- insert `local.tee merge` immediately before the source `local.set` / `local.tee`;
- retarget local gets by ordered plan cursor;
- replace legal entry reads with exact default instructions;
- prepend parameter copies as `local.get param; local.set merge`;
- append fresh local declarations in write-then-merge order.

A direct HOT mutator remains in `ssa.mbt` for focused unit coverage and helper use, but the public module pipeline commits through the raw plan.

## Validation and rollback

Full `ssa` shares the batched SSA writeback repair with `ssa-nomerge`.

After all changed definitions are produced:

1. validate the complete changed-definition batch against the module;
2. restore only invalid changed functions;
3. validate the repaired module;
4. roll back the whole pass only if batch repair itself cannot complete.

This repaired a production artifact stack-underflow found in absolute function 2848 without paying repeated full-module validation per changed function.

## Tests

`src/passes/ssa_test.mbt` covers:

- explicit-write planner inputs;
- parameter/default entry classification;
- nondefaultable entry rejection;
- repeated parameter writes;
- exact nullable-reference defaults;
- already-SSA body-local reads;
- explicit, parameter-entry, default-entry, and shared-set merges;
- loop backedges;
- branch and `br_table` joins;
- typed loop control;
- exceptional predecessors.

`src/passes/ssa_wbtest.mbt` locks no-partial-mutation validation.

`src/passes/pass_manager_wbtest.mbt` locks batched rollback for both public SSA variants.

`src/validate/gen_valid_ssa_full_wbtest.mbt` locks all fifteen singleton profiles, `ssa-all` aggregate sampling, labels, and generated feature facts.

## Output-shape differences

Two residual families are intentionally retained as measured Starshine wins:

- empty-arm `nop` cleanup: Starshine is canonically smaller and the symmetric `local-cleanup-debris` normalizer proves the difference is only removable cleanup;
- typed-loop stack carriers: Starshine lowers the same local merge behavior with fewer locals/operations and four fewer canonical bytes per dedicated case.

The typed family has separate `1,000/1,000` all-equal Node execution evidence. No typed case is equal-sized or larger.

Unreachable declaration-only differences are handled by the symmetric `ssa-local-allocation-debris` normalizer in the dedicated aggregate.

## Performance

The transform avoids the original quadratic LocalGraph fixed point and broad HOT lowering. On the 4,977,401-byte canonical artifact, Starshine emits a canonical result 5,424 bytes smaller than Binaryen v131.

Whole-command timing is not at parity:

- Starshine no-trace: about `4.024s`;
- Binaryen: about `1.202s`;
- Starshine raw owner: about `3.247s`;
- Binaryen pass timer: about `0.655s`.

The direct HOT pass timer is zero because the active implementation runs in raw preprocessing. Keep the remaining serial function-envelope/raw-owner gap under `[WALL]001`; do not describe it as achieved wall parity.

## Scheduler boundary

`optimize` and `shrink` continue to schedule `ssa-nomerge`, matching the documented Binaryen default sibling split. Full `ssa` is public and fully runnable, but remains out of presets.
