---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-flatten-primary-sources.md
  - ../../binaryen/passes/flatten/index.md
  - ../../binaryen/passes/flatten/binaryen-strategy.md
  - ../../binaryen/passes/flatten/flat-ir-contract-and-preludes.md
  - ../../binaryen/passes/flatten/wat-shapes.md
  - ../../binaryen/passes/flatten/starshine-strategy.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/cli/cli_test.mbt
  - 0065-2026-03-24-ir2-execution-plan.md
  - 0063-2026-03-24-pass-port-batches-and-registry-map.md
  - ../../../../agent-todo.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
  - ../../binaryen/passes/local-cse/index.md
  - ../../binaryen/passes/rereloop/index.md
  - ../../binaryen/passes/i64-to-i32-lowering/index.md
  - ../../binaryen/passes/simplify-locals-nonesting/index.md
  - ../../binaryen/passes/souperify/index.md
---

# `flatten` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `flatten` dossier already had a useful landing page, Binaryen strategy page, flat-IR mechanics page, and WAT-shape catalog.
However, it still had four durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the landing page still carried stale campaign wording from when `flatten` was the leading wiki-status-`none` target
- the touched catalogs still described the folder only as upstream research, without a clean bridge to the exact in-repo Starshine status and future port surfaces

This follow-up closes the provenance gap, adds the missing local strategy page, repairs the stale landing-page framing, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future port planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-flatten-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `Flatten.cpp` on `version_129` and `main`
- `flat.h` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `eh-utils.h`, `branch-utils.h`, `properties.h`, and `manipulation.h`
- the dedicated `flatten.wast`, `flatten_all-features.wast`, and `flatten-eh-legacy.wast` files
- the neighboring `opt_flatten.wast`, `flatten_rereloop.wast`, and `flatten_i64-to-i32-lowering.wast` files that show how other upstream passes consume flattened input

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/cli/cli_test.mbt`
- `docs/0065-2026-03-24-ir2-execution-plan.md`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- `agent-todo.md`
- the neighboring living dossiers for `simplify-locals-notee-nostructure`, `local-cse`, `rereloop`, `i64-to-i32-lowering`, `simplify-locals-nonesting`, and `souperify`

## Durable findings

### 1. The Binaryen explanation was already strong; the missing pieces were provenance and the local bridge

The existing upstream-facing pages were still broadly correct.
The missing pieces were:

- one immutable raw source manifest anchoring the exact official release/source/test URLs rechecked in this run
- one dedicated Starshine strategy page explaining the exact current local status and landing zone
- removal of stale campaign wording that no longer matched the folder's current role

So the right maintenance action was to add provenance and the local bridge, not to rewrite the core `flatten` explanation from scratch.

### 2. The official release/source freshness story is now explicit instead of scattered

The new raw manifest records the exact primary-source surface rechecked on 2026-04-23.
The most important provenance point is simple and worth keeping visible:

- on 2026-04-23 the official Binaryen GitHub `version_129` release page still showed publish date **2026-04-01**

The narrow current-`main` check in this run did not surface a new teaching-relevant contract drift beyond the current dossier's claims.
That lets the living folder cite one stable provenance anchor instead of relying on older scattered notes.

### 3. The honest Starshine story for `flatten` is currently registry tracking plus batch planning, not an implementation file

`flatten` is still unimplemented in Starshine.
There is no `src/passes/flatten.mbt` owner file today.

But the repo does have a real local status surface that was worth gathering in one place:

- `src/passes/optimize.mbt` keeps `flatten` in the removed-name registry
- `src/cli/cli_test.mbt` already preserves the public `--flatten` spelling in flag-order tests
- `docs/0065-2026-03-24-ir2-execution-plan.md` still puts `flatten` first in the preferred Batch 2 implementation order
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md` still records `flatten` in Batch 2 removed-until-landed planning
- `agent-todo.md` still has no dedicated `flatten` slice, which is an important local planning gap to say out loud instead of smoothing over

Before this run, that local state was scattered.
The new Starshine page turns it into one read-along path.

### 4. `flatten` should be taught locally as a cluster-root structural normalizer, not as just another cleanup pass

Re-reading the neighboring dossiers reinforces the most important planning point:

- `flatten` feeds `simplify-locals-notee-nostructure` and `local-cse` in the aggressive upstream cluster
- `rereloop` depends on already-flattened input rather than replacing `flatten`
- `i64-to-i32-lowering` treats flattened input as a real prerequisite
- `simplify-locals-nonesting` and `souperify` also depend on teaching the flatten-created world precisely

So the future local port should not be framed as generic “remove nesting.”
It is the structural cluster root that creates the input shape later flatness-sensitive passes rely on.

### 5. The current local planning gap is real and should stay explicit

Unlike several neighboring unimplemented passes, `flatten` still has no dedicated release-slice section in `agent-todo.md` today.
The older `docs/0065...` and `docs/0063...` batch plans still carry the useful intent, but the active backlog does not yet expose a focused `flatten` slice with concrete deliverables.

That absence is worth preserving explicitly for future contributors because it is a real project-state fact, not documentation noise.
The new Starshine page records that gap instead of pretending a modern local slice already exists.

### 6. The future local landing zone is concrete enough to document now

The new Starshine page records the most useful exact read-along path for a future port:

- removed-name registry truth in `src/passes/optimize.mbt`
- public CLI spelling stability in `src/cli/cli_test.mbt`
- current batch intent in `docs/0065-2026-03-24-ir2-execution-plan.md` and `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
- the missing active-slice gap in `agent-todo.md`
- the exact upstream-neighbor dossiers that define the intended cluster: `simplify-locals-notee-nostructure`, `local-cse`, `rereloop`, `i64-to-i32-lowering`, `simplify-locals-nonesting`, and `souperify`

That map is useful now even before any `flatten.mbt` file exists because it shows readers where the exact current local status lives and which future landing zone the port must serve.

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-flatten-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0267-2026-04-23-flatten-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/flatten/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/flatten/index.md`
- `docs/wiki/binaryen/passes/flatten/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/flatten/wat-shapes.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `flatten` work needs a clean provenance-plus-port-planning path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-flatten-primary-sources.md`
2. `docs/wiki/binaryen/passes/flatten/index.md`
3. `docs/wiki/binaryen/passes/flatten/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/flatten/flat-ir-contract-and-preludes.md`
5. `docs/wiki/binaryen/passes/flatten/wat-shapes.md`
6. `docs/wiki/binaryen/passes/flatten/starshine-strategy.md`
7. `src/passes/optimize.mbt`
8. `src/cli/cli_test.mbt`
9. `docs/0065-2026-03-24-ir2-execution-plan.md`
10. `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`
11. `agent-todo.md`
12. `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/index.md`
13. `docs/wiki/binaryen/passes/local-cse/index.md`
14. `docs/wiki/binaryen/passes/rereloop/index.md`
15. `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
16. `docs/wiki/binaryen/passes/simplify-locals-nonesting/index.md`
17. `docs/wiki/binaryen/passes/souperify/index.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status, the still-missing active backlog slice, and the neighboring local dossiers that explain why `flatten` is the structural root of several later aggressive-pass stories rather than just another isolated cleanup pass.
