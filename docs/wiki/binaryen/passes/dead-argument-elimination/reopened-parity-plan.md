---
kind: workflow
status: working
last_reviewed: 2026-07-21
sources:
  - ./completion-matrix.md
  - ./de-artifacting-inventory.md
  - ./implementation-structure-and-tests.md
  - ./starshine-port-readiness-and-validation.md
  - ./binaryen-strategy.md
  - ../dae-optimizing/starshine-strategy.md
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/param-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h
related:
  - ./index.md
  - ../dae-optimizing/index.md
  - ../../../../../agent-todo.md
---

# Reopened Binaryen-v131 DAE and DAEO parity plan

## Release note

The repository currently labels the active release line as `v0.1.1`, while the requested product goal is the initial `0.1.0` release. This plan does not change package versions. It treats the work below as blocking the next unpublished initial `0.1.x` release until the release number is resolved separately.

## Audit verdict

The July 21 closeout was valid as an evidence checkpoint, but premature as a claim of implementation parity.

The direct four-lane matrices, retained-artifact validity, idempotence, removal of production `FuncNNN` gates, exact slot-48 placement, and measured pass-local medians remain valuable. They do not close the implementation while the completion matrix still marks most behavior families `generic-partial` or `mixed`, and while the implementation dossier explicitly says that constant materialization, scratch localization, GC refinement, result removal, control reconstruction, type repair, specialized family extraction, and production-wide diagnostic/worklist plumbing remain outside the common transaction lifecycle.

This reopen is therefore not a rollback to artifact-specific code and not a demand for byte-identical output. The target remains Binaryen-v131 behavior parity, with source-backed Starshine improvements accepted only when they are valid, semantically equivalent, measured, deterministic, and covered by explicit reopening criteria.

## Binaryen-v131 reference lifecycle

A faithful local design should preserve these source-level properties even when Starshine uses a different IR:

1. Scan module code and functions for owned direct calls, direct tail calls, dropped direct calls, indirect/reference tail barriers, parameter live-in state, and `ref.func` exposure.
2. Mark exported or referenced functions as having unseen calls and do not change their boundaries.
3. For each closed direct boundary, refine live reference parameter types, refine result types, and apply a uniform constant actual when all owned calls agree.
4. Remove unread parameters from the callee and every owned call together. If nested operand effects block removal, localize calls and retry in a later iteration.
5. Attempt dropped-result removal only in an iteration that has not already rewritten the same calls for parameter removal, only when all direct calls drop the result, and only when tail/unseen-call constraints allow it.
6. Preserve uninhabitable-result information with `call; unreachable` repair.
7. In the optimizing variant only, run `precompute-propagate` followed by the default function optimization pipeline on the exact set of functions made worth optimizing.
8. Iterate to convergence while preserving Binaryen's one-single-caller unprofitable-chain throttle.

## Reopened workstreams

### 1. Boundary ownership and parameter live-in analysis

**Gap.** Starshine has rich boundary reasons and an original/current graph, but visibility, tail, tag/table/type exposure, and parameter-use legality are still consumed by multiple family-specific collectors. The pass also needs one CFG-quality definition of whether the incoming parameter value is live at function entry; syntactic `local.get` scanning is insufficient when a parameter is overwritten before its first read or when reads/writes occur through branches and exceptional control.

**Implementation status (2026-07-21 repair, `[O4Z-DAE-BOUNDARY]001`).**

Shared fact structures now in `src/passes/dead_argument_elimination.mbt`:

- `DaeFunctionExposure` — exact incoming exposure only: import/export/start/`ref.func` body vs module code/active/passive/declarative element. Type equality with tags, tables, `call_indirect`, or `call_ref` does **not** create exposure.
- `DaeOriginalBoundarySnapshot.exposure` — immutable per-function exposure snapshot; `escaped` remains the derived boolean OR of exact exposure.
- `DaeCurrentTopologyExtras` on `DaeCurrentBoundaryGraph` — absolute-index direct `return_call` callers/callees plus outgoing body facts (`has_outgoing_call_indirect` / `has_outgoing_call_ref` / `has_outgoing_return_call*`). Topology arrays and edge values use absolute function indices; definition-relative consumers convert through `dae_abs_func_idx` / `dae_def_idx_of_abs`.
- `DaeBoundaryFacts` — `{ original, graph, incoming_param_live_by_def, incoming_param_live_body_epochs }` with accessors for `original.exposure` and `graph.topology` (no duplicate mutable copies).
- Queries:
  - `dae_can_change_parameters` — incoming ownership only; outgoing tails/`call_indirect`/`call_ref` do not block parameter removal.
  - `dae_can_remove_function_result` — requires owned incoming boundaries, then rejects outgoing tails, direct-tail callees, and incomplete dropped observers.
  - `dae_is_incoming_parameter_live` / `dae_incoming_parameter_liveness`.

