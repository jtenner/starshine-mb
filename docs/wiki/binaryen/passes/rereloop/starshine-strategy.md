---
kind: concept
status: supported
last_reviewed: 2026-04-30
sources:
  - ../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md
  - ../../../raw/binaryen/2026-04-30-rereloop-current-main-refresh.md
  - ../../../raw/research/0316-2026-04-24-rereloop-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
  - ../souperify/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flat-cfg-builder-and-boundaries.md
  - ./wat-shapes.md
  - ../flatten/index.md
  - ../simplify-locals-nonesting/index.md
  - ../dataflow-optimization/index.md
  - ../souperify/index.md
---

# Starshine strategy for `rereloop` / `re-reloop`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md`](../../../raw/binaryen/2026-04-24-rereloop-primary-sources.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete future-port constraints implied by the upstream strategy.

## The honest current status

`re-reloop` is still **unimplemented** in Starshine.
There is no `src/passes/rereloop.mbt`, `src/passes/re_reloop.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- keep the local pass spelling `re-reloop` in the removed-name registry,
- reject active requests honestly instead of silently no-oping,
- keep the upstream Binaryen spelling `rereloop` visible in the wiki because official Binaryen uses that public name,
- keep the old Batch 2 port-intent breadcrumb visible,
- keep its absence from the canonical no-DWARF path explicit,
- keep the missing dedicated backlog slice explicit,
- and keep the future port framed as a flat-IR CFG-to-structure project, not as a small peephole.

So this page is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- removed pass-name tracking
  - [`src/passes/optimize.mbt#L144-L153`](../../../../../src/passes/optimize.mbt#L144-L153)
    - `pass_registry_removed_names()` includes `"re-reloop"`.
