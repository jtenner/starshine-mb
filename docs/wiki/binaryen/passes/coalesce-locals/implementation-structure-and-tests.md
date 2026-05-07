---
kind: concept
status: supported
last_reviewed: 2026-05-08
sources:
  - ../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md
  - ../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-coalesce-locals-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-22-coalesce-locals-primary-sources.md
  - ../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/simplify_locals.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
---

# `coalesce-locals` Implementation Structure And Tests

This page maps the source and test files that define upstream Binaryen's `coalesce-locals` contract, then maps that contract to the exact current Starshine status. It is a read-along companion to the strategy page, not a second strategy page.

## Source rule

Use Binaryen `version_129` as the tagged source oracle and [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md) as the latest freshness bridge. The 2026-05-05 recheck found no teaching-relevant current-`main` drift on the checked owner, scheduler, helper, and dedicated-test surfaces.

Primary upstream sources:

- `src/passes/CoalesceLocals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/CoalesceLocals.cpp>
- `src/passes/pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/opt-utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- `src/cfg/liveness-traversal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/cfg/liveness-traversal.h>
- `src/ir/numbering.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/numbering.h>
- `src/ir/utils.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/utils.h>
- `test/lit/passes/coalesce-locals.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/coalesce-locals.wast>

## Upstream owner-file map

| File | What to read it for | Contract it proves |
| --- | --- | --- |
| `src/passes/CoalesceLocals.cpp` | Main pass implementation | `isFunctionParallel()`, nonlinear local-slot coalescing, liveness/value-number analysis, greedy exact-type coloring, backedge weighting, normal-vs-learning order policy, and final local-index rewrite/cleanup. |
| `src/cfg/liveness-traversal.h` | CFG and liveness action collection | The pass reasons over basic-block liveness, live actions, dead-code unlinking, and mutation sites rather than just syntax scanning the function body. |
| `src/ir/numbering.h` | Value-numbering support | Interference is value-aware: overlapping locals can share a slot when the current values are proven equal. |
| `src/ir/utils.h` | Local-set/get cleanup helpers | Post-coloring cleanup deletes redundant copies and dead sets rather than merely shrinking the local declaration vector. |
| `src/passes/pass.cpp` | Public pass registration and scheduler slots | Binaryen exposes both `coalesce-locals` and `coalesce-locals-learning`; the ordinary optimize path uses the non-learning pass in the late local-cleanup cluster. |
| `src/passes/opt-utils.h` | Nested cleanup reruns after inlining | `coalesce-locals` can also appear through helper-driven late cleanup reruns, so Starshine's direct pass must stay stable when called repeatedly. |
| `test/lit/passes/coalesce-locals.wast` | Concrete behavior examples | The dedicated lit file is the best source for exact-type positives, type/interference negatives, equal-value overlap, zero-init, copy removal, backedge priority, and greedy-order examples. |

## `CoalesceLocals.cpp` read path

Read the owner file in this order:

1. Pass declaration and header comments.
   - Establishes that the pass is function-parallel and nonlinear in local count, which explains late scheduling.
2. Liveness setup around `doWalkFunction(...)`.
   - Collects per-basic-block action/liveness facts and prepares mutation sites.
3. `increaseBackEdgePriorities()`.
   - Gives loop-backedge copies extra weight before greedy coloring.
4. `calculateInterferences()`.
   - Combines liveness with value numbering so overlap is legal only when the locals hold the same value.
5. `pickIndicesFromOrder(...)` and the reverse-order comparison.
   - Greedily assigns exact-typed locals to shared slots and chooses the order that removes more copies.
6. `applyIndices()`.
   - Rewrites local indices, deletes redundant copies/dead writes, shrinks the local declaration list, and requests refinalization when cleanup changes expression types.

The important non-obvious detail is that the cleanup tail is part of correctness and usability. A port that only merges local declarations but leaves redundant `local.set` / `local.tee` traffic behind would not match the useful upstream pass.

## Scheduler and variant map

`pass.cpp` owns three public-facing facts:

- `coalesce-locals` is the ordinary public pass.
- `coalesce-locals-learning` is a separate public variant that explores more orderings.
- The default no-DWARF optimize path uses ordinary `coalesce-locals`, not the learning variant.

The canonical no-DWARF sequence uses it in two important places:

1. `optimize-casts -> local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`
2. `reorder-locals -> coalesce-locals -> reorder-locals`

That placement is why the Starshine dossier links `local-subtyping`, `local-cse`, `reorder-locals`, and `simplify-locals` rather than treating this as an isolated pass.

## Dedicated test-surface map

`test/lit/passes/coalesce-locals.wast` is the upstream behavior oracle for this dossier.

