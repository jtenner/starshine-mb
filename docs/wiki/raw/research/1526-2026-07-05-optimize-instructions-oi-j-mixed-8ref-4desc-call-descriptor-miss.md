# OptimizeInstructions OI-J mixed 8-ref/4-desc call descriptor miss

## Summary

Binaryen `version_130` folds the exact descriptor-cast miss where the reference operand is a direct call with 8 pure local arguments and the descriptor operand is a direct call with 4 pure local arguments. The optimized shape preserves all argument evaluation and both direct calls in source order, drops both call results, and then emits `unreachable`:

```wat
local.get x8
call $make_ref
drop
local.get x4
call $make_desc
drop
unreachable
```

Starshine now covers this narrow 8-reference-argument / 4-descriptor-argument pure-local direct-call default-mode slice in the public raw dispatcher. This continues the mixed-eight reference-argument descent after `(8,5)` and does not prove arbitrary arity, other mixed eight-argument arities, broader arities above eight, or non-local/effectful call arguments.

## Probe evidence

Local probe: `.tmp/oi-j-next-probes/desc-mixed-8ref-4desc-call-base-on-subtype.wat`.

- `wasm-tools validate --features all` accepted the input.
- `wasm-opt --version` reported `wasm-opt version 130 (version_130)`.
- `wasm-opt --all-features --optimize-instructions -S` rewrote `$cast` to ordered `local.get` x8; `call $make_ref`; `drop`; `local.get` x4; `call $make_desc`; `drop`; `unreachable` and removed `ref.cast_desc_eq`.
- The operand order is reference arguments/call first, then descriptor arguments/call, matching the original stack order and preserving both calls' global writes before the descriptor-cast trap.

## Implementation

- `src/passes/pass_manager.mbt` extends the explicit raw pure-local direct-call descriptor-miss arity predicate to the probed `(8,4)` shape only.
- `src/passes/optimize_instructions_test.mbt` adds red-first public-pipeline coverage for `optimize-instructions folds descriptor casts with mixed 8-ref 4-desc call exact descriptor misses`, using the shared direct-call descriptor-miss fixture and asserting the ordered call/drop/unreachable body.

## Boundaries

This slice is deliberately narrow. It does **not** claim parity for arbitrary arity direct calls, other mixed eight-argument arities, broader arities above eight, non-local/effectful/trapping/multivalue call arguments, indirect/call_ref/return_call* producers, escaping control/EH descriptor operands, nullable descriptor null-only casts, TNH/IIT call-produced behavior, `ref.test_desc`, or descriptor BrOn forms.

## Validation

Focused validation initially failed red-first with a residual `ref.cast_desc_eq` in the public optimized function:

```sh
moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with mixed 8-ref 4-desc call exact descriptor misses'
```

After implementation, the same focused test passed `1/1` with pre-existing warnings.

Final validation:

- `wasm-tools validate --features all .tmp/oi-j-next-probes/desc-mixed-8ref-4desc-call-base-on-subtype.wat` passed.
- `wasm-opt --all-features --optimize-instructions -S .tmp/oi-j-next-probes/desc-mixed-8ref-4desc-call-base-on-subtype.wat` produced the Binaryen-shaped ordered 8-ref-arg call/drop plus 4-desc-arg call/drop/unreachable output with no residual `ref.cast_desc_eq`.
- Focused `moon test src/passes --target native --filter 'optimize-instructions folds descriptor casts with mixed 8-ref 4-desc call exact descriptor misses'` passed `1/1` after implementation with pre-existing warnings.
- `moon fmt` passed.
- `moon info` passed with pre-existing warnings.
- `moon test` passed `7716/7716`.
- `moon build --target native --release src/cmd` passed with pre-existing warnings.
- Starshine probe replay with `_build/native/release/build/cmd/cmd.exe --format wat --optimize-instructions` produced validating wasm with no residual `ref.cast_desc_eq` after `wasm-tools print` inspection. The CLI printed the pre-existing WAT-input fallback parser warning for the `(rec ...)` text form.
- `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass optimize-instructions --jobs auto --starshine-bin _build/native/release/build/cmd/cmd.exe --out-dir .tmp/oi-j-mixed-8ref-4desc-call-descriptor-miss-genvalid-10000-20260705` compared `10000/10000`, normalized `10000`, and reported zero validation/property/generator/command failures and zero mismatches with Binaryen cache `10000/0`.