- registry entry construction for removed names
  - [`src/passes/optimize.mbt#L265-L270`](../../../../../src/passes/optimize.mbt#L265-L270)
    - each removed name becomes a `HotPassRegistryCategory::Removed` registry entry.
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L451-L466`](../../../../../src/passes/optimize.mbt#L451-L466)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is removed from the active hot pipeline registry`.
- active preset omission
  - [`src/passes/optimize.mbt#L241-L263`](../../../../../src/passes/optimize.mbt#L241-L263) and [`src/passes/optimize.mbt#L371-L444`](../../../../../src/passes/optimize.mbt#L371-L444)
    - the public `optimize` / `shrink` presets and preset-expand helpers include only currently implemented active passes, not `re-reloop`.
- CLI spelling parse coverage
  - [`src/cli/cli_test.mbt#L213-L216`](../../../../../src/cli/cli_test.mbt#L213-L216)
    - `parse_cli_args` accepts the local flag spelling `--re-reloop` and stores `"re-reloop"` as a requested pass flag.
- command-level rejection coverage
  - [`src/cmd/cmd_wbtest.mbt#L3843-L3848`](../../../../../src/cmd/cmd_wbtest.mbt#L3843-L3848)
    - `run_cmd_with_adapter(["--re-reloop", ...])` rejects the request and writes no output.
- help-output hiding for removed pass names
  - [`src/cmd/cmd_wbtest.mbt#L4724-L4727`](../../../../../src/cmd/cmd_wbtest.mbt#L4724-L4727)
    - public help includes active entries such as `--ssa-nomerge`, `--vacuum`, and `--optimize`, but does not include `--re-reloop`.
- older pass-port planning breadcrumb
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L44-L47`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L44-L47)
    - `re-reloop` is still listed under Batch 2 names removed until a hot implementation lands.
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `rereloop` / `re-reloop` in the active default route.
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `rereloop` / `re-reloop` slice.

That map is the durable local status today: the pass is known, intentionally unavailable, tested at the CLI/cmd boundary, hidden from help, and not assigned to an active implementation slice.

## Local-vs-upstream naming

Upstream Binaryen publishes the pass as `rereloop`.
Current Starshine tracks the preserved local spelling `re-reloop`.

Treat that as a naming split, not an algorithm split:

- Binaryen source, tests, and wiki prose should cite `rereloop` when discussing upstream behavior.
- Starshine registry and CLI behavior should cite `re-reloop` when discussing current local status.
- A future port should either keep the local spelling intentionally or add a deliberate alias plan; it should not silently lose the upstream spelling in docs.

## What Starshine currently does for this pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `re-reloop` in `pass_registry_removed_names()`.
That means:

- the historical flag remains discoverable to registry-level code,
- the repo has a current answer for the name,
- and future implementation work has a precise category to change when the pass lands.

### 2. The active pipeline rejects it honestly

The active pass-expansion path rejects removed names.
That matters because explicit requests do not pretend to restructure control flow, and future work must update the registry and tests intentionally rather than accidentally making the flag look active.

### 3. The public help surface hides it

The help cache only includes active hot passes and presets.
The command tests prove `--re-reloop` remains hidden, which is the right current behavior for a removed pass name.

### 4. The old Batch 2 map is only a breadcrumb

The pass-port batch map still lists `re-reloop`, but `agent-todo.md` has no dedicated current slice.
Treat that as preserved historical intent, not active implementation scope.

## Why this is not today's `merge-blocks`, `flatten`, or `simplify-locals`

### It is not `merge-blocks`

See [`../merge-blocks/index.md`](../merge-blocks/index.md).

Current Starshine `merge-blocks` flattens local HOT block shells and simplifies local structure. Upstream `rereloop` does something different: it consumes already-flat IR, builds a temporary CFG, and asks a generic structured-code renderer to synthesize new control flow. A future port should not hide `rereloop` inside block-merge cleanup.

### It is not `flatten`

See [`../flatten/index.md`](../flatten/index.md).

`flatten` creates the precondition. `rereloop` consumes the precondition. The correct relationship is:

1. make control flow flat enough,
2. rebuild a CFG,
3. render structured wasm again.

Skipping step 1 would violate Binaryen's own `Flat::verifyFlatness(function)` contract.

### It is not just another locals simplifier

See [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md) and [`../dataflow-optimization/index.md`](../dataflow-optimization/index.md).

The flatten-era cluster uses locals heavily, but `rereloop`'s core obligation is control-flow reconstruction. The helper `i32` label local is renderer bookkeeping, not a normal local-cleanup target.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- accept or deliberately alias the local `re-reloop` spelling while documenting upstream `rereloop`,
- enforce a hard flatness precondition before using branch conditions as CFG-edge conditions,
- build CFG blocks from flat top-level control, not arbitrary nested HOT trees,
- map named blocks to deferred join targets,
- map named loops to loop-entry/backedge targets,
- lower `if` into condition/arm/after CFG edges,
- lower `br` / `br_if` into CFG branches with correct fallthrough behavior,
- group `br_table` targets and preserve the duplicate-default-target temporary-block rule,
- preserve explicit `return` and `unreachable` terminators,
- hard-fail or intentionally gate EH until a researched EH design exists,
- patch CFG dead ends with explicit terminators before rendering,
- allocate and thread an `i32` helper label local or an equivalent renderer state,
- repair apparent result-typed fallthroughs with explicit `unreachable`,
- and refinalize or otherwise recompute final types after rendering.

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./flat-cfg-builder-and-boundaries.md`](./flat-cfg-builder-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Future local landing questions

The main open design question is not whether Binaryen's pass is real. It is how Starshine would represent the same two-layer algorithm.

A future implementation needs decisions for:

1. flatness source
   - reuse a future `flatten` port,
   - define a smaller Starshine-specific flatness predicate,
   - or reject unless an existing flatness-sensitive pipeline marker is present.
2. CFG representation
   - create a pass-local CFG builder like Binaryen,
   - reuse future IR2 CFG infrastructure,
   - or add a minimal adapter only for the reviewed flat control surface.
3. structured renderer
   - port a generic relooper,
   - use a smaller targeted renderer for Binaryen-compatible cases,
   - or defer the pass until Starshine has a broader structured-control rebuild layer.
4. scheduling
   - keep it outside default no-DWARF parity,
   - add it only to a future aggressive flat-IR pipeline,
   - or expose it only as an explicit experimental pass.

Until those questions are answered, keeping `re-reloop` removed is the honest local strategy.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep removed-pass rejection until the transform exists,
   - when the pass lands, update registry category, help behavior, tests, and docs in the same change.
2. flatness precondition tests
   - reject or preclude non-flat value-carrying control,
   - accept post-flatten shapes that match the Binaryen lit fixtures.
3. reduced CFG-shape tests
   - flat `if` tail rebuilds,
   - named-block join targets,
   - named-loop backedge targets,
   - conditional and unconditional branches,
   - grouped `br_table` targets,
   - duplicate-default-target switch cases,
   - dead-end terminator repair,
   - result-typed `unreachable` repair.
4. renderer artifact tests
   - helper `i32` label local or documented equivalent,
   - helper break/continue blocks,
   - cleanup interactions with `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, and `vacuum`.
5. source parity
   - compare focused `--flatten --rereloop` Binaryen fixtures against Starshine's local spelling after the pass becomes active.

## Bottom line

Current Starshine `rereloop` / `re-reloop` strategy is honest removed-name tracking plus an explicit future-proofing map:

- the pass name is preserved at [`src/passes/optimize.mbt#L144-L153`](../../../../../src/passes/optimize.mbt#L144-L153),
- active requests are rejected at [`src/passes/optimize.mbt#L451-L466`](../../../../../src/passes/optimize.mbt#L451-L466),
- CLI parsing and command rejection are covered at [`src/cli/cli_test.mbt#L213-L216`](../../../../../src/cli/cli_test.mbt#L213-L216) and [`src/cmd/cmd_wbtest.mbt#L3843-L3848`](../../../../../src/cmd/cmd_wbtest.mbt#L3843-L3848),
- help hides the removed pass at [`src/cmd/cmd_wbtest.mbt#L4724-L4727`](../../../../../src/cmd/cmd_wbtest.mbt#L4724-L4727),
- Batch 2 planning still mentions it at [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L44-L47`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L44-L47),
- the active backlog still has no dedicated slice,
- and there is no local owner file yet.

So the right mental model today is:

- **no transform yet**,
- **clear removed-registry behavior**,
- **source-backed Binaryen `rereloop` contract**,
- **future flat-IR CFG/rendering proof still unresolved**,
- **no default no-DWARF parity obligation today**.
