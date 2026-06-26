# OptimizeInstructions OI-D shift/rotate mask coverage

Date: 2026-06-25

## Question

Does Starshine `optimize-instructions` already match Binaryen `version_130` for constant shift/rotate amounts whose effective WebAssembly amount is obtained by masking the right-hand operand (`31` for i32, `63` for i64)?

## Binaryen oracle

Probe file: `.tmp/oi-d-shift-mask-probe.wat` and `.tmp/oi-d-rot-mask-probe.wat`.

Commands:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-shift-mask-probe.wat -o -
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-rot-mask-probe.wat -o -
```

Findings:

- `i32.shl(x, 32)` and `i64.shl(x, 64)` are reduced to the original local value.
- `i32.shr_u(x, 63)` and `i32.shr_s(x, -1)` are canonicalized to shift amount `31`.
- `i64.shr_u(x, 127)` is canonicalized to shift amount `63`.
- `i32.rotl(x, 32)` and `i64.rotl(x, 64)` are reduced to the original local value.
- `i32.rotr(x, 63)` and `i64.rotr(x, 127)` are canonicalized to rotate amount `31` / `63`.

## Starshine result

Added focused public-pipeline coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions canonicalizes masked constant shift amounts`

The test is status/coverage, not red-first implementation work: the current pass already rewrites these shapes through existing constant-fold/identity machinery. The fixture prevents future regressions and documents that this part of OI-D is already covered before broader `maxBits` scanner work continues.

## Validation

- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*masked constant shift*'` passed `1/1`.

## Remaining work

This does not close OI-D. Remaining scalar work still includes broader source-backed `maxBits` scanner behavior for masks and comparisons, additional safe producer facts if Binaryen proves them, and keeping dynamic shift amount boundaries narrow unless source/oracle evidence proves widening.