**Binaryen-aligned rules recorded here:**

- Actual function references (`ref.func`, element entries, exports, start) create exposure.
- Type equality does not create exposure.
- Outgoing tail calls are result-removal constraints, not general parameter barriers.
- Topology indices use one absolute function-index coordinate system.

**Liveness algorithm.** Prefer HOT CFG liveness via `dae_hot_param_entry_liveness` (`@ir.cfg_build` + `@ir.liveness_build` + `@ir.local_live_in` at the entry block), which models structured control including `block`/`if`/`loop`/`br*`/`try_table` exceptional edges. Writes kill incoming values; merges are conservative. Legacy `Try` is not HOT-lifted today, so analysis fail-closes by marking affected parameters live (safe). Stack-switching and other unsupported forms likewise fail closed.

**Consumers migrated.** Ordinary generic unused-parameter eligibility in `dae_run_core_once`, the scalar unused-param rewrite plan guard, and the selected unread dispatcher path now consume the shared live-in oracle and final `dae_can_change_parameters` guard. Specialized family scanners remain temporarily with TODOs pointing at later workstreams; the shared final guard is authoritative for protected/uncertain boundaries.

**Unsupported / fail-closed.** Legacy `Try` (no HOT lift), stack-switch/resume forms, uncertain exceptional/delegate paths, and exact exposure reasons above. Never classify an uncertain parameter as dead.

**Deterministic tests** in `dead_argument_elimination_wbtest.mbt` and `dae_optimizing_test.mbt`: exact export/start/`ref.func`/element exposure; type-only tag/table/indirect/`call_ref` non-exposure; outgoing-tail parameter eligibility vs result rejection; absolute imported-offset topology; real dispatcher stale rejection; public if/loop/try/tail/exposure integration.

**Exit criterion.** No signature-changing family has a private visibility or parameter-use scanner, and every unsupported exact exposure produces one reason-coded fail-closed outcome.

**Implementation strategy (historical plan; see status above for landed slice).**

- Build one immutable original exposure snapshot for imports, exports, start, `ref.func`, active and passive elements, table/type carriers, tags, module-level code, direct calls, and direct `return_call` sites.
- Maintain one current boundary graph containing exact direct callers, dropped-call observers, caller-to-callee parameter slices, direct-tail edges, and conservative indirect/reference tail barriers.
- Implement a parameter-only backwards liveness analysis at function entry. Track only parameter indices, ignore unreachable blocks, treat writes as kills, merge predecessor facts conservatively, and model `block`, `if`, `loop`, `br*`, `return`, `try_table`, decoded legacy `try`, catches, and delegate edges.
- Make every boundary-changing candidate consume the same `DaeBoundaryFacts` record. Unknown or unsupported control must fail closed before mutation.
- Keep indirect and `call_ref` callers conservative; Binaryen v131 does not rewrite those callsites in the original DAE pass.

**Required tests.** Parameters overwritten before first read; reads on one branch; loop-carried reads; `try_table` and legacy-`try` body/catch reads; export/start/ref.func/element exposure; direct and indirect tail barriers; imported and defined tags; module-level `ref.func`; stale caller-count refresh.

### 2. One value-slice carrier and one atomic parameter transaction

**Gap.** The ordinary private scalar path and forwarding components use validated plans, but constant materialization, localization, GC, results, control reconstruction, and older specialized paths still use separate application tails. Effect, trap, branch, ambient-stack, and localization facts are not yet universally carried by one operand representation.

**Landed under [O4Z-DAE-PLAN]001 (2026-07-21 analysis consolidation).** Ordinary unused-parameter analysis now derives call-operand decisions from one enriched `DaeValueSlice` per direct-call argument and one `DaeParameterAction` per callee parameter slot. Mutation application for the ordinary scalar path remains the existing rewrite-plan path; the full immutable transaction migration is still open.

