# Optimize-instructions OI-G mixed parameterized tiny memory.copy

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-G]` implementation coverage for a mixed stack-carried tiny `memory.copy` raw-gate escape.

## Question

The prior parameterized-copy slice admitted repeated tiny `memory.copy` instructions only when both address operands used the exact `pure local/constant; one-param direct call` spelling. Does Binaryen also lower mixed address operands where one side is a unary direct call and the other side is a no-param direct call or pure operand, and can Starshine admit that exact shape without claiming broad stack localization?

## Binaryen oracle

Probe file: `.tmp/oi-g-mixed-parameterized-memory-copy-probe.wat`

```wat
(module
  (memory 1)
  (func $dst1 (param i32) (result i32) local.get 0)
  (func $src0 (result i32) i32.const 16)
  (func $dst0 (result i32) i32.const 32)
  (func $src1 (param i32) (result i32) local.get 0)
  (func (param $d i32) (param $s i32)
    local.get $d
    call $dst1
    call $src0
    i32.const 1
    memory.copy
    call $dst0
    local.get $s
    call $src1
    i32.const 8
    memory.copy))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-mixed-parameterized-memory-copy-probe.wat -o -
```

Result: Binaryen `version_130` lowered both mixed tiny copies. The size-1 copy became a `store8(load8_u(...))` pair, and the size-8 copy became an `i64.store(i64.load(...))` pair. In both cases the store-address expression remains evaluated before the nested source load, preserving the original destination-before-source order.

## Starshine change

Added red-first public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands stack-carried mixed parameterized tiny memory.copy`

Before the implementation, the focused test failed with `stack-carried-effect-optimize-instructions-noop`. The raw OI pre-lift gate now parses each tiny-copy address operand independently as either:

- a pure local/constant or no-param one-result direct call operand, or
- a pure local/constant argument followed by a one-param one-result direct call.

The matched sequence must still be flat, end in a constant tiny size `1` / `2` / `4` / `8` and `memory.copy`, and contain a direct call before it escapes the raw `stack-carried-effect` skip. The existing HOT tiny-copy lowering performs the actual load/store rewrite.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-mixed-parameterized-memory-copy-probe.wat -o -` passed and lowered both mixed copies.
- Red-first: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*mixed parameterized tiny memory.copy*'` failed before implementation with `stack-carried-effect-optimize-instructions-noop`.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*mixed parameterized tiny memory.copy*'` passed `1/1`.
- Regression-focused: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*tiny memory.copy*'` passed `5/5`.

## Remaining work

This is still a narrow raw-gate escape. Broader stack-carried/localizing `memory.copy` forms remain open, including multi-parameter calls, non-pure call arguments, control-bearing operands, nonconstant sizes, mixed forms that require temp locals rather than direct HOT lifting, and any future overlap-safe multi-store copy lowering beyond exact sizes `1`/`2`/`4`/`8`.