The important families are:

- **Exact type positives**: same-typed locals can share a slot.
- **Type negatives**: different exact local types are not coalesced.
- **Interference negatives**: overlapping live ranges with different values stay separate.
- **Equal-value overlap positives**: overlap is allowed when value numbering proves the same value.
- **Zero-init cases**: implicit local initialization is part of the entry-state proof.
- **Copy-removal cases**: coalescing should delete redundant copies, not just reduce local declarations.
- **Dead-set/dead-tee cleanup**: cleanup can remove ineffective writes and may force refinalization.
- **Loop/backedge priority**: backedge copies can dominate the greedy choice because removing them is highly profitable.
- **Order-sensitivity cases**: greedy order can change the chosen sharing, which is why the non-learning and learning variants are distinct.

For examples of those shapes in beginner-oriented form, use [`./wat-shapes.md`](./wat-shapes.md). For the proof mechanics, use [`./interference-and-ordering.md`](./interference-and-ordering.md).

## Current Starshine file map

Starshine now implements this pass as an active direct module pass. The relevant local files are implementation, scheduler, or neighboring surfaces:

| Local file | Exact role today |
| --- | --- |
| `src/passes/coalesce_locals.mbt:2-5,347-574,576-850,851-1031,1032-1057` | Active module-pass owner with action scan, value-aware interference, exact-type coloring, local-index rewrite, redundant-copy cleanup, dead-write cleanup, and local-name-section invalidation. |
| `src/passes/coalesce_locals_test.mbt:14-341` | Focused direct-pass and ordered-neighborhood tests for registration, non-overlap merge, different-value overlap, later reread liveness, redundant-copy cleanup, ineffective-write cleanup, `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals`, and `reorder-locals -> coalesce-locals -> reorder-locals`. |
| `src/passes/optimize.mbt:277` | `coalesce-locals` is an active module pass spelling. |
| `src/passes/pass_manager.mbt:8936` | Dispatches `coalesce-locals` to `coalesce_locals_run_module_pass`. |
| `src/passes/reorder_locals.mbt:2`, `src/passes/reorder_locals.mbt:118`, `src/passes/reorder_locals.mbt:183`, `src/passes/reorder_locals.mbt:544` | Neighboring module pass with local-summary, access scan, in-place index rewrite, and module-pass entry logic the coalescer must compose with. |
| `src/passes/simplify_locals.mbt:15`, `src/passes/simplify_locals.mbt:70`, `src/passes/simplify_locals.mbt:4126`, `src/passes/simplify_locals.mbt:4191`, `src/passes/simplify_locals.mbt:4245`, `src/passes/simplify_locals.mbt:4348` | Neighboring HOT local cleanup pass with local-traffic cleanup machinery, but not a slot-coalescing implementation. |
| `docs/wiki/binaryen/no-dwarf-default-optimize-path.md:33` | Canonical no-DWARF pipeline still records both `coalesce-locals` slots. |
| `docs/wiki/raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md` | Current ordered-slot proof: new in-tree regressions, refreshed 10k direct parity, and current-head debug-artifact replay for the reorder sandwich. |

## What this page rules out

- Do not cite `reorder_locals.mbt` as if it implements coalescing. It sorts and drops unaccessed body locals; it does not prove value-aware compatibility between two simultaneously live locals.
- Do not cite `simplify_locals.mbt` as if it implements coalescing. It rewrites local traffic and removes dead/equivalent writes; it does not merge declaration slots using liveness coloring.
- Do not treat `coalesce-locals` as permission to publicly schedule every late local-cleanup neighbor. The exact coalesce neighborhoods are now proven, but broader preset and reorder-locals scheduling claims still belong to their own slices.

## Validation guidance for the Starshine port

The active local port is signed off with:

- focused WAT tests for the exact families listed above,
- registry and explicit-pass CLI tests proving `coalesce-locals` remains active,
- repeated-pass idempotence tests because Binaryen can rerun the local cleanup cluster,
- pass-targeted fuzz compare against `wasm-opt --coalesce-locals`, and
- ordered no-DWARF replay for the exact local clusters that own this pass.

That ordered replay now exists in two forms:

- in-tree regressions for both exact neighborhoods in `src/passes/coalesce_locals_test.mbt`, and
- current-head debug-artifact replay for `reorder-locals -> coalesce-locals -> reorder-locals` at `.tmp/self-opt-cl-reorder-sandwich-20260508` with normalized WAT and canonical-function equality.

Keep the current pages explicit that direct-pass behavior and the exact `coalesce-locals` neighborhoods are now proven, while broader preset or neighboring-pass claims still belong to the surrounding backlog slices.