Structures / APIs introduced or extended:

- `DaeValueSlice` — sole direct-call operand carrier; now carries `input_arity` / `output_arity`, optional static `value_type`, `DaeValueProducerKind`, observable-effect / trap / escaping-branch / unreachable facts, optional `DaeDirectCallKind`, call identity (`call_idx`, `caller_def`, `callee_abs`), and module/call/type/signature/body epochs. Per-function staleness is checked against the owning caller, not the target callee.
- `DaeValueProducerKind` — enum (not string compares): constant/pure leaf, local read, global read, ordinary expression, direct call, indirect call, `call_ref`, structured control, unreachable, unknown.
- `DaeDirectCallKind` — `DaeDirectCall` | `DaeDirectReturnCall`; part of slice / plan identity so a stale `call` plan cannot apply after the site becomes `return_call` (and vice versa).
- `DaeDirectCallOperandSlices` — ordered parameter slices for one owned direct callsite.
- `dae_direct_call_operand_slices` — authoritative recovery API; fails closed on stack underflow, ambiguous boundaries, call-kind / callee mismatch, ordering violations, and related unavailable evidence.
- `dae_direct_call_operand_slices_are_ordered` — non-overlap, source order, end-before-call, parameter-order (not reverse stack-pop) invariant helper.
- `DaeParameterAction` — `DaeKeepParameter`, `DaeRemovePureParameter`, `DaeRemoveParameterReplayEffects`, `DaeLocalizeParameterAndRetry`, `DaeMaterializeConstantParameter`, `DaeRefineParameterType` (materialize/refine reserved; ordinary analysis does not emit them yet).
- `dae_classify_parameter_slot` / `dae_classify_unused_parameter_actions` — consume `DaeBoundaryFacts`, shared incoming liveness, and owned callsite slices.

Fail-closed cases for slicing: stack underflow; ambiguous producer boundaries; structured-control / escaping-branch ambiguity when evidence is unavailable; unsupported multivalue composition; stale call identity / call kind; signature mismatch; call vs `return_call` mismatch. Classifier returns `Keep` for live params, unprotected missing slices, protected boundaries, unknown producers, and stale epochs.

Deterministic tests added in `dead_argument_elimination_wbtest.mbt` cover exact slice recovery (pure/mixed/multicallsite/imports/`return_call`/ambient/multi-instr/multivalue/underflow/stale kind), producer kinds, slot actions, ordering invariants, active-vs-inactive call identity, exact family touched derivation, original-escape rejection at the broad exact-root family entry, transactional dead-suffix parameter restoration, and public ordinary unused-parameter preservation (pure, effectful replay, `return_call`, live keep, legacy `try`, `ref.func` exposure, type-only tag).

**Remaining transaction work (still open):**

- Full immutable validated plan commit/rollback for every signature-changing family. The scalar plan owns detailed parameter edits; forwarding component plans atomically compose members and triggered ref-null materialization; and `DaeFamilyRewritePlan` wraps every other dispatcher result plus optimizing unread/dropped-result/GC batches, ordinary core candidates, reverse/low exact revisits, low exact cleanup, broad immutable-global and adjacent-root revisits, dead-suffix parameter restoration, and boundary cleanup. Family application derives touched ownership from exact body/signature deltas, ignores inactive dead-suffix calls in identity totals while still rescanning active bodies for stale inserted calls, and folds active-boundary unreachable-tail repair into the candidate before final validation. The three plan kinds and their successful applications now carry `DaeCommitEffects`: exact structural touched and semantic worth bitmaps, parameter/result/body/local/control/type/metadata consequences, invalidation domains, and decision reasons. Work outcomes and the DAEO adapter preserve these effects; covered definitions no longer have worth reverse-engineered from generic touched state. Exact local-count growth remains a temporary compatibility bridge only for older scalar producers that still return a bare module candidate. Older producer-specific mutation helpers still need the same lifecycle and direct effect emission.
- Constant materialization consolidation beyond the common scalar transaction. Solved uniform values, exact-literal/immutable-global fallback, and verified immediate suffixes become `DaeMaterializeConstantParameter` actions, honor original ownership, preserve older stack-carried operands, and commit through the complete scalar candidate. The selected exact-literal scan/mutate helper is removed: core immutable-global revisits and broad-cleanup folded-callee follow-up now enter epoch-bearing `DaeUniformActualWork` and return producer effects. Remaining older direct producer tails still need migration.
- Localization consolidation beyond the ordinary scalar transaction. The scalar plan now owns typed scratch-local insertion, localized removed-slot projection, exact caller epochs, candidate validation, commit, and rollback; forwarding/broad-family localization still needs the same lifecycle.
- GC parameter/result producer consolidation beyond the dispatcher and optimizing batch transactions.
- Dropped-result producer consolidation beyond the dispatcher and optimizing batch transactions.
- Control/type reconstruction cleanup beyond the dispatcher-owned lanes.
- Metadata finalization and complete touched/invalidation transaction.
- Migrate remaining parallel consumers (`dae_try_rewrite_candidate`, selected unread, select/GC helpers) marked with owning `[O4Z-DAE-*]` TODOs.

