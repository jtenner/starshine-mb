---
kind: concept
status: supported
last_reviewed: 2026-05-04
sources:
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../tuple-optimization/index.md
  - ../simplify-locals/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nonesting/index.md
  - ../reorder-locals/index.md
  - ../coalesce-locals/index.md
---

# Starshine `simplify-locals-nostructure` port readiness and validation

## Why this page exists

The landing, strategy, variant, and WAT-shape pages explain what Binaryen does.
This page answers the follow-along question:

- what is the smallest honest local slice?
- what must stay disabled so the sibling does not become full `simplify-locals`?
- what tests and oracle lanes prove the no-structure contract?

## Current hold point

Starshine still treats `simplify-locals-nostructure` as a removed compatibility name, not an active pass.
The state to preserve until implementation starts is:

- upstream Binaryen spelling: `simplify-locals-nostructure`
- current local spelling: `simplify-locals-no-structure`
- current local category: removed
- current CLI behavior: rejected as an unknown executable pass flag by the command-layer category gate
- current lower-level pipeline behavior: rejected as removed if it reaches the hot-pass expander
- current owner: none
- current preset role: none

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status and exact-slot blocker helper
  - `src/passes/optimize.mbt`
    - `pass_registry_removed_names()` includes `"simplify-locals-no-structure"`
    - `tuple_optimization_exact_slot_prereqs_ready()` stays false until both `code-pushing` and `simplify-locals-no-structure` stop being removed placeholders
    - the optimize/shrink preset lists stay honest instead of claiming the exact tuple slot prematurely
- direct regression proving the slot is still blocked
  - `src/passes/optimize_test.mbt`
    - the tuple-slot blocker regression keeps the current no-structure neighbor missing on purpose
- command-layer rejection for removed names
  - `src/cmd/cmd.mbt`
    - the CLI category gate still rejects the removed spelling instead of treating it as a runnable hot pass
- scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the early locals-cleanup slot where this pass belongs after `tuple-optimization` and before `vacuum -> reorder-locals`
- the nearest landed implementation surfaces a future port would compose with
  - `src/passes/simplify_locals.mbt`
    - current full `simplify-locals` descriptor, summary, sinkability logic, and cleanup phases
  - `src/passes/reorder_locals.mbt`
    - later local-index rewrite context for the same cleanup neighborhood
  - `src/passes/pass_manager.mbt`
    - active neighboring hot-pass dispatcher coverage, but no dedicated `simplify-locals-nostructure` case yet
- exact neighborhood dossiers that define the future slot
  - [`../tuple-optimization/index.md`](../tuple-optimization/index.md)
  - [`../simplify-locals/index.md`](../simplify-locals/index.md)
  - [`../simplify-locals-notee-nostructure/index.md`](../simplify-locals-notee-nostructure/index.md)
  - [`../simplify-locals-nonesting/index.md`](../simplify-locals-nonesting/index.md)
  - [`../reorder-locals/index.md`](../reorder-locals/index.md)
  - [`../coalesce-locals/index.md`](../coalesce-locals/index.md)

That map is refreshed by the 2026-05-04 current-main recheck: readers can jump directly from the upstream algorithm to exact local status, the tuple-slot honesty rule, and the nearest landed MoonBit locals cleanup surfaces.

## What Starshine currently does for this pass name

Today Starshine's behavior for `simplify-locals-nostructure` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps the local spelling `simplify-locals-no-structure` in the removed-name registry.
That means:

- the project still treats the upstream pass as a real missing pass
- the local compatibility spelling is preserved in the registry surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The pass already blocks one honest tuple slot

The most concrete current Starshine strategy fact lives in `tuple_optimization_exact_slot_prereqs_ready()`.
That helper requires both:

- `code-pushing`
- `simplify-locals-no-structure`

to become active before Starshine will claim the exact Binaryen tuple slot publicly.

The current tuple-slot regression in `src/passes/optimize_test.mbt` locks that honesty rule in place.

So the repo already treats `simplify-locals-nostructure` as a real scheduling blocker, not just as a name on a wish list.

### 3. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives the pass a real backlog slice under `SLNS`.
The current deliverables point in the right direction:

- simplify sets, gets, and dead locals without creating new structured returns
- preserve later coalescing opportunities
- add regressions for tee-like traffic and tuple scratch locals
- replay parity on the debug artifact in the intended early slot

That is a useful local framing because it matches the reviewed upstream contract much better than a vague “port simplify-locals earlier” description.

### 4. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places the pass in the canonical no-DWARF function pipeline:

- `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals`

That matters because the pass is not meant to run in isolation.
Upstream Binaryen expects:

- tuple cleanup to expose early local carriers first
- no-structure local sinking to trim those carriers without inventing new block / `if` / loop results
- `vacuum` to remove the leftover garbage
- `reorder-locals` to benefit from the cleaner early local set

That cluster story is part of the local strategy even before a MoonBit implementation exists.

## The right future Starshine implementation shape

The current docs and neighboring code strongly suggest that a future local `simplify-locals-nostructure` port should be taught as an **early HOT local-traffic cleanup pass without structure synthesis**, not as a renamed copy of full `simplify-locals`.

Why:

- Binaryen runs it in an earlier slot than full `simplify-locals`
- the exact upstream contract is still tee-enabled and nesting-enabled, but structure-disabled
- Starshine already has nearby sinkability and conflict machinery in `simplify_locals.mbt`
- Starshine already has a later local-index rewrite neighbor in `reorder_locals.mbt`
- the explicit tuple-slot gate proves the pass matters to honest scheduler placement today

