# OptimizeInstructions OI-M generalized selected-child localization

_Date:_ 2026-07-03
_Status:_ ACCEL001/ACCEL002 completed for direct one-use selected-child tuple extraction; OI-M remains active/P0 for the residual tuple/multivalue surfaces listed below.

## Question

Can Starshine stop widening OI-M direct one-use `tuple.extract(tuple.make(...))` selected-child localization one arity at a time?

## Binaryen source audit

Primary source: Binaryen `version_130` [`OptimizeInstructions.cpp::visitTupleExtract`](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/OptimizeInstructions.cpp#L2737-L2752).

Finding:

- `visitTupleExtract` has no explicit numeric selected-child arity cap.
- For concrete tuple extracts over `TupleMake`, it reads the selected result type from `make->type[curr->index]`, allocates one temp local of that type, replaces the selected tuple lane with a `local.tee`, builds a `local.get` of the temp, and calls `getDroppedChildrenAndAppend(make, get)`.
- The pass-local wrapper for `getDroppedChildrenAndAppend` delegates to the generic IR helper at [`OptimizeInstructions.cpp` lines 1632-1639](https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/OptimizeInstructions.cpp#L1632-L1639).
- The generic helper in [`src/ir/drop.cpp`](https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/drop.cpp#L26-L82) iterates children and preserves/drops only children with unremovable side effects, then appends the final value. It has no selected-child arity cap either.

Interpretation for Starshine: the upstream transform is generic over tuple lane count. The old Starshine hardcoded accepted-result-count list was an implementation throttle, not source-backed Binaryen behavior.

## Starshine contract implemented here

`src/passes/optimize_instructions.mbt` now admits any selected-child result count greater than zero for the existing direct-HOT localizer, under the already-established safe preconditions:

- the root is `tuple.extract` with one tuple operand;
- the tuple producer is live, one-use, and a direct `TupleMake`;
- every tuple child recursively excludes control/branch/EH/nested-region shapes that Starshine cannot safely reconstruct in this localizer;
- the selected child has scalar HOT result lanes and is localized by allocating one scratch local per selected result;
- selected-child lanes are stored in stack-pop order and the requested lane is reloaded from its matching scratch local;
- non-selected siblings are preserved only when they have effects or source-backed trap-only hazards, and multi-result non-selected siblings remain excluded until a separate safe sibling-localizer exists.

This implements arbitrary direct one-use selected-child arity. It does **not** implement multi-result non-selected sibling localization, multi-use tuple producers, control/branch/EH sibling reconstruction, or the broader generalized tuple-scratch reconstruction used by neighboring tuple passes.

## Tests

`src/passes/optimize_instructions_test.mbt` now has a reusable selected-child fixture/assertion helper:

- `optimize_instructions_test_tuple_selected_child_types` generates configurable scalar result vectors without huge duplicate fixtures.
- `optimize_instructions_test_assert_selected_child_localizes` builds a direct-HOT selected-child tuple, runs `optimize-instructions`, asserts a block replacement, checks every selected-child lane is stored with `LocalSet` in stack-pop order, and checks the final `LocalGet` uses the selected lane's scratch local rather than lane zero's local.

Representative coverage:

- low arity: `generic selected-child helper localizes second lane from two-result selected tuple child`;
- current boundary: `generic selected-child helper localizes twenty-sixth lane from twenty-six-result selected tuple child`;
- former boundary: `localizes twenty-seventh lane from twenty-seven-result selected tuple child`;
- source-audited stress: `generic selected-child helper localizes thirty-second lane from thirty-two-result selected tuple child`.

Red-first evidence: before implementation, focused `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*selected tuple child*'` passed the existing supported cases but failed the new 27-result and 32-result helper-backed positive tests because the root stayed `TupleExtract`. After replacing the hardcoded cap with the generalized non-empty-result predicate, the same focused command passed 30/30.

## Validation/evidence

Early implementation evidence in this slice:

- `moon fmt` passed.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*selected tuple child*'` passed 30/30 after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*tuple.extract*'` passed 23/23 after implementation.

Full validation evidence for the implementing slice:

- `moon info` passed with pre-existing warnings.
- `moon test` passed 7246/7246.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Direct `bun scripts/pass-fuzz-compare.ts --count 18 --seed 0x5eed --pass optimize-instructions --gen-valid-profile pass-oi-tuple --out-dir .tmp/oi-m-generalized-selected-direct18-20260703 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 2000 --keep-going-after-command-failures --runtime-execution node` compared 18/18 with 0 normalized, 0 cleanup-normalized, 18 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 18/0, runtime checked/unsupported/failed 18/0/0, and runtime matrix all-equal 1/1.
- Grouped `bun scripts/oi-parity-sweep.ts --family OI-M --count 108 --out-dir .tmp/oi-m-generalized-selected-count108-20260703 --starshine-bin target/native/release/build/cmd/cmd.exe --execute -- --max-failures 2000 --keep-going-after-command-failures --runtime-execution node` compared 108/108 with 0 normalized, 0 cleanup-normalized, 108 raw mismatches, zero validation/generator/property/command failures, Binaryen cache 108/0, runtime checked/unsupported/failed 108/0/0, runtime matrix all-equal 9/9, and all 18 OI-M tuple labels sampled.

Raw mismatches remain active OI-M parity evidence requiring agent classification; runtime all-equal evidence does not by itself close OI-M.

## Remaining OI-M work

OI-M stays active/P0. Remaining work is not hidden by runtime-green raw mismatch lanes. Follow-up ACCEL003 split the residual surface into explicit sub-blockers in `docs/wiki/raw/research/1417-2026-07-03-optimize-instructions-oi-m-sub-blocker-split.md` and `docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json`:

- covered-under-preconditions direct one-use selected-child arbitrary arity with reopening criteria;
- multi-result non-selected siblings;
- multi-use tuple producers and local-carried tuple values;
- control/branch/EH siblings and nested-region reconstruction;
- generalized tuple-scratch reconstruction/localization beyond this direct one-use selected-child localizer;
- fuzz/runtime residual classification and paste-ready summaries.

Do not infer OI-G or OI-I/OI-J/OI-K closure from this OI-M slice.
