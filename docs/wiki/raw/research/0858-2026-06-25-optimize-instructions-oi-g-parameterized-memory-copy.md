# Optimize-instructions OI-G parameterized tiny memory.copy

Date: 2026-06-25

## Slice

`[O4Z-AUDIT-OI-G]` implementation coverage for one additional source-backed stack-carried tiny `memory.copy` raw-gate escape.

## Question

The 2026-06-24 OI-G stack-carried tiny-copy slice admitted flat `memory.copy` forms whose destination and source were pure local/constant operands or no-parameter direct calls. Does Binaryen also lower the adjacent shape where each address operand is a direct call with one pure stack argument, and can Starshine safely let that exact pattern reach the existing HOT tiny-copy lowering?

## Binaryen oracle

Probe file: `.tmp/oi-g-parameterized-memory-copy-probe.wat`

```wat
(module
  (memory 1)
  (func $dst (param i32) (result i32) local.get 0)
  (func $src (param i32) (result i32) local.get 0)
  (func (param $d i32) (param $s i32)
    local.get $d
    call $dst
    local.get $s
    call $src
    i32.const 1
    memory.copy
    local.get $d
    call $dst
    local.get $s
    call $src
    i32.const 8
    memory.copy))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-parameterized-memory-copy-probe.wat -o -
```

Result: Binaryen `version_130` lowered both parameterized-call tiny copies: size `1` became `i32.store8(call $dst(local.get $d), i32.load8_u(call $src(local.get $s)))`, and size `8` became `i64.store align=1(call $dst(...), i64.load align=1(call $src(...)))`. The rewritten store-address child still evaluates before the nested load, preserving the original destination-call-before-source-call order.

## Starshine change

Added red-first public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions expands stack-carried parameterized tiny memory.copy`

Before the implementation, the focused test failed with `stack-carried-effect-optimize-instructions-noop`. The raw OI pre-lift gate now admits the exact repeated six-instruction shape:

1. pure local/constant argument,
2. direct call with one parameter and one result,
3. pure local/constant argument,
4. direct call with one parameter and one result,
5. constant tiny size `1` / `2` / `4` / `8`,
6. `memory.copy`.

The existing HOT `optimize_instructions_try_expand_tiny_memory_copy(...)` lowering then performs the load/store rewrite. This is intentionally not a general stack localizer: mixed pure/no-param/unary-call operands, multi-parameter calls, control-bearing calls, nonconstant sizes, and wider multi-store copies remain outside this escape until separately proven.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-parameterized-memory-copy-probe.wat -o -` passed and lowered both copies.
- Red-first: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*parameterized tiny memory.copy*'` failed before implementation with `stack-carried-effect-optimize-instructions-noop`.
- After implementation, `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*parameterized tiny memory.copy*'` passed `1/1`.

## Remaining work

The raw-gate escape is deliberately narrow. Broader stack-carried/localizing `memory.copy` families remain open, including mixed operand forms, calls with multiple parameters, non-pure call arguments, control-bearing operands, nonconstant sizes, and any future multi-store lowering beyond exact sizes `1`/`2`/`4`/`8`.
