# OptimizeInstructions OI-J both-call descriptor miss

## Summary

Binaryen `version_130` folds the exact descriptor-cast miss where both `ref.cast_desc_eq` operands are direct calls:

```wat
(call $make_ref)  ;; returns (ref $sub), where $sub <: $base and $sub != $base
(call $make_desc) ;; returns (ref (exact $base_desc))
(ref.cast_desc_eq (ref $base))
```

The optimized shape preserves both direct calls in source order, drops their results, and then emits `unreachable`:

```wat
(drop (call $make_ref))
(drop (call $make_desc))
unreachable
```

Starshine now covers this narrow default-mode slice in both the HOT descriptor-miss helper and the public raw dispatcher path that previously skipped stack-carried call/call descriptor casts before HOT lifting.

## Probe evidence

Local probe: `.tmp/oi-j-next-probes/desc-both-call-base-on-subtype.wat`.

- `wasm-tools validate --features all` accepted the input.
- `wasm-opt --all-features --optimize-instructions -S` rewrote `$cast` to `drop(call $make_ref); drop(call $make_desc); unreachable` and removed `ref.cast_desc_eq`.
- The operand order is reference call first, descriptor call second, matching the original stack order and preserving both calls' global writes before the descriptor-cast trap.

## Implementation

- `src/passes/pass_manager.mbt`
  - Adds a raw exact-descriptor miss helper for direct no-parameter `Call; Call; RefCastDescEq` when the first call returns a non-null strict subtype of the cast target and the second call returns a non-null exact descriptor whose type metadata describes the target.
  - Rewrites only that proven shape to `call(ref); drop; call(descriptor); drop; unreachable`, before the stack-carried-effect raw skip can return `stack-carried-effect-optimize-instructions-noop`.
- `src/passes/optimize_instructions.mbt`
  - Extends the HOT exact-descriptor miss helper's two-drop arm to admit a direct descriptor call as the second preserved operand after the existing exact-describes-target and strict-subtype miss proofs succeed.
- `src/passes/optimize_instructions_test.mbt`
  - Adds red-first coverage for `optimize-instructions folds descriptor casts with both operands call-produced exact descriptor misses`, including an AST-level check for `call 0; drop; call 1; drop; unreachable` order.

## Boundaries

This slice is deliberately narrow. It does **not** claim parity for:

- parameterized direct calls or stack-carried call arguments;
- `call_indirect`, `call_ref`, `return_call*`, or multivalue call producers;
- descriptor operands with escaping control, EH, branch payloads, or nested control not represented by the direct-call shape;
- nullable null-only descriptor casts;
- TNH/IIT-specific behavior for the both-call shape;
- `ref.test_desc` or descriptor BrOn forms, which remain tooling/representation boundaries until representation and oracle support are added.

## Validation

Focused validation initially failed red-first with a residual `ref.cast_desc_eq` in the public optimized function:

```sh
moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with both operands call-produced exact descriptor misses'
```

After implementation, the same focused test passed.

Final validation:

- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- Focused `moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with both operands call-produced exact descriptor misses'` passed `1/1` with pre-existing warnings.
- `moon test` passed `7650/7650`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Starshine probe replay with `_build/native/release/build/cmd/cmd.exe --optimize-instructions` produced `call $make_ref; drop; call $make_desc; drop; unreachable` and no residual `ref.cast_desc_eq`; `wasm-tools validate --features all` accepted the output. The command also printed a pre-existing `wat2wasm` fallback warning while still producing the requested wasm.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass optimize-instructions --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/oi-j-both-call-descriptor-miss-genvalid-10000-20260704` compared `10000/10000`, normalized `10000`, and reported zero validation/property/generator/command failures and zero mismatches with Binaryen cache `10000/0`.
- `python3 -m json.tool docs/wiki/binaryen/passes/optimize-instructions/parity-matrix.json >/dev/null` passed.
- `git diff --check` passed.
