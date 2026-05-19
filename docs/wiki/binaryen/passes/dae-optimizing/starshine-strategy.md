---
kind: concept
status: supported
last_reviewed: 2026-05-18
sources:
  - ../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md
  - ../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md
  - ../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md
  - ../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md
  - ../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md
  - ../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md
  - ../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md
  - ../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md
  - ../../../raw/research/0559-2026-05-12-dae002-nested-cleanup-scheduler-slice.md
  - ../../../raw/research/0558-2026-05-12-dae-local-declaration-frontier.md
  - ../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md
  - ../../../raw/binaryen/2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/research/0487-2026-05-05-dae-optimizing-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/research/0366-2026-04-25-dae-optimizing-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-24-dae-optimizing-primary-sources.md
  - ../../../raw/research/0285-2026-04-24-dae-optimizing-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/cmd/cmd.mbt
  - ../../../../../src/lib/types.mbt
  - ../../../../../src/validate/typecheck.mbt
  - ../../../../../src/validate/validate.mbt
  - ../../../../../src/wast/
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./signature-updates-and-nested-reruns.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ../dead-argument-elimination/starshine-strategy.md
  - ../precompute-propagate/index.md
---

# Starshine strategy for `dae-optimizing`

## Current status

Starshine now has a **partial active module-pass implementation** for Binaryen's upstream `dae-optimizing` pass.

The local naming caveat was resolved in the first implementation slice:

- upstream Binaryen exposes the public pass name `dae-optimizing`;
- Starshine now registers the exact canonical spelling `dae-optimizing` as an active module pass;
- Starshine also keeps the descriptive compatibility spelling `dead-argument-elimination-optimizing` as an active alias for the same optimizing module pass;
- plain `dead-argument-elimination` remains boundary-only and does not run the optimizing nested-cleanup trace.

Current implemented behavior is intentionally narrower than full Binaryen DAE:

- private direct-call dead scalar parameter removal;
- adjacent self-recursive `local.get` forwarding is ignored when proving params dead;
- removed actual side-effect preservation with `drop` repair;
- export and `ref.func` / element escape bailouts;
- value-producing `if` operands are preserved with `drop` repair when their parameter is removed, after which the optimizing cleanup lane may remove pure value debris while retaining side effects;
- no-param dropped/uncalled result removal with conservative unreachable-prefix cleanup;
- local-use scanning ignores dead suffixes after a root `unreachable`;
- case-000690-style escaped-result self-call operand preservation: if the original single `f64` parameter is stranded under an escaped direct-call result that becomes an undropped dead-suffix self-call operand, Starshine preserves that parameter while still pruning direct simple self-call operands and dropped self-call escaped-result operands, matching the observed Binaryen shape in [`../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md`](../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md);
- unused simple function type pruning after signature changes;
- a narrow exact-literal constant-actual materialization slice for private direct callees: if every direct caller passes the same literal and the callee never writes that parameter, Starshine removes the incoming param, rewrites callee `local.get`s to the literal, and relies on the touched-only nested cleanup lane for the remaining fold; as of 2026-05-13 this slice also handles sibling scalar memory-load carriers and typed single-result `TypeIdxBlockType` wrappers while staying on the same exact-literal/read-only guardrails;
- a small-module touched-function cleanup scheduler that records the required `precompute-propagate` prefix and now starts with a touched-only private `precompute-propagate-prefix` helper before the narrow local cleanup subset (`dead-code-elimination -> optimize-instructions -> local-cse -> pick-load-signs -> heap-store-optimization -> heap2local -> optimize-casts -> code-pushing -> simplify-locals -> code-folding -> precompute -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> coalesce-locals -> reorder-locals -> vacuum`) only on touched functions; that private prefix helper folds SSA-backed default-init and direct local constant facts and then reruns plain `precompute`, but it is not the public upstream sibling. `local-cse` now uses a function-filtered raw adapter, while `coalesce-locals` and `reorder-locals` use function-filtered adapters over the existing module passes in this nested lane, and all three remain public module passes for direct requests. The local-CSE adapter emits `pass[local-cse]:func/start/done` trace lines so DAE002 tests can pin its order before `simplify-locals`, and the scheduler itself emits `pass[dae-optimizing]:nested-pass name=...` lines so order tests can lock the guarded lane directly; size-skip traces distinguish `large-touched-set`, `large-module`, and `large-touched-function` while preserving the existing guard thresholds; `precompute-propagate-prefix` / `optimize-instructions` / `pick-load-signs` / `heap-store-optimization` / `heap2local` / `optimize-casts` / `code-pushing` / direct `precompute` / `code-folding` / `merge-blocks` / `remove-unused-brs` / `remove-unused-names` use the existing hot touched-function runner.

