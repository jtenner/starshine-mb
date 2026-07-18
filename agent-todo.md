# Agent Tasks

## Scope And Rules

- Keep only active unreleased work or explicitly deferred future work.
- Binaryen `version_131` O4z means `wasm-opt --all-features -O4 --shrink-level 4`.
- The v131 release leaves the existing 56-slot / 38-owner O4z scheduler unchanged; the v130-to-v131 pass-impact and reopening audit is `docs/wiki/binaryen/release-horizon-and-oracles.md`.
- The detailed preset diff and per-pass roster remain recorded in `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`; read that note as the unchanged scheduler baseline, not as v131 direct-pass signoff.
- Bare `wasm-opt` currently resolves to TinyGo's Binaryen `version_116`. Every v131 compare or self-opt command must pass an official verified v131 binary with `--wasm-opt-bin`; require `wasm-opt version 131 (version_131)` in the evidence.
- Direct pass behavior comes before ordered-neighborhood proof; preset scheduling comes last.
- Behavior parity is the target. Raw wasm/WAT equality is not required, but every remaining difference must be source-backed, measured, classified, and covered by reopening criteria.
- A pass is not closed merely because an ordinary random lane found no mismatch. Source/docs breadth, pass-specific generation, validity, performance, and the required four-lane closeout matrix still apply.
- Use `_build/native/release/build/cmd/cmd.exe` after a current native release build. Treat `target/native/...` as stale unless explicitly proven fresh.
- Moon commands must run serially.

## Binaryen v131 O4z Pass Ledger

This table covers every unique owner in the 56-slot top-level O4z path. Only rows marked **open** have active v0.1.0 work below.

| Pass | Current Starshine status | Active work |
| --- | --- | --- |
| `duplicate-function-elimination` | Direct behavior closed; both slots scheduled. | None. |
| `remove-unused-module-elements` | **Reopened for v131:** table initial values, null/wrong-type trap retention, and overlapping element segments changed upstream. | **Open v131 direct reassessment plus existing scheduler gap:** second early slot. |
| `memory-packing` | **Reopened for v131:** the imported zero-filled in-bounds overlap path is now released oracle behavior. | **Open v131 implementation and closeout.** |
| `once-reduction` | Closed. | None. |
| `global-refining` | Closed. | None. |
| `global-struct-inference` / `gsi` | Closed for ordinary GSI. | None. |
| `ssa-nomerge` | Closed. | None; full `ssa` is separate future work. |
| `flatten` | Closed: public behavior parity, top-level aggressive scheduling, and reviewed timing acceptance completed on 2026-07-17. | None; `1,140 us` over the 120-function representative is accepted as a pass-specific timing exception. |
| `simplify-locals` family | Closed: all five variants, four-lane direct evidence, O4z neighborhood, idempotence, and timing completed on 2026-07-17. | None; shared DAE/inlining/SGO scheduler infrastructure remains under `[O4Z-NESTED]001`. |
| `local-cse` | Direct behavior closed; both late and aggressive-prelude slots scheduled. | None; shared nested-rerun proof remains under `[O4Z-NESTED]001`. |
| `dead-code-elimination` / `dce` | Closed. | None. |
| `remove-unused-names` | Closed. | None. |
| `remove-unused-brs` | Direct behavior closed. | **Open scheduler reconciliation:** Starshine has one extra slot. |
| `optimize-instructions` | **Reopened for v131:** equal-ref, identical-select, idempotent-call/effect-order, and non-concrete-select behavior changed upstream. | **Open v131 focused parity and closeout.** |
| `heap-store-optimization` | Closed. | None. |
| `pick-load-signs` | Closed at Binaryen-v131-or-better parity: complete upstream behavior plus retained smaller/faster commuted-mask, unsigned-shift, and i64 evidence cleanups. | None; reopen only under the documented parity criteria. |
| `precompute-propagate` | Reopened against Binaryen v131. Shared function types, descriptor casts, shared-GC atomics, GC backing-array multibyte operations, strings, exact local/global heap identities, and the general-GC fixture instruction surface are now admitted; v131 `Precompute.cpp` remains byte-identical to v130. | **Open:** `[O4Z-PCP131]001` legacy effects, broader flow/effect retention, nested heap reads, stack switching, remaining refinalization, random-all classification, and full v131 profile/fuzz/runtime/performance closeout. |
| `code-pushing` | Closed. | None. |
| `tuple-optimization` | Closed with accepted performance exception. | None. |
| `simplify-locals-nostructure` | Closed with accepted performance caveat. | None. |
| `vacuum` | Direct behavior closed. | **Open scheduler placement:** remove/justify extra early slot and restore final slot. |
| `reorder-locals` | Closed; three slots scheduled. | None. |
| `heap2local` | **Reopened for v131:** upstream now rebuilds analysis after each successful candidate and handles unreachable type-flow repair. | **Open v131 focused parity and O4z slot recheck.** |
| `merge-locals` | Closed at Binaryen-v131 parity; both orientations, CFG influence, rollback, profiles, timing, and slot-27 scheduling completed on 2026-07-18. | None. |
| `optimize-casts` | Closed. | None. |
| `local-subtyping` | Closed. | None. |
| `coalesce-locals` | Direct behavior closed. | **Open extended-neighborhood shape parity:** the full slot-27 suffix can renumber locals differently even when `merge-locals` is a byte no-op in both tools. |
| `simplify-locals` | Closed. | None. |
| `code-folding` | Active narrow direct pass; not preset-ready. | **Open behavior breadth and scheduling.** |
| `merge-blocks` | Closed for the current v0.1.0 audit. | None. |
| `redundant-set-elimination` / `rse` | Direct behavior and 1x timing closed. | **Open scheduler slot.** |
| `dae-optimizing` | Active-partial; direct DAE remains raw-red; nested cleanup is incomplete. | **Open implementation and closeout.** |
| `inlining-optimizing` | **Reopened with plain `inlining` for v131:** released `@binaryen.inline` Always/Never policy is not consumed locally. | **Open shared-engine v131 parity; nested-scheduler proof remains under `[O4Z-NESTED]001`.** |
| `duplicate-import-elimination` | Closed and scheduled. | None. |
| `simplify-globals-optimizing` | Closed and scheduled. | Shared nested-scheduler proof only. |
| `string-gathering` | Accepted direct/preset status. | Non-blocking decoder/performance follow-up only. |
| `reorder-globals` | Accepted direct/preset status. | None. |
| `directize` | **Reopened for v131:** table initial values now participate in known-target/trap/unknown classification. | **Open v131 direct and accepted late-tail suffix reassessment; optional pass-arg breadth remains separate.** |

