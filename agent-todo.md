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
- Repository-wide `bun validate full --profile ci --target wasm-gc` passes `moon info`, formatting, checking, and the full deterministic suite, then remains blocked by a pre-existing randomized decoder round-trip abort in `src/fuzz`. The July 19, 2026 `[AUDIT]002` run passed `9435/9435` deterministic tests before reproducing an unrelated `i64.store32 align=32 offset=14882` decode as `array.store`; an earlier run reproduced the same blocker family on table-initializer instruction decoding.

## Binaryen v131 O4z Pass Ledger

This table covers every unique owner in the 56-slot top-level O4z path. Only rows marked **open** have active v0.1.0 work below.

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
| `merge-blocks` | Closed for the current v0.1.0 audit. | None. |
| `redundant-set-elimination` / `rse` | Direct behavior and 1x timing closed. | **Open scheduler slot.** |
| `dae-optimizing` | Active-partial; unified stable call facts and tail-boundary ownership improve the 15-leaf Binaryen-v131 matrix to `823/201`, while batched touched-function validation cuts fixed-artifact wall time to `568.782s`. The output is valid/idempotent and net smaller, but `2924 / +56531` gross-positive bodies, canonical remap, full four-lane semantics, plain-DAE/`dae2` renewal, recursive/shared breadth, and `40.624s` convergence runtime remain open. | **Open implementation and closeout.** |
| `inlining-optimizing` | The v131 shared-engine behavior audit is implemented locally: toolchain hints, CLI/configurable heuristics, complete trivial-instruction classes, Pattern A/B splitting, EH-aware direct/indirect/ref tail hoisting, roots, metadata repair, active `inline-main`, and exact nested order. **Release target: v0.2.0 or later; these changes are not part of the v0.1.0 release scope.** | Direct behavior has no open v131 transform-family gap. Track shipment under `[V02-INL]001`; shared DAE/SGO scheduler routing remains under `[O4Z-NESTED]001`. |
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

## v0.1.0 Primary O4z Work

### [O4Z-DAE]001 - Complete `dae-optimizing`

