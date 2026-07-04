# OI-J nullable strict-subtype descriptor exactification validation slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/exactness validation slice covers nullable descriptor equality casts where a nullable strict-subtype reference operand is paired with a fresh exact descriptor for the nullable supertype result:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (func $cast (param $x (ref null $sub)) (result (ref null $base))
    (ref.cast_desc_eq (ref null $base)
      (local.get $x)
      (struct.new_default $base_desc)))
)
```

Binaryen `version_130` exactifies this to `ref.cast_desc_eq (ref null (exact $base))`. Non-null `$sub` values still trap because they cannot match the exact `$base` descriptor, while `null` still passes the nullable target. Before this slice, Starshine's optimizer performed the exactification but final validation rejected the Binaryen-shaped exact descriptor cast with `ref.cast_desc_eq target does not match operand type`.

Out of scope: folding this nullable descriptor cast to `ref.cast nullref` or `unreachable` (Binaryen does not do that for this probe), effectful reference or descriptor operands, TNH/IIT behavior, `ref.test_desc`, descriptor BrOn forms, and broader exact-result descriptor-cast shapes beyond accepting the Binaryen-shaped exactified output.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.wat`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.binaryen-rerun2.wat
grep -n "ref.cast_desc_eq" .tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.binaryen-rerun2.wat
```

Observed output contains `ref.cast_desc_eq (ref null (exact $base))`.

A companion exact-result probe `.tmp/oi-j-next-probes/desc-nullable-exact-base-on-nullable-subtype.wat` shows Binaryen preserving the same exact nullable descriptor-cast spelling when the input result is already exact.

## Implementation

`src/validate/typecheck.mbt` now validates the inspected reference operand of `ref.cast_desc_eq` with the same reference test/cast compatibility predicate used by ordinary `ref.test` and `ref.cast`, instead of the narrower descriptor compatibility predicate. This accepts exact nullable supertype descriptor casts over nullable strict-subtype operands, matching Binaryen and wasm-tools validation.

The legacy one-operand descriptor-cast compatibility path remains guarded: if the top stack reference has descriptor metadata but does not match the target descriptor, validation still rejects it rather than treating that descriptor object as the inspected reference. Existing mismatched-descriptor and nullable-descriptor-operand rejection tests remain green.

No optimizer rewrite was broadened in this slice. The existing descriptor exactification path already produced the Binaryen-shaped `ref.cast_desc_eq (ref null (exact $base))`; the fix is that final validation now accepts that output.

## Tests

Added red-first tests:

- `src/validate/typecheck.mbt::Typecheck exact RefCastDescEq accepts nullable strict-subtype operands`
  - Red failure before implementation: `Expected Ok, got Err: ref.cast_desc_eq target does not match operand type`.
- `src/passes/optimize_instructions_test.mbt::optimize-instructions exactifies nullable descriptor casts on strict-subtype operands before final validation`
  - Red failure before implementation: public pipeline final validation rejected the optimized `ref.cast_desc_eq (RefType Null Exact (HeapType Idx 0))`.

After the validation fix, both tests pass. The broader `*RefCastDescEq*` validation filter still passes, preserving mismatched descriptor-target and nullable descriptor-operand rejection.

## Validation

Completed in this slice:

- Binaryen probe commands above passed; Binaryen output contains `ref.cast_desc_eq (ref null (exact $base))`.
- Red-first validation and public-pipeline tests failed before implementation with the final/typecheck descriptor target mismatch.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test --package jtenner/starshine/validate --file typecheck.mbt --target native --filter '*RefCastDescEq*'` passed `6/6`.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `42/42` with pre-existing warnings.
- Full `moon test` passed `7438/7438`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native probe replay using `target/native/release/build/cmd/cmd.exe --optimize-instructions` on `.tmp/oi-j-next-probes/desc-nullable-base-on-nullable-subtype.wasm`, followed by `wasm-tools validate --features all` and `wasm-tools print`, emitted a validating Starshine module containing `ref.cast_desc_eq (ref null (exact $base))`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-nullable-descriptor-exactification-genvalid-10000-20260704 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one nullable strict-subtype descriptor exactification validation blocker, but nullable descriptor null-only casts are not folded beyond Binaryen's exactification, effectful reference or descriptor operands remain open, TNH/IIT descriptor breadth remains open, arbitrary exact-result descriptor-cast shapes remain open, and generalized descriptor effect/control localization remains open. The `ref.test_desc` and descriptor BrOn forms remain unsupported/tooling/representation boundaries as documented in note `1456`.
