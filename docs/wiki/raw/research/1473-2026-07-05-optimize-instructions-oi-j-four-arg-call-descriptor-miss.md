# OptimizeInstructions OI-J four-argument call descriptor miss

## Summary

Binaryen `version_130` folds the exact descriptor-cast miss where both `ref.cast_desc_eq` operands are direct calls with exactly four pure local arguments:

```wat
local.get $a
local.get $b
local.get $c
local.get $d
call $make_ref   ;; returns (ref $sub), where $sub <: $base and $sub != $base
local.get $e
local.get $f
local.get $g
local.get $h
call $make_desc  ;; returns (ref (exact $base_desc))
ref.cast_desc_eq (ref $base)
```

The optimized shape preserves all argument evaluation and both direct calls in source order, drops both call results, and then emits `unreachable`:

```wat
local.get $a
local.get $b
local.get $c
local.get $d
call $make_ref
drop
local.get $e
local.get $f
local.get $g
local.get $h
call $make_desc
drop
unreachable
```

Starshine now covers this narrow default-mode slice in the public raw dispatcher before the stack-carried-effect skip can return the original body unchanged.

## Probe evidence

Local probe: `.tmp/oi-j-next-probes/desc-both-call-four-args-base-on-subtype.wat`.

- `wasm-tools validate --features all` accepted the input.
- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --optimize-instructions -S` rewrote `$cast` to ordered `local.get; local.get; local.get; local.get; call; drop; local.get; local.get; local.get; local.get; call; drop; unreachable` and removed `ref.cast_desc_eq`.
- The operand order is reference arguments/call first, then descriptor arguments/call, matching the original stack order and preserving both calls' global writes before the descriptor-cast trap.

## Implementation

- `src/passes/pass_manager.mbt`
  - Reuses the parameter-count-aware direct-call result helpers from the previous parameterized-call slices.
  - Adds a raw exact-descriptor miss arm for `LocalGet x4; Call; LocalGet x4; Call; RefCastDescEq` when the first call returns a non-null strict subtype of the cast target, the second call returns a non-null exact descriptor whose type metadata describes the target, and each call has exactly four parameters.
  - Rewrites only that proven shape to the ordered argument locals, `call(ref); drop`, ordered descriptor argument locals, `call(descriptor); drop`, and `unreachable` before the stack-carried-effect skip.
- `src/passes/optimize_instructions_test.mbt`
  - Adds red-first public-pipeline coverage for `optimize-instructions folds descriptor casts with four-arg call exact descriptor misses`, including an AST-level check for local/local/local/local/call/drop order.

## Boundaries

This slice is deliberately narrow. It does **not** claim parity for:

- calls with non-local, effectful, trapping, or multivalue arguments;
- calls with more than four arguments or mixed arities;
- `call_indirect`, `call_ref`, `return_call*`, or multivalue call producers;
- descriptor operands with escaping control, EH, branch payloads, or nested control not represented by the direct-call shape;
- nullable descriptor null-only casts;
- TNH/IIT-specific behavior for the parameterized-call shape;
- `ref.test_desc` or descriptor BrOn forms, which remain tooling/representation boundaries until representation and oracle support are added.

## Validation

Focused validation initially failed red-first with a residual `ref.cast_desc_eq` in the public optimized function:

```sh
moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with four-arg call exact descriptor misses'
```

After implementation, the same focused test passed `1/1` with pre-existing warnings.

Final validation:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-both-call-four-args-base-on-subtype.wat` passed.
- `wasm-opt --all-features --optimize-instructions -S .tmp/oi-j-next-probes/desc-both-call-four-args-base-on-subtype.wat` produced the Binaryen-shaped ordered local/local/local/local/call/drop/unreachable output with no residual `ref.cast_desc_eq`.
- Focused `moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with four-arg call exact descriptor misses'` passed `1/1` after implementation with pre-existing warnings.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test` passed `7654/7654`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Starshine probe replay with `_build/native/release/build/cmd/cmd.exe --optimize-instructions` produced validating wasm that prints `local.get $a; local.get $b; local.get $c; local.get $d; call $make_ref; drop; local.get $e; local.get $f; local.get $g; local.get $h; call $make_desc; drop; unreachable` and no residual `ref.cast_desc_eq`. The command also printed a pre-existing `wat2wasm` fallback warning while still producing the requested wasm.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass optimize-instructions --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/oi-j-four-arg-call-descriptor-miss-genvalid-10000-20260705` compared `10000/10000`, normalized `10000`, and reported zero validation/property/generator/command failures and zero mismatches with Binaryen cache `10000/0`.