## Binaryen v131 Release Refresh

### [V131-OI]001 - Reassess `optimize-instructions`

- **Goal:** match v131's new equal-reference, identical-select, idempotent-call/effect-order, and non-concrete-select behavior.
- **Deliverables:**
  - [ ] Add red-first fixtures for one-evaluation `ref.eq`, scratch-local identical selects, deep-effect idempotent calls, directional effect barriers, and non-concrete arm bailout.
  - [ ] Reconcile the OI family matrix and dedicated profile with `version_131` source/tests.
  - [ ] Run the full four-lane matrix with explicit official v131 `--wasm-opt-bin` plus the scheduled O4z neighborhoods.
- **Exit criteria:** no unclassified v131 OI family gap, validation failure, size-losing divergence without proof, or performance regression.

### [V131-MP]001 - Implement released imported-overlap `memory-packing`

- **Goal:** implement Binaryen v131's source-order trampling cleanup for overlapping active segments, including the imported-memory in-bounds gate.
- **Deliverables:**
  - [ ] Add red-first defined/imported, in-bounds/out-of-bounds, memory32/memory64, source-order, and partially trampled fixtures.
  - [ ] Preserve checked arithmetic, page-size semantics, instantiation trap observability, data names, and segment-op rewrites.
  - [ ] Refresh `memory-packing-all`, the full four-lane closeout, and O4z slot `3` evidence against explicit v131.
- **Exit criteria:** released overlap behavior is implemented or a narrower source-backed blocker is recorded; the current unconditional overlap bailout is gone for admitted v131 cases.

### [V131-RUME]001 - Reassess table-initial-value and overlap liveness

- **Goal:** match v131 RUME retention for table initial values, null/wrong-type writes, overlapping/dynamic element segments, and TNH policy.
- **Deliverables:**
  - [ ] Add red-first direct and return-indirect call fixtures for initializer targets, wrong-type traps, null trampling, dynamic offsets, and `trapsNeverHappen`.
  - [ ] Reconcile full RUME and non-function sibling behavior without over-rooting callable functions.
  - [ ] Run the full direct matrix plus both early RUME neighborhoods and the accepted late-tail suffix using explicit v131.
- **Exit criteria:** v131 liveness/trap semantics are classified and green; the existing second-early-slot scheduler gap remains separately visible.

