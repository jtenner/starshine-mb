# 1374 - remove-unused-brs GC unreachable-input and descriptor audit

Date: 2026-06-29

## Question

Continue `[O4Z-AUDIT-RUB-Q]` after the fallthrough-payload split boundary by auditing the next remaining GC `optimizeGC(...)` surfaces:

1. descriptor `br_on_cast_desc_eq*` forms, and
2. `GCTypeUtils::Unreachable` / `getDroppedChildrenAndAppend(...)` construction for `br_on_cast*` inputs that cannot execute.

## Source evidence

Local Binaryen oracle source is `.tmp/binaryen-v130/RemoveUnusedBrs.cpp` (`version_130`). In `optimizeGC(...)` the BrOn visitor handles `BrOnCast`, `BrOnCastFail`, `BrOnCastDescEq`, and `BrOnCastDescEqFail` in the same switch. Descriptor forms are special:

- descriptor casts do **not** use the normal heap-type GLB improvement, because the descriptor operand controls the target heap;
- Binaryen only improves descriptor nullability in narrow cases;
- even if static types imply `Success` or `SuccessOnlyIfNonNull`, descriptor value equality is not proven, so Binaryen returns without simplifying those cases;
- descriptor forms need `getRefValue()`, which uses `ChildLocalizer` when a descriptor operand exists so the ref can move across descriptor evaluation without changing effects or null-descriptor traps.

The lit source `.tmp/binaryen-v130/remove-unused-brs-desc.wast` confirms descriptor behavior is real RUB surface. Examples include `$no-glb`, `$improve-nullability`, `$only-improve-nullability`, and fail variants whose checks keep or only refine descriptor BrOn forms rather than lowering them like ordinary casts.

Local Starshine representation audit:

- `src/lib/types.mbt` has `RefCastDescEq`, but only ordinary branch-cast instructions: `BrOnCast(LabelIdx, CastOp, HeapType, HeapType)` and `BrOnCastFail(...)`.
- `src/ir` / pass code exposes `HotOp::BrOnCast` and `HotOp::BrOnCastFail`; repo search finds no `br_on_cast_desc_eq`, `br_on_cast_desc_eq_fail`, `BrOnCastDesc*`, or descriptor-bearing BrOn HOT op.
- The WAST/WAT parser recognizes `ref.cast_desc_eq*` leaf casts, but no descriptor BrOn parser/lowerer/binary/HOT path exists locally.

Conclusion: descriptor BrOn is still a representation blocker, not an implementable RUB transform in this slice. Reopen when local `Instruction`, binary decode/encode, WAT/WAST lowering, HOT lift/lower, validator, and pass tests can carry descriptor BrOn forms with both ref and descriptor operands.

## Implemented subset

Binaryen's `GCTypeUtils::Unreachable` branch replaces unreachable-input BrOn casts with `getDroppedChildrenAndAppend(curr, ..., unreachable, DropMode::IgnoreParentEffects)`, preserving side effects/results of earlier children before appending `unreachable`.

Starshine now implements the locally safe HOT child-form subset for ordinary `br_on_cast` / `br_on_cast_fail`:

- if the ref child is already a HOT `Unreachable`, replace the BrOn root with drops for any branch-payload children followed by that `unreachable` child;
- delete the obsolete BrOn node and mark the pass mutated as `gc-br-on-unreachable-input`;
- keep public stack-form unreachable-input shapes conservative for now, because the local stack/HOT candidate used during the red probe did not expose a child-form BrOn root after an `unreachable` stack producer.

This mirrors the `getDroppedChildrenAndAppend(...)` child-preservation contract for the representable child-form subset without introducing raw stack surgery.

## Tests

Added focused HOT tests in `src/passes/remove_unused_brs_test.mbt`:

- `remove-unused-brs replaces child-form unreachable-input br_on_cast with unreachable`
- `remove-unused-brs drops payload children for child-form unreachable-input br_on_cast`

Red-first evidence: before the implementation, public-pipeline probes with `unreachable; br_on_cast` failed because the optimized output still contained `br_on_cast`. The final tests target the representable child-form HOT subset directly; they pass after the implementation and verify the BrOn node is gone, `unreachable` remains, and payload children are dropped before the unreachable replacement.

## Validation

Completed after implementation:

- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` — passed `201/201`.
- `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` — passed; focused RUB tests `201/201`, `moon test src/passes` `3607/3607`.
- `moon info` — passed with 6 pre-existing warnings.
- `moon build --target native --release src/cmd` — passed with 27 pre-existing pass-manager unused-function warnings.
- `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-unreachable-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — timed out after 1200s before summary emission; partial artifacts contain `cases.jsonl`, `inputs/`, and `failures/` but no `result.json`.
- `bun scripts/pass-fuzz-compare.ts --count 100 --seed 0x5eed --pass remove-unused-brs --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-unreachable-100 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures` — timed out after 1200s before summary emission; partial artifacts contain `cases.jsonl`, `inputs/`, and `failures/` but no `result.json`.
- Raw count-10 probe without cleanup normalizer, `.tmp/pass-fuzz-remove-unused-brs-rub-q-unreachable-10`, compared `10/10` with `10` raw mismatches and no validation/generator/property/command failures. Sampled diffs are the known generated unreachable-control-debris family: Binaryen leaves void blocks containing `br` to the block followed by `unreachable`, while Starshine deletes the pure unreachable-control debris. Agent classification: Starshine-win / cleanup-normalized representation drift, not a semantic mismatch and not related to the new GC unreachable-input subset.
- Normalized count-10 probe with `--normalize unreachable-control-debris`, `.tmp/pass-fuzz-remove-unused-brs-rub-q-unreachable-10-normalized`, compared `10/10`: `0` normalized, `10` cleanup-normalized, `0` mismatches/failures.
- Normalized count-100 probe with `--normalize unreachable-control-debris`, `.tmp/pass-fuzz-remove-unused-brs-rub-q-unreachable-100-normalized`, compared `100/100`: `13` normalized, `87` cleanup-normalized, `0` mismatches, `0` validation/generator/property/command failures; cache `binaryenHits=100`, `binaryenMisses=0`, selected profile `binaryen-oracle-portable=100`.

## Status update

Implemented:

- HOT child-form ordinary `br_on_cast` / `br_on_cast_fail` `Unreachable` result subset with payload-drop preservation.

Still open / blocked:

- descriptor `br_on_cast_desc_eq*` forms: representation blocker until local instruction/HOT/binary/WAT/validator support exists;
- public stack-form unreachable-input BrOn cleanup: remains a narrow representation/candidate-lowering boundary unless a safe raw rewrite or child-form exposure is added;
- broader fallthrough-type/local.tee cast insertion and payload splits requiring Binaryen-style `ChildLocalizer` / scratch-local repair;
- nullable disjoint `SuccessOnlyIfNull`, which Binaryen `version_130` itself leaves as a TODO.