Current non-parity caveat: the call-graph pruning and touched-function tracking slice `[DAE]001` is complete as of 2026-05-12, and `[DAE]002` now has narrow touched-function scheduler regressions plus a narrow exact-literal constant-actual slice, but complete Binaryen result-removal scheduling and the real public `precompute-propagate` + default-function-pipeline nested cleanup are not implemented yet. A whole-module cleanup experiment rewrote unrelated functions and worsened direct parity; the active scheduler therefore remains size-guarded and skips broad artifact modules until a faster filtered batch runner exists. After the 2026-05-12 case-000690 fix, `.tmp/pass-fuzz-dae-690-final2-1000` removed `case-000690-gen-valid` from the failure set and reported `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` Binaryen/tool command failures; a follow-up classification found that all 13 remaining `gen-valid` mismatches are local-declaration-only diffs with exactly one local-decl hunk apiece, and the two command failures are unchanged `binaryen-rec-group-zero` parser/tool failures. The first `[DAE]002` scheduler slice preserved that frontier in `.tmp/dae002-mincleanup-1000` (`998/1000`, `985` normalized matches, `13` mismatches, `2` command failures), the local-CSE adapter preserved it again in `.tmp/dae002-local-cse-1000`, the merge-blocks addition preserved it in `.tmp/dae002-merge-blocks-1000`, the remove-unused-brs addition preserved it in `.tmp/dae002-remove-unused-brs-1000`, the remove-unused-names addition preserved it in `.tmp/dae002-remove-unused-names-1000`, the second merge-blocks addition preserved it in `.tmp/dae002-second-merge-blocks-1000`, the optimize-instructions addition preserved it in `.tmp/dae002-optimize-instructions-1000`, the code-folding addition preserved it in `.tmp/dae002-code-folding-1000`, the direct-precompute addition preserved it in `.tmp/dae002-precompute-1000`, the pick-load-signs addition preserved it in `.tmp/dae002-pick-load-signs-1000`, the heap2local addition preserved it in `.tmp/dae002-heap2local-1000`, and the heap-store-optimization addition preserved it in `.tmp/dae002-hso-1000` with the same counts. The code-pushing addition preserved that frontier again in `.tmp/dae002-code-pushing-1000`, the optimize-casts addition preserved it in `.tmp/dae002-optimize-casts-1000`, the reorder-locals addition preserved it in `.tmp/dae002-reorder-locals-1000`, and the coalesce-locals addition preserved it in `.tmp/dae002-coalesce-locals-1000` (`998/1000`, `985` normalized matches, `13` mismatches, `2` command failures) while a post-coalesce-locals debug-artifact trace still skips nested cleanup at `touched=12`. The new private prefix helper is currently covered by focused Moon tests for pass order and touched-only default-init local folding, and the new constant-actual slice is covered by focused every-direct-caller-same-literal plus scalar-load-sibling and typed single-result block-carrier regressions; a follow-up compare at `.tmp/dae002-const-actual-200` still matched the earlier 200-case frontier exactly (`199/200`, `198` normalized matches, `1` mismatch, `1` unchanged Binaryen/tool command failure). A later DAE002 blocker hunt expanded the passing ref-local regression surface to `ref.as_non_null(local.get ...)`, loop-carried locals, block-wrapped `try_table`, dominated and undominated sibling-join locals, and lib-constructed `call_ref` families, and it also found two inherited false leads outside the scheduler logic itself: after `optimize-instructions` simplified a ref-local `try_table` body nested under an outer `block`, HOT lowering computed catch depths against the full active label stack and rewrote a valid `catch_all 0` into invalid `catch_all 1`; and on duplicate-signature `call_ref` fixtures, `HotModuleContext` dropped declared function type slots, so `ref.func` widened to abstract `funcref` during HOT lifting and later failed a touched `local.set` into `(ref null (type ...))`. Fixing both issues restored the direct optimize-instructions shape, made the active `dae-optimizing` call-ref regressions pass, and removed two apparent DAE/local-subtyping blockers without broadening the guarded touched-only lane. A follow-up combo fuzz compare for `--dae-optimizing --local-subtyping` at `.tmp/dae-local-subtyping-1000` reported `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` unchanged `binaryen-rec-group-zero` command failures; its mismatch and command-failure case set exactly matches `.tmp/dae002-coalesce-locals-1000`, and the 13 mismatches remain local-declaration-only `gen-valid` diffs. That leaves no validated current touched-local-subtyping validity blocker in the exercised control-flow or `call_ref` families; the remaining open work is future local-subtyping parity/refinalization plus broader constant-actual/artifact/runtime parity, not a reproduced DAE scheduler bug. The follow-up runtime attribution in [`../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md`](../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md) removed the 30s+ pre-nested-marker timeout by replacing repeated DAE core call/dead-suffix scans with a single original call summary and suffix-target aggregation; artifact replay is feasible again but remains red at `defined=11 abs=28` and still misses the pass-local speed floor. The new caller-family attribution in [`../../../raw/research/0561-2026-05-13-dae002-check-range-load-shape-attribution.md`](../../../raw/research/0561-2026-05-13-dae002-check-range-load-shape-attribution.md) proved all `370` observed direct `moonbit.check_range` callers keep `lo` at literal `0`, fixed scalar-load sibling carriers for the exact-literal slice, and still left `.tmp/dae002-load-only-artifact` red at the same first diff. A second follow-up in [`../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md`](../../../raw/research/0562-2026-05-13-dae002-typeidx-block-carriers.md) added typed single-result `TypeIdxBlockType` carrier support and a focused regression, but `.tmp/dae002-typeidx-block-artifact` still stayed red at `defined=11 abs=28`. A third follow-up in [`../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md`](../../../raw/research/0563-2026-05-14-dae002-later-candidate-starvation.md) then showed that the current fixed `8`-iteration DAE core can starve a later exact-literal candidate after `9` earlier productive rewrites: Binaryen still rewrites the later `moonbit.check_range`-shaped callee to 2 params, while Starshine leaves it at 3, and the new `pass[dae-optimizing]:core iter=... primary_def=...` trace locks the reduced frontier directly as `primary_def=0..7`. A fourth follow-up in [`../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md`](../../../raw/research/0564-2026-05-14-dae002-check-range-rewrite-and-nested-skip.md) then fixed two real caller-rewrite blockers in the artifact path itself: ambient typed-loop entry-value slices and same-caller multi-call undercount. That made `dae_try_rewrite_candidate(...)` rewrite all `370` direct `moonbit.check_range` calls, moved the artifact frontier to `primary_def=11` first, and left Func 28 at the same 2-param signature as Binaryen. A fifth follow-up in [`../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md`](../../../raw/research/0565-2026-05-14-dae002-check-range-frontier-moved-to-func42.md) added a tiny touched-only rewritten-control simplifier for negated compare guards, which closed the old Func 28 body-form mismatch and moved the live artifact frontier forward to `defined=25 abs=42`. A sixth follow-up in [`../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md`](../../../raw/research/0566-2026-05-14-dae002-func42-forwarding-wrapper-chain.md) then showed Func 42 is blocked by a forwarding-wrapper chain `4558 -> 4559 -> 42`: Func 4558 is already directly exact-literal rewritable on the original artifact, Func 4559 becomes rewritable after 4558, and Func 42 becomes rewritable only after both higher-index wrappers fall. A seventh follow-up in [`../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md`](../../../raw/research/0567-2026-05-14-dae002-reverse-exact-literal-frontier-still-misses-4558.md) then showed that a cheap bounded reverse exact-literal lane still does not reach that chain soon enough on the real artifact: `4559` and `4558` only appear at reverse iterations `14` and `15`. An eighth follow-up in [`../../../raw/research/0568-2026-05-14-dae002-forwarded-const-low-prefix-revisit.md`](../../../raw/research/0568-2026-05-14-dae002-forwarded-const-low-prefix-revisit.md) added narrow forwarded-const analysis through wrapper-local `local.get` chains plus a low-prefix exact-literal revisit over the first `64` defined functions. That new slice moves the core frontier to `11, 25, 227, 233, ...`, so Func 42 is now reached as the second productive core rewrite on the original artifact, but the full artifact compare still differs first at `defined=25 abs=42`. A ninth follow-up in [`../../../raw/research/0569-2026-05-15-dae002-func42-shape-fix-and-low-callee-prefix.md`](../../../raw/research/0569-2026-05-15-dae002-func42-shape-fix-and-low-callee-prefix.md) then fixed the remaining direct Func 42 add-zero / const-order body drift and added a low-callee core revisit over high callees selected from the first `64` defined callers. That moves the full artifact compare forward again to `defined=64 abs=81`, but the retained slice still runs at `120946.581ms` pass-local versus Binaryen `939.053ms`, and a wider `128`-caller experiment was intentionally rejected after it pushed the frontier to `defined=128 abs=145` at roughly `211635.689ms`. So the next safe slice is now the remaining low-wrapper/high-callee family just beyond the current `64`-caller boundary, not the original Func 42 family shape.