### [V131-DIR]001 - Reassess `directize` table initial contents

- **Goal:** add v131 known/trap/unknown classification for table initializers while preserving growth/set/import boundaries.
- **Deliverables:**
  - [ ] Add red-first `ref.func`, null, `global.get`, imported-table, grow, set, in-range, and out-of-range initializer fixtures.
  - [ ] Preserve child effects, subtype checks, tail-call form, select lowering, EH repair, and refinalization.
  - [ ] Run the full direct matrix and `string-gathering -> reorder-globals -> directize` late-tail proof against explicit v131.
- **Exit criteria:** default v131 directize behavior is green; optional `directize-initial-contents-immutable` pass-arg work remains separately deferred.

### [V131-H2L]001 - Reassess sequential-candidate and unreachable flow safety

- **Goal:** match v131's post-mutation analysis rebuild and unreachable type-flow behavior.
- **Deliverables:**
  - [ ] Add red-first multiple sequential struct/array candidate fixtures that would expose stale LocalGraph/parent/branch-target data.
  - [ ] Add unreachable flow-through cases for adjusted allocation types.
  - [ ] Run `heap2local-all`, the full four-lane matrix, timing, and O4z slot/neighborhood evidence against explicit v131.
- **Exit criteria:** no stale-analysis or unreachable-flow mismatch remains and existing measured Starshine cleanup wins stay valid.

### [V131-INL]001 - Consume released `@binaryen.inline` policy

- **Goal:** align plain `inlining` and `inlining-optimizing` with v131 function-level toolchain Always/Never inline hints.
- **Deliverables:**
  - [ ] Confirm generic WAST/lowering carriage for `@binaryen.inline`, add focused coverage if absent, and add red-first inliner policy tests that distinguish it from `@metadata.code.inline` plus Starshine `no-inline*` markers.
  - [ ] Honor Never/Always after `try_delegate` rejection and before normal full-inline heuristics; preserve and remap the annotation correctly, while documenting the separate upstream-only `strip-toolchain-annotations` boundary.
  - [ ] Run both direct pass matrices and focused nested-suffix evidence against explicit v131.
- **Exit criteria:** shared-engine v131 policy is green without conflating metadata, toolchain hints, and pass-level no-inline flags.

### [V131-SPOT]001 - Renew shared-helper-sensitive closed-pass evidence

- **Goal:** determine whether v131 shared effect/type/finalization changes alter closed passes whose owner file did not change.
- **Targeted set:** `code-pushing`, `heap-store-optimization`, `precompute`, `remove-unused-brs`, all five `simplify-locals` variants, and `tuple-optimization`; DAE remains owned by its existing open slices.
- **Deliverables:**
  - [ ] Run focused v131 source/test probes before any full rerun.
  - [ ] Keep a pass closed when the probe is green and the owner contract is unchanged; open a dedicated slice only for a classified mismatch or missing released family.
- **Exit criteria:** every target has an explicit v131 renewed/unchanged verdict or an owning follow-up slice.

## v0.1.0 Primary O4z Work

### [O4Z-PCP131]001 - Bring `precompute` family to Binaryen v131 behavior parity

- **Status:** active; v131 `Precompute.cpp` has the same SHA-256 as the reviewed v130 source, but the broader v131 lit matrix confirms that the previous generated-profile closeout did not exercise the full interpreter contract.
- **Goal:** close direct plain `precompute` and `precompute-propagate` behavior gaps without changing the bounded one-local-solve/one-rerun public propagation contract.
- **Current progress:** ordered multiple local/global effect retention, same-expression/default-local flow, immutable aggregate identity through exact SSA locals and immutable globals, shared function/type decoding, descriptor extraction/casts/branch flow, exact regular cast-branch heap encoding, shared-GC atomics, backing-array multibyte operations, constant select/branch control flow, exact cast-block refinalization, and the full v131 string fixture now have focused coverage. The official general-GC fixture now decodes, optimizes, validates, and re-encodes; its remaining WAT differences are local-write/effect-shape cleanup and smaller unreachable canonicalization, with Starshine `1040` bytes versus Binaryen `1060`. Plain `precompute` now runs bounded raw scalar/unreachable cleanup around reachable `atomic.fence`, closing the former size-losing random-all family, and the current 1,000-case random-all sample has only 419 canonically smaller Starshine outputs. The current v131 wasm-smith lane has one intentional reachable-fence correctness difference plus 44 Binaryen tool failures. Legacy `try` admission for `precompute-effects`, broader nested heap reads, stack switching, general effect/control flow, broader refinalization, full random-all completion, and final closeout remain open.
- **Deliverables:**
  - [ ] Rebaseline all comparisons on `.tmp/binaryen-version-131-bin/bin/wasm-opt` with an isolated v131 cache.
  - [ ] Close supported v131 `precompute-effects`, partial-select, GC identity/immutable heap, ref/function, control-flow, string, and refinalization families with focused tests.
  - [ ] Separate known values from emitability and preserve allocation identity through locals, loops, and safe immutable nested reads.
  - [ ] Add missing string/reference instruction surface only where required by v131 pass behavior, including decoder/encoder/typecheck support and direct fixtures.
  - [ ] Preserve all effect, trap, branch, call, and write ordering while replacing proven parent values.
  - [ ] Add v131-specific GenValid leaves and runtime/idempotence coverage for every new family.
  - [ ] Complete the required four-lane closeout, self-optimization, and repeated pass-local benchmark against v131.
