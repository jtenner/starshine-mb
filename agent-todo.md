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

This table covers every unique owner in the 56-slot top-level O4z path. Only rows marked **open** have active v0.1.1 work below.

| Pass | Current Starshine status | Active work |
| --- | --- | --- |
| `duplicate-function-elimination` | Direct behavior closed; both slots scheduled. | None. |
| `remove-unused-module-elements` | Closed for Binaryen-v131 direct behavior: table initializers, typed indirect-call reachability, overlap trap retention, TNH handling, reference-only body nullification, and recursive-group validity are covered. | **Open scheduler gap only:** second early slot. |
| `memory-packing` | Closed at Binaryen-v131 behavior parity: source-order trampling, imported in-bounds admission, overflow-safe memory32/memory64 bounds, focused fixtures, four-lane evidence, and O4z slot proof are current. | None. |
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
| `optimize-instructions` | Closed for the representable Binaryen-v131 surface with four-lane direct evidence, O4z neighborhood proof, size wins, and pass-local timing. | Ordered memory-atomic acquire/release evidence remains a representation blocker outside OI; reopen when that instruction surface lands. |
| `heap-store-optimization` | Closed. | None. |
| `pick-load-signs` | Closed at Binaryen-v131-or-better parity: complete upstream behavior plus retained smaller/faster commuted-mask, unsigned-shift, and i64 evidence cleanups. | None; reopen only under the documented parity criteria. |
| `precompute` / `precompute-propagate` | Closed at Binaryen-v131-or-better behavior parity: the complete official fixture surface is admitted, broad control/effect flow is preserved or simplified more strongly, both required four-lane matrices are current, self-optimization validates, and repeated pass-local timing meets the `2x` target. | None; reopen for a semantic/validation failure, a pass-owned size-losing family, a source-backed missing evaluator family, or pass-local regression beyond `2x` Binaryen. |
| `code-pushing` | Closed. | None. |
| `tuple-optimization` | Closed with accepted performance exception. | None. |
| `simplify-locals-nostructure` | Closed with accepted performance caveat. | None. |
| `vacuum` | Direct behavior closed. | **Open scheduler placement:** remove/justify extra early slot and restore final slot. |
| `reorder-locals` | Closed; three slots scheduled. | None. |
| `heap2local` | Closed for the representable v131 surface: sequential branch-target struct/array candidates, unreachable flow, GC-supertype drop-only owners, and direct fresh packed/unpacked reads are covered; the four-lane matrix and O4z slot are current. | Shared reference `acqrel` cmpxchg remains a validator/atomic-semantics representation blocker; reopen when that surface lands. |
| `merge-locals` | Closed at Binaryen-v131 parity; both orientations, CFG influence, rollback, profiles, timing, and slot-27 scheduling completed on 2026-07-18. | None. |
| `optimize-casts` | Closed. | None. |
| `local-subtyping` | Closed. | None. |
| `coalesce-locals` | Direct behavior closed. | **Open extended-neighborhood shape parity:** the full slot-27 suffix can renumber locals differently even when `merge-locals` is a byte no-op in both tools. |
| `simplify-locals` | Closed. | None. |
| `code-folding` | Closed: Binaryen-v131 semantics, external validity, canonical late scheduling, and pass-local performance completed on 2026-07-19. | None; final representative medians are `1.70x` on the candidate-heavy fixture and `1.98x` on the large debug artifact. |
| `merge-blocks` | Closed for the current v0.1.1 audit. | None. |
| `redundant-set-elimination` / `rse` | Direct behavior, 1x timing, and the canonical late O4z scheduler slot are closed. The public optimize/shrink rosters run `heap-store-optimization -> redundant-set-elimination -> vacuum -> dae-optimizing`. | None for v0.1.1. |
| `dae-optimizing` | Closed locally for v0.1.1 DAE ownership. Numeric production identities are gone; final Binaryen-v131 four-lane matrices are current for plain DAE and DAEO; the shared nested roster and exact slot-48 placement are proven. Plain/optimizing retained artifacts validate and are byte-idempotent. Final medians are plain `85.329s` / `64.277s` and DAEO `25.440s` / `21.475s`; the latter improves the prior `47.956s` / `44.490s` without changing bytes. Retained thresholds are optional phase/profitability budgets only. | No DAE-owned work. The DAEO canonical `+4,318` local-layout/remap family belongs to shared nested local-cleanup passes, and the full large O4z wall stop is pre-DAEO in `simplify-locals-nostructure`. |
| `inlining-optimizing` | The v131 shared-engine behavior audit is implemented locally: toolchain hints, CLI/configurable heuristics, complete trivial-instruction classes, Pattern A/B splitting, EH-aware direct/indirect/ref tail hoisting, roots, metadata repair, active `inline-main`, and exact nested order. **Release target: v0.2.0 or later; these changes are not part of the v0.1.1 release scope.** | Direct behavior has no open v131 transform-family gap. Track shipment under `[V02-INL]001`; shared DAE/SGO scheduler routing remains under `[O4Z-NESTED]001`. |
| `duplicate-import-elimination` | Closed and scheduled. | None. |
| `simplify-globals-optimizing` | Closed and scheduled. | Shared nested-scheduler proof only. |
| `string-gathering` | Accepted direct/preset status. | Non-blocking decoder/performance follow-up only. |
| `reorder-globals` | Accepted direct/preset status. | None. |
| `directize` | Closed for Binaryen-v131 default behavior: `ref.func`, null, unknown initializer, element override, growth, set/import/export boundaries, and known/trap/unknown classification are covered. | Optional `directize-initial-contents-immutable` pass-arg breadth remains separate. |