- **Status:** note `1654` is the latest implementation slice, while note `1653` remains the latest complete generated-parity, fixed-artifact, and runtime checkpoint. Stable callsite paths now feed uniform-actual analysis when inactive dead-suffix calls conflict with active values; the focused active-`7` / inactive-`8` oracle exactly matches Binaryen v131. Exact path resolution remains restricted below `1024` total functions until containing scopes and entry-stack arities are cached without artifact-scale runtime regression. A unified `DaeFunctionInfo`-equivalent scanner now records stable structured callsite paths, direct/dropped/tail/inactive calls, reverse callers, unseen calls, and cached unused-parameter decisions. Direct tail callees remain owned for coordinated parameter removal but block result removal, fixing `128` dedicated-profile cases with zero regression. HOT liveness covers restricted call-free `try_table` exceptional edges; calls, legacy `try`, continuations, and read-only structured-carrier equivalence remain conservative. Touched HOT writeback validates changed functions together and restores only invalid definitions. `.tmp/daeo-unified-tail-eh-batch-20260719` is valid and byte-idempotent at raw/canonical `3121651` / `3181064`, or `-54854` / `-80332` versus Binaryen v131. Canonical bodies are `2924 / +56531` larger, `2568 / -136109` smaller, and `7670` equal. Wall time falls from about `1241s` to `568.782s`; second-invocation convergence is still `40.624s`. The accepted v131 DAEO aggregate is `1024/1024` with `823` exact matches plus `201` inspected wins totaling `-3120` raw / `-2124` canonical and zero failures. Plain DAE's accepted prior correct-profile smoke remains `512/512`; a later run with `128` Binaryen command failures is rejected. Full four-lane matrices, a clean-cache plain renewal, separate `dae2`, complete nested scheduling, remap/gross-positive reduction, recursive/shared breadth, and public execution remain open; late HSO still blocks optimize/shrink/O4z before DAEO.
- **Goal:** reduce every source-backed gross-positive output family, replace selected/artifact-specific behavior with generic Binaryen-compatible DAE, and keep real touched-function optimizing cleanup safe and bounded.
- **Why:** O4z slot 48 is already scheduled, but gross direct parity, nested scheduler runtime, the post-change semantic matrix, and public pre-slot execution remain open.
- **Deliverables:**
  - [ ] Keep shrinking direct DAE residual families by source-backed transform ownership, not output-shape acceptance alone.
  - [ ] Complete generic parameter removal, constant-actual propagation, result removal, GC type refinement, multivalue/control reconstruction, tail-call safety, and type-section repair.
  - [ ] Replace remaining selected `FuncXXX` gates with generic recognizers where possible; document any retained artifact-only boundary with reopening criteria.
  - [x] Refresh the fixed-artifact ledger from the current native binary before using its sizes or top-function ranking as current evidence.
  - [ ] Continue the Func `41` structured coalescing/liveness reducer and current Funcs `9639`/`1247`/`6377`/`1111`/`7556`/`7919`/`7007` loss families without offsetting their losses against unrelated wins. Current canonical leaders are Func `41 +995`, Func `9639 +492`, Func `1247 +489`, Func `6377 +436`, Func `1111 +435`, and Func `7556 +421`. Do not retry generic broad loop coloring without exact definite-initialization state and per-function profitability: the July 19 probe regressed current DAEO by `+432` raw / `+806` canonical, `+916` gross-positive bytes, and about `+794.501s` pass-local time.
  - [x] Repair definite-initialization-sensitive fallback local cleanup with branch-aware fallthrough counting, and strengthen unconditional-branch target validation so invalid nested result candidates still roll back.
  - [ ] Renew, then eliminate or source-backedly classify, the canonical-remap ledger. The note-`1651` `704 / +4922` ledger is stale after the tail-boundary correction and must not be cited as current.
  - [ ] Retain the candidate-context touched-function validation batch that reduced first-invocation wall time to `568.782s`; optimize the remaining nested cleanup and `40.624s` byte-identical second invocation without dropping measured output gains.
  - [ ] Implement the touched-function nested `precompute-propagate -> default O4z function pipeline` using shared scheduler infrastructure.
  - [ ] Remove or narrowly justify large-module/touched-set guards with runtime and performance evidence.
  - [ ] Keep direct DAE and `dae-optimizing` profiles/results separate; renew plain `dae` / `dae2` against explicit Binaryen v131.
  - [ ] Expand recursive components, mixed/multivalue result reconstruction, typed control, GC refinement, tail/escape handling, and recursive/shared type repair from focused red cases.
  - [ ] Complete current four-lane direct and optimizing closeout plus ordered slot-48/runtime artifact proof.
- **Current sources:** `docs/wiki/binaryen/passes/dead-argument-elimination/`, `docs/wiki/binaryen/passes/dae-optimizing/`, and research notes `1645`, `1649`, `1650`, `1651`, `1652`, `1653`, and `1654`.
- **Exit criteria:** zero unclassified gross-positive direct/optimizing residual families, a fresh green four-lane matrix for the widened behavior, real touched-only nested cleanup within an accepted runtime bound, no selected-function correctness dependency where a generic proof is feasible, and valid runtime-green O4z slot behavior after the late-HSO blocker.

### [O4Z-DAE-MODEL]001 - Replace parallel DAE facts with boundary candidates and epochs