A 2026-05-18 artifact push later moved the live frontier to `.tmp/dae-parity-selected236-locals-fast-artifact` with first diff `defined=237 abs=254`; a follow-up runtime slice kept the output byte-identical but rerouted the artifact-specific low-callee and low-wrapper loops through the narrower unread-param helper with shared current-call facts, bringing repeated artifact pass-local timings to `1204.050ms`, `1375.033ms`, `1238.117ms`, and `1449.124ms` versus Binaryen `901.666ms`, `933.922ms`, `924.685ms`, and `1038.630ms`. A later reverse-lane runtime slice kept the output byte-identical again while routing the same stable high-wrapper chain (`4593, 4592, 4591, 4589, 4588, 4587, 4586, 4584`) through selected exact-literal rewrites on large modules; repeated artifact pass-local timings after both runtime slices were `1210.633ms`, `1190.713ms`, and final post-format validation `1159.661ms` versus Binaryen `995.422ms`, `953.055ms`, and `972.156ms`. A subsequent runtime-only slice reused one current-call-fact snapshot across that stable reverse selected-def chain, preserving byte-identical output and the same Func237 frontier while improving repeated pass-local artifact timings to `954.237ms`, `1041.034ms`, and `1105.814ms` versus Binaryen `977.574ms`, `954.835ms`, and `946.393ms`. The next runtime slice reused one selected-lane current-call-fact snapshot across the selected dropped-result, mid exact-literal, immutable-global exact-literal, and high exact-literal lanes; this again preserved byte-identical output and the same Func237 frontier, with artifact pass-local timings `893.956ms`, `935.269ms`, and `1045.306ms` versus Binaryen `923.955ms`, `924.723ms`, and `997.389ms`. [`../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md`](../../../raw/research/0570-2026-05-18-dae002-func237-frontier-classification.md) classifies this remaining first diff as a local/control carrier shape, not another boundary rewrite miss: Binaryen's printed Func237 starts with a side-effect/trap-preserving void `block`, then materializes the live default carrier as `i32.const 0` in a later `local.set` before wrapper-object stores; Starshine still lowers the same region as a leading value block assigned to a temp local, with the surviving live edge carrying the default-zero value through local/control scaffolding. The exact Binaryen mechanics are inferred from artifact output and prior nested-rerun docs rather than from a dedicated upstream helper citation, so keep this claim scoped to the observed artifact family. Broad selected Func237 nested cleanup, reduced nested cleanup without DCE/coalesce, forced existing nested cleanup, selected coalescing, and a narrow default-carrier prototype all failed to advance the first diff and either consumed or exceeded the already tight runtime headroom. Future work should therefore avoid another broad selected cleanup pass and should only try a much narrower raw/HOT structural fold if it can match the real lowered shape and preserve trap/effect order.

