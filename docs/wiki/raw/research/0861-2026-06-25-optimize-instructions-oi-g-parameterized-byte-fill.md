# Optimize-instructions OI-G parameterized byte memory.fill

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-G]` implementation coverage for source-backed stack-carried size-1 `memory.fill` raw-gate escapes with one-argument direct-call destination/value operands.

## Question

Starshine already lowered flat byte `memory.fill` forms when destination and value operands were pure local/constants or no-param direct calls. Does Binaryen also lower the adjacent parameterized direct-call shape, and can Starshine safely let that exact byte-fill pattern reach the existing HOT lowering while keeping wider call-backed fills documented as boundaries?

## Binaryen oracle

Probe file: `.tmp/oi-g-parameterized-byte-fill-probe.wat`

```wat
(module
  (memory 1)
  (func $dst1 (param i32) (result i32) local.get 0)
  (func $val1 (param i32) (result i32) local.get 0)
  (func $dst0 (result i32) i32.const 32)
  (func $val0 (result i32) i32.const 255)
  (func (param $d i32) (param $v i32)
    local.get $d
    call $dst1
    local.get $v
    call $val1
    i32.const 1
    memory.fill
    call $dst0
    local.get $v
    call $val1
    i32.const 1
    memory.fill))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-parameterized-byte-fill-probe.wat -o -
```

Result: Binaryen `version_130` lowered both size-1 fills to `i32.store8`, preserving the destination expression before the value expression. The probe complements the existing source-backed wider-fill boundary: Binaryen keeps direct-call and computed values for size `2`/`4`/`8`, but lowers byte fills.

## Starshine change

Added red-first public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands stack-carried parameterized byte memory.fill`

Before the implementation, the focused test failed with `stack-carried-effect-optimize-instructions-noop`. `run_hot_pipeline_optimize_instructions_is_byte_stack_memory_fill(...)` now uses the same independently parsed operand matcher as tiny `memory.copy`: each destination/value operand may be a pure local/constant, a no-param one-result direct call, or a pure local/constant argument followed by a one-param one-result direct call. The shape must remain flat, use constant size `1`, end in `memory.fill`, and contain a direct call before it escapes the raw stack-effect skip. The existing HOT `optimize_instructions_try_expand_tiny_memory_fill(...)` then emits `i32.store8`.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-parameterized-byte-fill-probe.wat -o -` passed and lowered both byte fills.
- Red-first: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*parameterized byte memory.fill*'` failed before implementation with `stack-carried-effect-optimize-instructions-noop`.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*parameterized byte memory.fill*'` passed `1/1`.
- Regression-focused: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*memory.fill*'` passed `13/13`.

## Remaining work

This is not broad `memory.fill` materialization. Wider call-backed or computed fills remain source-backed keep-spelling boundaries under Binaryen `version_130`; zero-size fill cleanup remains blocked on trap-relaxed/TNH/IIT-equivalent support; non-flat/control-bearing and temp-localizing fill forms remain open until separately proven.