- **Owner:** `src/passes/dead_argument_elimination.mbt` analysis and scheduler layers.
- **Status:** reason-coded decisions/counters, the coherent immutable original snapshot, and the mutable current boundary graph with module/call/signature/body epochs are implemented. The dependency graph records direct and direct-tail edges, exact typed and epoch-stamped caller-parameter-to-callee-parameter operand-slice edges and their deterministic family-component closure, exact uniform-value caller invalidations, conservative result/type/body/cleanup domains, and normalized Tarjan SCCs. A monotone per-slot solver merges forwarded-only, uniform, conflicting, and blocked states and attaches solved values to epoch-bearing uniform work items. `dae_process_work_item(...)` owns common stale refresh, no-change/deferred/commit outcomes, diagnostics, computed/localized, solved uniform-literal, GC parameter, and GC result production dispatch, plus atomic forwarding. The low exact-parameter GC chain and terminal result-caller closure now consume those GC families; broad GC batches and remaining exact result/type/body/cleanup extraction still need common plans.
- **Goal:** preserve one immutable original boundary snapshot, one incrementally refreshed current boundary graph, explicit caller/callee/result dependencies, and deterministic candidate epochs.
- **Reason:** current legality still flows through many parallel arrays and specialized phases; stale candidates and repeated scans prevent a correctness-independent worklist.
- **Deliverables:** reason-coded decisions/counters; coherent original/current records; SCC/component graph; function/signature/body epochs; stale-plan rejection and requeue; no correctness-critical low/high/reverse bands.
- **Dependencies:** the v131 completion matrix and de-artifacting inventory in `docs/wiki/binaryen/passes/dead-argument-elimination/`.
- **Exit criteria:** every boundary candidate names its dependencies and expected epochs; stale candidates never mutate; full-module facts are rescanned only when invalidated.
- **Suggested tests:** export/start/ref.func/element/call_indirect/call_ref classification, direct and indirect tail barriers, mutual recursion, stale call-count retry, deterministic queue order.

### [O4Z-DAE-PLAN]001 - Unify DAE value evidence and transactional rewrites

- **Owner:** DAE value-slice, localization, GC refinement, dropped-result, and module finalization helpers.
- **Status:** the common epoch-bearing `DaeRewritePlan` and validated atomic application boundary are implemented. Ordinary private scalar unread-parameter removal covers imports, repeated/multiple callers, direct/`return_call`, type reuse/append, written removed-slot preservation, and speculative callee cleanup. A thin `DaeComponentRewritePlan` now makes forwarding-component commits atomic across ordered members, caller/member epochs, call composition, source sections, candidate validation, and rollback. Constant materialization, localization, GC argument/result refinement, dropped results, control reconstruction, selected paths, and full dispatcher ownership remain open.
- **Goal:** construct one immutable caller/callee/control/type/metadata rewrite plan before mutation.
- **Reason:** several local transactions are already sound, but signature-changing families still use separate evidence and application tails.
- **Deliverables:** one value-slice carrier with stack/effect/trap/control metadata; parameter-action model; localization as a requeue transition; shared GC LUB evidence; result dependency graph; generic control/typeidx/multivalue reconstruction; one module finalizer.
- **Dependencies:** `[O4Z-DAE-MODEL]001`.
- **Exit criteria:** caller edits, callee projection, control/type repair, metadata policy, candidate validation, commit, rollback, and requeue are owned by one plan lifecycle.
- **Suggested tests:** mixed removed/kept params, ambient-stack operands, escaping branches, trapping/effectful producers, direct return_call, GC argument/result LUB, typed select, typeidx block/if/loop/try_table, multivalue lanes, bottom results, grouped types, imported/defined tags.

### [O4Z-DAE-WORKLIST]001 - Remove selected definitions and arbitrary boundary caps

