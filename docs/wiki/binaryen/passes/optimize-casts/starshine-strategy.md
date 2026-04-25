---
kind: concept
status: supported
last_reviewed: 2026-04-25
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/ir/hot_core.mbt
  - ../../../../../src/ir/hot_flags.mbt
  - ../../../../../src/ir/hot_lift.mbt
  - ../../../../../src/ir/hot_lower.mbt
  - ../../../../../src/binary/encode.mbt
  - ../../../../../src/binary/decode.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/wast/lower_to_lib.mbt
  - ../../../../../agent-todo.md
  - ../../no-dwarf-default-optimize-path.md
  - ../heap2local/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./two-phase-dataflow.md
  - ./wat-shapes.md
  - ../heap2local/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine Strategy For `optimize-casts`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md) and the current-main implementation/test bridge in [`../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`optimize-casts` is still **unimplemented** in Starshine.
There is no `src/passes/optimize_casts.mbt` owner file today.

That does **not** mean there is no Starshine strategy surface.
The current local strategy is registry and cluster planning:

- keep the pass spelling tracked in the registry surface
- keep the canonical no-DWARF slot documented
- keep the backlog slice focused on cast-family scope, trap timing, and artifact validation
- teach the surrounding GC/local cleanup dossiers a future port would need to compose with
- keep the upstream-vs-backlog scope mismatch explicit instead of silently broadening the planned work

So this page is intentionally a **status-and-port-map** page rather than a fake implementation page.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- tracked but removed pass-name status
  - `src/passes/optimize.mbt:145-152`
    - `pass_registry_removed_names()` includes `"optimize-casts"`
- no active dispatcher
  - `src/passes/pass_manager.mbt`
    - no `optimize-casts` case exists today
- backlog and delivery plan
  - `agent-todo.md:355-364`
    - `#### OC - Optimize Casts`
    - `[OC]001 - Cast Tightening Rules`
    - `[OC]002 - GC Regression Matrix and Artifact Compare`
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the GC/local cleanup slot where `optimize-casts` belongs after `heap2local` and before `local-subtyping -> coalesce-locals -> local-cse`
- surrounding living dossiers a future port must line up with
  - `docs/wiki/binaryen/passes/heap2local/index.md`
  - `docs/wiki/binaryen/passes/local-subtyping/index.md`
  - `docs/wiki/binaryen/passes/coalesce-locals/index.md`
  - `docs/wiki/binaryen/passes/local-cse/index.md`

The implementation/test-map page adds the exact reusable local primitive map for a future port: `src/lib/types.mbt:723-764`, `src/lib/types.mbt:3995-3996`, `src/lib/types.mbt:4170-4171`, `src/wast/lower_to_lib.mbt:1297-1298`, `src/binary/encode.mbt:2580`, `src/binary/encode.mbt:2897-2912`, `src/binary/decode.mbt:3116-3124`, `src/validate/typecheck.mbt:3228`, `src/validate/typecheck.mbt:3265`, `src/ir/hot_core.mbt:70-73`, `src/ir/hot_flags.mbt:81`, `src/ir/hot_lift.mbt:612-625`, `src/ir/hot_lift.mbt:764-818`, and `src/ir/hot_lower.mbt:1080-1084`.

That code-and-doc map is the practical addition in this follow-up: readers can now jump directly from the upstream algorithm to the exact local status and future landing zone.

## What Starshine currently does for this pass name

Today Starshine's behavior for `optimize-casts` is deliberately limited.

### 1. The name is tracked, not forgotten

`src/passes/optimize.mbt` keeps `optimize-casts` in `pass_registry_removed_names()`.
That means:

- the project still treats `optimize-casts` as a real known pass
- the spelling is preserved in the registry-level compatibility surface
- the pass remains visible in tracker and backlog work instead of silently falling out of planning

That is the right current behavior for an unimplemented parity pass.

### 2. The work is planned as a parity slice, not an orphan idea

`agent-todo.md` already gives `optimize-casts` a real backlog slice under `OC`.
The current deliverables point in the right general direction:

- GC cast tightening after `heap2local`
- explicit regression coverage for exact refs, nullability, and escaping values
- artifact-level proof before calling the slot done

But one important mismatch needs to stay explicit.
The current backlog wording still says a future port should cover `ref.cast`, `ref.test`, nullability, and subtype simplifications.
The reviewed Binaryen `version_129` source does **not** support that broad reading.

Current source-backed teaching should stay:

- `optimize-casts` handles **`ref.cast` and `ref.as_non_null` only** in the reviewed upstream oracle
- future Starshine work should preserve that scope unless a newer upstream source or a deliberate local design doc widens it on purpose

The docs should not smooth that contradiction away.

### 3. The scheduler slot is already documented

`docs/wiki/binaryen/no-dwarf-default-optimize-path.md` already places `optimize-casts` in the middle of the GC/local cleanup cluster.
That matters because this pass is not meant to run in isolation.
Upstream Binaryen expects `heap2local` to expose stronger local cast facts first, and then expects `local-subtyping`, `coalesce-locals`, and `local-cse` to exploit the cleaner refined-local traffic afterwards.

That cluster story is part of the local strategy even before a MoonBit implementation exists.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that a future local `optimize-casts` port should be taught as a **mid-cluster HOT GC/local rewrite family**, not as an isolated generic cast optimizer.

Why:

- Binaryen runs it immediately after `heap2local`
- the strict earlier-motion half is useful only while subtype facts are strongest
- the looser later-reuse half exists to expose cleaner refined-local traffic for `local-subtyping`, `coalesce-locals`, and `local-cse`
- the current local dossiers for those neighboring passes already explain the pressures a future port would need to preserve

So the local strategy should be thought of as:

1. identify a HOT-level representation of Binaryen's two upstream halves
   - strict earlier cast duplication inside narrow linear windows
   - looser later reuse via a fresh refined carrier local
2. preserve the same correctness boundaries locally
   - `ref.cast` and `ref.as_non_null` only
   - strict trap-timing barriers for earlier motion
   - same-index local-write invalidation
   - no fake CFG-wide reasoning beyond the reviewed window rules
3. keep the scheduler story honest
   - land the real pass after `heap2local`
   - keep it before `local-subtyping -> coalesce-locals -> local-cse`
4. preserve the handoff to later local cleanup neighbors
   - let later passes consume the refined-local traffic instead of trying to subsume them

In other words, the future port should slot into a local GC/local cleanup ecosystem that is already documented.

## The most important local dependency map

### Upstream `optimize-casts` is downstream of `heap2local`

See [`../heap2local/index.md`](../heap2local/index.md).

Why it matters locally:

- Binaryen runs `heap2local` first so local GC values and casts are easier to reason about
- the current Starshine `heap2local` dossier already explains the local direct-array and allocation-localization subset that can expose the right castable traffic
- a future Starshine `optimize-casts` port should therefore validate not only `--optimize-casts` in isolation, but also the real `heap2local -> optimize-casts` neighborhood

### Upstream `optimize-casts` is the immediate left neighbor of `local-subtyping`

See [`../local-subtyping/index.md`](../local-subtyping/index.md).

Why:

- Binaryen expects cast reuse to sharpen local-flow facts before declaration narrowing runs
- the scheduler note in the no-DWARF page keeps that exact order explicit
- a future local implementation should therefore treat `optimize-casts` as a feeder for local-type narrowing, not as a replacement for it

### The next pressure is `coalesce-locals`

See [`../coalesce-locals/index.md`](../coalesce-locals/index.md).

Why:

- Binaryen places `coalesce-locals` immediately after `local-subtyping`
- the local cleanup cluster expects narrowing to happen before coalescing widens or merges traffic again
- a future local implementation should preserve that ordering pressure instead of treating all local cleanup as interchangeable

### Late reuse cleanup still matters

See [`../local-cse/index.md`](../local-cse/index.md).

Why:

- the later-reuse half of `optimize-casts` intentionally materializes fresh refined locals and `local.tee`s
- `local-cse` is one of the later neighboring passes expected to profit from the clearer local-value flow rather than to be replaced by it

So a future local implementation should keep the `optimize-casts -> local-cse` relationship explicit.

## What Starshine does **not** have yet

A future contributor should be careful not to overread the current local surface.
Starshine does **not** currently have:

- a MoonBit implementation file for `optimize-casts`
- HOT or raw candidate collection for earlier-cast duplication or later refined-local reuse
- pass-specific local invalidation machinery for same-index writes in this pass
- pass-specific tests or CLI execution coverage beyond the tracked registry and backlog surfaces

So the current repo status is best summarized as:

- name tracked
- backlog tracked
- scheduler slot documented
- neighboring GC/local passes documented
- transform itself not yet landed

## Validation plan for the eventual port

The existing backlog plus neighboring pass docs imply the right validation ladder.
A future real implementation should validate in this order:

1. reduced shape tests for the real upstream families
   - earlier `ref.cast` duplication in strict linear windows
   - earlier `ref.as_non_null` duplication only when the target local is nullable
   - later refined-local reuse via fresh carrier locals
2. negative correctness tests
   - same-index `local.set` barriers
   - side-effect and call barriers for earlier motion
   - non-linear-window bailouts
   - unsupported `ref.test` and other wider cast-family negatives
3. cluster interaction tests
   - `heap2local -> optimize-casts`
   - `optimize-casts -> local-subtyping`
   - `local-subtyping -> coalesce-locals`
   - `coalesce-locals -> local-cse`
4. artifact and oracle comparison
   - the `OC` slice in `agent-todo.md`
   - the canonical no-DWARF debug-artifact replay path

That is more useful locally than a generic “compare with Binaryen later” note because it points directly at the in-repo workflow and keeps the pass-scope warning explicit.

## Bottom line

Current Starshine `optimize-casts` strategy is honest registry and cluster planning:

- the pass name is intentionally preserved in `src/passes/optimize.mbt`
- the backlog already treats it as a real GC/local parity slice under `OC`
- the canonical slot is already documented in the no-DWARF optimizer notes
- the surrounding `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse` dossiers already define the practical landing zone for a future port
- the docs now keep one important contradiction explicit: the current Binaryen oracle is `ref.cast` plus `ref.as_non_null`, even though the backlog wording is still broader

So the right mental model today is not “nothing exists locally.”
It is:

- **no transform yet**
- **clear tracked status**
- **clear slot in the cleanup cluster**
- **clear neighboring implementation map for the eventual port**
- **clear warning not to silently broaden the reviewed upstream contract**
