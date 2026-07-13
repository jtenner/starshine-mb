---
kind: concept
status: supported
last_reviewed: 2026-07-04
sources:
  - ../../../raw/research/1443-2026-07-04-coalesce-locals-o4z-neighborhood-structured-tee.md
  - ../../../raw/research/1442-2026-07-04-coalesce-locals-direct-refresh-loop-unused-locals.md
  - ../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md
  - ../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md
  - ../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md
  - ../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md
  - ../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md
  - ../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/reorder_locals.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/optimize_test.mbt
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./interference-and-ordering.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ../local-subtyping/index.md
  - ../local-cse/index.md
  - ../reorder-locals/index.md
  - ../simplify-locals/index.md
---

# Starshine `coalesce-locals` port readiness and validation matrix

This page is the implementation-readiness and validation bridge for the active local `coalesce-locals` pass.
It does not replace the upstream strategy or shape catalog.
Instead, it answers: which Starshine surfaces are now active, which placement/artifact caveats remain, and which Binaryen shape families are locked by tests first?

## Current readiness snapshot

| Area | Current Starshine state | Port implication |
| --- | --- | --- |
| Registry | `src/passes/optimize.mbt:277` tracks `coalesce-locals` as an active module pass. | Keep the public spelling stable. |
| Dispatcher | `src/passes/pass_manager.mbt:8936` dispatches to `coalesce_locals_run_module_pass`. | Direct `--coalesce-locals` requests are active and covered by registry/CLI tests. |
| Presets | `src/passes/optimize_test.mbt` now locks both live public `coalesce-locals` neighborhoods: `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` and the late `simplify-locals -> vacuum -> reorder-locals -> coalesce-locals -> reorder-locals -> vacuum` cleanup cluster. | Preserve both proven slots; future preset work belongs to remaining neighboring owners, not CL/RL slot uncertainty. |
| Ordered-slot proof | `src/passes/coalesce_locals_test.mbt` and `docs/wiki/raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md` now cover both exact neighborhoods. | Treat `[CL]003` as closed; future work belongs to neighboring-pass or preset slices, not direct `coalesce-locals` uncertainty. |
| Local-index rewrite substrate | `src/passes/reorder_locals.mbt:118`, `:183`, and `:544` already scan and rewrite local users and rebuild declarations for a landed module pass. | Reuse the local-index and metadata-repair lessons; do not copy the exact reorder algorithm as the coalescing algorithm. |
| Later cleanup substrate | `src/passes/simplify_locals.mbt:70`, `:4126`, `:4191`, `:4245`, and `:4348` already own HOT local-traffic cleanup phases. | Let later cleanup remain a consumer; do not grow `coalesce-locals` into generic simplify-locals. |
| Core pass | `src/passes/coalesce_locals.mbt` implements action scanning, value-aware interference, exact-type greedy coloring, index rewrite, redundant-copy cleanup, ineffective-write cleanup with branch-aware structured effective-write marking, effective-copy weighting and copy-connected-first coloring order, structured param-slot reuse, non-loop structured `local.tee` coalescing under the conservative interference overlay, structured self-copy cleanup, bounded structured copy-chain forwarding and derived branch-carrier consume-forwarding into dead slots with destination-read-after-source-write rejection, source-write/destination-read interference restoration after copy/consume relaxation, path-disjoint branch-result slot reuse with same-path clobber-read guards, structured ineffective-write cleanup, conservative loop unused-local and unread/write-only scratch coalescing, a 4096-flattened-local guard around dense non-loop coloring, name-section invalidation, and the `[AUDIT006-D]` TypeIdx/RecIdx invariant comment. | Keep future changes parity-driven and add focused fixtures before changing coloring or cleanup behavior; replace the huge-local boundary with sparse coloring before claiming Binaryen shape parity above the guard. |

## Landed direct-pass shape

The landed Starshine port is deliberately narrow:

1. collect locals, declared types, params, and synthetic zero-init facts for one function;
2. walk local uses/defs with enough liveness information to reject different-value overlap;
3. allow same-value overlap only when a local value-number proof is available;
4. require exact type equality for all locals sharing a final index;
5. allow body locals to reuse compatible param slots only when liveness proves the param slot is no longer live;
6. choose an index mapping using the Binaryen-tested greedy-order objective;
7. rewrite local indices and declarations through module-safe metadata repair;
8. delete redundant copies and dead sets only when the value/effect rules are already proven;
9. refinalize or revalidate after any dead tee / unreachable cleanup family that can change expression types;
10. compare isolated pass output first, and leave surrounding Binaryen order for separate preset/neighborhood replay.

This keeps the pass aligned with [`./binaryen-strategy.md`](./binaryen-strategy.md) and avoids two common overextensions:

- subtype-aware merging, which belongs outside default `coalesce-locals`;
- dead-store elimination, which belongs to neighboring cleanup passes unless it is the specific post-coalescing debris Binaryen removes.

## Landed first tests

The local test set is small but covers the core correctness envelope.

