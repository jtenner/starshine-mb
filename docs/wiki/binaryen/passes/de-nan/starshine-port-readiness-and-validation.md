---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-de-nan-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-24-de-nan-primary-sources.md
  - ../../../raw/research/0434-2026-05-04-de-nan-current-main-recheck.md
  - ../../../raw/research/0341-2026-04-25-de-nan-current-main-recheck.md
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
  - ./starshine-strategy.md
  - ../global-effects/index.md
  - ../precompute/index.md
---

# Starshine port readiness and validation for `de-nan` / `denan`

Use this page together with [`./starshine-strategy.md`](./starshine-strategy.md) and the upstream strategy / shape pages.
It records the current local hold point and the validation order a future port would need.

## Current hold point

`de-nan` is still **unimplemented** in Starshine.
The local registry keeps it as a removed compatibility name, and there is no owner file or backlog slice yet.

That means the current local behavior is still:

- the registry knows `de-nan`
- explicit requests are rejected as removed
- the canonical no-DWARF path does not schedule it
- the pass remains a future module-owned instrumentation candidate, not a landed HOT pass

## Exact local code map

- [`src/passes/optimize.mbt#L140-L149`](../../../../../src/passes/optimize.mbt#L140-L149)
  - `pass_registry_removed_names()` includes `de-nan`
- [`src/passes/registry_test.mbt#L120-L126`](../../../../../src/passes/registry_test.mbt#L120-L126)
  - registry category is still `Removed`
- [`src/passes/registry_test.mbt#L213-L218`](../../../../../src/passes/registry_test.mbt#L213-L218)
  - removed-name execution still rejects `de-nan`
- [`docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43`](../../../../../docs/0063-2026-03-24-pass-port-batches-and-registry-map.md#L41-L43)
  - Batch 1 still records `de-nan` as removed until a hot implementation lands
- [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - no default no-DWARF slot for the pass today
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
  - no dedicated active slice yet

## Why the future port is module-owned, not just a peephole

Binaryen `denan` inserts helper calls, sanitizes entry params, and appends helper functions after the walk.
That means a faithful Starshine port needs module-level ownership even if some expression rewrites happen in the HOT layer.

The biggest boundaries to keep honest are:

- constant NaN repair can happen outside functions
- helper-call repair cannot
- `local.get` must stay unwrapped
- result-fallthrough shells must stay structurally stable
- SIMD handling still needs lane-wise scalar checks

## Suggested validation ladder

1. **Registry honesty**
   - keep removed rejection until the pass is actually implemented
2. **Shape tests**
   - NaN globals become zero
   - nonconstant float producers get helper-wrapped
   - entry params sanitize in defined functions only
   - imported functions do not get entry repair
   - `local.get` stays plain
   - fallthrough shells stay intact
   - helper names avoid collisions
   - SIMD helper emission stays feature-gated
   - helper calls never appear in nonfunction contexts
3. **Binaryen compare**
   - run focused `--pass denan` fixtures once Starshine gains the pass
4. **Broader fuzzing**
   - only after the reduced shape set is green

## Source bridge

The 2026-05-04 current-main recheck confirmed there is still no simpler function-only contract hiding behind the pass name.
That keeps the local strategy unchanged: `de-nan` stays a removed compatibility name until a real module pass lands.

## Cross-links

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./helper-functions-fallthrough-and-boundaries.md`](./helper-functions-fallthrough-and-boundaries.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
