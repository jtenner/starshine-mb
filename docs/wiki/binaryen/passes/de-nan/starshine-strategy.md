---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0478-2026-05-05-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md
  - ../../../raw/research/0512-2026-05-06-de-nan-current-main-line-anchor-refresh.md
  - ../../../raw/research/0283-2026-04-24-de-nan-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../global-effects/index.md
  - ../precompute/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./helper-functions-fallthrough-and-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../global-effects/index.md
  - ../precompute/index.md
---

# Starshine Strategy For `de-nan` / `denan`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md`](../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md), the focused current-main recheck in [`../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-de-nan-current-main-recheck.md), the 2026-05-06 line-anchor refresh in [`../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md), and the companion validation bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the main uncertainty a future parity port must resolve.

## The honest current status

`de-nan` is still **unimplemented** in Starshine.
There is no `src/passes/de_nan.mbt`, `src/passes/denan.mbt`, or similarly named owner file today.

The current Starshine strategy is deliberately limited:

- preserve the local pass spelling `de-nan` in the registry as a known removed name
- reject active requests honestly instead of silently no-oping
- keep the upstream Binaryen spelling `denan` visible in the wiki because official Binaryen uses that public name
- keep the old Batch 1 port-intent breadcrumb visible
- keep its absence from the canonical no-DWARF path explicit
- keep the missing dedicated backlog slice explicit
- document why a future port is probably module-owned instrumentation, not a small default-preset peephole