**Implementation strategy.**

- Generalize `DaeValueSlice` into the sole direct-call operand carrier. It must record exact instruction span or HOT expression identity, input/output arity, static value type, producer kind, observable effects, potential traps, escaping branch/control, unreachable production, and epoch dependencies.
- Represent each parameter slot with an explicit action: `Keep`, `RemovePure`, `RemoveReplayEffects`, `LocalizeAndRetry`, `MaterializeConstant`, or `RefineType`.
- Preserve WebAssembly left-to-right operand evaluation. Removed pure operands disappear; removable effectful operands are replayed in the same relative order; operands with nested effects/control are localized around the whole call before retry rather than spliced unsafely.
- Build the complete caller edits, callee signature/body/local projection, type-section edits, control/type repairs, metadata policy, touched set, and invalidation set before mutation.
- Revalidate module/call/signature/body/type epochs immediately before applying the plan. Construct and validate a candidate module, then commit atomically or return the original module with a stable rollback reason.
- Preserve removed parameter storage only when the body still writes or reads the remapped local. Handle non-defaultable references, `local.tee` result types, old-type shadow locals, and local-index remapping explicitly.
- Treat direct `call` and direct `return_call` composition as part of the plan identity.

**Required tests.** Mixed kept/removed slots; multiple calls in one caller; ambient stack values; effectful and trapping producers; escaping branches; unreachable operands; direct `return_call`; parameter writes; non-defaultable locals; typed `local.tee`; stale call-kind changes; validation rollback; unchanged unrelated functions.

**Exit criterion.** Every signature-changing parameter family crosses the same immutable plan and validation boundary; no family mutates a callsite before the full module rewrite is known valid.

### 3. Uniform constants, immutable globals, localization, and forwarding SCCs

**Gap.** Uniform-value work exists, but several constant and forwarding lanes still depend on phase-specific admission, original-shape seeds, small/broad ordering, nullable-count thresholds, or separate retry paths. This can miss Binaryen transformations even when it no longer threatens validity.

**Implementation strategy.**

- Match Binaryen's `PossibleConstantValues` contract for every represented per-operand constant expression: numeric and SIMD constants, `ref.null`, `ref.func`, `string.const`, supported `extern.convert_any` / `any.convert_extern` wrappers, and immutable `global.get` identity. Do not equate merely similar expressions or mutable globals.
- Keep generic tuple constant expressions out of the DAE parameter contract unless upstream changes: Binaryen v131 `applyConstantValues` visits each `Call` / `CallRef` operand independently, while `PossibleConstantValues` stores one `Literal`; the broader `TupleMake` branch belongs to the shared `Properties::isConstantExpression` API, not this per-parameter use (Binaryen v131 `src/passes/param-utils.cpp`, `src/ir/possible-constant.h`, and `src/ir/properties.h`).
- Use one per-parameter monotone lattice over the forwarding graph: `Unseen`, `ForwardedOnly`, `Uniform(value)`, `Conflict`, and `Blocked`. Merge caller evidence through normalized SCCs until no slot changes.
- Materialize the agreed value in the callee before ordinary live-in analysis/removal, then let the common parameter plan delete the now-unread boundary input.
- Replace correctness- or parity-affecting `<=1024`, `<=4096`, prefix, nullable-count, and phase-only admissions with exact candidate facts. A retained threshold may only suppress optional non-boundary cleanup and must be labeled as such in diagnostics.
- Preserve Binaryen's deliberate one-wave single-caller profitability throttle; do not turn the pass into unbounded chain pruning.
- When removal fails because of nested effects, localize every owned call to the target with a ChildLocalizer-equivalent transform, repair exceptional nested-pop/control structure, mark the affected callers stale, and requeue the boundary.
- Commit recursive forwarding components atomically. The component transaction rejects stale type/call identities and any member that escaped in the original module before changing a signature; triggered ref-null specialization is included in the same final candidate so a cycle cannot expose partial follow-up edits.

