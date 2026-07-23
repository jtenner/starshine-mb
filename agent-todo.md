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
| `remove-unused-module-elements` | Correctness-repaired on 2026-07-21 so decoded legacy `try` bodies, typed/catch-all handlers, catch tags, nested references, type carriers, and remapped indices participate in reachability and rewriting. Prior v131 evidence predates the repair. | **Open evidence renewal and scheduler work:** `[AUDIT-CORRECTNESS]001` plus the second early slot. |
| `memory-packing` | Correctness-repaired on 2026-07-21 after fixing five operand stack deltas; prior v131 parity evidence predates the repair. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `once-reduction` | Direct behavior closed after the 2026-07-21 branch-exit, legacy-`try`, and tail-call repairs. Fresh v131 evidence is regular `100000/100000` exact, random-all `10000/10000` exact, wasm-smith exact for all `9956` comparable cases, and one dedicated raw terminal-tail Starshine-win family with zero true-semantic or Starshine failures. | None. |
| `global-refining` | Closed. | None. |
| `global-struct-inference` / `gsi` | Closed for ordinary GSI. | None. |
| `ssa-nomerge` | Direct behavior is closed, including the 2026-07-21 unsupported-HOT admission repair and the repeated precompute value-block allocation repair. Branch-free value-block operand writes now participate in LocalGraph facts; the post-default path preserves Binaryen's already-SSA tee/get and source-order fresh-local allocation. All 17 saved cases are raw-byte identical to Binaryen v131, and the targeted profile is `10000/10000` normalized. The stopped random-all partial still contains 54 separate declaration-only residuals with identical executable bodies. | None; full `ssa` remains separate future work. |
| `flatten` | Closed: public behavior parity, top-level aggressive scheduling, and reviewed timing acceptance completed on 2026-07-17. | None; `1,140 us` over the 120-function representative is accepted as a pass-specific timing exception. |
| `simplify-locals` family | Closed: all five variants, four-lane direct evidence, O4z neighborhood, idempotence, and timing completed on 2026-07-17. | None; shared DAE/inlining/SGO scheduler infrastructure remains under `[O4Z-NESTED]001`. |
| `local-cse` | Direct behavior closed; both late and aggressive-prelude slots scheduled. | None; shared nested-rerun proof remains under `[O4Z-NESTED]001`. |
| `dead-code-elimination` / `dce` | Closed. | None. |
| `remove-unused-names` | Closed. | None. |
| `remove-unused-brs` | Correctness-repaired on 2026-07-21 so selectification cannot speculate unchosen traps or move condition writes/calls past invalidated local and mutable-global arm reads. Prior v131 parity evidence predates the repair. | **Open evidence renewal and scheduler reconciliation:** `[AUDIT-CORRECTNESS]001`; Starshine also has one extra slot. |
| `optimize-instructions` | Closed for the representable Binaryen-v131 surface with four-lane direct evidence, O4z neighborhood proof, size wins, and pass-local timing. | Ordered memory-atomic acquire/release evidence remains a representation blocker outside OI; reopen when that instruction surface lands. |
| `heap-store-optimization` | Closed. | None. |
| `pick-load-signs` | Closed at Binaryen-v131-or-better parity: complete upstream behavior plus retained smaller/faster commuted-mask, unsigned-shift, and i64 evidence cleanups. | None; reopen only under the documented parity criteria. |
| `precompute` / `precompute-propagate` | Correctness-repaired on 2026-07-21 so raw terminal-branch flattening uses the target label arity instead of assuming one payload; prior v131 parity evidence predates the repair. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `code-pushing` | Closed. | None. |
| `tuple-optimization` | Closed with accepted performance exception. | None. |
| `simplify-locals-nostructure` | Closed with accepted performance caveat. | None. |
| `vacuum` | Direct Binaryen-v131 behavior is closed for the current represented surface. Both 2026-07-21 three-family slices are implemented; regular `100000` and pass-owned aggregate `10000` lanes are exact. The required random-all lane leaves only measured six-byte Starshine-win symmetric-`if` removals, and wasm-smith leaves only the measured case-3694 six-byte win plus Binaryen tool failures. | Scheduler and ordered-preset work only under `[O4Z-PRESET]001`; no open direct parity family. |
| `reorder-locals` | Correctness-repaired on 2026-07-21 so local-use scanning and index rewriting cover decoded legacy `try` protected and catch bodies while preserving handler structure. Three slots remain scheduled. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `heap2local` | Closed for the representable v131 surface: sequential branch-target struct/array candidates, unreachable flow, GC-supertype drop-only owners, and direct fresh packed/unpacked reads are covered; the four-lane matrix and O4z slot are current. | Shared reference `acqrel` cmpxchg remains a validator/atomic-semantics representation blocker; reopen when that surface lands. |
| `merge-locals` | Correctness-repaired on 2026-07-21: the raw straight-line fallback now rejects decoded legacy `try` exactly as it rejects other structured/EH control, preventing partial local analysis. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `optimize-casts` | Closed. | None. |
| `local-subtyping` | Correctness-repaired on 2026-07-21 to match the validator's abstract heap hierarchy; prior v131 parity evidence predates the repair. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `coalesce-locals` | Direct behavior closed; the 2026-07-21 retained-copy and subtype-boundary orientation family now matches Binaryen v131 without widening exact-type coalescing. | **Open extended-neighborhood and local-shape parity:** the full slot-27 suffix can renumber locals differently even when `merge-locals` is a byte no-op in both tools; the latest 300-case random-all lane also retains three conservative loop-copy/param-reuse gaps and one structured block-flattening gap. |
| `simplify-locals` | Closed. | None. |
| `code-folding` | Closed: Binaryen-v131 semantics, external validity, canonical late scheduling, and pass-local performance completed on 2026-07-19. | None; final representative medians are `1.70x` on the candidate-heavy fixture and `1.98x` on the large debug artifact. |
| `merge-blocks` | Correctness-repaired on 2026-07-21 so effectful ambiguous roots cannot move before `unreachable`; prior v131 parity evidence predates the repair. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `redundant-set-elimination` / `rse` | Direct behavior, 1x timing, and the canonical late O4z scheduler slot are closed. The 2026-07-21 repair also removes newly unread admitted body-local set shells while preserving RHS evaluation; the fresh 300-case explicit-v131 lane is exact. The public optimize/shrink rosters run `heap-store-optimization -> redundant-set-elimination -> vacuum -> dae-optimizing`. | None for v0.1.1. |
| `dae-optimizing` | **Reopened, active-partial.** The July 21 matrices, artifact validity/idempotence, de-artifacting, shared roster, slot-48 proof, and medians remain valid evidence, but they do not close source-family ownership. The current completion matrix still records most boundary, value, GC, result, control, type, transaction, worklist, and nested-lifecycle families as `generic-partial` or `mixed`. | **Open initial-release parity work:** `[O4Z-DAE]001` and its owned slices. The canonical `+4,318` local-layout/remap family remains under shared local-cleanup ownership; the pre-DAEO full-O4z wall stop remains under `simplify-locals-nostructure`. |
| `inlining-optimizing` | The v131 shared-engine behavior audit is implemented locally: toolchain hints, CLI/configurable heuristics, complete trivial-instruction classes, Pattern A/B splitting, EH-aware direct/indirect/ref tail hoisting, roots, metadata repair, active `inline-main`, and exact nested order. **Release target: v0.2.0 or later; these changes are not part of the v0.1.1 release scope.** | Direct behavior has no open v131 transform-family gap. Track shipment under `[V02-INL]001`; shared DAE/SGO scheduler routing remains under `[O4Z-NESTED]001`. |
| `duplicate-import-elimination` | Correctness-repaired on 2026-07-21 so call, return-call, and ref.func remapping traverses decoded legacy `try` regions and duplicate function-import removal clears stale raw name payloads after function-index remapping. The new raw-name repair has an exact 300-case explicit-v131 lane. | **Open legacy-EH evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `simplify-globals-optimizing` | Closed and scheduled. | Shared nested-scheduler proof only. |
| `string-gathering` | Accepted direct/preset status. | Non-blocking decoder/performance follow-up only. |
| `reorder-globals` | Correctness-repaired on 2026-07-21 so traffic, dependency, and index-rewrite walkers cover decoded legacy `try` protected and catch bodies. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`. |
| `directize` | Correctness-repaired on 2026-07-21 so table mutation/growth/runtime classification, indirect-call discovery, and nested rewriting cover decoded legacy `try` protected and catch bodies. | **Open evidence renewal:** `[AUDIT-CORRECTNESS]001`; optional `directize-initial-contents-immutable` breadth remains separate. |

## Binaryen v131 Release Refresh

### [V131-SPOT]001 - Renew shared-helper-sensitive closed-pass evidence

- **Goal:** determine whether v131 shared effect/type/finalization changes alter closed passes whose owner file did not change.
- **Targeted set:** `code-pushing`, `heap-store-optimization`, `precompute`, `remove-unused-brs`, all five `simplify-locals` variants, and `tuple-optimization`; DAE remains owned by its existing open slices.
- **Deliverables:**
  - [ ] Run focused v131 source/test probes before any full rerun.
  - [ ] Keep a pass closed when the probe is green and the owner contract is unchanged; open a dedicated slice only for a classified mismatch or missing released family.
- **Exit criteria:** every target has an explicit v131 renewed/unchanged verdict or an owning follow-up slice.

### [AUDIT-CORRECTNESS]001 - Renew evidence after cross-pass correctness repairs

- **Status:** **Deferred with explicit user approval on 2026-07-21.** Implementation and red-first deterministic regression work are complete for `merge-blocks`, `once-reduction`, `memory-packing`, `local-subtyping`, `remove-unused-brs`, `precompute` / `precompute-propagate`, full `ssa` plan application, and the raw merge-locals cleanup. The precompute repair makes raw terminal-branch flattening label-arity-aware: void targets discard all dead values, scalar targets preserve one payload, and unresolved type-indexed/multivalue targets fail closed. The recovery attempt verified official `wasm-opt version 131 (version_131)` at `.tmp/binaryen-version-131-bin/bin/wasm-opt` (binary SHA-256 `bad4b6524b2c8e4b27b9aa69bde1a4b9a05ec8887c77ef0d34300f5825acd97c`), reran the focused repaired-pass tests, `moon info`, `moon fmt`, and full `moon test` (`9722/9722`) successfully, then stopped before the native rebuild and compare matrices when the user deferred evidence renewal and requested a normal three-issue bug-search pass. The previous audit checkpoint's native build SHA-256 `e925ebcdcb40bdc0cb5b36fd838912e27755747f409293a280a9d0934d860d42` and two original semantic replays therefore remain the latest recorded build/replay evidence. Reopen only when explicit post-repair v131 matrix renewal is prioritized; do not cite this partial recovery as renewed compare-pass evidence.
- **Goal:** renew explicit Binaryen-v131 direct evidence for the six behavior-changing public pass families after the repair.
- **Deliverables:**
  - [ ] Run the required four-lane v131 matrix for `merge-blocks`.
  - [x] Run the required four-lane v131 matrix for `once-reduction` (2026-07-21: regular and random-all exact, wasm-smith exact for all comparable cases with 44 Binaryen/tool failures, dedicated raw terminal-tail residual classified as a measured Starshine win).
  - [ ] Run the required four-lane v131 matrix for `memory-packing`.
  - [ ] Run the required four-lane v131 matrix for `local-subtyping`.
  - [ ] Run the required four-lane v131 matrix for `remove-unused-brs`.
  - [ ] Run the required four-lane v131 matrices for `precompute` and `precompute-propagate`.
  - [x] Keep full `ssa`'s stale-plan regression white-box because it hardens an internal failure path without widening public transform admission.
  - [x] Keep raw merge-locals output unchanged while deleting its unreachable orientation-two branch.
- **Exit criteria:** all six behavior-changing public pass families have fresh explicit-v131 direct matrices with zero validation or true semantic failures, or an inspected mismatch has its own owning follow-up.

### [AUDIT-LEGACY-EH]001 - Repair decoded legacy `try` traversal across optimizer passes

- **Status:** implementation and deterministic validation complete on 2026-07-21; explicit v131 evidence renewal remains tracked separately. Red-first white-box tests initially failed seven traversal families, then passed after the repairs. Current pass tests are `6243/6243`; native and wasm-gc repository suites are `9722/9722`; `moon check --target wasm-gc` has 183 warnings and zero errors; every CI fuzz suite passes when the Moon command is run directly. The aggregate Bun wrapper reproduced the documented intermittent subprocess failure before the identical direct command succeeded. Legacy `@lib.Instruction::Try(BlockType, Expr, Array[LegacyCatch], LabelIdx?)` is a real input produced by `src/binary/decode.mbt`; it is not interchangeable with `TryTable`. Shared and correctness-sensitive walkers now traverse the protected body plus every `LegacyCatch` / `LegacyCatchAll` body, while broader TryTable-only owners explicitly fail closed before mutation.
- **Goal:** make every affected pass either traverse legacy try and catch bodies correctly or explicitly fail closed before mutation. Do not treat the absence of legacy-EH coverage in existing generated profiles as proof that the instruction is unreachable.
- **Why:** the omissions can leave stale remapped indices, hide live references or state mutations, and permit transforms based on incomplete control/effect facts. These are potential semantic miscompiles or invalid-module producers, not representation-only parity gaps.
- **Deliverables:**
  - [x] **Fix the shared structured-instruction walker.** Extend `pass_rewrite_structured_instr` in `src/passes/pass_common.mbt` to recurse through the protected body and every legacy catch body while preserving the block type, catch tags/catch-all shape, and delegate target. Add focused `untee` and `avoid-reinterprets` tests proving nested rewrites occur in both the try body and catches. This item is pass-completeness work; the remaining items below are correctness repairs.
  - [x] **Repair `reorder-locals`.** Update `rl_scan_instruction` and `rl_rewrite_instrs_in_place` in `src/passes/reorder_locals.mbt` to visit the protected body and all legacy catch bodies. Add red-first cases where a local is used only in a try/catch and where reordering an outside-used local would otherwise leave a stale catch-body index. Assert encoded local indices and external validation, not only rendered text.
  - [x] **Repair `reorder-globals`.** Update global traffic counting, defined-global dependency collection, and instruction rewriting in `src/passes/reorder_globals.mbt` for legacy try/catch bodies. Test globals referenced only in the protected body and only in catches, including a case where reordering changes their absolute indices.
  - [x] **Repair `duplicate-import-elimination`.** Extend `die_rewrite_instruction` in `src/passes/duplicate_import_elimination.mbt` so `call`, `return_call`, and `ref.func` indices are remapped inside the protected body and all catches after a duplicate function import is removed. Cover body, typed catch, catch-all, and delegate-bearing shapes; validate the rewritten module and invoke the surviving target where practical.
  - [x] **Repair `remove-unused-module-elements`.** Extend `rume_scan_instruction` and every related rewrite/nullification traversal in `src/passes/remove_unused_module_elements.mbt` to scan legacy try/catch bodies and catch tag references. Add fixtures where functions, globals, tables/memories, data/element segments, and tags are reachable only through the protected body or a catch. The pass must not remove or renumber any such live element incorrectly.
  - [x] **Repair `directize`.** Extend table mutation, table growth, runtime-table classification, indirect-call discovery, and nested rewrite walkers in `src/passes/directize.mbt` across legacy try/catch bodies. The key regression must place `table.set`, `table.grow`, or another table-content invalidator inside a legacy try and prove an indirect call is not directized from stale initial contents. Also cover an eligible indirect call nested inside a try/catch for positive rewrite completeness.
  - [x] **Repair `once-reduction`.** Extend `or_scan_instrs`, `or_analyze_instrs_flow`, and `or_rewrite_instrs_flow` in `src/passes/once_reduction.mbt` across protected and catch bodies with conservative exceptional-flow merging. A noncanonical write to a candidate once-global inside either region must invalidate the candidate; calls and reads there must participate in dataflow; no guard, write, or call may be removed from incomplete facts.
  - [x] **Repair the raw `merge-locals` fallback.** `merge_locals_raw_is_straight_line` in `src/passes/merge_locals.mbt` currently rejects `TryTable` but not legacy `Try`, while its flat local dataflow does not inspect nested try/catch effects. Fail closed on legacy `Try` unless the raw algorithm is deliberately extended with full exceptional control flow. Add red-first protected-body and catch-body read/write cases proving no unsafe retarget occurs.
  - [x] **Audit the remaining `TryTable`-only raw walkers.** Search non-test `src/passes/*.mbt` for walkers matching `@lib.TryTable` without `@lib.Try`; classify each as correctness-sensitive, completeness-only, or deliberately fail-closed. Add an explicit legacy-`Try` case or a pre-mutation rejection for every correctness-sensitive owner, and record the final owner list in the relevant pass dossiers so this systemic variant omission cannot silently recur.
- **Final owner classification:** full legacy-region traversal is implemented in `pass_common`, `reorder-locals`, `reorder-globals`, `duplicate-import-elimination`, `remove-unused-module-elements`, `directize`, and `once-reduction`; raw `merge-locals` fails closed on legacy `Try`. `coalesce-locals`, `duplicate-function-elimination`, `global-refining`, `global-struct-inference`, `inlining` / `inline-main`, `local-subtyping`, `memory-packing`, `simplify-globals-optimizing`, and `string-gathering` now use the shared module-level pre-mutation legacy-try guard because their remaining TryTable-oriented raw algorithms do not yet model exceptional handler flow. HOT pass-manager paths remain deliberately fail-closed where legacy regions cannot be lifted, while the precompute family's existing raw preservation path remains explicit.
- **Invariants:** traverse every protected and catch body exactly once; preserve catch ordering, tag indices, catch-all form, delegate target, block type, stack typing, and exceptional control flow; do not flatten legacy `Try` into `TryTable`; do not mutate from partial analysis.
- **Dependencies:** none. This correctness slice supersedes any ledger claim that the affected passes are fully closed for all decoded instruction forms; scheduler work can proceed independently but release signoff cannot ignore these repairs.
- **Suggested test setup:** construct or decode real legacy-EH wasm rather than using only synthetic `Instruction` arrays; include typed catch, catch-all, delegate, body-only reference, catch-only reference, and mixed normal/exceptional exits. For each mutating pass, confirm the test fails before implementation, then run focused tests, `moon info`, `moon fmt`, `moon test`, external wasm validation, and targeted semantic execution or compare-pass replay where supported.
- **Exit criteria:** implementation criteria complete: every checkbox above is complete; affected passes have deterministic protected/catch regressions; no repaired or guarded pass mutates from facts that omit legacy EH; the remaining `TryTable`-only walker inventory is classified; focused and repository-wide validation is green. Fresh explicit-v131 direct evidence remains under `[AUDIT-CORRECTNESS]001` and is not implied by this deterministic closeout.

## v0.1.1 Primary O4z Work

### [O4Z-DAE]001 - Reopen plain DAE and DAEO parity for the initial release

- **Status:** active-partial. The July 21 direct matrices and artifact/performance evidence remain regression baselines, not implementation closeout. The detailed source-backed plan is `docs/wiki/binaryen/passes/dead-argument-elimination/reopened-parity-plan.md`. The 2026-07-22 test-budget audit reduced the default public DAE/DAEO file from more than 16 minutes to 5 seconds on wasm-gc and 13 seconds on JS after a warm build by moving aggregate/artifact/threshold replays to explicit `#skip` lanes while retaining bounded behavior and white-box coverage. The current bounded suites are green at `335/335` white-box DAE and `325/325` DAEO. The July 22 active-parity renewal completed both variants' four compare lanes on native SHA-256 `3534db2ee9641a5b10193aef5535c96ac5277af5dc36ff6514bf9fa32bbea04a`: both regular `100000` lanes are exact, DAEO wasm-smith has zero residuals, and all remaining dedicated/random/plain-wasm residuals are existing measured cleanup families or Binaryen-v131 oracle failures documented in the pass fuzzing page.
- **Release target:** the repository currently says `v0.1.1`; the requested product target is the initial `0.1.0` release. Resolve version numbering separately, but do not publish the next initial `0.1.x` release while the DAE-owned slices below remain open.
- **Goal:** implement every represented Binaryen-v131 DAE family through generic boundary facts, value evidence, atomic plans, exact invalidation, and a truthful optimizing lifecycle.
- **Why:** the completion matrix still marks most A-J families `generic-partial` or `mixed`; the former closeout deleted active work whose own status still named open constant/localization/GC/result/control/type/worklist migrations.
- **Non-goals:** byte-identical output; optimizing indirect/call_ref callers that upstream DAE treats as unseen; duplicating shared local-layout algorithms inside DAE; assigning the pre-DAEO full-O4z wall stop to DAE.
- **Dependencies:** `[O4Z-NESTED]001` for the shared function-pipeline API and neighboring local-cleanup owners for canonical local layout.
- **Exit criteria:** all owned slices below are closed, every represented upstream source family is implemented or narrowly excepted, matrices and artifacts are renewed, and no DAE-owned release blocker remains.

### [O4Z-DAE-BOUNDARY]001 - Unify exposure facts and parameter live-in analysis

- **Owner:** `src/passes/dead_argument_elimination.mbt` boundary scanning, liveness, and current graph.
- **Status:** repaired on 2026-07-21 to Binaryen-v131 incoming-ownership semantics (reopened briefly after the initial landing, then closed again by this repair).
- **Deliverables:**
  - [x] One immutable original exposure snapshot for imports, exports, start, actual `ref.func`, and actual element references only.
  - [x] One current graph for direct calls, direct `return_call`, dropped calls, parameter-flow edges, result observers, and outgoing-tail facts.
  - [x] Separate queries: `dae_can_change_parameters` (incoming ownership) vs `dae_can_remove_function_result` (result-tail legality).
  - [x] One CFG-quality parameter live-in analysis that treats writes as kills and covers branches, loops, `try_table`, decoded legacy `try`, catches, and delegates.
  - [x] Absolute-index topology with explicit abs/def helpers; no duplicate exposure/topology storage on `DaeBoundaryFacts`.
  - [x] Exact fail-closed reasons and focused/public tests for actual exposure, type-only non-exposure, imported offsets, stale dispatcher rejection, and outgoing-tail result restrictions.
- **Exit criteria:** no signature-changing family uses a private visibility or parameter-use scanner; type equality alone never blocks parameter removal.

### [O4Z-DAE-PLAN]001 - Finish the common value-slice and transaction lifecycle

- **Owner:** value-slice, operand disposition, caller/callee projection, localization, and rewrite-plan helpers.
- **Status (2026-07-22 partial):** canonical direct-call operand slices, canonical parameter-slot actions, and ordinary unused-parameter analysis migration landed. Plain DAE and DAEO now pass `traps_never_happen` through core and nested convergence; scalar classification and callsite plans erase trap-only removed operands under TNH while ordinary mode preserves their evaluation. The scalar, forwarding-component, and family plans now carry validated `DaeCommitEffects` alongside the candidate: structural touched ownership stays separate from semantic worth, per-definition `worth_decided` records whether a producer owns the worth decision, and effects record parameter/result/body/local/control/type/metadata consequences, invalidation domains, and decision reasons. Successful scalar/component/family applications, `DaeWorkCommitted`, exact-literal worklist batches, core aggregation, and the DAEO pass-manager adapter preserve those effects. Scalar removal marks the callee worth without marking callsite-only callers; localization marks exact scratch-owning callers; materialization marks the callee; forwarding marks component members and any triggered ref-null follow-up. The pass manager now trusts the merged producer-effect stream across core scalar work, call-sink uniform work, forwarding components, broad uniform work, and payoff work; it no longer infers semantic worth from before/after local-count growth. Scalar plans report their own effects, and forwarding-component plans explicitly mark scratch-owning localized callers. Dispatcher-backed unread/localization work now invokes the canonical scalar classifier and immutable plan directly, reports those plan effects, including the represented stack-carried-void localization consequence directly from the committed scalar plan. No local-growth compatibility inference remains in the work-item adapter or pass manager. The general remove/constant compatibility entry now rebuilds current boundary facts and delegates to the immutable scalar plan, so every remaining caller of `dae_try_rewrite_candidate(...)` receives canonical slot classification, stack-carried-void slice recovery when requested, boundary ownership, epoch/call-identity checks, validation, rollback, and producer effects. Select operand recovery now uses the same canonical ordered value-slice collector instead of a private two-step stack walk. Verified immediate-suffix and selected ref-null compatibility producers now also reconstruct or consume original/current facts, require exact caller/count evidence, and commit through the scalar plan; their former direct caller-scope/callee finalization tails are deleted. The late semantic global-suffix specialization now commits its caller/callee candidate through `DaeFamilyRewritePlan` against the immutable original boundary, publishes exact materialization/local/type effects, and merges them into core/DAEO worth ownership instead of applying its selected-phase result directly. Only non-scalar phase-local application tails remain outside scalar/component/family plan ownership. The selected exact-literal scan/mutate helper is removed: ordinary literals, immediate suffixes, immutable globals, dynamically exposed global callees, broad-cleanup folded callees, and the historical Func867 default-literal fixture now enter epoch-bearing `DaeUniformActualWork` with original ownership and producer effects; its snapshot-less production helper is deleted. `DaeFamilyRewritePlan` still wraps every other dispatcher result and older producer family before commit. The scalar plan no longer carries an always-empty control-result rewrite list or a never-selected preserve-metadata branch; stale names remain the single explicit scalar metadata policy. Older producer-specific mutation helpers, broader metadata finalization, and complete invalidation ownership remain open.
- **Deliverables:**
  - [x] Make one `DaeValueSlice` carry arity, type, effects, traps, branches, unreachable state, producer identity, and epochs for every direct-call operand.
  - [x] Express each slot as keep, pure removal, effect replay, localization/retry, constant materialization, or type refinement while preserving left-to-right evaluation. *(ordinary unused-parameter analysis emits keep / remove-pure / remove-replay / localize-and-retry; uniform/general constant producers emit materialization; type refinement remains family-owned)*
  - [ ] Move GC refinement, result removal, control reconstruction, and remaining older paths through immutable validated plans. *(dispatcher families, optimizing unread/dropped/GC batches, ordinary-core GC parameter refinement and dropped-result removal, reverse/low exact revisits, low exact cleanup, broad immutable-global and adjacent-root revisits, dead-suffix parameter restoration, boundary cleanup, verified immediate suffixes, selected ref-null compatibility producers, and the late semantic global-suffix specialization now cross scalar/component/family validation; GC/result and control/type mutation helpers remain)*
  - [ ] Repair removed-slot locals, non-defaultable refs, typed tees, local indices, direct `return_call`, type edits, metadata, touched sets, and invalidations atomically.
- **Exit criteria:** no boundary-changing family mutates callsites or types outside the common candidate validation/commit/rollback boundary.

### [O4Z-DAE-FLOW]001 - Complete constants, localization, and recursive forwarding

- **Owner:** uniform-value solver, immutable-global handling, SCC/component discovery, and localization retry.
- **Deliverables:**
  - [ ] Match represented Binaryen per-operand constants: numeric/SIMD, `ref.null`, `ref.func`, `string.const`, supported ref conversions, and immutable `global.get`. *(uniform `v128.const`, `ref.func`, `string.const`, `ref.i31`, externalized/re-internalized i31 conversion expressions, immediate suffixes, and immutable globals use the generic value-slice/materialization work item with exact structural equality, original ownership, and producer effects; broader reference literals remain. Binaryen v131 DAE visits individual call operands through a single-`Literal` `PossibleConstantValues`, so generic `TupleMake` constant-expression support is not a DAE parameter requirement.)*
  - [ ] Use one monotone per-slot lattice across normalized forwarding SCCs and commit whole components atomically. *(the shared flow state now distinguishes unseen, forwarded-only, uniform, conflict, and blocked with monotone joins; solver failure records blocked rather than conflating it with unvisited state. Component commits enforce original ownership plus module/call/type/member/caller epochs and exact call identities, and include triggered ref-null materialization before final validation; broader normalized SCC dependency breadth remains)*
  - [ ] Remove parity-affecting `1024`/`4096`, prefix, nullable-count, and phase-only admissions; retain only explicitly optional cleanup budgets. *(the common exact-literal worklist no longer accepts an external productive limit or inert call-facts argument, and both early uniform-constant collection lanes now use one module-size-independent semantic admission policy. The computed/unread dependency worklist now also runs at every optimizing module size. Scalar parameter candidates no longer defer direct-caller cycles at `1024`, and forwarded-constant profitability revisits scan the full definition set at every size instead of stopping at `4096`; the post-revisit exact-literal frontier now admits every semantically eligible parameter count and type shape; broad plain-DAE uniform flow and optimizing reverse-exact replay are selected by pass semantics at every module size instead of the former `1024` definition split; other phase-order admissions remain tracked.)*
  - [ ] Localize all owned calls on effect blockage, repair EH/control structure, mark callers stale, and requeue through the common worklist.
  - [x] Preserve Binaryen's one-wave single-caller profitability throttle. *(the core reports consumed state; DAEO carries it across post-cleanup work and every producer-effect-frontier wave, and both written-forwarding and changed-terminal/default-argument fixtures prevent a second same-pass pruning wave)*
- **Exit criteria:** supported uniform values and forwarding are definition- and module-size-independent, and localization is a normal epoch transition.

### [O4Z-DAE-TYPES]001 - Generalize GC refinement, returned-value evidence, and type finalization

- **Owner:** GC argument/result LUBs, return evidence, control reconstruction, type-section edits, rec groups, and type liveness.
- **Deliverables:**
  - [ ] Strict-improvement reference-parameter LUB across every owned direct operand, including old-type local repair for incompatible writes. *(direct-GC batch discovery is definition-count-independent; direct actual evidence now covers allocation, exact `ref.func`, direct/tail call, typed indirect/tail-indirect, and typed call-ref/tail-call-ref producers across parsed and decoded abstract reference params; ordinary-core parameter refinement dispatches `DaeGcParameterRefinementWork`, derives exact `DaeRefineParameterType` plus any simultaneous `DaeRefineResult` actions, and commits through `DaeRewritePlan`; the optimizing direct-GC batch preserves producer effects through its family transaction; written refined parameters from both ordinary-core and optimizing batch producers now receive entry-initialized old-type locals with all nested gets/sets/tees remapped; nonnullable old types use nullable storage plus recursive `ref.as_non_null` repair on gets/tees, matching Binaryen's nondefaultable-local policy. ordinary-core collection plus optimizing-batch initial and stale-refresh evidence now share one exact-caller, fail-closed actual-value collector, and both parameter LUB application paths share one exact-length, exact-call-count strict-refinement combiner; the obsolete multi-target mutable collector and private batch plan have been deleted)*
  - [ ] One returned-value API for fallthrough, explicit returns, block/if/loop/select, typed/typeidx controls, static locals, tuples, flat multivalue lanes, and represented exceptional exits. *(GC result closure derives nested direct result dependencies from stable call identities; single-result analysis joins multiple nested explicit returns with fallthrough, treats `ref.null` arms as nullable bottom and rewrites control-pair nulls to the joined result type; direct `ref.null` result evidence now also participates in the generic instruction candidate path, so null-bottom explicit returns join with sibling/fallthrough leaves instead of aborting the multi-return collector; it accepts parsed/decoded abstract heap LUBs, derives exact `ref.func` result types, follows direct and typed `return_call` / `return_call_indirect` / `return_call_ref` signatures, and refines self-called functions when recursive results do not flow out, while decoded flat multivalue fallthrough lanes are covered and tuple/control producers still need consolidation)*
  - [ ] Lane-wise result LUB plus call, tee, parent-control, and caller refinalization. *(productive ordinary-core GC parameter/result and dropped-result commits, plus GC result dependency closure, construct and drain epoch-bearing `DaeControlReconstructionWork` and `DaeTypeRepairRetryWork` followups through one executor using producer effects and stale-item refresh. Result-only GC refinement now represents exact `DaeRefineResult` actions and commits its signature/body/type candidate through the common `DaeRewritePlan`; parameter+result and dropped-result products still use family plans, and broader lane/caller repair remains open)*
  - [ ] One deterministic type edit plan covering reuse/append, typeidx controls, rec groups, exactness/nullability, abstract heaps, tags, call_ref/call_indirect, tables/elements, globals, and metadata policy.
- **Exit criteria:** no broad GC batch, control carrier, or type-pruning family owns a private mutation tail.

### [O4Z-DAE-RESULTS]001 - Complete dropped-result, tail, multivalue, and bottom repair

- **Owner:** result-observer graph, dropped-call locations, return rewriting, and bottom handling.
- **Status (2026-07-22 partial):** all ordinary-core dropped-result admissions—including the three zero-parameter predicates and argument-side repair—preserve their source order and dispatch `DaeDroppedResultWork`. Complete-result and partial multivalue removal project arbitrary shrinking parameter/result sequences through `DaeRewritePlan`; the optimizing unread-parameter, direct-GC, and dropped-result batches now drain refreshed per-definition candidates through the same plan and merge exact producer effects. All signature-changing dispatcher families now require `DaeRewritePlan`; only control/type reconstruction and structurally unsupported phase-local products retain the family-plan fallback. Every path reports producer-owned callee/result plus exact caller/drop effects. Per-definition worth ownership prevents those effects from suppressing legacy changed boundaries merged into the same core wave. The obsolete selected-definition wrapper, descending attempt/cap collectors, empty fallback-neighborhood carrier, and rejected bucketed-attempt scaffold are deleted; their useful fact, timing, and exact-touched tests now target the live definition helper. The current dependency graph derives active non-tail undropped result observers, active direct-tail dependencies, their combined result-forwarding frontier, and the inverse per-caller result dependency rows from stable call identities while excluding dropped calls from observer evidence. Result-domain requeue consumes those exact rows, and GC result closure now performs dependency postorder plus forwarder requeue through the same graph without a productive cap or terminal-body shape scan. Ordinary dropped-result admission and the optimizing batch consume the authoritative current boundary guard: original/current ownership, every direct observer dropped, no direct-tail callee relation, and no outgoing direct/indirect/reference tail from the target. The specialized dead-suffix result families now consume one source-compatible fact carrier combining immutable original exposure, exact target identity, active call identities, common result observers/direct-tail dependencies, target-local outgoing tail facts, specialized dead-suffix legality, and module/call/type/signature/body/result epochs. Their candidates report exact result/caller effects and result-domain invalidations into `DaeFamilyRewritePlan`; exported, `ref.func`, element-exposed, stale, observed, direct-tail-callee, and target-outgoing-tail cases fail closed while valid dead chains and unrelated tails remain productive. Broader lane breadth and unified return/control repair remain open.
- **Deliverables:**
  - [x] Remove a result only when every owned direct call drops it and unseen/tail dependencies permit it. *(ordinary `DaeDroppedResultWork`, the live definition helper, and the optimizing batch require the current authoritative boundary guard; the shared specialized dropped-result context now enforces original exposure ownership while preserving dead-suffix-specific observer evidence; target-less lower repair evidence retains a conservative aggregate fallback)*
  - [x] Keep indirect/reference tails conservative; encode direct-tail compatibility in dependency epochs. *(current topology separates outgoing direct/indirect/reference tails and direct-tail callees; stable call identities provide exact tail dependency rows and stale work is epoch-rejected)*
  - [ ] Rewrite drops, call types, explicit returns, fallthrough values, controls, and multivalue lanes through one atomic result plan while preserving effects.
  - [ ] Preserve uninhabitable-result information with `call; unreachable`; broaden inhabitation only with proved type analysis.
  - [ ] Prevent stale double rewriting of one call for parameters and results in the same iteration.
- **Exit criteria:** every dropped-result decision and repair is graph-backed, transactional, and lane-aware.

### [O4Z-DAE-WORKLIST]001 - Finish common family dispatch, invalidation, diagnostics, and budgets

- **Owner:** `DaeBoundaryWorklist`, `DaeWorkItem`, `dae_process_work_item`, and family collectors.
- **Status (2026-07-23 partial):** committed work-item effects drive dependency requeue by explicit invalidation domain across before/after graphs. Result invalidation uses exact undropped observer/direct-tail rows, metadata-only changes remain local, and common work families publish narrow parameter/materialization, result, and control-only domain sets. Dispatcher unread/localization reuses the supplied immutable original/current graph, and stack-carried void-effect recovery is plan-owned. The canonical core worklist now aggregates `DaeDiagnostics` in production and both plain DAE and DAEO emit one deterministic trace record containing every counter plus every stable reason code; cleanup reentry emits its own scoped record. Producers without domains retain the conservative caller/callee fallback; legacy result/type/body/cleanup loops and selected/nested diagnostic counters still need migration.
- **Deliverables:**
  - [ ] Route every family through epoch-bearing no-change/deferred/commit/stale/rollback outcomes.
  - [ ] Replace parallel full scans and specialized phase loops with exact caller/callee/result/type/body/cleanup invalidations.
  - [ ] Remove correctness and required-parity attempt/cardinality caps; a defensive budget may stop optional work only with valid output and explicit telemetry.
  - [ ] Plumb production counters for selected-only admission, guards, stale retries, rollbacks, localization, type/result edits, and nested replay. *(plain DAE and DAEO now emit deterministic canonical-core records for analyzed/produced/applied/requeued work, semantic edit counters, and all stable reason codes; selected-only, guard, scratch-local reuse, effect replay, specialized-loop, and nested-roster counters remain)*
- **Exit criteria:** no required transform depends on a `FuncNNN`, numeric band, module-size bucket, or arbitrary productive-attempt cap; selected-only correctness counters are zero.

### [O4Z-DAEO-LIFECYCLE]001 - Match Binaryen's worth-optimizing set and nested convergence

- **Owner:** `src/passes/pass_manager.mbt` DAEO touched scheduler and the shared boundary/nested loop.
- **Status (2026-07-23 partial):** the arbitrary `touched_count > 8`, module `>100`, local `>128`, and instruction `>1000` lifecycle selectors are removed. Ordinary nested replay derives a Binaryen-shaped worth set from producer-owned parameter/refinement/localization/result effects plus result-change callers in both original and current call graphs; plain callsite-only edits and touched callers with unchanged preexisting locals are not replayed. Producer-owned body-only worth functions enter the same frontier regardless of encoded body size. Worth ownership is explicit per definition, so producers authoritatively include or exclude exact callsite-only callers without any local-count compatibility inference. Changed-boundary local compaction and immutable-field folding now run transactionally at every function/module cardinality, then the shared `precompute-propagate`-first roster executes exactly once; the former private broad-cleanup roster and folded-callee recursion are deleted. The selected literal/global owner-order blocker was resolved by common epoch-bearing uniform work items. A 101-definition replay and the formerly blocked literal/global fixtures match explicit Binaryen v131 output. Every validated changed boundary enters the filtered roster. Post-core call-sink, forwarding-component, broad-uniform, and payoff effects are merged with core effects before worth selection, and the pass manager no longer infers caller worth from local-count growth. DAEO carries the consumed one-wave single-caller state across post-cleanup reentry. Final convergence no longer recursively replays the whole optimizing pass: an exact producer-owned seed drains represented boundary families through epoch-bearing work items, applies followup control/type work, requeues only effect invalidations, runs the shared nested roster only for committed worth, and retains only valid strictly smaller waves. Legacy worth inference and whole-pass retry are retired.
- **Deliverables:**
  - [ ] Define `worthOptimizing` from productive param/refinement/localization/result changes and affected callers, not artifact size or definition identity.
  - [x] Run touched-only `precompute-propagate` plus the shared default function roster, nested and validated; keep plain DAE free of this suffix. *(the private broad-cleanup roster is deleted, exact-order traces prove one shared execution, and plain DAE remains negative)*
  - [x] Replace `touched_count > 8`, module `>100`, local `>128`, instruction `>1000`, and material-caller thresholds with source-matched per-function profitability or explicitly non-parity budgets. *(all listed lifecycle selectors and the exact changed-boundary heavy-replay thresholds are removed; transactional validation and non-larger per-definition retention remain)*
  - [x] Feed nested body changes back into DAE until boundary and nested cleanup both converge. *(final convergence drains the producer effect frontier across represented work families, refreshes exact invalidations, replays the shared touched roster, preserves the one-wave throttle, and retains only valid strictly smaller waves; recursive whole-pass retry is deleted)*
  - [ ] Keep the canonical `+4,318` local-layout/remap family under shared local-cleanup ownership.
- **Exit criteria:** DAEO visible cleanup is selected by the same semantic touched set at every module size, or every omission is an explicit measured performance exception rather than parity closeout.

### [O4Z-DAE-RELEASE]001 - Renew source tests, generated evidence, artifacts, and release integration

- **Owner:** DAE/DAEO tests, compare profiles, dossiers, artifacts, presets, and release metadata.
- **Deliverables:**
  - [x] Port or map all represented v131 cases from `dae_tnh`, `dae-gc`, `dae-gc-refine-params`, `dae-gc-refine-return`, `dae-optimizing`, and `dae-refine-params-and-optimize`; exclude experimental `dae2`. *(the source-case map covers every upstream module/function family, records common ownership and reopening criteria, and TNH-1 now has exact plain/optimizing behavior)*
  - [ ] Add arbitrary-definition red-first tests for every generic recognizer and keep artifact functions only as regressions.
  - [ ] Keep plain and optimizing traces, normalizers, matrices, artifacts, and medians separate.
  - [ ] After each widening, run focused/white-box/public tests, serial full tests, wasm-gc check/test, external validation, idempotence, runtime execution, and explicit-v131 regular/dedicated/wasm-smith/random-all lanes.
  - [ ] Classify every residual per source family/function; do not offset a missing or larger family with unrelated aggregate wins.
  - [ ] Reopen and close completion-matrix rows as their common owner path lands; complete ordered slot-48 artifact replay and resolve the `0.1.0` versus `0.1.1` release label.
- **Exit criteria:** zero semantic/validation failures, zero unclassified size-losing families, accepted performance, exact-once public placement, and no active DAE-owned release blocker.

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

### [AUDIT]004 - Thin module-pass coverage

- Keep only still-useful test expansion:
  - `directize`: imported/exported/passive/declarative/multi-table/tail-call negatives and positives;
  - any newly widened scheduler owner from the primary O4z queue.
- Do not duplicate already closed DIE/once-reduction breadth tasks; decoded legacy-`Try` correctness repairs are explicitly owned by `[AUDIT-LEGACY-EH]001`.

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