So this is a **status-and-port-planning** page, not an implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- removed pass-name tracking
  - [`src/passes/optimize.mbt#L145-L149`](../../../../../src/passes/optimize.mbt#L145-L149)
    - `pass_registry_removed_names()` includes `"de-nan"`
- registry entry construction for removed names
  - [`src/passes/optimize.mbt#L311-L312`](../../../../../src/passes/optimize.mbt#L311-L312)
    - each removed name becomes a `HotPassRegistryCategory::Removed` registry entry
- active request guard for removed passes
  - [`src/passes/optimize.mbt#L522-L524`](../../../../../src/passes/optimize.mbt#L522-L524)
    - `run_hot_pipeline_expand_passes(...)` returns `pass flag {name} is removed from the active hot pipeline registry`
- pass-specific registry-category coverage
  - [`src/passes/registry_test.mbt#L136-L138`](../../../../../src/passes/registry_test.mbt#L136-L138)
    - `pass_registry_category("de-nan")` is expected to be `Removed`
- removed-name request-rejection coverage
  - [`src/passes/registry_test.mbt#L237-L239`](../../../../../src/passes/registry_test.mbt#L237-L239)
    - the generic removed-name execution test currently uses `de-nan` as its representative removed pass
- older pass-port planning breadcrumb
  - [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43)
    - `de-nan` is still listed under Batch 1 names removed until a hot implementation lands
- canonical scheduler context by omission
  - [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
    - the current canonical no-DWARF path page does not place `de-nan` / `denan` in the active default route
- backlog context by omission
  - [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
    - there is currently no dedicated `de-nan` / `denan` slice

That map is the durable local status today: the pass is known, intentionally unavailable, tested as removed, and not assigned to an active implementation slice. The 2026-05-05 current-main recheck did not find any upstream drift that would justify changing this local classification or adding `denan` as a separate accepted spelling.

## Why this is not an ordinary HOT peephole today

Binaryen's `denan` has some expression-local rewrites:

- constant `f32` / `f64` / `v128` NaNs become zero constants
- nonconstant float/SIMD producers are wrapped in helper calls
- `local.get` and result-fallthrough shells are skipped

But the real upstream pass also has module-level responsibilities:

- choose fresh helper function names without colliding with user functions
- synthesize helper functions after the main walk
- add a SIMD helper only when SIMD is enabled
- sanitize non-imported function parameters at entry
- run nested `merge-blocks` cleanup after adding entry fixups
- avoid inserting helper calls in nonfunction contexts such as global initializers
- advertise that the transform adds effects because it inserts calls

That combination makes the future Starshine landing shape nontrivial.
A faithful port probably needs a module owner even if it reuses HOT-region rewriting for function bodies.

## What Starshine currently does for the pass name

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `de-nan` in `pass_registry_removed_names()`.
That means:

- the spelling remains discoverable in local registry behavior
- historical CLI/planning docs and new wiki pages can point at one consistent local status
- future port work does not need to rediscover whether the repo intended to track the upstream pass

### 2. The active pipeline rejects it honestly

When a user requests a removed pass name, `run_hot_pipeline_expand_passes(...)` rejects the request with a removed-pass error.
That behavior matters because:

- explicit pass requests do not silently pretend to sanitize NaNs
- the registry category remains executable documentation
- future implementation work will have to change the category and tests intentionally

### 3. The old Batch 1 map is only a breadcrumb

The pass-port batch map still lists `de-nan` under Batch 1 removed names, but `agent-todo.md` has no dedicated current slice for it.
Treat that as a weak historical planning signal, not an active commitment.

## What a future Starshine port must preserve

A faithful port should preserve the source-backed contract from the rest of this folder:

- accept or deliberately map the local `de-nan` spelling while documenting that upstream calls the pass `denan`
- report, schedule, or invalidate as an effect-adding transform because helper calls are inserted
- repair NaN constants to zero constants wherever that replacement is legal, including global initializers
- never insert helper calls into nonfunction contexts
- sanitize defined-function `f32`, `f64`, and `v128` params at entry
- skip imported-function entry repair
- wrap nonconstant `f32`, `f64`, and `v128` producers inside function bodies
- skip plain `local.get`
- skip result-fallthrough shells such as `local.set`, `block`, `if`, `loop`, `try`, `try_table`, `select`, and `break`
- generate helper function names collision-safely
- add helper functions after the instrumented module walk so they are not instrumented themselves
- preserve the scalar helper self-equality NaN test
- preserve the SIMD helper's scalar lane-extraction strategy instead of replacing it with direct vector equality
- preserve or equivalently eliminate the temporary wrapper blocks caused by entry-param fixups

For the upstream details, use:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./helper-functions-fallthrough-and-boundaries.md`](./helper-functions-fallthrough-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)

## Nearby boundaries to keep distinct

### `precompute`

See [`../precompute/index.md`](../precompute/index.md).

Both passes can replace constants, but they have opposite teaching frames:

- `precompute` folds expressions while preserving ordinary optimizer semantics
- `denan` deliberately changes NaN behavior by forcing NaN values to zero

Do not file `de-nan` under generic constant folding.

### `global-effects`

See [`../global-effects/index.md`](../global-effects/index.md).

Both pages talk about effects, but for different reasons:

- `global-effects` computes and uses effect information
- `denan` advertises `addsEffects()` because it inserts helper calls

Do not cite an effect-analysis page as evidence that Starshine already has a `de-nan` implementation.

## Validation plan for the eventual port

A future implementation should validate in layers:

1. registry behavior
   - keep removed-pass rejection until the transform exists
   - when the pass lands, update registry category, help behavior, tests, and docs in the same change
2. reduced WAT-shape tests
   - NaN global constants become zero constants
   - function-body NaN constants become zero constants
   - nonconstant `f32` / `f64` producers are helper-wrapped
   - non-imported params are sanitized at entry
   - imported functions are not entry-sanitized
   - `local.get` remains unwrapped
   - result-fallthrough shells are not double-wrapped
   - helper names avoid user-function collisions
   - SIMD helper emission is feature-gated
   - nonfunction contexts never receive helper calls
3. source parity
   - compare direct `--pass denan` / local `--pass de-nan` behavior against Binaryen for focused fixtures
4. broader fuzzing only after the reduced rules are green
   - classify differences around NaN payloads, helper-call placement, and SIMD helper behavior explicitly

## Current-main source bridge

The 2026-05-06 line-anchor refresh in [`../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md`](../../../raw/binaryen/2026-05-06-de-nan-current-main-line-anchor-refresh.md) is now the freshness citation for this local strategy page.

It matters locally because it confirms that current upstream still looks like the same module-owned instrumentation pass:

- no new upstream pass spelling that Starshine should mirror today
- no new default-path role that would make `de-nan` a no-DWARF parity obligation
- no simpler function-local-only contract that would make a HOT-only port sufficient
- no change to the helper-call / entry-param / result-fallthrough contract future Starshine tests must compare against

So the local status remains deliberate: keep `de-nan` as a removed compatibility name until a real module pass lands.

## Bottom line

Current Starshine `de-nan` strategy is honest removed-name tracking plus an explicit future-proofing map:

- the pass name is preserved at [`src/passes/optimize.mbt#L145-L149`](../../../../../src/passes/optimize.mbt#L145-L149)
- active requests are rejected at [`src/passes/optimize.mbt#L522-L524`](../../../../../src/passes/optimize.mbt#L522-L524)
- current tests already prove `de-nan` is removed and rejected at [`src/passes/registry_test.mbt#L136-L138`](../../../../../src/passes/registry_test.mbt#L136-L138) and [`src/passes/registry_test.mbt#L237-L239`](../../../../../src/passes/registry_test.mbt#L237-L239)
- Batch 1 planning still mentions it at [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43)
- the active backlog still has no dedicated slice
- there is no local owner file yet

So the right mental model today is:

- **no transform yet**
- **clear removed-registry behavior**
- **source-backed Binaryen `denan` contract**
- **future module-owned instrumentation proof still unresolved**
- **no default no-DWARF parity obligation today**
