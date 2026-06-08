---
kind: concept
status: supported
last_reviewed: 2026-06-08
sources:
  - ../../../raw/research/0719-2026-06-08-duplicate-function-elimination-behavior-gap-inventory.md
  - ../../../raw/binaryen/2026-05-13-duplicate-function-elimination-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md
  - ../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
  - ../../../../../src/passes/duplicate_function_elimination.mbt
  - ../../../../../src/passes/duplicate_function_elimination_test.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/optimize.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./type-compaction-and-metadata.md
  - ./parity.md
---

# DFE scheduler, validation, and parity bridge

This page is the read-along bridge for validating Starshine `duplicate-function-elimination` against Binaryen without mixing three different questions:

1. What does upstream Binaryen DFE require?
2. What does current Starshine DFE intentionally add?
3. What must be proven before scheduling Starshine DFE inside public presets?

Use this page after the overview and shape catalog:

- [`index.md`](./index.md) explains the pass at a beginner level.
- [`wat-shapes.md`](./wat-shapes.md) shows transformed module shapes.
- [`binaryen-strategy.md`](./binaryen-strategy.md) explains upstream Binaryen.
- [`starshine-strategy.md`](./starshine-strategy.md) maps current MoonBit code.
- [`type-compaction-and-metadata.md`](./type-compaction-and-metadata.md) separates local extras from upstream DFE proper.
- [`parity.md`](./parity.md) records current parity framing.

## One-sentence rule

A valid Starshine DFE change must preserve the upstream hash/equality/function-reference rewrite contract, keep local type/name/annotation cleanup explicitly labeled as local extra behavior, and preserve the now-tested two-slot Binaryen preset neighborhoods in `optimize` and `shrink`.

## Beginner validation checklist

For a small hand-written module, check these outcomes first:

| Shape | Expected Starshine explicit-pass behavior | Why it matters |
| --- | --- | --- |
| Two identical defined functions | Later duplicate is removed; earlier survivor remains. | Basic DFE proof from [`wat-shapes.md`](./wat-shapes.md). |
| Duplicate called by another function | Call is retargeted to the survivor. | Function-body rewrite proof. |
| Duplicate used by `ref.func`, export, start, or element segment | Every function-index carrier points at the survivor. | Whole-module rewrite proof. |
| Candidate with a semantic annotation mismatch | Functions do not merge. | Equality must not erase behavior-changing metadata. |
| Candidate differing only in non-semantic metadata | Functions can merge. | Matches Binaryen's equality model. |
| No duplicate functions but compactable element expressions | Starshine may still canonicalize element segments and strip names. | Current local extra behavior, not upstream DFE proper. |
| Duplicate simple function types after a merge | Starshine may compact duplicate simple types and repair type-index users. | Current local extra behavior described in [`type-compaction-and-metadata.md`](./type-compaction-and-metadata.md). |

## Advanced validation checklist

### 1. Upstream contract to preserve

Binaryen current `main` still matches the source-backed contract captured in this folder, and the 2026-05-13 recheck did not change that conclusion:

- choose an option-dependent repeat budget;
- hash defined functions by type/body/semantic annotations;
- exact-compare only collision candidates;
- keep the earliest equivalent survivor;
- remove later duplicates; and
- rewrite module-wide function references through the replacement map.

The repeat budget matters because a callee rewrite can make callers equal only after an earlier round. Starshine's direct pass now iterates to a fixed point, and the 2026-06-08 preset update schedules the two top-level Binaryen DFE neighborhoods in public `optimize` and `shrink`.

### 2. Current Starshine implementation to preserve

The local read path is:

1. `src/passes/optimize.mbt:241` registers `duplicate-function-elimination` as a module pass.
2. `src/passes/pass_manager.mbt:8674-8675` dispatches it to `dfe_run_module_pass_with_perf(...)`.
3. `src/passes/duplicate_function_elimination.mbt` runs duplicate-detection/rebuild/rewrite iterations until no additional merge is found.
4. `src/passes/duplicate_function_elimination.mbt:2537-2827` rewrites function-index carriers in instructions and module sections.
5. `src/passes/duplicate_function_elimination.mbt:3172-3243` compacts duplicate simple type indices after a successful merge.
6. `src/passes/duplicate_function_elimination.mbt:3500-3532` orders the explicit pass: iteration, element canonicalization, name stripping on no-merge path, and duplicate-type compaction on merge path.

