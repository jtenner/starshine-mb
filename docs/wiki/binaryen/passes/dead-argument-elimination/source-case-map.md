---
kind: workflow
status: working
last_reviewed: 2026-07-22
sources:
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/param-utils.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/possible-constant.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/properties.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_131/test/lit/passes/dae-refine-params-and-optimize.wast
  - ../../../../../src/passes/dead_argument_elimination.mbt
  - ../../../../../src/passes/dead_argument_elimination_wbtest.mbt
  - ../../../../../src/passes/dae_optimizing_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/pass_manager_wbtest.mbt
related:
  - ./reopened-parity-plan.md
  - ./completion-matrix.md
  - ./implementation-structure-and-tests.md
  - ./de-artifacting-inventory.md
  - ../dae-optimizing/starshine-strategy.md
  - ../../../../../agent-todo.md
---

# Binaryen-v131 original DAE source-case map

This is the active source-to-Starshine map for the original `dead-argument-elimination` engine and its `dae-optimizing` wrapper. It excludes `dae2.wast`: `dae2` is a different experimental pass and is not evidence for this engine.

## Status vocabulary

- **Exact**: the focused Starshine fixture asserts the Binaryen-v131 boundary/type/control result.
- **Equivalent**: the boundary behavior is the same but Starshine intentionally omits Binaryen helper locals or other measured debris.
- **Fail closed**: Starshine preserves the original boundary for a narrowly unsupported surface with a focused negative test.
- **Coverage gap**: the source behavior is represented upstream but does not yet have a focused Starshine proof.
- **Lifecycle gap**: focused behavior exists, but the producer still relies on a family-specific candidate builder, compatibility worth inference, conservative invalidation, or whole-pass DAEO retry.

A row is not closed merely because the July 22 generated matrix is green. Closure requires the source behavior, focused positive and negative coverage, common transaction/worklist ownership, and current generated evidence to agree.

## Source algorithm contract

| Binaryen-v131 owner | Source behavior | Current Starshine owner | Current classification | Remaining gap / reopening condition |
| --- | --- | --- | --- | --- |
| `DAEScanner` | Collect direct calls, dropped direct calls, direct/indirect/reference tails, exports, and exact `ref.func` exposure. | `DaeOriginalBoundarySnapshot`, `DaeCurrentBoundaryGraph`, `DaeBoundaryFacts`. | Exact. | Reopen for a new callable exposure form or stale topology regression. |
| `ParamUtils::getUsedParams` | Entry liveness, with writes killing incoming values and unreachable code ignored. | HOT CFG liveness plus conservative fallback. | Exact for represented control; fail closed for unsupported legacy/EH lifting. | Reopen when HOT can represent the currently guarded legacy/continuation form. |
| `PossibleConstantValues` / `applyConstantValues` | One per-operand `Literal` or immutable global identity; disagreement becomes unknown. | `DaeValueSlice`, five-state flow lattice, `DaeUniformActualWork`. | Exact for represented literals/globals; no tuple-expression requirement. | Reopen if Binaryen changes from one `Literal` per operand or adds a new constant expression form. |
| `ParamUtils::removeParameters` | Remove parameters and all owned direct operands together; preserve unremovable effects by localization; under traps-never-happen, erase trap-only operands; allocate replacement locals and repair nondefaultable locals. | Scalar/component/family candidates plus value-slice replay/localization, TNH-aware trap-only removal, and local projection. The general remove/constant, verified immediate-suffix, and selected ref-null compatibility entries are scalar-plan-backed. | Behavior exact or equivalent-smaller; lifecycle partial. | No local-growth inference remains; verified suffix/ref-null entries are plan-owned, and closure now waits on the remaining non-scalar mutation tails and common finalization/effects. |
| `ParamUtils::localizeCallsTo` | Child-localize every owned target call, then repair nested EH pops. | Typed scratch-local scalar plan plus component/localization paths; stack-carried void effects use the same canonical slices and producer effects. | Exact for represented direct/`return_call` forms; fail closed on unsupported escaping control. | Scalar dispatcher retries are plan-owned; close when every broad/component localization enters one epoch-bearing work item and exact caller epoch. |
| `refineArgumentTypes` / `TypeUpdating::updateParamTypes` | Strict reference LUB over every owned direct actual, skipping unread parameters; repair old-type writes/tees/locals. | Shared exact-caller value-slice collection, strict LUB, and old-type local repair. | Exact focused behavior; lifecycle partial. | Initial and stale-refresh parameter collection now use the canonical evidence API; close when every repair enters the common type finalizer. |
| `LUB::getResultsLUB` / `ReFinalize` | Join every returned value, explicit return, and tail return source; update call and parent types. | GC result worklist, returned-value scanners, control/type follow-ups. | Exact on represented source cases; lifecycle partial. | Close when one returned-value carrier owns all represented controls and every type user is finalized atomically. |
| `removeReturnValue` / `ReturnUtils::removeReturns` | Remove a result only when all owned calls drop it and tail/unseen constraints permit it; preserve bottom with `call; unreachable`. | Observer graph, dropped-result work, specialized dead-suffix plans. | Exact for represented scalar/bottom cases; lifecycle partial. | Close when ordinary and specialized repairs share one lane-aware atomic result plan without stale double rewriting. |
| `OptUtils::optimizeAfterInlining` | In DAEO only, run `precompute-propagate` then the default function optimization roster on `worthOptimizing`. | Shared nested roster and touched adapters in `pass_manager.mbt`. | Roster exact; lifecycle partial. | Replace legacy worth inference and final whole-pass strictly-smaller retry with effect-frontier convergence. |
| `unprofitableRemovalIters` | Permit one single-caller parameter-removal wave, then stop further parameter-chain churn. | Carried single-caller throttle state. | Exact. | Reopen only if a focused source case shows a second same-invocation wave. |

