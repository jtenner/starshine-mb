---
kind: concept
status: supported
last_reviewed: 2026-07-02
sources:
  - ../../../raw/research/1403-2026-07-02-optimize-casts-recursive-audit-kickoff.md
  - ../../../raw/binaryen/2026-04-22-optimize-casts-primary-sources.md
  - ../../../raw/binaryen/2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0260-2026-04-22-optimize-casts-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0364-2026-04-25-optimize-casts-current-main-and-test-map.md
  - ../../../raw/research/0469-2026-05-05-optimize-casts-current-main-recheck.md
  - ../../../raw/research/0537-2026-05-06-optimize-casts-direct-revalidation.md
  - ../../../raw/research/0551-2026-05-08-optimize-casts-ordered-slot-replay.md
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
  - ./fuzzing.md
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
- keep the canonical no-DWARF slot documented and now scheduled in public `optimize` / `shrink` at `heap2local -> optimize-casts -> local-subtyping -> coalesce-locals -> local-cse`
- keep the remaining follow-up focused on cast-family scope, trap timing, descriptor/branch-cast coverage, exact-ref reasoning, and broader artifact/full-path validation beyond the closed preset-readiness slice
- teach the surrounding GC/local cleanup dossiers that the active pass still has to compose with `heap2local`, `local-subtyping`, `coalesce-locals`, and `local-cse`
- keep the upstream-vs-local scope mismatch explicit instead of silently broadening the completed work

So this page is now a **status, parity, and remaining-neighborhood map** rather than a pre-port placeholder.

## Exact local code map today

The fastest read-along path through the current Starshine status is:

- active HOT implementation
  - `src/passes/optimize_casts.mbt`
    - removes provably redundant GC casts, folds statically known `ref.test` outcomes, and rewrites guaranteed-success / guaranteed-fail branch casts
- active dispatcher
  - `src/passes/pass_manager.mbt`
    - routes `"optimize-casts"` to `optimize_casts_run(...)`
- registry and category coverage
  - `src/passes/optimize.mbt`
    - tracks `"optimize-casts"` as an active pass name
- focused behavior tests
  - `src/passes/optimize_casts_test.mbt`
    - covers redundant `ref.cast`, guaranteed-true `ref.test`, descriptor casts/tests, guaranteed-success `br_on_cast` / `br_on_cast_fail`, and nullable-to-nonnull trap preservation
  - `src/passes/optimize_casts_wbtest.mbt`
    - covers the conservative negative heap/ref matcher for exact refs, abstract disjoint heaps, nullable non-null-target failures, and inexact-ref conservatism
- dedicated generated coverage
  - `src/validate/gen_valid.mbt` / `src/validate/gen_valid_tests.mbt`
    - register and test `optimize-casts-all` plus leaves for later reuse, early motion, barriers, best-cast, `ref.as_non_null`, static folds, and the GC/local cleanup neighborhood
  - `docs/wiki/binaryen/passes/optimize-casts/fuzzing.md`
    - documents the aggregate, selected-profile metadata, and current non-closeout status
- backlog and delivery plan
  - `agent-todo.md`
    - the standalone `[OC]005` ordered-slot / preset-readiness gate is closed on 2026-05-08
    - remaining broader GC/local follow-up now lives under neighboring backlog slices instead of a dedicated `OC` blocker
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

Today Starshine's behavior for `optimize-casts` is still deliberately limited, but the reopened audit has started landing source-backed local-flow subsets.

### 1. The active pass is narrow and direct-only

`src/passes/optimize_casts.mbt` currently owns a conservative HOT rewrite, not the whole upstream Binaryen strategy. It removes casts when the source reference type already satisfies the target, folds `ref.test` / `ref.test_desc` when the static source type guarantees success or failure, removes redundant `ref.cast_desc_eq`, rewrites guaranteed-success `br_on_cast` to an unconditional branch, rewrites single-ref guaranteed-fail `br_on_cast` to the fallthrough reference, rewrites guaranteed-success `br_on_cast_fail` to the fallthrough reference, rewrites guaranteed-fail `br_on_cast_fail` to an unconditional branch, preserves nullable-to-nonnull `ref.cast` trap behavior, and now has a conservative later-reuse subset for direct `ref.cast(local.get x)`, direct `ref.cast(local.tee x ...)`, direct nullable-source `ref.as_non_null(local.get x)`, and direct nullable-source `ref.as_non_null(local.tee x ...)` followed by later same-local root reads or later reads inside admitted branch-free fallthrough blocks before a same-local write. That later-reuse subset appends a nullable fresh local and normally wraps the original cast/as-non-null in `local.tee`; dropped value-block forms may lower the original dropped cast as `local.set`, but the observable reuse remains a fresh-local read. Starshine also has a first strict early-motion subset that duplicates a following dropped `ref.cast` or nullable-source `ref.as_non_null` onto an earlier dropped same-local `local.get` when the intervening window is empty or contains only a `nop`, dropped constant, dropped `i32.eqz`-of-constant, or dropped `i32.add`/`i32.mul`-of-constants root. The nullable-local choice is a Starshine local/validator constraint, not exact Binaryen body-local shape parity. Same-local `local.set` and `local.tee` roots are pre-scanned as write barriers so the pass does not retarget their own reads through the remembered refined local and does not carry facts past them. Roots that compute a same-local refinement are protected from retargeting unless the remembered best cast is strictly more refined than every refinement in the root, which keeps repeated identical and unrelated casts on the original local while allowing the Binaryen `best-2`-style narrower-then-broader cast source to reuse the earlier narrowed value. A narrow mixed `ref.cast`/`ref.as_non_null` gate also lets an earlier nullable best cast feed a later same-local `ref.as_non_null` source when the non-null version of the remembered cast type is more refined than the `ref.as_non_null` result; same-local writes still block that mixed reuse. Branch-free void block roots and single-child dropped value-block roots are scanned as fallthrough regions; structured-control roots that are not admitted by that narrow scanner do not seed refinement facts, so branch-skipped casts do not leak out as fresh-local reuse. Non-nullable `ref.as_non_null` sources are intentionally not materialized through this path because the original local is already refined.

