---
kind: concept
status: supported
last_reviewed: 2026-05-05
sources:
  - ../../../raw/research/0464-2026-05-05-local-cse-port-readiness-and-validation.md
  - ../../../raw/binaryen/2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-local-cse-primary-sources.md
  - ../../../raw/research/0453-2026-05-05-local-cse-current-main-recheck.md
  - ../../../raw/research/0358-2026-04-25-local-cse-current-main-and-test-map.md
  - ../../../raw/research/0262-2026-04-22-local-cse-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
  - ../../no-dwarf-default-optimize-path.md
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./starshine-strategy.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./wat-shapes.md
  - ./basic-block-windows-and-barriers.md
  - ../flatten/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../coalesce-locals/index.md
  - ../simplify-locals/index.md
  - ../reorder-locals/index.md
---

# Starshine Port Readiness And Validation For `local-cse`

This page is the bridge between the upstream source-backed `local-cse` contract and a future Starshine port.
It does **not** claim an implementation.
It says what is already in-tree, what the nearest landing zone is, and what should be proven first once work starts.

For the exact upstream algorithm and source/test map, read:

- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md)
- [`./wat-shapes.md`](./wat-shapes.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)

## Current readiness status

Starshine still treats `local-cse` as **removed**.
There is no owner file, no dispatcher case, and no active port slice yet.

That is the honest state to keep until the missing neighbors exist and the first real transform lands.

## What already exists locally

The nearest local surfaces are:

| Surface | Why it matters |
| --- | --- |
| `src/passes/optimize.mbt` | Keeps `local-cse` in the removed registry, preserves the known pass spelling, and blocks active requests cleanly. |
| `src/passes/pass_manager.mbt` | Has no `local-cse` dispatcher case, so no transform can run by accident. |
| `src/passes/simplify_locals.mbt` | Already models local effect/conflict checks and cleanup behavior close to the pass's safety questions. |
| `src/passes/reorder_locals.mbt` | Already handles local-index rewriting and is the closest landed example of temp-local bookkeeping work. |
| `src/passes/pass_manager_wbtest.mbt` | Already carries nearby replay tests for simplify-locals boundary behavior. |
| `src/cmd/cmd_wbtest.mbt` | Already carries artifact replay lanes that a future `local-cse` port should extend. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md` | Documents the canonical late-cluster slot where the pass belongs. |
| `agent-todo.md` | Holds the `LCSE` slice that should be filled before implementation starts. |

For the exact local code-map anchors, see [`./starshine-strategy.md`](./starshine-strategy.md).

## What a faithful port will need first

1. **Whole-tree candidate matching**
   - repeated whole expressions, not generic subtree CSE
   - first-occurrence originals
   - parent-over-child request cancellation
2. **Window safety**
   - limited linear reuse windows
   - explicit resets around non-linear control
   - effect and generativity filtering
3. **Temp-local materialization**
   - append locals honestly
   - rewrite originals with `local.tee`
   - rewrite repeats with `local.get`
4. **Local-index repair and replay**
   - keep the new locals consistent with the existing rewrite and replay machinery
   - preserve the late clean-up relationship with `simplify-locals`

## Validation ladder

Start small and stay honest about the missing neighbors.

### 1. Shape tests first

Add focused tests for the source-backed families in [`./wat-shapes.md`](./wat-shapes.md):

- repeated arithmetic roots
- repeated loads
- before-`if` / then-arm positives
- parent-over-child cancellation
- after-`if` window resets
- local-write invalidation
- idempotent direct-call positives
- generative GC-root negatives
- tiny-root profitability no-ops

### 2. Registry and CLI proof

Before any optimizer-slot claim, prove that:

- the pass name is still tracked as removed
- explicit `--local-cse` requests fail cleanly
- the current catalog text still points at the real implementation gap

### 3. Pass-targeted parity

Once active code exists, sign off with pass-targeted fuzz compare against Binaryen on the canonical pass spelling.

### 4. Neighborhood replay

Only after the adjacent local cleanup neighbors are represented locally should the no-DWARF neighborhood replay claim be made.
That means the validation story should stay conservative until the `flatten -> simplify-locals-notee-nostructure -> local-cse` and `coalesce-locals -> local-cse -> simplify-locals` slots are actually testable end to end.

## Bottom line

`local-cse` is still documentation plus port planning.
The current repo already has the nearby local machinery that a future port will need, but it does not yet have the pass itself.
Keep this page as the implementation-readiness bridge until that changes.