**Required tests.** Long forwarding chains; reordered parameter forwarding; mutually recursive cycles; multiple independent SCCs; constant disagreement; immutable-global identity; represented ref/null/string constants and flat multivalue lanes; localization nested inside another call; EH-localization repair; large module with one candidate; prior threshold boundaries; deterministic queue order.

**Exit criterion.** Uniform values and forwarding are definition- and module-size-independent, all supported constant forms match the upstream contract, and localization is a normal requeue transition rather than a side phase.

### 4. GC parameter/result refinement and returned-value carriers

**Gap.** Starshine covers many focused GC/control shapes, but broad GC batches, arbitrary returned-value carriers, local value flow, richer parameterized controls, and recursive/shared type repair remain outside one generic lifecycle.

**Implementation strategy.**

- Compute a least upper bound for each live reference parameter across every owned direct operand. Refine only on a strict subtype improvement and never refine an unread parameter before ordinary removal.
- Apply a TypeUpdating-equivalent repair when the old parameter type is still needed by writes: create an old-type local, copy the refined incoming parameter into it, and retarget incompatible body accesses. Recompute `local.tee`, typed control, and parent expression types.
- Build one returned-value evidence API covering implicit fallthrough, explicit `return`, terminal `block` / `if` / `loop`, typed and type-indexed controls, `select`, static `local.get` types, simple nested carriers, tuples, flat multivalue lanes, and represented `try_table` exits.
- Compute result LUBs lane by lane. Update the function result, every direct call expression, terminal control types, and dependent callers in one transaction.
- Refinalize only the changed functions and their affected parents when possible; use module-wide refinalization only as a conservative fallback.
- Extend the type graph utilities for exactness, nullability, abstract heap types, recursive groups, shared types, and mixed rec groups. Unsupported proposal forms must fail closed with a representation-blocker test.

**Required tests.** Upstream `dae-gc-refine-params` and `dae-gc-refine-return` families; sibling leaf LUB; nullable/non-null exactness; incompatible leaves; parameter writes and tees; explicit-return branches; typed/type-indexed block/if/loop; multivalue lanes; local-return evidence; recursive-group result and parameter types; shared/unshared barriers.

**Exit criterion.** Parameter and result refinement use the same generic value/type evidence and type finalizer across all represented carriers; no broad GC batch or selected carrier owns a private mutation tail.

### 5. Dropped results, tail dependencies, multivalue observation, and bottom repair

**Gap.** Dropped-result work is far stronger than the old implementation, but observer discovery, explicit-return rewriting, multivalue lane observation, specialized control repair, and bottom/uninhabited forms are still fragmented.

**Implementation strategy.**

- Build an exact result-observer graph from direct calls and direct tail calls. A result may be removed only when all owned direct calls drop it, the function has no unseen calls, the function itself has no tail-call result dependency, and it is not a direct-tail callee whose signature must remain compatible.
- Keep indirect and reference tail calls as explicit fail-closed barriers unless a future source-backed type relation proves otherwise.
- Do not rewrite the same call location for parameter deletion and result removal in one stale iteration. Use plan epochs or Binaryen-equivalent phase separation.
- Replace function results, call result types, surrounding drops, explicit returns, fallthrough values, typed controls, and multivalue lanes through one return-rewrite plan that preserves operand effects and control.
- For an uninhabitable removed result, replace the dropped call with `call; unreachable` so callers retain non-returning information. Cover non-null null-heap bottoms first, then broaden only with a proved inhabitation analysis.
- Track result observation per lane for tuples/multivalue functions rather than assuming a whole-result suffix shape.

**Required tests.** All calls dropped; one observed call; recursive calls; caller and callee direct tails; indirect/ref tail barriers; explicit return and fallthrough; effectful return operands; multivalue partial observation; `call(unreachable)`; direct `return_call(unreachable)`; uninhabitable references; stale drop location after another rewrite.