- **Exit criteria:** no broad source-backed behavior disclaimer remains for either public variant, zero unclassified direct v131 residual families, valid/runtime-equivalent output, and Starshine pass-local median remains within `2x` Binaryen.


### [O4Z-CF]001 - Finish and schedule `code-folding`

- **Status:** active narrow direct HOT pass; prior direct audit accepted a subset, but current living docs still disclaim full Binaryen tail-sharing coverage and preset readiness.
- **Goal:** close the remaining source-backed terminating-tail/expression-exit families and schedule slot 38.
- **Why:** a subset signoff is not enough for O4z behavior parity, and `code-folding` is absent from both public presets.
- **Deliverables:**
  - [ ] Reconcile the v130/current cost/search structure and remaining exact tail-family matrix.
  - [ ] Implement or narrowly classify remaining named/unnamed, typed, EH, multivalue, and expression-parent families.
  - [ ] Add a pass-specific aggregate profile and current four-lane closeout.
  - [ ] Recheck candidate-heavy pass-local timing after current source-cost reconciliation.
  - [ ] Prove `vacuum -> code-folding -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks`.
- **Exit criteria:** no broad source-backed behavior disclaimer remains, direct closeout is current, and slot 38 is scheduled with exact-order tests.

### [O4Z-DAE]001 - Complete `dae-optimizing`

- **Status:** highest remaining implemented-pass risk. Direct/plain DAE remains raw-red; the latest reduction-disabled 10000-case evidence is `5000` normalized dedicated direct, `9136` normalized direct random-all, and `9633` normalized optimizing random-all, with zero failures but unresolved families. Current `dae_run_nested_cleanup(...)` applies one exact-ref fold/rerun path and otherwise returns the module unchanged.
- **Goal:** replace selected/artifact-specific behavior with generic Binaryen-compatible DAE and implement real touched-function optimizing cleanup.
- **Why:** O4z slot 48 is already scheduled, but the implementation and nested scheduler are still partial.
- **Deliverables:**
  - [ ] Keep shrinking direct DAE residual families by source-backed transform ownership, not output-shape acceptance alone.
  - [ ] Complete generic parameter removal, constant-actual propagation, result removal, GC type refinement, multivalue/control reconstruction, tail-call safety, and type-section repair.
  - [ ] Replace remaining selected `FuncXXX` gates with generic recognizers where possible; document any retained artifact-only boundary with reopening criteria.
  - [ ] Implement the touched-function nested `precompute-propagate -> default O4z function pipeline` using shared scheduler infrastructure.
  - [ ] Remove or narrowly justify large-module/touched-set guards with runtime and performance evidence.
  - [ ] Keep direct DAE and `dae-optimizing` profiles/results separate.
  - [ ] Complete current four-lane direct and optimizing closeout plus ordered slot-48/runtime artifact proof.
- **Current sources:** `docs/wiki/binaryen/passes/dead-argument-elimination/`, `docs/wiki/binaryen/passes/dae-optimizing/`, and research notes `1562` through `1567`.
- **Exit criteria:** zero unclassified direct/optimizing residual families, real touched-only nested cleanup, no selected-function correctness dependency where a generic proof is feasible, and valid runtime-green O4z slot behavior.

### [O4Z-PRESET]001 - Reconcile the exact 56-slot public preset

