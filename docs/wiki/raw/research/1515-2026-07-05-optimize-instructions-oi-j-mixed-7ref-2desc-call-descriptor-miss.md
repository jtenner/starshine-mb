# OptimizeInstructions OI-J mixed 7-ref/2-desc call descriptor miss

## Summary

Binaryen `version_130` folds the exact descriptor-cast miss where the reference operand is a direct call with seven pure local arguments and the descriptor operand is a direct call with two pure local arguments:

```wat
;; local.get $a0 ... local.get $a6
call $make_ref   ;; returns (ref $sub), where $sub <: $base and $sub != $base
;; local.get $b0 ... local.get $b1
call $make_desc  ;; returns (ref (exact $base_desc))
ref.cast_desc_eq (ref $base)
```

The optimized shape preserves all argument evaluation and both direct calls in source order, drops both call results, and then emits `unreachable`:

```wat
local.get x7
call $make_ref
drop
local.get x2
call $make_desc
drop
unreachable
```

Starshine now covers this narrow 7-reference-argument / 2-descriptor-argument pure-local direct-call default-mode slice in the public raw dispatcher. This continues the seven-reference-argument descent after `(7,3)` and does not prove arbitrary arity, the inverse `(2,7)`, additional mixed-seven arities, or non-local/effectful call arguments.

## Probe evidence

Local probe: `.tmp/oi-j-next-probes/desc-mixed-7ref-2desc-call-base-on-subtype.wat`.

- `wasm-tools validate --features all` accepted the input.
- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --optimize-instructions -S` rewrote `$cast` to ordered `local.get` x7; `call $make_ref`; `drop`; `local.get` x2; `call $make_desc`; `drop`; `unreachable` and removed `ref.cast_desc_eq`.
- The operand order is reference arguments/call first, then descriptor arguments/call, matching the original stack order and preserving both calls' global writes before the descriptor-cast trap.

## Implementation

- `src/passes/pass_manager.mbt`
  - Extends the explicit raw pure-local direct-call descriptor-miss arity predicate to the probed `(7,2)` shape only.
  - Requires the first call to have exactly 7 parameters and return a non-null strict subtype of the cast target.
  - Requires the second call to have exactly 2 parameters and return a non-null exact descriptor whose type metadata describes the target.
  - Reuses the existing pure-local direct-call scanner so the rewrite is still ordered reference argument locals, `call(ref); drop`, ordered descriptor argument locals, `call(descriptor); drop`, and `unreachable` before the stack-carried-effect skip.
- `src/passes/optimize_instructions_test.mbt`
  - Adds red-first public-pipeline coverage for `optimize-instructions folds descriptor casts with mixed 7-ref 2-desc call exact descriptor misses`, using the shared direct-call descriptor-miss fixture and asserting the ordered `local.get` x7; `call(ref); drop`; `local.get` x2; `call(desc); drop`; `unreachable` body.

## Boundaries

This slice is deliberately narrow. It does **not** claim parity for:

- arbitrary arity direct calls, the inverse `(2,7)`, or broader mixed arities beyond the explicitly probed whitelist;
- non-local, effectful, trapping, or multivalue call arguments;
- `call_indirect`, `call_ref`, `return_call*`, or multivalue call producers;
- descriptor operands with escaping control, EH, branch payloads, or nested control not represented by the direct-call shape;
- nullable descriptor null-only casts;
- TNH/IIT-specific behavior for parameterized direct calls;
- `ref.test_desc` or descriptor BrOn forms, which remain tooling/representation boundaries until representation and oracle support are added.

## Validation

Focused validation initially failed red-first with a residual `ref.cast_desc_eq` in the public optimized function:

```sh
moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with mixed 7-ref 2-desc call exact descriptor misses'
```

After implementation, the same focused test passed `1/1` with pre-existing warnings.

Final validation:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-mixed-7ref-2desc-call-base-on-subtype.wat` passed.
- `wasm-opt --all-features --optimize-instructions -S .tmp/oi-j-next-probes/desc-mixed-7ref-2desc-call-base-on-subtype.wat` produced the Binaryen-shaped ordered 7-ref-arg call/drop plus 2-desc-arg call/drop/unreachable output with no residual `ref.cast_desc_eq`.
- Focused `moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with mixed 7-ref 2-desc call exact descriptor misses'` passed `1/1` after implementation with pre-existing warnings.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test` passed `7705/7705`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Starshine probe replay with `_build/native/release/build/cmd/cmd.exe --format wat --optimize-instructions` produced validating wasm with no residual `ref.cast_desc_eq` after `wasm-tools print` inspection. The CLI printed the pre-existing `sh: 1: wat2wasm: not found` fallback warning.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass optimize-instructions --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/oi-j-mixed-7ref-2desc-call-descriptor-miss-genvalid-10000-20260705` compared `10000/10000`, normalized `10000`, and reported zero validation/property/generator/command failures and zero mismatches with Binaryen cache `10000/0`.