## `dae_tnh.wast`

The file contains five anonymous modules, so rows use source order.

| Case | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| TNH-1 trapping unused `struct.get` actual | With traps-never-happen enabled, remove the unused trapping actual and parameter; preserve the trapping evaluation in ordinary mode. | `dead-argument-elimination removes trapping unused actuals only under traps-never-happen`; `dae-optimizing removes trapping unused actuals only under traps-never-happen`. | Exact. Both public entrypoints receive `HotPipelineOptions.traps_never_happen`; value-slice observability distinguishes actual effects from trap-only replay policy. | Parameter value-slice / effect policy and scalar transaction. | Reopen if a trap-producing operand with a real observable effect is erased, ordinary mode stops preserving the trap, or nested DAEO convergence loses the option. |
| TNH-2 unreachable actual to void target | Do not remove the parameter when doing so changes the call from unreachable to concrete; preserve the unreachable caller. | `dae value producer kinds classify trap control and unreachable producers`; public unreachable/control fixtures. | Exact fail-closed behavior. | Value-slice classifier and candidate validation. | Reopen if unreachable operands become safely repairable through an atomic call/type plan. |
| TNH-3 unreachable actual to result target | Same guard when the target returns a value. | Same unreachable producer and result/control coverage. | Exact fail closed. | Value-slice classifier and result plan. | Same as TNH-2. |
| TNH-4 unreachable actual through direct `return_call` | Preserve unreachable direct-tail identity; no call type transition is needed. | `dead-argument-elimination repairs direct return_call sites when removing an unused parameter`; direct-call-kind white-box coverage. | Exact for the removable peer-parameter case; unreachable target operand remains conservative. | Scalar transaction. | Reopen if direct-tail unreachable operand repair broadens. |
| TNH-5 mixed signature with one unreachable kept operand and one removable constant | Remove only the safe peer parameter while leaving the unreachable operand and call identity intact. | `dead-argument-elimination removes one overwritten incoming parameter from a mixed signature` plus mixed operand-slice tests. | Exact focused shape. | Scalar transaction. | Reopen on stale slot/call-kind drift. |

## `dae-gc.wast`

