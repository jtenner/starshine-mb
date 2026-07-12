---
kind: concept
status: supported
last_reviewed: 2026-07-10
sources:
  - ../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md
  - ../../../raw/research/0435-2026-05-04-dead-argument-elimination-current-main-recheck.md
  - ../../../raw/research/0406-2026-04-26-dead-argument-elimination-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md
  - ../../../raw/research/0293-2026-04-24-dead-argument-elimination-primary-sources-and-starshine-followup.md
  - ../../../raw/research/0159-2026-04-21-dead-argument-elimination-binaryen-research.md
  - ../../../raw/research/0230-2026-04-21-dead-argument-elimination-implementation-followup.md
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/DeadArgumentElimination.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/param-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/return-utils.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/lubs.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae_tnh.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-params.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-gc-refine-return.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-optimizing.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae-refine-params-and-optimize.wast
  - https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/dae2.wast
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../dae-optimizing/index.md
  - ../dae2/index.md
---

# `dead-argument-elimination` implementation structure and tests

This page is the compact owner-file and proof-surface map for Binaryen `version_129` plain `dead-argument-elimination` / `dae`.

The current tagged source manifest is [`../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md`](../../../raw/binaryen/2026-04-24-dead-argument-elimination-primary-sources.md). It records the 2026-04-24 official release-page recheck, the reviewed `version_129` source/test URLs, and a narrow current-`main` no-teaching-drift spot check. The later 2026-05-04 current-main freshness layer is [`../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-dead-argument-elimination-current-main-recheck.md); the 2026-04-26 Starshine-readiness bridge remains in [`../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md`](../../../raw/binaryen/2026-04-26-dead-argument-elimination-port-readiness-primary-sources.md), and the local validation ladder is [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Biggest source-confirmation result

The real owner split is smaller and cleaner than the folder previously implied:

- `src/passes/DeadArgumentElimination.cpp` owns the **shared core algorithm** for both plain `dae` and `dae-optimizing`;
- `src/passes/pass.cpp` owns the public registration split;
- `src/passes/opt-utils.h` owns only the optimizing variant's extra nested cleanup replay.

So plain `dae` should be taught as:

- the shared `DeadArgumentElimination.cpp` engine in non-optimizing mode,
- not as a separate standalone implementation file,
- and not as a tiny wrapper around the optimizing pass.

## Core source files

## `src/passes/DeadArgumentElimination.cpp`

This is the main implementation file.

It owns the real plain-pass contract:

- `DAEFunctionInfo` and the module-wide direct-call bookkeeping,
- `DAEScanner` and the initial direct-call / dropped-call / tail-call / `ref.func` scan,
- the `refineArgumentTypes(...)` and `refineReturnTypes(...)` phases,
- constant-actual materialization,
- dead-parameter removal,
- dropped-return elimination,
- localization-driven iteration,
- and the `optimize` boolean that decides whether the optimizing rerun happens.

This file therefore proves the most important relationship in the folder:

- plain `dae` and `dae-optimizing` are the same boundary-rewrite engine with one scheduler-changing flag difference.

## `src/passes/pass.cpp`

This file matters because it proves the public naming and split:

- `dae`
- `dae-optimizing`
- `dae2`

For the first two, `pass.cpp` confirms that both names are real public passes in `version_129` and that the plain-vs-optimizing distinction is deliberate public API, not a local wiki invention.

It also prevents a common teaching mistake:

- `dae2` is a separately registered experimental pass,
- not a hidden extra mode or test bucket for the original DAE engine.

## `src/passes/opt-utils.h`

This file matters for one very specific reason:

- it owns the `OptUtils::optimizeAfterInlining(...)` helper that only `dae-optimizing` runs after productive iterations.

That means `opt-utils.h` is evidence for the sibling split, not for the plain boundary algorithm itself.

## Helper ownership files

## `src/passes/param-utils.h`

This helper file owns most of the hard boundary-rewrite plumbing that the main DAE file delegates:

- `getUsedParams(...)`
- constant-actual application
- parameter removal
- call-operand localization

So if a reader wants the exact “how do calls and callee params get rewritten safely?” surface, this is the most important helper after the main pass file.

One output-shape consequence matters for Starshine residual classification: tagged Binaryen `ParamUtils::removeParameters(...)` allocates a fresh local for every removed parameter before rewriting any remaining `local.get` uses. That generic helper therefore leaves an unread replacement local even when the removed parameter has no surviving get or write. Starshine's shared removed-parameter projection instead retains a body local only for a surviving write or proven caller-side localization. When neither exists, omitting the unaddressable default-only local is a semantic and size improvement, not evidence that the boundary iteration failed.

## `src/ir/lubs.h`

This file matters because it owns the least-upper-bound logic for:

- GC parameter refinement from direct-call operands,
- and result refinement from actual returned values.

That helper is the compact proof that plain DAE is also a type-tightening pass, not only a delete-unused-params pass.

## `src/ir/type-updating.h`

This file matters because param/result refinement is not just signature editing.

It owns the follow-up repair surface that keeps rewritten function signatures and direct call sites valid after type changes.

## `src/ir/return-utils.h`

This file matters because dropped-return elimination changes the callee body too, not just the callers.

It owns the return-rewrite helper used once DAE has proved that a function result can disappear.

## Official tests and what they prove

## There is no single dedicated plain-`dae` file

This is the most important test-map correction.

Binaryen `version_129` does **not** give plain `dae` one neat dedicated `dae.wast` file.
Instead, the real plain-pass proof surface is spread across a small family of files.

That is why this page exists.

## `test/lit/passes/dae_tnh.wast`

This is the sharpest plain-pass file for the tricky control/value corner cases.

It proves plain DAE behavior around:

- dropped-return removal with traps-never-happen assumptions,
- `call(unreachable)` and related caller repair,
- and the fact that removing a dead boundary input or dead result must still preserve unreachable typing information.

## `test/lit/passes/dae-gc.wast`

This is the broad GC/reference-family oracle for the shared DAE core.

It proves families such as:

- reference-typed parameter refinement,
- result refinement,
- constant actual materialization in GC-heavy cases,
- and conservative bailouts around exported or escaping boundaries.

## `test/lit/passes/dae-gc-refine-params.wast`

This is the clearest focused oracle for one specific plain-pass subtopic:

- GC parameter LUB refinement.

It is the best short answer when someone asks whether plain DAE really narrows still-live params.

## `test/lit/passes/dae-gc-refine-return.wast`

This is the corresponding focused oracle for:

- result-type refinement.

It proves that the pass is not only about shrinking the incoming side of the boundary.

## `test/lit/passes/dae-optimizing.wast`

This file still matters, but it should be taught carefully.

It is best used as:

- shared-core evidence for the underlying DAE engine,
- plus proof that the optimizing wrapper exposes extra visible cleanup after the same boundary rewrites.

It is **not** the main plain-pass oracle.

## `test/lit/passes/dae-refine-params-and-optimize.wast`

This is another shared-core-plus-optimizing-boundary file.

It is useful because it shows the interaction between:

- param refinement,
- and the optimizing rerun.

Again, that makes it good sibling-boundary evidence, not the main plain-pass proof file.

## `test/lit/passes/dae2.wast`

This file is important mostly as a negative attribution rule.

It belongs to the separately registered experimental `dae2` pass.
So the `dead-argument-elimination` dossier should explicitly **not** use it as evidence for the original DAE engine.

## File map in one table

| File | Why it matters | Main thing it proves |
| --- | --- | --- |
| `src/passes/DeadArgumentElimination.cpp` | Core algorithm | Plain `dae` and `dae-optimizing` share one boundary-rewrite engine |
| `src/passes/pass.cpp` | Public registration | `dae`, `dae-optimizing`, and `dae2` are separate public pass names |
| `src/passes/opt-utils.h` | Optimizing-only helper | The nested cleanup replay belongs only to `dae-optimizing` |
| `src/passes/param-utils.h` | Boundary rewrite helpers | Used-param discovery, constant actuals, param removal, and localization are helper-owned |
| `src/ir/lubs.h` | Refinement helper | Param/result narrowing is part of plain DAE |
| `src/ir/type-updating.h` | Type repair helper | Signature refinement needs explicit repair work |
| `src/ir/return-utils.h` | Return rewrite helper | Dropped-return elimination also rewrites callee returns |
| `test/lit/passes/dae_tnh.wast` | Control/value oracle | TNH and `call; unreachable` repairs are part of the real contract |
| `test/lit/passes/dae-gc.wast` | Broad shared-core oracle | GC refinement, constant actuals, and conservative bailouts are real plain-pass behavior |
| `test/lit/passes/dae-gc-refine-params.wast` | Focused plain oracle | Param refinement is real and separate from deletion |
| `test/lit/passes/dae-gc-refine-return.wast` | Focused plain oracle | Result refinement is real and separate from dropped-return removal |
| `test/lit/passes/dae-optimizing.wast` | Sibling-boundary oracle | The optimizing pass adds visible cleanup after the same core rewrites |
| `test/lit/passes/dae-refine-params-and-optimize.wast` | Sibling-boundary oracle | Param refinement plus optimizing cleanup belong together only in the optimizing variant |
| `test/lit/passes/dae2.wast` | Negative attribution oracle | `dae2` evidence should not be silently credited to plain `dae` |

## What this source map says about the real public contract

The source/test map blocks three common mistakes.

## Mistake 1: teaching plain `dae` as “a tiny wrapper over helpers”

Wrong.
The core boundary algorithm still lives in `DeadArgumentElimination.cpp`.
The helpers support it, but do not replace the main owner file.

## Mistake 2: teaching plain `dae` as if it had one neat dedicated golden file

Wrong.
The real proof surface is the combined `dae_tnh` + `dae-gc*` family, with optimizing files used only as contrast.

## Mistake 3: teaching `dae2` as more evidence for the original DAE engine

Wrong.
`dae2` is a separately registered experimental pass and should stay in its own dossier.

## Current Starshine observability and prefix-elision proof surface

The active Starshine core now routes recursive instruction observability through `DaeInstructionObservabilityEvidence` in [`src/passes/dead_argument_elimination.mbt`](../../../../../src/passes/dead_argument_elimination.mbt). The carrier separates observable effects, branch control, and conservative trap/unknown status. Existing effect-only and effect-or-branch callers project from the same evidence, while pre-unreachable prefix elision additionally checks escaping-branch legality and constant-safe numeric trap conditions.

The adjacent proof surface is split deliberately:

- [`src/passes/dead_argument_elimination_wbtest.mbt`](../../../../../src/passes/dead_argument_elimination_wbtest.mbt) locks pure/effect/branch/trap classification;
- [`src/passes/dae_optimizing_test.mbt`](../../../../../src/passes/dae_optimizing_test.mbt) locks public plain-DAE retention of a reachable zero-divisor trap while still removing the unused parameter and dead post-unreachable suffix;
- `.tmp/dae-coverage-forced-portable-classification-20260710.json` exhaustively classifies all `259` current coverage residuals as constant-safe, effect-free, non-escaping pure-prefix elimination with measured size and output-performance wins;
- the same tests keep plain `dead-argument-elimination` / `dae` distinct from the optimizing-only cleanup suffix.

This local evidence does not replace the upstream owner/test map above. It documents the current Starshine safety boundary around one extra cleanup direction that Binaryen plain DAE does not perform.

## Current Starshine original-result boundary proof surface

The main Starshine core now groups original result-preservation and result-removal pruning through `DaeOriginalResultBoundaryContext`, `DaeOriginalResultBoundaryRow`, and `DaeOriginalResultBoundaryEvidence`. Shared original parameter, call, self-call, escape, and dead-suffix facts are indexed once into `DaeOriginalResultPreservationRow`; the prune row is derived from that row plus prune-only facts instead of performing a second parallel-array indexing pass.

The resulting per-definition projection has multiple production consumers:

- unobserved-unreachable cleanup;
- zero-call dead-suffix and result-side cleanup;
- zero-parameter dropped-result removal;
- current-parameter argument-side result repair;
- parameterized self-side-chain preservation.

[`src/passes/dead_argument_elimination_wbtest.mbt`](../../../../../src/passes/dead_argument_elimination_wbtest.mbt) locks equality of every shared preservation/prune field and out-of-range fail-closed defaults. Fresh direct and optimizing compare lanes retain the exact pre-refactor counts, so this is evidence-ownership consolidation rather than a hidden legality or scheduling change.

The same original-boundary setup now collects dead-suffix escaped-result call facts through `DaeOriginalDeadSuffixEscapedResultCallFacts`. `dae_collect_original_dead_suffix_escaped_result_call_facts_with_escaped(...)` scans each original function once and records both dropped and undropped escaped-result calls, replacing two parallel whole-module collectors. The carrier is shared by the main and reverse cores; dropped and undropped projections participate in distinct preservation, unobserved, zero-call, and exact-literal decisions. Whitebox coverage locks mixed evidence and no-code defaults, and unchanged 10000-case compare counts prove that this ownership change did not alter scheduling or legality.

`DaeOriginalEscapedResultOperandCallFacts` extends that ownership consolidation without becoming a universal result-side bag. `dae_collect_original_escaped_result_operand_call_facts_with_escaped(...)` receives the existing dropped suffix facts, walks each original caller once, and records two exact outputs: dead-suffix escaped-result operand target counts from escaped callers, and private-result caller counts only for targets whose own dead suffix has a dropped escaped-result call. The former feeds preservation/reverse and unobserved/zero-call decisions; the latter feeds unobserved/zero-call result-side guards. The old two operand collectors and the private collector's duplicate per-callee suffix scan are gone. Whitebox coverage locks both arrays and no-code defaults; full DAE/pass-manager/public tests and unchanged 10000-case direct/optimizing compare counts prove the slice is ownership consolidation rather than a policy or scheduler change.

`DaeOriginalResultEscapeRow` is the narrow per-definition consumer projection for the exact overlap between unobserved-unreachable and zero-call/uncalled-result decisions. It carries private-result escaped-operand counts and undropped escaped-result suffix flags alongside the preservation row's escaped dead-suffix count, escaped-operand dead-suffix count, escaped-callee private-result count, undropped-self-caller result counts, no-param undropped-self-caller result counts, and param-operand self-result-caller count. The two decisions still own different predicates; the row only removes duplicate original-array indexing and never stores current direct-call counts or current simplified-body facts. Whitebox coverage locks shared-field equality, dropped-versus-undropped distinction, and fail-closed out-of-range defaults. Unchanged focused/full tests and compare counts establish that the projection preserves result policy and the plain-vs-optimizing scheduler boundary.

`DaeOriginalResultSideCallRow` is the matching narrow projection for zero-call side-call policy. It adds only original other-call and recursive void/result-side flags, reuses preservation-owned result-other and mutual-call facts, and feeds both the shared dead-suffix side-call evidence helper and separate no-self/private-result/uncalled-result decisions. The zero-call branch also consumes existing preservation/prune fields for its original parameter/call/self/nonself/result-side baseline instead of indexing those arrays again. Prior-call facts and current body/self/module-call facts deliberately remain outside the row. Whitebox coverage locks the shared facts and out-of-range defaults; unchanged 10000-case compare counts show ownership consolidation rather than policy drift.

`DaeOriginalResultCleanupPreservationEvidence` is the narrower two-consumer decision projection derived by `DaeOriginalResultBoundaryEvidence`. It contains only mixed-self suffix preservation and the existing result-side-chain cleanup summary. Unobserved-function removal and zero-call uncalled-result cleanup consume the same combined predicate; zero-call dead-suffix-only parameter cleanup reads the exact result-side-chain field. Unique prior-call, same-operand, escaped-undropped suffix, parameterized dropped-self-caller, and current body/self/module-call facts stay branch-owned. Whitebox `174/174` plus unchanged direct and optimizing 10000-case counts establish policy ownership consolidation rather than a legality or scheduler change.

`DaeCallsiteRewritePlan` and `DaeCallsiteRewriteApplicationEvidence` are the shared whole-argument application beneath ordinary callsite replay/drop repair and typed scratch-local localization. `dae_callsite_rewrite_plan(...)` consumes one `DaeCallsiteValueSliceEvidence`, requires contiguous operand coverage from the ambient-stack cursor to the call, and records either a normal `DaeOperandRemovalPlan` or a defaultable scratch type per parameter. `dae_apply_callsite_rewrite_plan(...)` copies prefix, ordered operands, call, and suffix once and returns the rewritten call index plus localization metadata. Ordinary repair and localization are two production consumers. Slice 162 adds `dae_localization_scratch_slot(...)`: the caller-owned DAE scratch pool now reuses exact defaultable types across sequential and nested callsites, keeps different types separate, uses nullable declarations for non-null references, and never borrows pre-existing locals or crosses caller boundaries. Removed-parameter local projection, recursive control traversal, GC actual refinement, touched accounting, and retry/frontier scheduling remain caller-owned. Whitebox `176/176`, public plain-DAE sequential/nested coverage, and unchanged direct/optimizing 10000-case counts establish typed allocation reuse without legality or scheduler drift.

`DaeCoreResultApplication` and `dae_apply_core_result(...)` are the shared scheduler-state application for productive `DaePassResult`s. The helper installs the returned module, adopts the first touched bitmap or OR-merges later results, preserves prior aggregate `changed` state on no-op results, marks productive results as applied, and propagates their primary definition. The fixed core loop, restored-operand application, reverse exact-literal paths, low forwarded-constant and immutable-global revisits, low callee loops, and boundary wrapper/callee lane consume it. Break/continue rules, candidate order, call-fact refresh/reuse, iteration limits, trace labels, raw cleanup, and final return-suffix touched policy remain outside.

`dae_apply_cleanup_result_preserving_touched(...)` is the optimizing cleanup application layer above ordinary core-result handling. It installs productive cleanup modules, preserves aggregate changed state on no-op results, propagates applied/primary metadata, and intentionally keeps the scheduler-owned touched bitmap instead of adopting or merging cleanup-returned touched data. Module raw cleanup and final return-suffix cleanup are the two production consumers. Their scanners remain separate: raw cleanup consumes touched evidence for live-local-copy admission and can suppress returned touched allocation, while final suffix cleanup scans separate wrapper/terminal-return shapes after post-raw scheduling. Red-first whitebox locks productive and no-op ownership. Validation reached whitebox `188/188`, public DAE `303/303`, pass suites `5196/5196`, full tests `8648/8648`, native build, and unchanged fresh reduction-disabled raw-red lanes. Plain DAE does not schedule either cleanup.

`dae_apply_selected_core_result(...)` is the narrow selected-lane layer above that ordinary application. It clears one already-consumed singleton bit for productive and no-op results, then delegates unchanged result application. Func236 local retargeting, Func256 loop-carrier retargeting, and three Func237 early-shape producers consume it. Selection setting, producer invocation, candidate order, no-change control flow, fact timing, traces, and iteration policy remain in `dae_run_core(...)`; raw cleanup and final return handling retain their specialized touched semantics. Whitebox `178/178`, public DAE `303/303`, full Moon validation, and unchanged three-lane raw-red counts establish selected lifecycle consolidation rather than a generic frontier or scheduler merge.

`dae_apply_primary_selected_core_result(...)` is the distinct multi-selection layer. It applies ordinary result state first, then clears only a productive result's valid `primary_def`; no-op results leave every candidate selected. The low-callee and low-wrapper-callee unread-parameter loops consume it while retaining fixed current call facts, candidate construction/order, `14`/`21` bounds, break-on-no-change control, and traces. Whitebox `179/179`, public DAE `303/303`, full Moon validation, and unchanged three-lane raw-red counts establish primary-selected lifecycle consolidation rather than a generic frontier, fact cache, or scheduler merge.

`dae_try_apply_selected_def_func_rewrite_once(...)` is the selected full-function module boundary for caller-owned locals-and-body rewrites. It validates one selected definition against the current code section, supplies the current `Func` plus current type section, rejects absent or equal output, preserves unrelated functions, installs the changed code, strips stale names, and returns exact touched/primary metadata. Func287 setup-local compaction, Func288 switch-carrier compaction, Func288 return-wrapper flattening, Func237 raw-debris/local trimming, Func299 inverted-result-`if` cleanup, Func236 local retargeting, and Func246 builder folding are seven direct production consumers. The Func288 return-wrapper route fixes an actual missing selected-bit check while retaining its exact three-local gate; the Func237 raw route retains current-signature resolution before local trimming. The body-only boundary delegates through the same application. Whitebox `182/182`, public DAE `303/303`, full Moon/native validation, and unchanged reduction-disabled three-lane counts establish module application consolidation rather than recognizer, type-section, scheduler, or cleanup unification.

`dae_try_apply_first_selected_func_rewrite_once(...)` is the dynamic selected scanner above the fixed-definition boundary. It walks selected current definitions in ascending order, passes each current `Func`, definition index, and type section to a caller-owned rewrite, delegates absent/equal rejection and installation through `dae_try_apply_selected_def_func_rewrite_once(...)`, and stops after the first productive result. Selected nop removal, Func408 pair-`if` carrier repair, selected i32-constant local-set inlining, and selected terminal-call local-set inlining are four production consumers. Recursive/body recognizers, current callee and target signature resolution, protected-local counts, trailing-local trimming, traces, and caller scheduling remain outside. Red-first whitebox proves an earlier selected no-op followed by one later productive rewrite, exact `[0, 1]` visitation, no later visit, current type-section/function delivery, unrelated-function preservation, stale-name removal, and exact touched/primary metadata. Whitebox `183/183`, public DAE `303/303`, full Moon/native validation, and unchanged reduction-disabled three-lane counts establish dynamic scan/application ownership rather than recognizer, signature, scheduler, or cleanup unification.

`dae_try_apply_selected_def_typed_func_rewrite_once(...)` is the current-signature projection over the same fixed selected full-function boundary. It resolves the admitted selected definition's current `FuncType`, supplies the current function, signature, and type section to a caller-owned rewrite, and delegates absent/equal rejection plus module installation and result metadata to `dae_try_apply_selected_def_func_rewrite_once(...)`. Func311 and Func313 terminal-call argument rewrites are the two consumers. Func311 keeps separate high-local partial and one-`i64`-local full products; Func313 keeps its suffix-staging recognizer and trimmed-local product. Both retain exact signature/shape traces and bounded scheduler loops. Red-first whitebox proves unselected callback suppression and current signature/type delivery; the existing four public Func311/Func313 tests protect their products. Post-rebase validation reached whitebox `184/184`, pass-manager `216/216`, public DAE `303/303`, pass suites `5192/5192`, full tests `8644/8644`, and fresh zero-failure compare lanes. Func298 type-section timing, Func323 multi-function/signature mutation, selected const-`if` multi-function application, specialized touched policy, cleanup, and revisits remain outside.

`dae_try_apply_selected_def_funcsec_func_rewrite_once(...)` is the narrower selected one-function boundary for products that require both current signature evidence and `FuncSec` reuse while leaving `TypeSec` unchanged. It admits the selected definition against current function/type/code sections, supplies the current `Func`, resolved `FuncType`, and concrete type section to a caller-owned rewrite, rejects absent or equal function products, canonicalizes the definition to the first existing equivalent function type, installs the changed code, strips stale names, and reports exact one-definition touched/primary metadata. Func256 and Func298 loop-carrier compaction are the two production consumers. Their body recognizers, loop spill/mapping/condition/wrapping sequence, high-local checks, local products, and Func298 traces remain outside. Red-first whitebox proves unselected suppression, current signature/type delivery, equivalent type-index reuse, unrelated-function preservation, stale-name removal, no-op rejection, and exact metadata. Validation reached whitebox `185/185`, public DAE `303/303`, pass suites `5193/5193`, full tests `8645/8645`, native build, and unchanged fresh reduction-disabled raw-red lanes. TypeSec-changing caller-plus-callee products remain outside.

`dae_run_bounded_singleton_selected_core_rewrite(...)` is the bounded scheduler layer above the singleton lifecycle. It repeatedly threads current module, touched accumulation, and aggregate changed state through one selected producer, breaks on the first no-op, and calls a caller-owned productive callback before the next iteration. Func237 terminal-br0 (bound `2`) and the separate Func267/268 const-`if` loops (bound `8`) are three production consumers. Their bounds, trace text, producer identity, phase placement, and dependencies remain caller-owned. The early, unconditional late, and productive-Func867-gated Func237 inner-loop sites plus Func867 specialization use the one-shot layer. Red-first whitebox and fresh unchanged compare counts establish scheduler-lifecycle ownership without importing optimizing scheduling into plain DAE.

`dae_run_singleton_selected_core_rewrite(...)` is the scheduler lifecycle boundary for one selected producer. It activates exactly one definition in the scratch selection, invokes the producer against the current module, clears the consumed singleton for productive and no-op results, and delegates module/touched/aggregate-changed/primary handling to `dae_apply_selected_core_result(...)`. Current consumers include Func233/327/1794 const-`if`, Func867 specialization, and the early, unconditional late, productive-Func867-gated, and final Func237 inner-loop sites; the bounded layer also delegates every terminal-br0 and Func267/268 iteration through it. Phase placement, trace labels, bounds, and dependent follow-on transforms remain caller-owned. The const-`if` producer still supports a multi-selection bitmap, but no current production scheduler call uses that mode, so this lifecycle does not invent multi-function result application. Red-first whitebox locks active-during-callback and cleared-after-callback behavior plus no-op preservation; public const-`if` products remain green. Validation reached whitebox `187/187`, public DAE `303/303`, pass suites `5195/5195`, full tests `8647/8647`, native build, and unchanged fresh reduction-disabled raw-red lanes.

`DaeRemovedParamCalleeRewriteEvidence` and `dae_removed_param_callee_rewrite_evidence(...)` form the shared removed-parameter callee projection below generic candidate rewriting and the selected Func323/Func3737 caller-plus-callee paths. The helper validates aligned param/removal/constant/localization inputs, computes the kept signature, preserves written or localized removed params as correctly typed body locals, substitutes current constants before remapping locals, remaps pre-existing body locals, and returns the reconstructed locals/body. The generic candidate, Func323 nine-param product, and Func3737 wrapper product are three production consumers; they retain distinct caller repair, candidate legality, cleanup, and traces. All three delegate `TypeSec`/`FuncSec`/code installation and changed-function touched accounting to `dae_apply_module_code_finalization(...)`. Red-first whitebox locks the mapped constant/local product, while public Func323/Func3737 tests lock caller-plus-callee behavior. Validation reached whitebox `186/186`, public DAE `303/303`, pass suites `5194/5194`, full tests `8646/8646`, native build, and unchanged fresh reduction-disabled raw-red lanes.

`dae_try_apply_selected_def_body_rewrite_once(...)` is now the locals-preserving projection of that selected-function boundary below nine Func237 body producers. It validates the selected definition against the current code section, passes the current body and type section to one body-specific rewrite, rejects absent or equal output, preserves locals and unrelated bodies, installs the changed code, strips stale names, and returns exact touched/primary metadata. Outer-loop carrier, nested branch-result, zero-branch, leading-retain-call, inner-iteration-loop, terminal-br0, dropped-result branch-carrier, unreachable-after-`if`, and parameter-loop spill producers consume it. Their body recognizers and local-0 safety gates remain separate, and `dae_run_core(...)` still owns singleton selection lifecycle, result application, order, terminal-br0 iteration, late and Func867-dependent revisits, traces, and cleanup policy. Whitebox `182/182`, public DAE `303/303`, full Moon/native validation, and unchanged three-lane raw-red counts establish current-module application consolidation rather than shape or scheduler unification.

`DaeDroppedResultUnreachableCalleeRewritePlan` is the shared application carrier after three separate dropped-result decisions have already proved legality. `dae_dropped_result_unreachable_callee_rewrite_plan(...)` fixes the common dropped-call cleanup ordering and selected/full repair scope while leaving each caller to choose all-caller versus no-param-caller repair and retained params. `dae_apply_dropped_result_unreachable_callee_rewrite(...)` applies repair, replaces the callee with empty-local `unreachable`, updates its signature, and rebuilds the module. Unobserved-unreachable, dead-self-suffix-result, and uncalled-result removal now share this application instead of open-coding it three times; their evidence predicates remain branch-owned. Whitebox coverage locks caller repair, callee body/locals, signature update, touched mask, and primary definition. Unchanged direct/optimizing compare counts show application ownership consolidation rather than policy or scheduler drift.

`DaeModuleSignatureContext` is the generic module-signature boundary extracted beneath all result- and body-specific policy. `dae_module_signature_context(...)` collects the definition index, copied function-type indices, function section, and type section without running dropped-result legality. `dae_apply_module_signature_finalization(...)` performs only type/function replacement, stale-name removal, and callee-only result metadata; it intentionally preserves the existing code section. Signature-only GC refinement remains its direct consumer, and the code-applying paths consume it through the next generic layer. Whitebox coverage locks this preservation boundary.

`DaeModuleCodeFinalizationPlan` and `DaeModuleCodeTouchedPolicy` are that generic code-applying layer. `dae_module_code_finalization_plan(...)` copies next params/results plus an explicit callee-only or changed-function touched policy; `dae_apply_module_code_finalization(...)` delegates signature replacement to the signature finalizer, installs the caller-owned rewritten function array, and widens touched metadata only when requested. Direct GC refinement, selected dropped-result append-`drop` removal, full-module dropped-result unreachable-callee application, and dead-suffix-only unreachable parameter removal are production consumers. The selected result path requests changed-function widening; the other paths retain callee-only scheduling. Call-count verification, optional type-section pre-update, result legality, call/drop repair timing, dead-suffix repair order, callee-body construction, and parameter retention stay outside the generic plan. Whitebox coverage proves code installation, signature replacement, changed-function touched accounting, and the existing callee-only unreachable mask. Fresh `172/172` whitebox, full Moon/native validation, and unchanged three-lane compare evidence establish generic application ownership rather than a policy merge.

`DaeTypeidxControlRewritePlan` and `DaeTypeidxControlRewriteApplication` are the narrower shared control/type-section application beneath three direct-GC result-refinement branches. `dae_typeidx_control_rewrite_plan(...)` copies params, refined results, primary body, and optional else body while validating block/loop/paired-if shape; `dae_apply_typeidx_control_rewrite(...)` reuses or appends the exact simple function type and rebuilds the corresponding typeidx instruction. Parametric terminal typeidx block/loop/if refinement, zero-input terminal multi-result `if` refinement, and preserved multi-result loop carriers consume it. Candidate/LUB legality, consumed-param stack safety, terminal/body selection, and module finalization remain branch-owned. Whitebox coverage proves type reuse, all three reconstruction kinds, and invalid-shape rejection; fresh `173/173` whitebox, full Moon/native validation, and unchanged three-lane raw-red evidence establish control-application ownership rather than behavior or scheduler drift.

## Porting takeaway

For the exact current local registry, request-rejection, and future shared-core plan, read [`./starshine-strategy.md`](./starshine-strategy.md).

If Starshine ever ports plain DAE, the clean source-backed implementation target is:

- one shared direct-call boundary engine,
- helper-backed param/result/call rewriting,
- no optimizing cleanup rerun in the plain variant,
- and tests drawn from the real distributed plain-pass proof family instead of a fictional single `dae.wast` contract.

## Recommended local teaching rule

When plain `dead-argument-elimination` is cited elsewhere in the wiki:

- point here for the owner/test split,
- point to `dae-optimizing` only for the nested-rerun difference,
- and keep `dae2` explicitly marked as neighboring-but-separate.