The pass now also has a dedicated GenValid aggregate, `optimize-casts-all`, with singleton leaves for later reuse, early motion, barrier negatives, best-cast/subtype selection, `ref.as_non_null`, static folds, and the ordered GC/local neighborhood. The aggregate records each sampled leaf in the manifest `selected_profile` field. It is not a green closeout lane yet because it intentionally includes strict early-motion and broader local-flow families that are still only partially implemented; the early-motion subset still excludes calls, trapping/effectful roots, loads, structured control, non-constant pure trees, and broader unary/binary expression trees beyond the current constant `i32.eqz`/`i32.add`/`i32.mul` cases until each is source-backed and barrier-tested.

The 2026-05-06 direct revalidation ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts` and reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 Binaryen empty-recursion-group parser/canonicalization command failures. The 2026-05-06 branch-cast widening replayed the same 10000-case lane with `--out-dir .tmp/pass-fuzz-optimize-casts-oc-branch` and again reported 6759 compared cases, 6759 normalized matches, 0 semantic mismatches, and 20 command failures. The 2026-05-06 negative/exact-ref tightening ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --keep-going-after-command-failures --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts` and reported 9975 compared cases, 9975 normalized matches, 0 validation failures, 0 generator failures, 25 Binaryen command failures, and 0 mismatches. It also ran `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --generator gen-valid --pass optimize-casts --out-dir .tmp/pass-fuzz-optimize-casts-gen-valid` and reported 10000 compared cases, 10000 normalized matches, 0 validation failures, 0 generator failures, 0 command failures, and 0 mismatches. The 2026-05-08 ordered-slot replay refreshed the direct 10k lane (`.tmp/pass-fuzz-optimize-casts-oc005-20260508`) with 6759 compared cases, 6759 normalized matches, 0 mismatches, and 20 Binaryen command failures, then replayed `--heap2local --optimize-casts --local-subtyping --coalesce-locals --local-cse` on `tests/node/dist/starshine-debug-wasi.wasm` with normalized-WAT equality and canonical-function equality. That closes the public preset-slot proof and allows `optimize-casts` into `optimize` / `shrink`.

### 2. The remaining work is planned as parity follow-up, not an orphan idea

The standalone `OC` preset-readiness slice is now closed.
The remaining deliverables still point in the right general direction:

- GC cast tightening after `heap2local`
- explicit regression coverage for exact refs, nullability, and escaping values
- broader artifact/full-path proof for the remaining non-slice follow-up work

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
Starshine has an active MoonBit pass, dispatcher, registry, preset slot, focused static-fold tests, and a first conservative later-reuse subset, but it does **not** yet have the full two source-backed Binaryen local-flow phases from `OptimizeCasts.cpp`:

- strict earlier duplication of later `ref.cast` / `ref.as_non_null` values to earlier `local.get`s beyond the current empty, `nop`, dropped-const, dropped-`i32.eqz`-of-constant, and dropped-`i32.add`/`i32.mul`-of-constants subset, including wider pure windows and all effect/trap/control barriers
- full later reuse of already-computed best casts across Binaryen's broader fallthrough, adjacent-block, repeated-cast, and best-subtype cases beyond the current direct-root, narrower-then-broader source-retargeting, branch-free void-block, and dropped branch-free value-block fallthrough subsets
- full later reuse for `ref.as_non_null` beyond the current direct nullable-source root-linear subset
- green dedicated `optimize-casts-all` GenValid evidence after the still-open trigger families shrink
- final four-lane direct-pass signoff for the widened behavior

So the current repo status is best summarized as:

- active narrow static-folding pass plus first later-reuse subsets for `ref.cast`, nullable-source `ref.as_non_null`, direct `local.tee` sources, repeated-cast and unrelated-cast source protection, simple narrower-subtype best-cast selection including narrower-then-broader cast source retargeting and nullable-cast-to-`ref.as_non_null` source reuse, branch-free void fallthrough blocks, dropped branch-free value blocks, and strict empty, `nop`, dropped-const, dropped-`i32.eqz`-of-constant, and dropped-`i32.add`/`i32.mul`-of-constants early cast/as-non-null motion
- public preset slot and neighborhood proof from 2026-05-08
- stale upstream local-flow parity gaps now reopened under `[O4Z-AUDIT-OC]`
- a dedicated `optimize-casts-all` GenValid aggregate exists, but it is intentionally not a green closeout lane while broad early-motion/local-flow gaps remain

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

- **active narrow implementation with early later-reuse subsets and one strict empty/`nop`/dropped-const/dropped-`i32.eqz`-of-constant/dropped-`i32.add`/`i32.mul`-of-constants early-motion subset**
- **clear tracked status**
- **clear slot in the cleanup cluster**
- **clear neighboring implementation map for the remaining port**
- **clear warning not to silently broaden the reviewed upstream contract**