**Exit criterion.** Every dropped-result decision comes from the common observer graph and every body/caller repair comes from one atomic result plan.

### 6. Type-section, rec-group, liveness, and metadata finalization

**Gap.** Function-type reuse/append is implemented in important paths, but multiple specialized type mutation tails, conservative rec-group pruning, imported/defined tag liveness, and metadata policy remain partial.

**Implementation strategy.**

- Introduce one module type-edit plan that interns replacement function signatures deterministically, rewrites function-section references, and rewrites type-indexed control only when its full parameter/result contract is known.
- Rebuild recursive groups atomically. Preserve relative indices and group boundaries, reuse an equivalent existing type when legal, and never strand a member or reference after pruning.
- Compute function-type liveness from functions, `call_indirect`, `call_ref`, tables/elements, globals, imported and defined tags, module-level code, and all represented type carriers before pruning.
- Keep local/function names and custom metadata under an explicit policy. Binaryen clears local names during generic parameter removal; Starshine may retain or clear different metadata only when the behavior is intentional and deterministic.
- Validate the complete candidate after type and metadata edits, not only the touched body.

**Required tests.** Reuse versus append; duplicate signatures; imported and defined tags; type used only by call_ref/call_indirect/table/element/global; singleton and mixed rec groups; recursive function types; type-indexed controls; local-name policy; stale type epoch; imported-tag regression.

**Exit criterion.** All DAE families request edits from one type finalizer, and no live type can be pruned because a family-specific scanner omitted a carrier.

### 7. Common worklist, invalidation domains, diagnostics, and budgets

**Gap.** All ten work-family labels have handlers, but result/type/body/cleanup invalidations remain conservative and several specialized collectors still perform their own lifecycle. The completion matrix still describes production-wide diagnostic plumbing as partial.

**Implementation strategy.**

- Make every candidate an epoch-bearing `DaeWorkItem` with target, family, component, exact slot/lane evidence, expected module/call/signature/body/type epochs, and dependency domains.
- Route every family through `dae_process_work_item` and one `NoChange`, `Deferred`, `Commit`, `StaleRequeue`, or `Rollback` result.
- Refresh only invalidated facts: callers for call/body changes, callee and SCC neighbors for signature/forwarding changes, result observers for result changes, and type users for type changes.
- Remove productive-attempt and module-cardinality caps from correctness and parity behavior. A defensive budget may stop optional work only after leaving a valid committed module, emitting a reason code, and saving enough evidence to reproduce the skipped frontier.
- Keep deterministic component and definition ordering. Terminate through monotone parameter/result/type reduction plus duplicate-suppressed queue exhaustion.
- Require production counters for selected-only rewrites, guard skips, stale retries, rollbacks, localizations, type edits, result edits, and nested passes. Selected-only correctness counters must remain zero.

**Required tests.** Stale signature/body/call/type epochs; changing call counts; deterministic requeue; no-progress localization; many independent candidates; long result chains; mixed family invalidation; work-budget fail-closed behavior; zero selected-only production admission.

**Exit criterion.** No production family owns a parallel scan-and-mutate loop, and no correctness or required parity transform depends on a numeric band, module size, definition identity, or arbitrary attempt cap.

### 8. Exact DAEO touched set and optimizing lifecycle

**Gap.** Starshine shares the nested roster and has correct slot placement. The arbitrary `touched_count > 8` replay skip was removed on 2026-07-22, and ordinary replay now derives a semantic worth set from changed signatures, result-change callers, and exact local-count growth for transitional scratch-local cleanup instead of replaying every structurally changed callsite caller or every touched caller with preexisting locals. Full replay is still selected by module-size and material-caller thresholds. Local-count and instruction-count no longer suppress semantic nested replay: those checks now belong only to the earlier broad changed-boundary fast-skip policy, so the authoritative 129-local cleanup transaction runs before the per-function nested roster. The selected literal/global blocker exposed by the first module-guard removal trial is addressed: those producers now use the common epoch-bearing uniform-value lifecycle with original ownership and effects. The module guard remains open pending a fresh focused removal replay.

**Implementation strategy.**

