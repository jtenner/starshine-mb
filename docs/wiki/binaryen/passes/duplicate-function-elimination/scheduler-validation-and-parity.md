---
kind: concept
status: supported
last_reviewed: 2026-05-13
sources:
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

A valid Starshine DFE change must preserve the upstream hash/equality/function-reference rewrite contract, keep local type/name/annotation cleanup explicitly labeled as local extra behavior, and not claim Binaryen preset parity until the multi-round and two-slot scheduler gap is tested.

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

The repeat budget matters because a callee rewrite can make callers equal only after an earlier round. Binaryen's public optimizer can keep iterating at higher optimization or shrink levels, while a single explicit Starshine pass run currently does not.

### 2. Current Starshine implementation to preserve

The local read path is:

1. `src/passes/optimize.mbt:241` registers `duplicate-function-elimination` as a module pass.
2. `src/passes/pass_manager.mbt:8674-8675` dispatches it to `dfe_run_module_pass_with_perf(...)`.
3. `src/passes/duplicate_function_elimination.mbt:3245-3498` runs one duplicate-detection/rebuild/rewrite iteration.
4. `src/passes/duplicate_function_elimination.mbt:2537-2827` rewrites function-index carriers in instructions and module sections.
5. `src/passes/duplicate_function_elimination.mbt:3172-3243` compacts duplicate simple type indices after a successful merge.
6. `src/passes/duplicate_function_elimination.mbt:3500-3532` orders the explicit pass: iteration, element canonicalization, name stripping on no-merge path, and duplicate-type compaction on merge path.

The local implementation is deliberately broader than upstream DFE in some areas. Do not “fix” those differences away unless the change is a planned semantic decision and the tests/docs are updated together.

### 3. Current Starshine preset gap

`src/passes/optimize.mbt:259-281` defines the public `optimize` and `shrink` preset entries, and those arrays currently omit `duplicate-function-elimination`.

So there are two valid validation modes today:

- explicit-pass validation: `--pass duplicate-function-elimination` or a focused `run_hot_pipeline(..., ["duplicate-function-elimination"])` test;
- future preset validation: ordered no-DWARF replay that decides whether to add the early Binaryen slot, the late Binaryen slot, and/or a multi-round loop.

Do not treat green explicit-pass tests as evidence that Starshine's public `optimize` / `shrink` presets match Binaryen's DFE scheduling.

## Known Starshine-vs-Binaryen split

| Area | Binaryen | Current Starshine |
| --- | --- | --- |
| Pass kind | Whole-module pass. | Whole-module pass. |
| Candidate set | Defined functions only. | Defined functions only. |
| Core proof | Hash prefilter plus exact equality. | Hash prefilter plus exact equality over normalized local forms. |
| Survivor choice | Earliest equivalent function survives. | Earliest equivalent function survives. |
| Function-reference rewrite | Required. | Required and implemented across code/module carriers. |
| Iteration | Option-dependent repeat budget. | One explicit duplicate-elimination iteration. |
| Default scheduling | Early global pre-pass and late global post-pass. | Explicit pass only; public presets omit DFE today. |
| Type compaction | Not DFE proper. | Local extra after a successful merge for duplicate simple function types. |
| Name and annotation cleanup | Not the central upstream algorithm. | Local extra cleanup with focused tests. |

## Tests to read first

`src/passes/duplicate_function_elimination_test.mbt` is the current local proof surface:

- `:99-194` covers ordinary function-reference rewrites.
- `:196-252` locks the current single-pass transitive-unlock boundary.
- `:254-698` covers duplicate simple-type compaction and type-index repair.
- `:700-764` covers element-expression canonicalization when no functions merge.
- `:766-848` covers name stripping and annotation-map rewrite bookkeeping.

That test split is useful because it mirrors the documentation split:

- upstream core DFE,
- local extra cleanup,
- and the known iteration gap.

## Recommended future signoff before preset scheduling

Before adding DFE to `optimize` or `shrink`, collect evidence in this order:

1. Focused MoonBit tests for every row in the beginner checklist.
2. A test that intentionally distinguishes one-round Starshine behavior from Binaryen's higher-budget behavior, or an implementation change that closes that gap.
3. Binaryen-oracle `compare-pass` runs for explicit `duplicate-function-elimination` after normalizing known local extras or deciding they are intended output differences.
4. Ordered no-DWARF replay proving the early and late DFE slots do not introduce downstream Starshine regressions.
5. A docs update to [`parity.md`](./parity.md), [`starshine-strategy.md`](./starshine-strategy.md), and this page recording the exact scheduler decision.

## Open decision

Starshine still needs to decide how to model Binaryen's repeat behavior:

- implement Binaryen's repeat budget inside the explicit module pass;
- keep the explicit pass one-round and rely on repeated preset slots;
- or keep the local one-round explicit behavior and document a deliberate non-parity choice.

Until that decision is made, this folder should say “active explicit module pass with a scheduler/iteration parity gap,” not “fully scheduled Binaryen-equivalent DFE.”

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
