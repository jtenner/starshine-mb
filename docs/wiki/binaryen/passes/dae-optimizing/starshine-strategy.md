---
kind: concept
status: supported
last_reviewed: 2026-05-12
sources:
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
- a small-module touched-function cleanup scheduler that records the required `precompute-propagate` prefix and then runs a narrow local cleanup subset (`dead-code-elimination -> optimize-instructions -> local-cse -> pick-load-signs -> heap-store-optimization -> heap2local -> optimize-casts -> code-pushing -> simplify-locals -> code-folding -> precompute -> merge-blocks -> remove-unused-brs -> remove-unused-names -> merge-blocks -> vacuum`) only on touched functions; `local-cse` is adapted through a function-filtered raw rewrite for this nested lane while remaining a public module pass for direct requests, that adapter now emits `pass[local-cse]:func/start/done` trace lines so DAE002 tests can pin its order before `simplify-locals`, and the scheduler itself emits `pass[dae-optimizing]:nested-pass name=...` lines so order tests can lock the guarded lane directly; size-skip traces distinguish `large-touched-set`, `large-module`, and `large-touched-function` while preserving the existing guard thresholds; `optimize-instructions` / `pick-load-signs` / `heap-store-optimization` / `heap2local` / `optimize-casts` / `code-pushing` / direct `precompute` / `code-folding` / `merge-blocks` / `remove-unused-brs` / `remove-unused-names` use the existing hot touched-function runner.

Current non-parity caveat: the call-graph pruning and touched-function tracking slice `[DAE]001` is complete as of 2026-05-12, and `[DAE]002` now has narrow touched-function scheduler regressions, but complete Binaryen result-removal scheduling and the real `precompute-propagate` + default-function-pipeline nested cleanup are not implemented yet. A whole-module cleanup experiment rewrote unrelated functions and worsened direct parity; the active scheduler therefore remains size-guarded and skips broad artifact modules until a faster filtered batch runner exists. After the 2026-05-12 case-000690 fix, `.tmp/pass-fuzz-dae-690-final2-1000` removed `case-000690-gen-valid` from the failure set and reported `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` Binaryen/tool command failures; a follow-up classification found that all 13 remaining `gen-valid` mismatches are local-declaration-only diffs with exactly one local-decl hunk apiece, and the two command failures are unchanged `binaryen-rec-group-zero` parser/tool failures. The first `[DAE]002` scheduler slice preserved that frontier in `.tmp/dae002-mincleanup-1000` (`998/1000`, `985` normalized matches, `13` mismatches, `2` command failures), the local-CSE adapter preserved it again in `.tmp/dae002-local-cse-1000`, the merge-blocks addition preserved it in `.tmp/dae002-merge-blocks-1000`, the remove-unused-brs addition preserved it in `.tmp/dae002-remove-unused-brs-1000`, the remove-unused-names addition preserved it in `.tmp/dae002-remove-unused-names-1000`, the second merge-blocks addition preserved it in `.tmp/dae002-second-merge-blocks-1000`, the optimize-instructions addition preserved it in `.tmp/dae002-optimize-instructions-1000`, the code-folding addition preserved it in `.tmp/dae002-code-folding-1000`, the direct-precompute addition preserved it in `.tmp/dae002-precompute-1000`, the pick-load-signs addition preserved it in `.tmp/dae002-pick-load-signs-1000`, the heap2local addition preserved it in `.tmp/dae002-heap2local-1000`, and the heap-store-optimization addition preserved it in `.tmp/dae002-hso-1000` with the same counts. The code-pushing addition preserved that frontier again in `.tmp/dae002-code-pushing-1000`, and the optimize-casts addition preserved it in `.tmp/dae002-optimize-casts-1000` (`998/1000`, `985` normalized matches, `13` mismatches, `2` command failures) while a post-optimize-casts debug-artifact trace still skips nested cleanup at `touched=12`. The follow-up runtime attribution in [`../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md`](../../../raw/research/0560-2026-05-12-dae002-call-summary-runtime-attribution.md) removed the 30s+ pre-nested-marker timeout by replacing repeated DAE core call/dead-suffix scans with a single original call summary and suffix-target aggregation; artifact replay is feasible again but remains red at `defined=11 abs=28` and still misses the pass-local speed floor. A post-optimize-casts trace still skips the large debug artifact nested lane at `touched=12`, so this change does not broaden artifact cleanup.

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
  - `[DAE]002` covers nested `optimizeAfterInlining` replay plus artifact comparison; its narrow scheduler now includes touched-only `optimize-instructions`, `pick-load-signs`, `heap-store-optimization`, `heap2local`, `optimize-casts`, `code-pushing`, direct `precompute`, `local-cse`, `code-folding`, repeated `merge-blocks`, `remove-unused-brs`, and `remove-unused-names` cleanup, the nested `local-cse` adapter now traces `func/start/done` so order tests can pin it before `simplify-locals`, and the scheduler itself now traces `nested-pass name=...` so tests can lock the guarded order directly, but the full `precompute-propagate` + default-function-pipeline replay and artifact parity remain open.

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
