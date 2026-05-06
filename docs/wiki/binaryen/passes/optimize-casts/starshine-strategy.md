---
kind: concept
status: supported
last_reviewed: 2026-05-06
sources:
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md
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
  - ./starshine-port-readiness-and-validation.md
  - ../heap2local/index.md
  - ../local-subtyping/index.md
  - ../coalesce-locals/index.md
  - ../local-cse/index.md
---

# Starshine Strategy For `optimize-casts`

Use this page together with the raw primary-source manifest in [`../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md`](../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md), the current-main implementation/test bridge in [`../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md), the 2026-05-05 freshness recheck in [`../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md), and the dedicated port-readiness bridge in [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).
The goal here is not to re-explain upstream Binaryen, but to show the exact current Starshine status, the local code and doc surfaces that already track the pass, and the concrete neighboring implementation areas a future port would have to hook into.

## The honest current status

`optimize-casts` now has an active narrow HOT implementation in Starshine.
The current owner file is `src/passes/optimize_casts.mbt`, with dispatcher coverage in `src/passes/pass_manager.mbt`, registry coverage in `src/passes/optimize.mbt`, and focused tests in `src/passes/optimize_casts_test.mbt`.

The current local strategy is direct-pass parity plus conservative cluster planning:

- keep the active pass spelling and category tracked in the registry surface
- keep the canonical no-DWARF slot documented but out of public presets until the neighborhood is proven
- keep the backlog slice focused on cast-family scope, trap timing, descriptor/branch-cast coverage, exact-ref reasoning, and artifact validation
- teach the surrounding GC/local cleanup dossiers that the active pass still has to compose with `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse`
- keep the upstream-vs-local scope mismatch explicit instead of silently broadening the completed work

So this page is now a **status, parity, and remaining-neighborhood map** rather than a pre-port placeholder.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active HOT implementation
  - `src/passes/optimize_casts.mbt`
    - removes provably redundant GC casts, folds statically known `ref.test` outcomes, and rewrites guaranteed-success branch casts
- active dispatcher
  - `src/passes/pass_manager.mbt`
    - routes `"optimize-casts"` to `optimize_casts_run(...)`
- registry and category coverage
  - `src/passes/optimize.mbt`
    - tracks `"optimize-casts"` as an active pass name
- focused behavior tests
  - `src/passes/optimize_casts_test.mbt`
    - covers redundant `ref.cast`, guaranteed-true `ref.test`, descriptor casts/tests, guaranteed-success `br_on_cast` / `br_on_cast_fail`, and nullable-to-nonnull trap preservation
- backlog and delivery plan
  - `agent-todo.md`
    - `#### OC - Optimize Casts Follow-up`
    - `[OC]003`, `[OC]004`, and `[OC]005` track descriptor/branch-cast expansion, exact-ref tightening, ordered-neighborhood proof, and preset readiness
- canonical scheduler context
  - `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
    - the GC/local cleanup slot where `optimize-casts` belongs after `heap2local` and before `local-subtyping -> coalesce-locals -> local-cse`
- surrounding living dossiers future ordered proof must line up with
  - `docs/wiki/binaryen/passes/heap2local/index.md`
  - `docs/wiki/binaryen/passes/local-subtyping/index.md`
  - `docs/wiki/binaryen/passes/coalesce-locals/index.md`
  - `docs/wiki/binaryen/passes/local-cse/index.md`

The implementation/test-map page adds the exact reusable local primitive map for active and future `optimize-casts` work: `src/lib/types.mbt:723-764`, `src/lib/types.mbt:3995-3996`, `src/lib/types.mbt:4170-4171`, `src/wast/lower_to_lib.mbt:1297-1298`, `src/binary/encode.mbt:2580`, `src/binary/encode.mbt:2897-2912`, `src/binary/decode.mbt:3116-3124`, `src/validate/typecheck.mbt:3228`, `src/validate/typecheck.mbt:3265`, `src/ir/hot_core.mbt:70-73`, `src/ir/hot_flags.mbt:81`, `src/ir/hot_lift.mbt:612-625`, `src/ir/hot_lift.mbt:764-818`, and `src/ir/hot_lower.mbt:1080-1084`.

The readiness bridge now owns the implementation ladder and validation order so this page can stay focused on current status, scope honesty, and exact local code-map pointers.

## What Starshine currently does for this pass name

Today Starshine's behavior for `optimize-casts` is deliberately limited.

### 1. The active pass is narrow and direct-only

`src/passes/optimize_casts.mbt` currently owns a conservative HOT rewrite, not the whole upstream Binaryen strategy. It removes casts when the source reference type already satisfies the target, folds `ref.test` / `ref.test_desc` when the static source type guarantees success, removes redundant `ref.cast_desc_eq`, rewrites guaranteed-success `br_on_cast` to an unconditional branch, rewrites guaranteed-success `br_on_cast_fail` to the fallthrough reference, and preserves nullable-to-nonnull `ref.cast` trap behavior.

The 2026-05-06 direct revalidation ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts` and reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. The 2026-05-06 branch-cast widening replayed the same 10000-case lane with `--out-dir .tmp/pass-fuzz-optimize-casts-oc-branch` and again reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 command failures. This keeps direct parity green, but it does not prove the public preset slot.

### 2. The remaining work is planned as parity follow-up, not an orphan idea

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

That cluster story remains part of the local strategy even though the direct pass is active.

## The right future Starshine implementation shape

The current docs and neighboring passes strongly suggest that future `optimize-casts` widening should stay a **mid-cluster HOT GC/local rewrite family**, not become an isolated generic cast optimizer.

Why:

- Binaryen runs it immediately after `heap2local`
- the strict earlier-motion half is useful only while subtype facts are strongest
- the looser later-reuse half exists to expose cleaner refined-local traffic for `local-subtyping`, `coalesce-locals`, and `local-cse`
- the current local dossiers for those neighboring passes already explain the pressures future ordered proof would need to preserve

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

## Validation bridge

See [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the implementation ladder, negative families, neighborhood order, and oracle comparison plan.

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