The local implementation is deliberately broader than upstream DFE in some areas. Do not “fix” those differences away unless the change is a planned semantic decision and the tests/docs are updated together.

### 3. Current Starshine preset gap

`src/passes/optimize.mbt` now defines public `optimize` and `shrink` preset entries with two DFE slots:

- early pre-pass neighborhood: `duplicate-function-elimination -> remove-unused-module-elements -> memory-packing`;
- late post-pass neighborhood: `dae-optimizing -> inlining-optimizing -> duplicate-function-elimination -> duplicate-import-elimination -> simplify-globals-optimizing -> remove-unused-module-elements`.

Validation modes therefore split into direct DFE behavior and preset-neighborhood behavior. Keep both focused direct tests and preset order/behavior tests green when changing this pass.

## Known Starshine-vs-Binaryen split

| Area | Binaryen | Current Starshine |
| --- | --- | --- |
| Pass kind | Whole-module pass. | Whole-module pass. |
| Candidate set | Defined functions only. | Defined functions only. |
| Core proof | Hash prefilter plus exact equality. | Hash prefilter plus exact equality over normalized local forms. |
| Survivor choice | Earliest equivalent function survives. | Earliest equivalent function survives. |
| Function-reference rewrite | Required. | Required and implemented across code/module carriers. |
| Iteration | Option-dependent repeat budget. | Direct pass iterates to fixed point; presets schedule the two top-level DFE slots. |
| Default scheduling | Early global pre-pass and late global post-pass. | Public presets now include the early and late DFE neighborhoods. |
| Type compaction | Not DFE proper. | Local extra after a successful merge for duplicate simple function types. |
| Name and annotation cleanup | Not the central upstream algorithm. | Local extra cleanup with focused tests. |

## Tests to read first

`src/passes/duplicate_function_elimination_test.mbt` is the current local proof surface:

- `:99-194` covers ordinary function-reference rewrites.
- `:196-252` locks fixed-point transitive-unlock behavior.
- `:254-698` covers duplicate simple-type compaction and type-index repair.
- `:700-764` covers element-expression canonicalization when no functions merge.
- `:766-848` covers name stripping and annotation-map rewrite bookkeeping.

That test split is useful because it mirrors the documentation split:

- upstream core DFE,
- local extra cleanup,
- and the now-tested preset scheduler shape.

## Future signoff rule for scheduler changes

Before changing DFE placement in `optimize` or `shrink`, collect evidence in this order:

1. Focused MoonBit tests for every row in the beginner checklist.
2. Keep the focused fixed-point/callee-unlocking test green so direct DFE cannot regress to the old one-round behavior.
3. Binaryen-oracle `compare-pass` runs for explicit `duplicate-function-elimination` after normalizing known local extras or deciding they are intended output differences.
4. Ordered no-DWARF replay proving any changed early or late DFE neighborhood does not introduce downstream Starshine regressions.
5. A docs update to [`parity.md`](./parity.md), [`starshine-strategy.md`](./starshine-strategy.md), and this page recording the exact scheduler decision.

## 2026-06-08 scheduler decision

Starshine now models Binaryen's two top-level DFE slots in public presets, including the adjacent DAE / inlining / duplicate-import neighborhood needed to keep the late slot source-shaped. Direct fixed-point behavior remains guarded separately. Remaining preset-path gaps belong to the broader no-DWARF preset inventory, not to a missing DFE scheduler slot.

## Sources

- [`../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md`](../../../raw/binaryen/2026-04-27-duplicate-function-elimination-validation-primary-sources.md)
- [`../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md`](../../../raw/research/0425-2026-04-27-duplicate-function-elimination-validation-bridge.md)
- [`./binaryen-strategy.md`](./binaryen-strategy.md)
- [`./starshine-strategy.md`](./starshine-strategy.md)
- [`./type-compaction-and-metadata.md`](./type-compaction-and-metadata.md)
- [`./parity.md`](./parity.md)
- [`../../../../../src/passes/duplicate_function_elimination.mbt`](../../../../../src/passes/duplicate_function_elimination.mbt)
- [`../../../../../src/passes/duplicate_function_elimination_test.mbt`](../../../../../src/passes/duplicate_function_elimination_test.mbt)
- [`../../../../../src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt)
- [`../../../../../src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt)