For a concrete future implementation sequence and validation ladder, use [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md). This status page stays focused on current local truth.

## Exact local code map

## Registry and request behavior

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
  - `pass_registry_entries()` registers `dae-optimizing` and `dead-argument-elimination-optimizing` as `HotPassRegistryCategory::ModulePass` entries.
  - `pass_registry_boundary_only_names()` still lists plain `dead-argument-elimination` as boundary-only.
  - `optimize_preset_passes(...)` and `shrink_preset_passes(...)` do not include `dae-optimizing` yet because direct parity and the touched-function nested scheduler are still incomplete.

- [`src/passes/registry_test.mbt`](../../../../../src/passes/registry_test.mbt)
  - The registry tests prove the active/boundary/removed classification mechanism, but they do not yet have a dedicated assertion for either DAE optimizing spelling.
  - If a future alias is added, add a focused test so the upstream spelling cannot silently drift again.

## Scheduler and parity context

- [`docs/wiki/binaryen/no-dwarf-default-optimize-path.md`](../../no-dwarf-default-optimize-path.md)
  - Names `dae-optimizing` as the first late post-pass Binaryen slot.
  - Records the nested rerun rule: `dae-optimizing` and `inlining-optimizing` both call the post-inlining cleanup helper on changed functions.

- [`docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`](../../../raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md)
  - Records the original DAE backlog contract: remove provably dead call parameters, then rerun the nested post-inlining cleanup pipeline on touched functions.

