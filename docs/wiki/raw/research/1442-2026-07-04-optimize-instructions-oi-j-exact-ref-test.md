# OI-J exact `ref.test` behavior slice

Date: 2026-07-04

## Scope

This slice closes one finite unresolved OI-J exactness behavior gap after the representation work in `1440`: successful `ref.test` predicates whose target carries an exact heap immediate. It does not change descriptor casts, `ref.test_desc`, TNH/IIT descriptor behavior, broad useful-type-info, or escaping descriptor-control localizers.

Sources and anchors:

- `docs/wiki/raw/research/1439-2026-07-03-optimize-instructions-oi-j-roadmap.md`
- `docs/wiki/raw/research/1440-2026-07-03-optimize-instructions-oi-j-representation-blockers.md`
- `src/passes/optimize_instructions.mbt`
- `src/passes/optimize_instructions_test.mbt`
- Probe directory: `.tmp/oi-j-exact-ref-test-20260704/`

## Pre-change gap

Roadmap probe 10 was representable after `1440`, but `optimize-instructions` still left the exact predicate in place:

```wat
(func (param $x (ref (exact $a))) (result i32)
  (ref.test (ref (exact $a)) (local.get $x)))
```

Binaryen `version_130` folds the predicate to true while preserving operand effects by dropping the tested value before `i32.const 1`. Starshine already simplified the paired exact `ref.cast` in this probe; only the exact `ref.test` branch was missing.

A focused red-first test, `optimize-instructions folds exact ref.test on already exact operands`, failed with residual `ref.test (RefType Not Null Exact ...)` before implementation.

## Implementation

`optimize_instructions_try_fold_ref_test_null` now accepts `Instruction::RefTest(nullable, exact, target)` instead of only inexact tests. It reuses the existing non-exact known-match path and adds `optimize_instructions_ref_operand_matches_exact_test_target` for operands whose computed HOT result type is already exact for the target heap and whose nullability makes the test definitely true.

Effect handling follows the existing successful-test policy:

- pure operands may be removed and replaced with `i32.const 1`;
- effectful operands are preserved as a dropped prefix before `i32.const 1`.

A probe also showed Binaryen folds non-null same-heap inexact locals for exact `ref.test` to true, even though exact `ref.cast` on the same inexact local remains fail-closed to preserve the cast trap/result proof. The Starshine test records that `ref.test`/`ref.cast` distinction explicitly.

## Probe evidence

After rebuilding `target/native/release/build/cmd/cmd.exe`, focused probes in `.tmp/oi-j-exact-ref-test-20260704/` were replayed against Binaryen and Starshine:

- `10-exact-success-test-cast.wat`: both tools now print `drop(local.get $x); i32.const 1` for the exact `ref.test`, and `local.get $x` for the already-exact cast.
- `exact-ref-test-effectful.wat`: both tools preserve the `global.set`-carrying block as a dropped prefix before `i32.const 1`.
- `exact-ref-test-inexact-boundary.wat`: both tools fold the non-null same-heap inexact exact-test predicate to `drop(local.get $x); i32.const 1`.
- A paired `exact-ref-cast-inexact-same.wat` probe confirms the exact cast remains as `ref.cast (ref (exact $a))`, so this slice does not erase exact-cast traps/proofs for inexact locals.

All Starshine probe outputs validated with `wasm-tools validate --features all`.

## Validation

Completed during the slice:

- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --filter '*exact ref.test*'` failed before implementation and passed after implementation.
- `moon fmt`
- `moon build --target native --release src/cmd`
- Focused Binaryen/Starshine replay for `.tmp/oi-j-exact-ref-test-20260704/` with `wasm-tools validate --features all` on Starshine outputs.

Final signoff after docs updates also passed:

- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null`
- `moon info` (pre-existing warnings only)
- `moon fmt`
- full `moon test` (`7419/7419`)
- regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-exact-ref-test-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000` with `10000` normalized matches and zero validation/generator/property/command failures or mismatches
- `git diff --check`

## Remaining OI-J work

OI-J remains `blocked-surface` for full grouped parity. Active residuals include:

- `ref.test_desc` text/binary/tooling support, still blocked by the subopcode/operand ambiguity and external tool rejection described in `1440`;
- exactness breadth beyond this exact-test success slice and the earlier exact-cast guard slices;
- broader descriptor cast/test behavior and useful-type-info beyond the covered exact, strict-subtype, and descriptor-operand cases;
- broader TNH/IIT behavior beyond the focused descriptor-profile lanes;
- effectful/trapping/control descriptor children beyond the currently represented localizers;
- escaping-control descriptor-child behavior requiring a true label-aware localizer.
