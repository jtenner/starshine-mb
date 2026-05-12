---
kind: concept
status: supported
last_reviewed: 2026-05-12
sources:
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
- value-producing `if` operands are preserved with `drop` repair when their parameter is removed;
- no-param dropped/uncalled result removal with conservative unreachable-prefix cleanup;
- local-use scanning ignores dead suffixes after a root `unreachable`;
- case-000690-style escaped-result self-call operand preservation: if the original single `f64` parameter is stranded under an escaped direct-call result that becomes an undropped dead-suffix self-call operand, Starshine preserves that parameter while still pruning direct simple self-call operands and dropped self-call escaped-result operands, matching the observed Binaryen shape in [`../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md`](../../../raw/research/0557-2026-05-12-dae-case-000690-escaped-self-operand.md);
- unused simple function type pruning after signature changes;
- a nested-cleanup trace marker for the required `precompute-propagate` prefix.

Current non-parity caveat: complete Binaryen result-removal scheduling and the real touched-function-filtered nested cleanup scheduler are not implemented yet. A whole-module cleanup experiment rewrote unrelated functions and worsened direct parity, so the active pass records the nested lane but does not run the default cleanup pipeline until a filtered scheduler lands. After the 2026-05-12 case-000690 fix, `.tmp/pass-fuzz-dae-690-final2-1000` removed `case-000690-gen-valid` from the failure set and reported `998/1000` compared, `985` normalized matches, `13` mismatches, and `2` Binaryen/tool command failures.

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
  - `[DAE]002` covers nested `optimizeAfterInlining` replay plus artifact comparison.

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
   - preserve uninhabitable-result behavior with `call; unreachable`-style repair.

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