| Test family | Why it is required | Existing wiki anchor |
| --- | --- | --- |
| Exact-type positive | Coalescing is type-exact, not subtype-based. | [`./wat-shapes.md`](./wat-shapes.md) |
| Type mismatch negative | Prevents silent invalid local index reuse. | [`./wat-shapes.md`](./wat-shapes.md) |
| Different-value overlap negative | Protects ordinary liveness interference. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Same-value overlap positive | Proves the pass is value-aware rather than lifetime-only. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Zero-init / param entry | Locks the implicit-entry facts that affect merge legality. | [`./binaryen-strategy.md`](./binaryen-strategy.md) |
| Redundant-copy removal | Proves the pass optimizes for copy removal, not just local-count reduction. | [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) |
| Dead set / dead tee cleanup | Exercises `applyIndices` cleanup and refinalization boundaries. | [`./wat-shapes.md`](./wat-shapes.md) |
| Loop backedge priority | Prevents a locally valid but Binaryen-divergent greedy order. | [`./interference-and-ordering.md`](./interference-and-ordering.md) |
| Dual scheduler slot replay | Verifies both no-DWARF roles: after `local-subtyping` and after `reorder-locals`. | [`../../no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md) |

## Validation ladder

Current status before moving the direct pass into public preset slots:

1. **Unit shape tests** are green for active registration, non-overlap merging, interference negatives, structured `local.tee`, copy-chain forwarding, derived branch-carrier consume-forwarding, branch-aware side-carrier effective writes, effective-copy/copy-connected side-carrier coloring, destination-read-after-source-write guarding, source-write/destination-read interference restoration, path-disjoint branch-result param-slot reuse, loop unread-local scratch coalescing, loop adjacent and non-adjacent copy-through coalescing, concrete-ref direct-struct-get packing after unused leading and trailing locals, redundant-copy cleanup, immediate tee/drop debris cleanup, nested block-escape live branch-carrier writes, return-arm dead-write cleanup, branch-to-outer-block-continuation live-write preservation, dead write cleanup, the intentional 4097-local dense-coloring boundary, the exact `local-subtyping -> coalesce-locals -> local-cse -> simplify-locals` order, and the exact `reorder-locals -> coalesce-locals -> reorder-locals` order.
2. **Registry tests** prove `--coalesce-locals` is an active module pass with dispatcher and CLI coverage.
3. **Preset tests** keep the public first slot explicit and keep public `reorder-locals` scheduling separate from the direct pass.
4. **Fuzz parity** is green for the refreshed 2026-07-04 closeout matrix after structured-scalar slot-order cleanup: regular GenValid `.tmp/pass-fuzz-coalesce-locals-genvalid-100000-structured-scalar-order-final-20260704` (`100000/100000` normalized, zero failures), dedicated pass-specific profile `.tmp/pass-fuzz-coalesce-locals-profile-10000-structured-scalar-order-final-20260704` (`10000/10000` normalized, zero failures; selected leaves `straight-line=4290`, `structured=2885`, `loop-copy-through=2825`), random all-profiles `.tmp/pass-fuzz-coalesce-locals-random-all-profiles-10000-structured-scalar-order-final-20260704` (`10000/10000` normalized, zero failures), and explicit wasm-smith with the documented `unreachable-control-debris` normalizer at `.tmp/pass-fuzz-coalesce-locals-wasm-smith-10000-structured-scalar-order-final-normalized-20260704` (`9956/10000` compared, `9955` normalized, `1` compare-normalized, `0` mismatches, `44` Binaryen/oracle command failures). The corresponding raw wasm-smith lane has one narrow no-local cleanup-debris mismatch. Earlier green lanes include the loop adjacent copy-chain lane, loop unread-local scratch lane, effective-copy weighting / copy-connected coloring lane, branch-aware structured effective-write lane, path-disjoint branch-result slot-reuse lane, source-write/destination-read interference lane, destination-read guard lane, dense-local guard lane, structured ineffective-write lane, bounded structured copy-chain lane, structured `local.tee` lane, older 2026-05-08 mixed-generator direct lane, `.tmp/pass-fuzz-cl-genvalid-10000-livecount`, and older mixed-generator comparable cases at `.tmp/pass-fuzz-cl-mixed-1000-livecount` with zero mismatches.
5. **Artifact Starshine-side validation** is green for the direct pass: running Starshine `--coalesce-locals` over the rebuilt debug WASI artifact writes a validating output.
6. **Direct-pass self-opt artifact compare** is canonically/function equal with Binaryen on both `.tmp/self-opt-cl-debug-livecount` and `.tmp/self-opt-cl-optimized-livecount`; the optimized-artifact direct pass timer is now faster than Binaryen (`591.437ms` vs `629.109ms`), while total wall time remains slightly above Binaryen.
7. **Reorder-sandwich artifact replay** is green at `.tmp/self-opt-cl-reorder-sandwich-20260508` with `Normalized WAT equal: yes` and `Canonical function compare equal: yes` on the checked-in debug artifact.

That is enough to treat the current direct `coalesce-locals` slot work as proven for the v0.1.0 audit scope. The reopened random-all-profiles closeout is now green: the first 10k attempt timed out, but the follow-up reductions closed the `heap2local-struct` and `ssa-nomerge-smoke` families, replay `.tmp/pass-fuzz-coalesce-locals-random-all-replay-all-structured-scalar-order-final-20260704` normalized the previous `125/125` residuals, and the required 10k lane normalized all cases. The broader TypeIdx invariant docs outside the local `[AUDIT006-D]` comment remain outside CL, and sparse-coloring follow-up is needed only if the documented `>4096` huge non-loop boundary becomes release-significant.

## Health-check outcome from this run

The first 2026-07-04 direct refresh fixed the current regular GenValid mismatch family by allowing structured body locals to reuse dead fixed parameter slots and by coalescing syntactically unused locals inside loop functions; later loop fallback hardening also coalesces same-typed unread/write-only loop locals into dead scratch slots and adjacent/non-adjacent single-use copy-through chains without admitting general read loop-local merging.
The later 2026-07-04 O4z neighborhood replays fixed narrower non-loop structured `local.tee`, structured self-copy cleanup, bounded branch copy-chain, derived branch-carrier consume-forwarding, destination-read-after-source-write guarding, source-write/destination-read interference restoration, path-disjoint branch-result param-slot reuse, and structured ineffective-write subsets, then added branch-aware effective-write marking so mutually exclusive arm writes are not dropped by flattened cleanup, effective-copy weighting/copy-connected ordering so live carrier copy chains are not displaced by ineffective copy traffic, loop adjacent/non-adjacent copy-through coalescing for function-18-style shuttles, narrow concrete-ref direct-struct-get packing plus preferred-first GC-ref ordering for the `heap2local-struct` neighboring-profile family, immediate tee/drop debris cleanup, nested nonlocal block-escape live-write preservation, label-aware terminal/branch continuation liveness, top-level tail param reuse after ineffective dead writes, and structured-scalar coloring order for the sampled `ssa-nomerge-smoke` family. The checked startup-map GC/local prefix drift moved from `+317/+319` through `+19/+21` to current Starshine raw/code-body size wins: `-20` raw bytes at `+ coalesce-locals` and `-18` raw bytes at `+ local-cse`. The same closeout track added the dedicated `coalesce-locals-all` profile and scaled it to a green 10k lane; broad random-all is now also green at the required 10k size. The first textual diff remains function `defined=3 abs=3`; per-function code-body splitting measures that function as a local Starshine size win (`341` vs `355` bytes), while loop-heavy function `defined=18 abs=18` is now a smaller local residual (`+20` code-body bytes) inside an aggregate Starshine-smaller code section. A follow-up hardening test and guard now bound the dense non-loop coloring matrices by skipping functions above 4096 flattened locals; that closes the unbounded GC-churn hazard as a documented boundary, not as huge-function Binaryen output parity.
The 2026-05-05 implementation run promoted `coalesce-locals` from removed-name planning to active direct module-pass status.
No contradiction was found between the 2026-04-22 tagged source manifest and the 2026-05-05 current-main recheck for the teaching-level `coalesce-locals` contract.
The 2026-05-08 ordered-slot replay refresh reran the standard direct signoff lane after landing exact-neighborhood regressions: `.tmp/pass-fuzz-coalesce-locals-20260508` reported `6759/10000` compared cases, `6759` normalized matches, and `20` Binaryen empty-recursion-group command failures.
That same refresh closed the remaining slot proof: `src/passes/coalesce_locals_test.mbt` now covers both exact neighborhoods, and `.tmp/self-opt-cl-reorder-sandwich-20260508` compares green on normalized WAT and canonical-function equality over the checked-in debug artifact.

## Sources

- [`../../../raw/research/1443-2026-07-04-coalesce-locals-o4z-neighborhood-structured-tee.md`](../../../raw/research/1443-2026-07-04-coalesce-locals-o4z-neighborhood-structured-tee.md)
- [`../../../raw/research/1442-2026-07-04-coalesce-locals-direct-refresh-loop-unused-locals.md`](../../../raw/research/1442-2026-07-04-coalesce-locals-direct-refresh-loop-unused-locals.md)
- [`../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md`](../../../raw/research/0550-2026-05-08-coalesce-locals-ordered-slot-replay.md)
- [`../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md`](../../../raw/research/0518-2026-05-06-coalesce-locals-direct-revalidation.md)
- [`../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md`](../../../raw/research/0473-2026-05-05-coalesce-locals-current-main-recheck.md)
- [`../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md`](../../../raw/research/0372-2026-04-25-coalesce-locals-port-readiness-health-check.md)
- [`../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md`](../../../raw/research/0352-2026-04-25-coalesce-locals-current-main-and-test-map.md)
- [`../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md`](../../../raw/research/0264-2026-04-22-coalesce-locals-primary-sources-and-starshine-followup.md)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
- [`../../../../../src/passes/reorder_locals.mbt`](../../../../../src/passes/reorder_locals.mbt)
- [`../../../../../src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- [`../../../../../src/passes/optimize_test.mbt`](../../../../../src/passes/optimize_test.mbt)
- [`../../../../../agent-todo.md`](../../../../../agent-todo.md)
