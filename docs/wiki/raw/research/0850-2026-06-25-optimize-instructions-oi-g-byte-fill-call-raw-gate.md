# Optimize-instructions OI-G byte memory.fill call raw-gate

## Slice

Continue `[O4Z-AUDIT-OI-G]` by shrinking the stack-carried-effect raw gate for a source-backed `memory.fill` shape: flat byte fills whose destination/value operands are pure stack operands or no-param one-result direct calls.

## Binaryen oracle

Probe: `.tmp/oi-g-effectful-byte-fill-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-effectful-byte-fill-probe.wat -o -
```

Result: Binaryen `version_130` lowers both probed size-1 fills to `i32.store8`:

- `local.get $dst; call $get; i32.const 1; memory.fill` becomes `i32.store8(local.get $dst, call $get)`.
- `local.get $dst; local.get $value; i32.const 1; memory.fill` becomes `i32.store8(local.get $dst, local.get $value)`.

This differs from the wider non-local fill boundary in `0849`/earlier OI-G docs: size-2/4/8 call-backed or computed values stay as `memory.fill`, but size-1 has no repeated-byte materialization problem and is source-backed as a direct store8 lowering.

## Red-first evidence

Focused test added first:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*byte memory.fill with local and call values*'
```

Before implementation it failed because the public/raw pipeline returned the original function behind `stack-carried-effect-optimize-instructions-noop`, leaving both `memory.fill` instructions in place.

## Implementation

`src/passes/pass_manager.mbt` now admits the exact flat byte-fill stack form through the OI raw gate when every four-instruction group is:

1. destination: pure local/constant stack operand or no-param one-result direct call,
2. value: pure local/constant stack operand or no-param one-result direct call,
3. size: `i32.const 1` or `i64.const 1`,
4. `memory.fill`.

The helper intentionally requires at least one call so purely local/constant byte fills continue through the normal non-effect path. Non-byte sizes remain outside this escape; Binaryen keeps currently probed call-backed/computed wider fills.

The existing HOT `optimize_instructions_try_expand_tiny_memory_fill(...)` then rewrites size-1 `memory.fill` to `i32.store8`, preserving operand evaluation order.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-effectful-byte-fill-probe.wat -o -` passed and lowered both byte fills to `i32.store8`.
- Red-first focused test failed before implementation with retained `memory.fill` due to `stack-carried-effect-optimize-instructions-noop`.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*byte memory.fill with local and call values*'` passed `1/1`.

## Remaining OI-G risks

This slice only narrows the raw gate for flat size-1 fills. It does not change the source-backed keep-spelling boundary for non-local wider size-2/4/8 `memory.fill` values, zero-size trap-relaxed bulk-memory cleanup, nonconstant-size copies/fills, or broader stack-carried effect/localizing forms.