- **Status:** blocked on direct pass work above.
- **Goal:** make Starshine's `shrink`/O4z expansion intentionally match the Binaryen v130 56-slot top-level order, with documented Starshine-only extensions.
- **Current differences to resolve:**
  - [ ] Add the second early `remove-unused-module-elements` slot.
  - [x] Add `flatten -> simplify-locals-notee-nostructure -> local-cse`.
  - [ ] Remove or prove the extra early `vacuum -> remove-unused-brs` pair.
  - [x] Replace both plain `precompute` substitutions with `precompute-propagate`.
  - [x] Add `merge-locals` after `heap2local`; the exact `heap2local -> merge-locals -> optimize-casts` lane is `10000/10000` green.
  - [ ] Reconcile the downstream local-numbering shape gap in the extended `local-subtyping -> coalesce-locals -> local-cse` suffix; a reduced probe is byte-identical with and without `merge-locals` in each tool, so this does not reopen the pass.
  - [ ] Add `code-folding` before the first late `merge-blocks`.
  - [ ] Add `redundant-set-elimination -> vacuum` after late HSO.
  - [ ] Keep final `strip-debug` explicitly documented as a Starshine extension outside the Binaryen 56 slots.
  - [ ] Preserve feature gates, no-DWARF policy, repeated cleanup slots, canonical aliases, and exact order tests.
- **Exit criteria:** exact expansion tests, every newly scheduled direct pass independently signed off, and an ordered generated-artifact/runtime/size comparison with no unclassified regression.

### [O4Z-NESTED]001 - Reconcile optimizing nested reruns

- **Status:** partially implemented across DAE, inlining, and SGO.
- **Goal:** make nested optimizing reruns use one shared, truthful, touched-function-filtered representation of the final O4z function pipeline.
- **Why:** top-level order is insufficient. Binaryen reruns function cleanup after DAE/inlining, and SGO reruns the default function pipeline without the extra propagating prefix.
- **Deliverables:**
  - [ ] Define one tested function-pipeline expansion API parameterized by O4z levels, feature gates, and whether `precompute-propagate` is prepended.
  - [ ] Route DAE, inlining, and SGO through it without semantic forks.
  - [ ] Preserve touched-function filtering; do not mutate unrelated functions.
  - [ ] Replace broad large-module/tail-call bypasses only with focused safe guards or repaired owners.
  - [ ] Add exact nested-order tests and pass-specific runtime/artifact evidence.
- **Dependencies:** `[O4Z-PCP]001`, `[O4Z-CF]001`, and `[O4Z-PRESET]001`. The SimplifyLocals prelude and `merge-locals` are signed; this slice owns only shared scheduler routing.
- **Exit criteria:** DAE/inlining/SGO nested traces match the intended roster and stay valid, runtime-green, and within accepted pass-local performance bounds.

## v0.1.0 O4z Supporting Work

### [O4Z-STARTUP]001 - Preserve the startup-map regression guard

- Keep `tests/repros/o4z-debug-startup-map-init-repro.wasm` until a smaller generated-artifact fixture replaces it.
- Recover precision one owner at a time only with focused tests and runtime evidence: nested SSA liveness, safe commutative ordering, tee-aware local sinking, path-sensitive local coalescing, and branchy vacuum cleanup.
- Source: `docs/wiki/binaryen/passes/late-pipeline-dispatch.md`.

### [JSON-AS]001 - Repeatable artifact correctness and size signoff

- **Goal:** keep a pinned opt-in `json-as` replay that builds debug artifacts, validates Starshine/Binaryen outputs, executes runtime suites, and records section/function/type/code/custom-section deltas.
- **Active work:**
  - [ ] Add a documented opt-in clone/build/replay task under existing Bun tooling; do not add shell scripts under `scripts/`.
  - [ ] Re-measure the final `strip-debug` custom-section wins.
  - [ ] Measure each newly scheduled O4z pass/neighborhood on medium-naive, medium-simd, and large-swar artifacts.
  - [ ] Keep validation and runtime execution separate; validation alone previously missed corruption.
  - [ ] Prefer `d8` when available; otherwise retain a checked-in-equivalent Node/WASI smoke path.
- Historical completed correctness incidents belong in the wiki, not as active entries.

### [WALL]001 - Cross-pass wall-time attribution

- Separate pass-local time from decode, validation, HOT lift/lower, parse/emit, buffering, caching, and process startup.
- Keep aggregate wall time outside direct pass correctness closeout unless a pass is clearly the owner.
- Current recurring targets: self-optimization command overhead, repeated HOT lifting, validation/encoding, and any newly widened exact O4z preset.

### [AUDIT]002 - Raw skip and threshold boundary coverage

