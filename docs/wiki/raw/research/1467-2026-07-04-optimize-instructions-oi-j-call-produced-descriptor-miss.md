# OI-J call-produced descriptor-cast mismatch slice

Date: 2026-07-04

## Scope

This finite OI-J descriptor/effect slice covers `ref.cast_desc_eq` operations where the reference operand is a direct call that produces a non-null strict-subtype reference, while the descriptor operand is an erasable fresh exact descriptor for the target supertype:

```wat
(module
  (rec
    (type $base (sub (descriptor $base_desc) (struct (field i32))))
    (type $base_desc (sub (describes $base) (struct)))
    (type $sub (sub $base (descriptor $sub_desc) (struct (field i32) (field i64))))
    (type $sub_desc (sub $base_desc (describes $sub) (struct)))
  )
  (global $g (mut i32) (i32.const 0))
  (func $make (result (ref $sub))
    (i32.const 7)
    (global.set $g)
    (struct.new_default_desc $sub
      (struct.new_default $sub_desc)))
  (func $cast (result (ref $base))
    (ref.cast_desc_eq (ref $base)
      (call $make)
      (struct.new_default $base_desc)))
)
```

The explicit `$base_desc` descriptor can only match exact `$base` instances, so the non-null `$sub` result of the call cannot pass the descriptor equality check. The direct call still must execute before the cast trap. Starshine now preserves that call as a dropped prefix before `unreachable`.

Out of scope: call-indirect and call_ref operands, effectful descriptor calls, call arguments with escaping control, EH, multivalue operands, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, TNH/IIT behavior, `ref.test_desc`, descriptor BrOn forms, and generalized descriptor effect/control localization.

## Binaryen evidence

Probe: `.tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.wat`.

Commands:

```text
wasm-tools validate --features all .tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.wat
wasm-opt --all-features .tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.wat --optimize-instructions -S -o .tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.binaryen.wat
grep -n "call \\$make\|global.set\|unreachable\|ref.cast_desc_eq\|drop\|struct.new" .tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.binaryen.wat
```

Binaryen `version_130` emits `drop(call $make)` followed by `unreachable` in the cast function, with no residual `ref.cast_desc_eq`. The helper function still contains the `global.set` and descriptor-bearing `struct.new_default_desc` allocation, so the call's effects and allocation behavior are preserved by the dropped call.

## Implementation

`src/passes/optimize_instructions.mbt` adds `optimize_instructions_exact_descriptor_miss_reference_call_can_drop_before_unreachable(...)`. The helper is intentionally limited to direct `Call` reference operands whose expression tree is straight-line under the existing exact descriptor miss predicate. It is only consulted for the reference operand after the exact-descriptor miss proof succeeds; descriptor operands still use the older branch-free block-only drop predicate.

When the reference call is the only non-erasable operand and the descriptor operand can be erased, the existing one-drop unreachable replacement rewrites the cast to `drop(call); unreachable`.

## Tests

Added red-first focused public-pipeline test:

- `src/passes/optimize_instructions_test.mbt::optimize-instructions folds descriptor casts with call-produced exact descriptor miss refs`

Red result before implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with call-produced exact descriptor miss refs'
=> failed with residual `ref.cast_desc_eq (ref (exact $base))` in the optimized cast function body
```

Green result after implementation:

```text
moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter 'optimize-instructions folds descriptor casts with call-produced exact descriptor miss refs'
=> Total tests: 1, passed: 1, failed: 0.
```

The test asserts the cast function still calls the effectful producer, contains `unreachable`, and no longer contains `ref.cast_desc_eq`.

## Validation

Completed in this slice:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.wat` passed.
- Binaryen probe command above passed and emitted `drop(call $make); unreachable` with no residual descriptor cast.
- Red-first focused test above failed before implementation with residual `ref.cast_desc_eq`.
- Green focused test above passed `1/1` after implementation.
- `moon test --package jtenner/starshine/passes --file optimize_instructions_test.mbt --target native --filter '*descriptor*'` passed `46/46` with pre-existing warnings.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Full `moon test` passed `7627/7627`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Native Starshine probe replay using `_build/native/release/build/cmd/cmd.exe --optimize-instructions` on `.tmp/oi-j-next-probes/desc-call-ref-base-on-subtype.wasm`, followed by `wasm-tools validate --features all` and `wasm-tools print`, emitted a validating Starshine module with `call $make`, `drop`, `unreachable`, and no residual `ref.cast_desc_eq`.
- Regular GenValid compare-pass: `bun scripts/pass-fuzz-compare.ts --count 10000 --seed 0x5eed --pass optimize-instructions --out-dir .tmp/oi-j-call-ref-descriptor-miss-genvalid-10000-20260704 --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe` compared `10000/10000`, normalized `10000`, mismatches `0`, validation/generator/property/command failures `0`, command failures `0`, Binaryen cache hits/misses `10000/0`.

## Remaining OI-J work

OI-J remains `blocked-surface`. This slice removes one direct-call reference operand variant of the exact descriptor miss, but call-indirect/call_ref operands, effectful descriptor calls, escaping labels/control, nested control, EH, multivalue operands, nullable descriptor null-only casts, arbitrary exact-result descriptor-cast shapes, broader TNH/IIT descriptor breadth, and generalized descriptor effect/control localization remain open. The `ref.test_desc` and descriptor BrOn forms remain unsupported/tooling/representation boundaries as documented in note `1456`.