- [`.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json`](../../../../../.artifacts/self-opt-pass-audit-o4z-generated-2026-04-18/skipped-unimplemented-slots.json)
  - Records saved generated-artifact skipped slot `48` as `dae-optimizing`.

- [`agent-todo.md`](../../../../../agent-todo.md)
  - Keeps the active DAE backlog slice family.
  - `[DAE]001` covers call-graph pruning, safe parameter removal, call localization, and touched-function tracking.
  - `[DAE]002` covers nested `optimizeAfterInlining` replay plus artifact comparison; its narrow scheduler now includes touched-only `optimize-instructions`, `pick-load-signs`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `code-pushing`, `simplify-locals`, direct `precompute`, `local-cse`, `code-folding`, repeated `merge-blocks`, `remove-unused-brs`, `remove-unused-names`, `coalesce-locals`, `reorder-locals`, and `vacuum` cleanup. The nested `local-cse` adapter traces `func/start/done`, the nested scheduler traces `nested-pass name=...`, and guarded skips now distinguish `large-touched-set`, `large-module`, and `large-touched-function`, but the full `precompute-propagate` + default-function-pipeline replay and artifact parity remain open.

## Strategy implication for a future Starshine port

A Starshine port should be designed as a module-boundary and scheduler feature, not as a HOT expression peephole.

Minimum required pieces:

1. **Boundary ownership analysis**
   - collect direct calls by callee;
   - treat exports and `ref.func` escapes as unseen calls;
   - skip imports and externally visible signatures.

2. **Signature rewrite engine**
   - remove dead params from callee declarations and every direct callsite;
   - refine GC reference params using direct-call operand LUBs;
   - refine result types from actual returned values;
   - remove dropped results only when tail-call and dropped-call facts allow it.

3. **Callsite repair**
   - preserve evaluation order for removed call operands;
   - localize hard call operands before parameter removal when needed;
   - preserve uninhabitable-result behavior with `call; unreachable`-style repair;
   - avoid adding broad parameter/result preservation rules solely to match Binaryen's unused-local declaration shape; the current saved 1000-case frontier is local-declaration drift, not a known semantic/signature mismatch.

4. **Nested cleanup scheduler**
   - track every function whose body or boundary changed;
   - prepend the `precompute-propagate` sibling before the default function cleanup pipeline, matching Binaryen's optimizing replay contract;
   - keep this nested lane separate from `simplify-globals-optimizing`, whose nested cleanup contract is intentionally different.

5. **Name compatibility decision**
   - decide whether to add a `dae-optimizing` alias, rename `dead-argument-elimination-optimizing`, or keep both documented as distinct upstream-vs-local spellings;
   - add registry tests for the chosen behavior.

## Validation plan when the port starts

Use the Binaryen dossier as the behavior checklist:

- [`./binaryen-strategy.md`](./binaryen-strategy.md) for phase order, data ownership, and nested cleanup behavior.
- [`./implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) for the upstream owner-file, helper, and lit-proof map.
- [`./signature-updates-and-nested-reruns.md`](./signature-updates-and-nested-reruns.md) for boundary safety, localization, result removal, and rerun caveats.
- [`./wat-shapes.md`](./wat-shapes.md) for beginner-friendly positive and negative shapes to convert into focused tests.
- [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md) for the first-slice analyzer, mutating, and nested-rerun plan.
- [`../dead-argument-elimination/implementation-structure-and-tests.md`](../dead-argument-elimination/implementation-structure-and-tests.md) for the shared upstream owner-file and proof-surface map.

Concrete future tests should cover at least:

- known-boundary dead-param removal;
- every-caller-same-constant materialization;
- GC parameter and result refinement;
- exported / `ref.func` / import bailouts;
- hard call-operand localization;
- dropped-return removal and uninhabitable-result repair;
- nested cleanup replay on touched functions;
- registry behavior for whichever local spelling decision is chosen.