| Upstream function/family | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| `$foo -> $bar` i31, tee, and nondefaultable removed param | Remove the unused non-null parameter, make replacement storage nullable, update `local.tee`, preserve unreachable tee typing, and insert `ref.as_non_null` where required. | `dae GC parameter refinement repairs nondefaultable reused parameter locals`; typed scratch/local projection tests; nested cleanup ref-local validity tests. | Exact safety behavior; local layout may differ. | Old-type/local repair. | Mechanical consolidation into the common type finalizer remains. |
| `$get-nonnull` / `$send-nonnull` | Remove an unused non-null reference parameter safely. | Nondefaultable local and plain localization tests. | Exact or equivalent-smaller replacement-local shape. | Scalar plan and nondefaultable repair. | Reopen on a validator/defaultability regression. |
| `$foo` / `$call-foo` ref.func constants | Materialize the identical first `ref.func`, reject differing second values, and preserve exact function identity. | `dae materialized ref.func constants compare function identity`; `dae-optimizing materializes uniform ref.func actuals`. | Exact behavior. | Uniform work item. | Reopen for new typed-function-reference literal semantics. |
| `$bar` / `$call-bar` null constants | Materialize identical nulls; reject null-versus-i31 conflict. | Nullable join, ref-null specialization, and five-state conflict tests. | Exact behavior. | Uniform lattice/component transaction. | Reopen for a new null heap hierarchy rule. |
| `$0 -> $1` string constants | Materialize per-slot `string.const` values and remove both parameters. | `dae-optimizing materializes uniform string.const actuals`. | Exact behavior. | Uniform work item. | Reopen if string constant encoding/equality changes. |
| `$a`, `$b`, `$c` helpers | Serve as exact `ref.func` identities; their boundaries remain otherwise unchanged. | Ref.func identity and exposure tests. | Exact. | Constant equality and original exposure. | None beyond new function-reference proposal forms. |

## `dae-gc-refine-params.wast`

| Upstream function/family | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| `$various-params-no` | Incomparable actual LUBs do not refine either parameter. | `dae GC parameter LUB evidence is complete and fail closed`; incomparable/strict-improvement tests. | Exact fail closed. | Shared strict-LUB API. | Reopen if subtype/LUB rules change. |
| `$various-params-yes` | Refine two live reference parameters independently while preserving an intervening scalar lane. | Direct-call common-LUB, multi-slot parameter, and definition-count-independent direct-GC transaction tests. | Exact. | Canonical exact-caller value-slice collector and shared strict-LUB API. | Reopen if a multi-target wave observes stale caller evidence or loses an independent scalar lane. |
| `$various-params-set` | Refine params; create old-type storage only for the param written with an incompatible value. | `dae GC parameter refinement repairs reused old-type parameters with a local`. | Exact safety behavior. | Old-type-local repair. | Move repair requests into the common type-edit plan. |
| `$various-params-tee` | Refine the param, update typed tee and parent block type. | GC parameter repair plus typeidx/control reconstruction tests. | Exact. | Type/control follow-up work. | Close when the common finalizer owns every parent-control update. |
| `$various-params-null` | Refine one parameter to non-null bottom evidence and retain nullable type for the other; unrelated locals stay untouched. | Nullable typed-select/LUB tests and local-remap safety tests. | Exact. | Canonical ordered select/value-slice evidence plus parameter local repair. | Reopen on abstract heap hierarchy changes or select-slice ordering drift. |
| `$various-params-middle` | Join sibling leaves at their strict common middle supertype. | `dead-argument-elimination narrows live GC parameters to common direct-call LUB`. | Exact. | Shared strict-LUB API. | None beyond new subtype forms. |
| `$unused-and-refinable` | Remove the unread parameter instead of refining it first. | Ordinary unread action classifier and GC LUB skip-unread tests. | Equivalent-smaller when Starshine omits Binaryen's unread replacement local. | Scalar transaction. | Reopen if an unread param is refined or if writes lose their old type. |
| `$non-nullable-fixup` | Refine a written non-null parameter while preserving nondefaultable old-type storage. | `dae GC parameter refinement repairs nondefaultable reused parameter locals`. | Exact safety behavior. | Old-type-local repair. | Common type finalizer ownership remains. |
| `$update-null` | Rewrite broad `ref.null` evidence so it participates in a tighter nullable LUB. | Nullable typed-select and nullable explicit-return join tests. | Exact. | Shared LUB and ref.null repair. | Reopen on null heap typing changes. |
| `get_*` helper functions | Supply broad, exact, nullable, and sibling result types used as operand evidence. | Direct/tail/indirect/reference call-result parameter evidence tests. | Exact evidence. | Canonical parameter evidence collector. | Close when all call-result producers enter one API. |

## `dae-gc-refine-return.wast`