So the local strategy should be thought of as:

1. identify a HOT-level representation of the real upstream families
   - single-use sinks into existing consumers
   - later tee creation for multi-use locals
   - overwrite cleanup and dead-local cleanup
   - no block / `if` / loop result synthesis
2. preserve the same correctness boundaries locally
   - first-cycle single-use-only rule
   - later tee-enabled sinking
   - directional effect invalidation
   - explicit `try` / `try_table` throwing-value barriers
   - late equivalent-get cleanup
3. keep the scheduler story honest
   - land the real pass after `tuple-optimization`
   - keep it before `vacuum -> reorder-locals`
   - do not claim the public tuple slot until both missing neighbors really exist
4. preserve the handoff to later cleanup neighbors
   - let `vacuum`, `reorder-locals`, and later `coalesce-locals` / full `simplify-locals` consume the earlier cleanup work instead of trying to subsume them all here

In other words, the future port should slot into a local cleanup ecosystem that partly exists already.

## The most important local dependency map

### Upstream `simplify-locals-nostructure` is the missing right neighbor for `tuple-optimization`

See [`../tuple-optimization/index.md`](../tuple-optimization/index.md).

Why it matters locally:

- the current tuple-slot gate in `src/passes/optimize.mbt` already treats `simplify-locals-no-structure` as the missing right neighbor
- a future Starshine port should therefore validate not only the pass in isolation, but also the real `tuple-optimization -> simplify-locals-nostructure` neighborhood
- that is the most concrete current reason this pass matters even before it has an owner file

### Existing Starshine `simplify-locals` code is the nearest landed local reasoning surface

See [`../simplify-locals/index.md`](../simplify-locals/index.md), `src/passes/simplify_locals.mbt`, and `src/passes/pass_manager.mbt`.

Why:

- the current HOT locals helper surfaces already model sink candidates, conflict checks, and cleanup phases in MoonBit form
- the current full-pass tests already exercise local traffic, overwrite barriers, and condition-boundary cases that are close to the kinds of safety questions a future early port will face

So the current local implementation map for `simplify-locals-nostructure` begins here, even before a dedicated owner file exists.

### Existing Starshine `reorder-locals` code is the nearest landed local-index rewrite surface

See [`../reorder-locals/index.md`](../reorder-locals/index.md) and `src/passes/reorder_locals.mbt`.

Why:

- an eventual `simplify-locals-nostructure` port will reduce and reshape local traffic before the first reorder pass
- Starshine already has a module pass that scans local users and rewrites local indices in one canonical place
- `reorder_locals` gives future contributors an in-repo model for local-index rewrites and local metadata stability work

That does not make `reorder-locals` an implementation of this pass, but it does make it an important local read-along file.

### Later local cleanup still matters

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen uses this pass early, before later local-slot compaction and later full local cleanup
- future Starshine work should therefore avoid broadening `simplify-locals-nostructure` until it silently subsumes later cleanup families
- the pass should leave later local-slot and full-structure cleanup opportunities intact, just like the backlog wording already says

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `simplify-locals-nostructure`
- pass-specific candidate collection for the early no-structure variant
- pass-specific tee/no-structure regression tests
- pass-specific CLI execution coverage beyond the tracked registry, tuple-slot gate, backlog, and neighboring simplify-locals replay surfaces

So the current repo status is best summarized as:

- name tracked
- slot blocker tracked
- backlog tracked
- scheduler slot documented
- neighboring local cleanup and rewrite files implemented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - single-use sinks into existing consumers
   - later tee positives for multi-use locals
   - overwrite cleanup and dead-local cleanup
   - preserved block / `if` / loop result structure
2. negative correctness tests
   - effect barriers
   - `try` / `try_table` throwing-value barriers
   - no accidental block / `if` / loop result synthesis
   - tuple scratch-local cases that still need no-structure cleanup without broadening into full `simplify-locals`
3. cluster interaction tests
   - `tuple-optimization -> simplify-locals-nostructure`
   - `simplify-locals-nostructure -> vacuum`
   - `vacuum -> reorder-locals`
4. artifact and oracle comparison
   - the `SLNS` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path once the exact slot becomes locally representable
   - pass-targeted Binaryen comparison against `--simplify-locals-nostructure`

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and the exact neighboring code surfaces.

## What not to do

Do not start by routing this name to the active full `simplify-locals` implementation.
That would immediately violate the Binaryen contract because the active pass has structure rewrites and ordinary nested sinks that the no-structure variant must reject.

Do not add the pass to `optimize` or `shrink` presets during the first port.
The source-backed role is a tuple-neighbor / explicit-pipeline sibling, not part of the current Starshine no-DWARF preset.

Do not hide the local spelling mismatch.
The current repo says `simplify-locals-no-structure`; the upstream pass says `simplify-locals-nostructure`.
A faithful port should make that choice visible in tests.

## Sources

- [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md`](../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md)
- [`../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md`](../../../raw/research/0117-2026-04-20-simplify-locals-nostructure-binaryen-research.md)
- Binaryen `version_129` pass source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Binaryen `version_129` scheduler source: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` after-inlining helper: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Binaryen `version_129` helper sources:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Binaryen `version_129` dedicated tests:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