- **Owner:** `dae_run_core(...)` and selected DAE/DAEO helpers.
- **Status:** the ordinary core full-module forward rescans are replaced by a deterministic queue over current caller/callee invalidations. Binaryen's source-backed one-wave single-caller profitability stop remains between queue frontiers. The shared work-item model carries target/component/exact members/family, solved per-slot values, and expected epochs; the common dispatcher owns computed/localized and solved uniform-literal candidate execution, production forwarding transactions over exact collector-provided members, stale refresh, explicit deferred termination, diagnostics, and post-commit invalidation requeue. Broad original-shape identity and scalar constructor seeds now solve current values after the relevant forwarding frontier; this generically removes the former fixed definitions `4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584` without preempting the computed-cycle proof. Small-module immutable globals now carry policy on uniform work items and run dispatcher-backed waves to exhaustion, removing their selected scan and `64` cap. Broad immutable/suffix work, broad GC batches, dropped results, control/type repair, cleanup revisits, and other selected artifact lanes still use separate phases, arrays, bands, or caps. The terminal GC-result closure no longer has its depth-`16` cutoff and runs dispatcher-backed dependency postorder to exhaustion. Forwarding-component discovery itself is uncapped: the former 8-component, 64-node, 8-round, 129-instruction, and bounded sink/cycle retry limits are removed in favor of monotonic exhaustion.
- **Goal:** replace production Func-number gates, fixed candidate bands, and correctness-affecting iteration caps with a dependency-driven worklist.
- **Reason:** the baseline inventory still finds hard-coded chains, wrapper lists, dropped-result fallbacks, local maps, and `8/14/21/32/64/512` policies.
- **Deliverables:** generic component and result queues; defensive fail-closed work budget only; selected-only and guard-skip counters; generic focused replacements for every retained artifact fixture; removal of obsolete/unreachable lanes.
- **Dependencies:** `[O4Z-DAE-MODEL]001`, `[O4Z-DAE-PLAN]001`.
- **Exit criteria:** no correctness path depends on `FuncNNN`, definition windows, module cardinality, or productive-attempt caps; retained heuristics omit only optional profitability cleanup.
- **Suggested tests:** long forwarding chains, many independent candidates, recursive components, localization no-progress, stale retry, large module with one candidate, large touched set, former Func237/288/3737/3765 fixtures through generic recognizers.

### [O4Z-DAE-RELEASE]001 - Close plain DAE and DAEO evidence and release integration

- **Owner:** shared nested scheduler, optimizer presets, validation tooling, DAE/DAEO dossiers, and v0.1.0 release metadata.
- **Goal:** route DAE, inlining, and SGO through one touched default-function pipeline; close direct behavior, performance, artifacts, presets, docs, and release preparation.
- **Reason:** DAEO currently has a DAE-local 22-step roster, broad touched/size skips, a `568.782s` fixed-artifact first invocation, and no current full v131 four-lane matrix; plain DAE is also unclosed.
- **Deliverables:** shared pipeline API; exact touched `precompute-propagate -> O4z function pipeline`; combined finite DAEO lifecycle; direct plain and optimizing four-lane matrices; artifact validation/runtime/section/timing ledger; exact public roster and alias tests; completed docs and release notes.
- **Dependencies:** `[O4Z-DAE-WORKLIST]001`, `[O4Z-NESTED]001`, `[O4Z-PRESET]001`, and resolution or precise attribution of pre-DAEO HSO wall ownership.
- **Exit criteria:** completion matrix closed, no unclassified residual, accepted pass-local performance, runtime-green representative artifacts, exact-once preset placement, no active DAE release blocker, clean committed tree.
- **Suggested tests:** plain-vs-optimizing debris split, nested trace order, untouched function identity, optimize/shrink/O4z exact order, repeated application, wasm-gc full gate, runtime replay, full required compare matrices.

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

- **Release target:** v0.2.0 or later. Do not count or publish these changes as part of v0.1.0.
- **Implementation status:** completed locally on 2026-07-19; retain the implementation, tests, generated interfaces, harness admission, and documentation for the later release.
- **Scope:** plain `inlining`, `inlining-optimizing`, active `inline-main`, `no-inline*` policy, Binaryen toolchain hints, all six CLI/configuration controls, complete represented trivial-instruction policy, Pattern A/B partial splitting, EH-safe direct/indirect/ref tail handling, roots, metadata repair, and touched nested cleanup order.
- **Evidence:** focused inlining `120/120`, white-box `14/14`, CLI `54/54`, command `107/107`, full `9452/9452`; official-v131 GenValid closeout produced `10000/10000` normalized matches for both plain and optimizing modes with zero mismatches or failures.
- **Release gate:** before the eventual v0.2.0-or-later publication, rerun generated interfaces, README API sync, the focused suites, the full repository suite, both explicit-v131 10,000-case lanes, and the repository-wide validation gate after the unrelated decoder fuzz blocker is resolved.

### [AUDIT]005 - Standalone no-inline policy tests

- **Status:** implemented 2026-07-19 as part of `[V02-INL]001`; not part of v0.1.0 scope.
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