| Upstream function/family | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| `$refine-return-no-return` | No reachable returned value means no refinement. | Result-evidence no-candidate/fail-closed tests. | Exact fail closed. | Returned-value evidence. | Reopen if new reachable-exit forms are represented. |
| `$refine-return-no-refining` | Keep the declared result when one return source is already the broad type. | Strict result-refinement tests. | Exact. | Returned-value LUB. | None beyond subtype changes. |
| `$refine-return-flow` and `$call-refine-return-flow` | Refine fallthrough result, update recursive call type, refinalize parent `if`, then refine the caller. | Fallthrough, dependency closure beyond sixteen, and typeidx/typed-if result tests. | Exact represented behavior. | Result worklist and control/type follow-ups. | Close when one returned-value carrier and one finalizer own the whole chain. |
| `$refine-return-return` | Refine from an explicit return operand. | `dae GC result refinement joins multiple explicit returns and fallthrough`; public explicit-return tests. | Exact. | Returned-value evidence. | None for represented scalar lane. |
| `$refine-return-many` | Join multiple explicit returns and fallthrough. | `dae GC result refinement joins multiple explicit returns and fallthrough` plus the null-bottom explicit-return regression. | Exact. | Returned-value evidence. | Wider exceptional exits remain fail closed. |
| `$refine-return-many-lub` / `-2` | Compute a common abstract heap LUB independent of whether the broad source is explicit or fallthrough. | Abstract heap return joins and mixed return/fallthrough tests. | Exact. | Returned-value LUB. | Reopen on hierarchy changes. |
| `$refine-return-tuple` | Refine one tuple/multivalue result lane while preserving the scalar lane and tuple extraction. | `dae GC result refinement narrows one multivalue tuple lane`; flat multivalue public tests. | Exact represented lane behavior. | Result-lane evidence. | Generic tuple-like carrier consolidation remains mechanical; no tuple constant materialization is implied. |
| `$do-return-call` / `$return-ref-func` | Derive exact `ref.func` result and preserve direct `return_call` compatibility. | Exact ref.func result and direct-tail result evidence tests. | Exact. | Result evidence and direct-tail graph. | Reopen on typed-function-reference changes. |
| `$tail-callee`, `$tail-caller-yes`, `$tail-caller-no` | Direct tail result evidence refines when all exits agree and stays broad when another return blocks it. | `dae GC result refinement follows direct tail calls`; mixed explicit-return tests. | Exact. | Returned-value evidence. | None for direct represented tails. |
| indirect-tail family | Use typed `return_call_indirect` result evidence; broad competing return blocks refinement. | Indirect result-slice evidence and public typed indirect-tail tests. | Exact represented evidence; indirect callers remain unowned for boundary rewriting. | Returned-value evidence. | Reopen only with source-backed ownership of indirect callsites. |
| call-ref-tail family | Use typed `return_call_ref` evidence; tolerate unreachable targets without assertion. | Call-ref result-slice evidence, public call-ref tail tests, and unreachable producer tests. | Exact represented evidence; unowned reference callers remain conservative. | Returned-value evidence. | Reopen only with exact typed-reference ownership proof. |
| `$update-null` / `$call-update-null` | Rewrite null arm type while joining multiple explicit-return leaves at their nullable common parent. | Nullable control-pair repair plus `dae GC result refinement joins null-bottom explicit returns`; direct `ref.null` now enters generic result-instruction evidence. | Exact. | Returned-value LUB and source rewrite. | Reopen on new null/branch carrier forms. |

## `dae-optimizing.wast`

| Upstream function/family | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| `$0`, `$1`, `$2` | Core DAE removes constants/dead params, then DAEO runs the touched nested roster and cleans the resulting local/control debris. | Nested roster order, touched-only identity, local cleanup, and deterministic convergence tests. | Focused behavior represented; output can be equivalent-but-different through shared local cleanup. | Pass-manager DAEO lifecycle. | Release-blocking lifecycle gap: replace broad cleanup predicates and whole-pass strict-size retry with producer-effect frontier convergence. |
| `$export -> $internal`, `$import`, `$impossible` | Remove an unused uninhabitable result, rewrite caller to `call; unreachable`, then nested DCE deletes unreachable suffix work while preserving imported effects. | `dead-argument-elimination preserves uninhabitable dropped-call control`; optimizing unused-return cleanup and effect-preservation tests. | Exact semantic behavior. | Atomic result plan plus nested roster. | Close when bottom repair and nested requeue are one effect frontier. |

## `dae-refine-params-and-optimize.wast`

| Upstream function/family | Binaryen-v131 behavior | Existing Starshine proof | Output | Common owner | Gap / reopening condition |
| --- | --- | --- | --- | --- | --- |
| `$len` / `$optimize-after-refinement` | Refine `(ref eq)` to `(ref array)`, then nested optimization removes the now-redundant `br_on_cast_fail` path. | Exact non-null/refinement cleanup tests, nested optimize-casts/ref-local validity tests, and post-refinement dead-parameter convergence tests. | Represented and valid; no single source-named fixture currently mirrors this two-function test exactly. | GC parameter evidence plus DAEO nested roster. | Add a focused source-shaped regression only if later lifecycle work changes this path; do not duplicate existing refinement and optimize-casts proofs now. |

