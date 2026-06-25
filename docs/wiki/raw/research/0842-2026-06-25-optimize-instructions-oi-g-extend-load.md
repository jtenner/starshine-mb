# Optimize-instructions OI-G extend-load cleanup

## Question

Can Starshine match Binaryen `version_130` for direct `i64.extend_i32_*` wrappers around one-use i32 loads?

## Binaryen evidence

Probe: `.tmp/oi-g-extend-load-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-extend-load-probe.wat -o -
```

Binaryen rewrites:

- `i64.extend_i32_u(i32.load p)` to `i64.load32_u p`
- `i64.extend_i32_s(i32.load p)` to `i64.load32_s p`
- `i64.extend_i32_u(i32.load8_u p)` to `i64.load8_u p`
- `i64.extend_i32_s(i32.load8_s p)` to `i64.load8_s p`

A companion probe `.tmp/oi-g-extend-load-mixed-probe.wat` shows Binaryen also rewrites `i64.extend_i32_s(i32.load8_u p)` and `i64.extend_i32_s(i32.load16_u p)` to unsigned i64 narrow loads, while keeping the signed-i32-load plus unsigned-i64-extend direction because the signed 32-bit intermediate must be zero-extended to i64.

## Starshine change

`src/passes/optimize_instructions.mbt` now rewrites one-use load children under `i64.extend_i32_u` / `i64.extend_i32_s` to the matching i64 representation load when the loaded value semantics are identical:

- full `i32.load` + unsigned/signed i64 extend becomes `i64.load32_u` / `i64.load32_s`
- unsigned `i32.load8_u` / `i32.load16_u` becomes unsigned i64 narrow loads for either i64 extend opcode
- signed `i32.load8_s` / `i32.load16_s` becomes signed i64 narrow loads only for `i64.extend_i32_s`

The one-use guard mirrors the reinterpret-load slice: rewriting the parent into a new load consumes the original load node and must not duplicate a shared load effect.

## Tests and validation

Focused red-first evidence:

```sh
moon test --target native src/passes/optimize_instructions_test.mbt --filter '*extend_i32 loads*'
```

Before implementation the test failed with retained `i32.load ... i64.extend_i32u`. After implementation it passed `1/1`.

Broader validation for the committed slice is recorded in the commit body and wiki log.

## Remaining follow-ups

This narrows OI-G load-result cleanup but does not close broader shared-load canonicalization, additional `optimizeStoredValue` shapes, raw-gate escapes, zero-size trap-relaxed bulk-memory cleanup, or nonconstant pointer-add decisions.
