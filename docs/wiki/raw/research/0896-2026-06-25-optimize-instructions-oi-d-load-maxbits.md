# OptimizeInstructions OI-D unsigned-load maxBits compare slice

Date: 2026-06-25

## Question

Does Binaryen `version_130` use unsigned load result widths as `maxBits` evidence for out-of-range unsigned/equality compares, and should Starshine's direct HOT `optimize-instructions` implementation cover the same narrow surface?

## Binaryen oracle

Probe: `.tmp/oi-d-load8u-maxbits-probe.wat`

```wat
(module
  (memory 1)
  (func $effect (result i32) (i32.const 0))
  (func (param $p i32) (result i32)
    (i32.eq
      (i32.load8_u (local.get $p))
      (i32.const 256)))
  (func (result i32)
    (i32.eq
      (i32.load16_u (call $effect))
      (i32.const 65536))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-load8u-maxbits-probe.wat -o -
```

Result: Binaryen rewrites both compares to `drop(load); i32.const 0`, preserving the trapping load and any address effects rather than deleting the left operand.

## Starshine change

Added a red-first focused test, `optimize-instructions folds unsigned load maxBits compares`, in `src/passes/optimize_instructions_test.mbt`. It initially failed because Starshine only propagated unsigned `maxBits` facts through direct `and` / `shr_u` binary expressions.

`src/passes/optimize_instructions.mbt` now treats unsigned load instructions as direct width facts for the existing compare folder:

- `i32.load8_u` => max `255`
- `i32.load16_u` => max `65535`
- `i64.load8_u` => max `255`
- `i64.load16_u` => max `65535`
- `i64.load32_u` => max `4294967295`

The existing replacement path preserves loads as `drop(load); i32.const result` when the loaded expression is not proven side-effect/trap-free.

## Scope and boundaries

This is a narrow OI-D scalar/maxBits extension. It does not claim Binaryen's full local scanner, signed range proofs, CFG/phi width facts, or broader load-store canonicalization. Signed loads and sign-ext relational folds remain governed by the existing sign-extension slices and boundaries.

## Validation

- Red-first focused test failed before implementation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*unsigned load maxBits*'`.
- After implementation, the same focused command passed `1/1`.