## Positive and negative coverage summary

- Positive coverage exists for ordinary removal, direct `return_call`, constants, immutable globals, i31/ref/null/ref.func/string values, strict parameter/result LUBs, written-param repair, typed tees, fallthrough, explicit returns, flat multivalue lanes, direct/indirect/reference tails, bottom repair, localization, SCC forwarding, and DAEO touched cleanup.
- Negative coverage exists for exported/start/ref.func/element exposure, incomparable or incomplete LUBs, stale epochs and call identities, indirect/reference caller ownership, tail-result blockers, escaping branch operands, trapping/effectful preservation, invalid candidates, written forwarding components, and unsupported legacy/continuation control.
- The one source-backed behavior gap found by the initial mapping, **TNH-aware unused-operand removal**, is now closed for both plain DAE and DAEO with ordinary-mode preservation coverage.
- The remaining release blockers are lifecycle/ownership gaps, not newly discovered source transform families: producer-specific candidate construction, common type/result finalization, remaining specialized/nested invalidation diagnostics, and DAEO effect-frontier convergence.

## `generic-partial` row classification

| Completion-matrix rows | Classification | Reason |
| --- | --- | --- |
| A1, A2, A3, C1, F2, K1 | **current generic ownership** | The completion matrix now records common boundary ownership, direct/return-call identities, value slices, transactional scalar commits, and plain/optimizing separation. Reopen only for a new source surface or failing focused proof. |
| B1, B2, B3, A4, C2 | **2. release-blocking lifecycle risk** | Behavior is broadly represented. Scalar, dispatcher unread/localization, general remove/constant, verified suffix/ref-null, and forwarding-component effects reach DAEO without local-growth inference; non-scalar phase-local application tails remain. |
| D1, D2, E1, E2, E3, E4 | **2. release-blocking lifecycle risk** plus **4. mechanical consolidation** | Focused Binaryen-v131 behavior exists; collection and control/type finalization remain fragmented. |
| F1, F4 | **2. release-blocking lifecycle risk** | Legality is graph-backed, but ordinary/specialized body and caller repair are not yet one lane-aware atomic result plan. |
| F3 | **3. represented fail-closed exception** | Indirect/reference tails remain conservative barriers; reopen only with an exact source-backed target/type relation. |
| G1, G2, G3, G4 | **2. release-blocking correctness/lifecycle risk** | Multiple mutation tails and the simple-type pruner do not yet constitute one complete deterministic type-user/finalizer plan; metadata policy is still implicit name stripping. |
| H1, H2 | **5. stale documentation** | Original/current ownership and epochs are present and exercised; later producers still need to consume them uniformly. |
| H3, H4, I1, I2 | **2. release-blocking lifecycle risk** | Family validation, producer-owned worth, and canonical-core production diagnostics exist, but conservative fallback invalidation, unintegrated selected/nested counters, and parallel phase loops remain. |
| J1, J2, J3, J4 | **2. release-blocking lifecycle risk** | Shared roster and producer-owned semantic worth exist; the whole-pass strictly-smaller retry still needs effect-frontier replacement. |
| K2 | **4. mechanical preservation** | Slot 48 and exact-once placement are already covered; rerun only at final integration signoff. |
| L1, L2 | **historical evidence checkpoint**; L3 **reopened** | Generated/artifact evidence remains valid provenance, but the completion matrix now prevents those rows from overriding open lifecycle ownership and requires final renewal before release closure. |

## Immediate implementation order from the map

1. Retire remaining non-scalar phase-local mutation tails; TNH, general remove/constant, verified suffix/ref-null, scalar unread/localization, and forwarding effect ownership are closed.
2. Consolidate returned-value evidence and common GC/control/type finalization; initial/stale GC parameter collection and select slicing are canonical.
3. Consolidate the atomic result plan and remove stale-call double-rewrite opportunities.
4. Move remaining production loops through epoch-bearing work items, exact invalidations, and complete diagnostics.
5. Replace DAEO whole-pass retry with effect-frontier convergence.
6. Reconcile this map, the completion matrix, inventory, backlog, and release note before final long gates.