## Binaryen v131 Release Refresh

### [V131-SPOT]001 - Renew shared-helper-sensitive closed-pass evidence

- **Goal:** determine whether v131 shared effect/type/finalization changes alter closed passes whose owner file did not change.
- **Targeted set:** `code-pushing`, `heap-store-optimization`, `precompute`, `remove-unused-brs`, all five `simplify-locals` variants, and `tuple-optimization`; DAE remains owned by its existing open slices.
- **Deliverables:**
  - [ ] Run focused v131 source/test probes before any full rerun.
  - [ ] Keep a pass closed when the probe is green and the owner contract is unchanged; open a dedicated slice only for a classified mismatch or missing released family.
- **Exit criteria:** every target has an explicit v131 renewed/unchanged verdict or an owning follow-up slice.

## v0.1.1 Primary O4z Work

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
  - [x] Add `code-folding` before the first late `merge-blocks`; direct four-lane parity and exact-order scheduling closed on 2026-07-18.
  - [ ] Reconcile the classified post-`code-folding` cleanup shapes: return/tail-call and movement fixtures are smaller Starshine `br_if` forms, while block-exit and EH fixtures remain size-losing gaps in neighboring `merge-blocks` / branch cleanup.
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

## v0.1.1 O4z Supporting Work

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

### [AUDIT]006 - Function `TypeIdx`/`RecIdx` invariant documentation

- Finish the wiki/inline/test documentation that module function-section references are global `TypeIdx`, while `RecIdx` is rec-group-local and impossible in validated function-section positions.

### [SGO]003-[SGO]005 - Deferred SGO improvements

- Optional breadth only after a new semantic/artifact need.
- Nested-cleanup runtime experiments only with measured ownership.
- Default-local compare normalization is tooling/cosmetic work, not a direct SGO correctness blocker.

## v0.2.0 Or Later Work

### [V02-INL]001 - Ship the Binaryen v131 inlining-family expansion

- **Release target:** v0.2.0 or later. Do not count or publish these changes as part of v0.1.1.
- **Implementation status:** completed locally on 2026-07-19; retain the implementation, tests, generated interfaces, harness admission, and documentation for the later release.
- **Scope:** plain `inlining`, `inlining-optimizing`, active `inline-main`, `no-inline*` policy, Binaryen toolchain hints, all six CLI/configuration controls, complete represented trivial-instruction policy, Pattern A/B partial splitting, EH-safe direct/indirect/ref tail handling, roots, metadata repair, and touched nested cleanup order.
- **Evidence:** focused inlining `120/120`, white-box `14/14`, CLI `54/54`, command `107/107`, full `9452/9452`; official-v131 GenValid closeout produced `10000/10000` normalized matches for both plain and optimizing modes with zero mismatches or failures.
- **Release gate:** before the eventual v0.2.0-or-later publication, rerun generated interfaces, README API sync, the focused suites, the full repository suite, both explicit-v131 10,000-case lanes, and the repository-wide validation gate after the unrelated decoder fuzz blocker is resolved.

### [AUDIT]005 - Standalone no-inline policy tests

- **Status:** implemented 2026-07-19 as part of `[V02-INL]001`; not part of v0.1.1 scope.
- Focused marker, deduplication, no-match, stripped-name wildcard, `no-full-inline`, `no-partial-inline`, clone-survival, and partial-split policy tests live in `src/passes/inlining_test.mbt`.

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

### [INL]020-[INL]021 - Optional future inlining breadth

- Revisit tiny hot-path struct/array allocation inlining only with measured canonical-size and wall-time wins.
- Keep table/indirect-call **callee recovery** research deferred; v131's direct-call planner and copied-body indirect/ref-call handling are complete.
- Expression-level code metadata, branch hints, source maps, and copied callee debug-name synthesis remain shared metadata-substrate work rather than open inlining transform families.

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