- Inventory all `can_skip`, `unchecked`, `giant`, `large`, and numeric threshold gates in `src/passes/pass_manager.mbt`.
- Add focused ±1 boundary tests and trace reasons for RUB and simplify-locals gate families.
- Distinguish correctness guards from performance guards and remove unexplained magic thresholds.

### [TOOL]001 - Self-opt compare normalization symmetry

- Canonicalize equivalent Binaryen/Starshine artifact paths symmetrically or ignore only proven transparent unused-label void wrappers.
- Preserve raw artifacts; do not hide semantic, size-losing, or validation differences behind normalization.

### [STRIP-DEBUG]001 - Artifact measurement

- Direct pass and final preset placement are complete.
- Re-measure debug-artifact custom-section size, validation, and runtime effects after the final O4z scheduler lands.

## v0.1.1 Optimizer Follow-ups

### [SSA-FULL]001 - Complete public full `ssa`

- Not an O4z blocker: O4z uses `ssa-nomerge`.
- Active work: simple explicit-write merge locals; parameter/default entry inputs and prepend ordering; loop/branch/EH/typed-control classification; harness admission; dedicated profile; direct closeout.

### [AUDIT]003 - DAE de-artifacting

- Inventory selected-function helpers by transform family and safety proof.
- Convert the smallest safe families to generic recognizers with red-first non-artifact fixtures.
- Keep selected fixtures as regressions; retain selected-only gates only with explicit reasons and reopening criteria.

### [AUDIT]004 - Thin module-pass coverage

- Keep only still-useful test expansion:
  - `directize`: imported/exported/passive/declarative/multi-table/tail-call negatives and positives;
  - any newly widened scheduler owner from the primary O4z queue.
- Closed DIE/once-reduction audit batches do not need duplicate active tasks.

### [AUDIT]005 - Standalone no-inline policy tests

- Add focused `no-inline`, `no-full-inline`, and `no-partial-inline` marker tests independent of inlining integration.

### [AUDIT]006 - Function `TypeIdx`/`RecIdx` invariant documentation

- Finish the wiki/inline/test documentation that module function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- Optional breadth only after a new semantic/artifact need.
- Nested-cleanup runtime experiments only with measured ownership.
- Default-local compare normalization is tooling/cosmetic work, not a direct SGO correctness blocker.

## v0.2.0 Deferred Work

### Shared-Everything Threads

Keep the dependency order; detailed proposal rules live in the Shared-Everything wiki pages.

1. Model proposal entities, heap/reference types, limits/flags, rec groups, shared descriptors, and annotations.
2. Decode/encode proposal bytes with contextual legality checks and round-trip tests.
3. Validate shared/unshared domains, type graphs, subtyping/LUB/GLB, rec groups, memory/table/global/tag rules, and proposal opcodes.
4. Link/import/export proposal entities and type graphs without index or ownership corruption.
5. Extend optimizer harness protocol, feature flags, semantic hashing, and compare/fuzz normalization.
6. Extend generators and shrinkers with high-yield proposal cases.
7. Preserve proposal structures through HOT lift/lower with provenance and correct failure boundaries.
8. Expose CLI flags, update docs, and run focused plus full proposal signoff.

### [INL]020-[INL]024 - Deferred inlining breadth

- Add EH/tail-call/multivalue/generated direct-call coverage only after the shared type/HOT substrate is ready.
- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call callee-recovery research deferred until the direct-call surface is stable.

### [HOT]001-[HOT]004 - Deferred structural improvements

- Replace exact-expression span identity with stronger source provenance where needed.
- Preserve unknown/custom metadata through HOT round trips.
- Reduce opaque fallback lowering without sacrificing correctness.
- Keep any O4z startup-map local/tee/loop repair tied to `[O4Z-STARTUP]001` rather than opening unrelated HOT rewrites.

### [FUZZ]001 - Continuous parity triage

- Keep no permanent active bug entry when all maintained suites are green.
- On a new mismatch: save the seed/artifacts, minimize it, classify it, add the focused regression first, repair the owning pass/harness/codec, and archive the durable result in the relevant dossier.

## Backlog Hygiene

- Remove a slice when its exit criteria are met; do not retain completed checkbox diaries here.
- Move durable closeout evidence to the pass dossier, `docs/wiki/log.md`, or a numbered research note.
- Add a new active slice only when it has a concrete owner, goal, reason, deliverables, dependencies, exit criteria, and suggested tests.
- Keep release blockers and known failures visible until resolved.
