# OptimizeInstructions OI-J call-produced descriptor operand miss

## Summary

Binaryen `version_130` folds the descriptor-cast miss where the reference operand is a pure non-null strict-subtype local and the descriptor operand is a direct call returning an exact descriptor for the target supertype. The call is preserved for effects, then the failed descriptor equality cast becomes `unreachable`:

```wat
(local.get $x) ;; (ref $sub), where $sub <: $base and $sub != $base
(call $make_desc) ;; returns (ref (exact $base_desc))
(ref.cast_desc_eq (ref $base))
```

rewrites to:

```wat
(call $make_desc)
drop
unreachable
```

Starshine now covers this narrow default-mode slice in both the HOT descriptor-miss helper and the public raw dispatcher path that previously skipped stack-carried effect shapes before HOT lifting.

## Probe evidence

Local probe: `.tmp/oi-j-next-probes/desc-call-desc-base-on-subtype.wat`.

- `wasm-tools validate --features all` accepted the input.
- Binaryen `wasm-opt --all-features --optimize-instructions -S` preserves the direct descriptor-producing call as `drop(call $make_desc)` and removes the residual `ref.cast_desc_eq` by emitting `unreachable`.
- Starshine initially kept the descriptor cast in the public pipeline because `run_hot_pipeline_raw_optimize_instructions_skip` classified `local.get; call; ref.cast_desc_eq` as `stack-carried-effect-optimize-instructions-noop` before HOT could run.

## Implementation

- `src/passes/optimize_instructions.mbt`
  - The exact-descriptor miss proof now derives exact described heaps from direct `HotOp::Call` descriptor operands by resolving the callee function type through `HotModuleContext`.
  - The miss fold admits direct descriptor calls in the drop-before-`unreachable` arm after the descriptor exactly-describes-target proof and strict-subtype reference miss proof have both succeeded.
- `src/passes/pass_manager.mbt`
  - The raw exact-descriptor miss fold now handles the direct `LocalGet; Call; RefCastDescEq` public-pipeline shape when the descriptor call has no parameters, returns one non-null exact descriptor reference, that descriptor metadata describes the cast target, and the local type is a non-null strict subtype of the target.
  - This raw fold runs before the stack-carried-effect skip and rewrites to `call; drop; unreachable`, preserving the descriptor call effects and erasing the pure reference local.
- `src/passes/optimize_instructions_test.mbt`
  - Added red-first coverage for `optimize-instructions folds descriptor casts with call-produced exact descriptor operands`.

## Boundaries

This slice is deliberately narrow. It does **not** claim parity for:

- descriptor calls with parameters or stack-carried arguments;
- `call_indirect`, `call_ref`, `return_call*`, or multivalue descriptor producers;
- both-call reference/descriptor operand ordering;
- descriptor operands containing escaping control, EH, or nested control not represented by the direct-call shape;
- nullable null-only descriptor casts, `ref.test_desc`, or descriptor BrOn forms;
- TNH/IIT-specific descriptor behavior beyond already documented slices.

## Validation

Focused validation:

```sh
moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with call-produced exact descriptor operands'
```

passed after the implementation. Full validation also passed:

- `moon fmt`
- `moon info` with pre-existing warnings
- `moon test` (`7649/7649`)
- `moon build --target native --release src/cmd` with pre-existing warnings
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass optimize-instructions --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/oi-j-call-desc-operand-miss-genvalid-10000-20260704`: compared `10000/10000`, normalized `10000`, zero validation/property/generator/command failures, zero mismatches, Binaryen cache `10000/0`.