- Define `worthOptimizing` from source semantics, not artifact size: a callee whose parameter was removed or refined; a function whose body was changed by localization/materialization; a callee whose result was removed; and affected callers when bottom repair or removed drops create cleanup opportunities.
- Run `precompute-propagate` followed by the shared default function optimization roster on exactly that set. Mark the runner nested and validate immediately before and after in debug/verification modes.
- Preserve plain DAE separation: no nested cleanup in `dae`.
- Replace broad touched/module/local/instruction guards with a per-function profitability decision that is independent of definition identity and does not omit mandatory boundary/type/control repair. If a defensive runtime budget remains, it must be telemetry-visible and must not be counted as Binaryen parity closeout.
- Feed nested body changes back into the common DAE worklist until neither boundary rewriting nor nested cleanup creates a new DAE candidate.
- Keep the canonical `+4,318` retained-artifact local-layout/remap family under shared `simplify-locals` / `coalesce-locals` / local-ordering ownership. Do not hide it as a DAE win or duplicate those algorithms inside DAE.

**Required tests.** Exact touched-only identity; unrelated function byte identity; more than eight touched functions; more than 100 definitions; touched functions above 128 locals or 1,000 instructions; tail-call bodies; post-refinement dead parameter; post-result-removal dead parameter; nested trace order; repeated application; runtime budget diagnostics.

**Exit criterion.** DAEO's visible cleanup is selected by the same semantic touched set at every module size, or every retained omission is explicitly classified as a non-parity performance exception with a focused reopen condition.

### 9. Source-test, generated, artifact, and release closeout

**Gap.** The generated evidence is strong, but it currently substitutes for source-family completion in the release claim. Several official Binaryen test families are represented only by bounded local fixtures, and the completion matrix still records generic-partial implementation ownership.

**Implementation strategy.**

- Port or map every represented case from Binaryen-v131 `dae_tnh.wast`, `dae-gc.wast`, `dae-gc-refine-params.wast`, `dae-gc-refine-return.wast`, `dae-optimizing.wast`, and `dae-refine-params-and-optimize.wast`. Keep `dae2.wast` excluded from original DAE signoff.
- Add red-first arbitrary-definition tests for every generic recognizer; keep historical artifact functions only as regressions.
- Maintain separate plain DAE and DAEO suites, traces, normalizers, matrices, artifacts, and medians.
- After each behavior widening, run focused white-box tests, public pass tests, `moon info`, `moon fmt`, serial full tests, wasm-gc check/test, external validation, idempotence, runtime execution where possible, and the official-v131 regular, dedicated, wasm-smith, and random-all lanes.
- Classify residuals per behavior family and per function. Aggregate size wins cannot offset a source-backed larger/missing family.
- Reopen the completion matrix rows as work lands; close a row only when its common owner path, focused source family, generated evidence, and reopening criterion are all current.

**Exit criterion.** Every represented Binaryen-v131 DAE family is either implemented through the common lifecycle or documented as a narrow representation/performance exception; there are zero validation or semantic failures, zero unclassified size-losing families, accepted pass-local performance, exact-once public placement, and no active DAE-owned release blocker.

## Accepted divergences that do not reopen DAE semantics

- Starshine may omit Binaryen's unread replacement local when the removed parameter has no surviving read or write. That is a valid, smaller projection, not a missed iteration.
- Byte-identical output is not required. Proven pure unreachable-prefix cleanup and other deterministic Starshine size wins may remain when they preserve effects, traps, control, validation, and runtime behavior.
- Unknown indirect callers, `call_ref` callers, indirect/reference tail calls, continuations, and unsupported exceptional/type proposal forms may remain conservative barriers; they require focused negative tests and explicit reopening conditions, not speculative rewriting.
- The retained DAEO canonical local-layout/remap delta belongs to shared local-cleanup passes.
- The 1,800-second full-O4z stop occurs before DAEO in `simplify-locals-nostructure`; it is not a DAE performance defect.

## Recommended implementation order

1. Boundary/live-in facts.
2. Generic value slices and atomic parameter plans.
3. Uniform constants, localization, and forwarding SCCs.
4. GC parameter/result refinement and type finalization.
5. Dropped results, tails, multivalue observation, and bottom repair.
6. Full common worklist/invalidation migration.
7. Exact DAEO touched lifecycle and guard replacement.
8. Official source-test mapping, four-lane renewal, artifacts, performance, preset replay, and release signoff.

Do not widen nested cleanup or artifact admission before the common transaction and epoch model owns the corresponding boundary family. Correctness and stale-plan rejection come before recovering output shape.