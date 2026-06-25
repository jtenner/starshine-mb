# Optimize Instructions OI-D Dynamic Shift MaxBits Boundary

Date: 2026-06-25

## Question

Does Binaryen `version_130` fold unsigned maxBits comparisons through a dynamic `shr_u` amount when the shifted value already has a known small range?

## Oracle probe

Probe: `.tmp/oi-d-dynamic-shr-maxbits-boundary-probe.wat`

```wat
(module
  (func (export "dynamic") (param $x i32) (param $s i32) (result i32)
    local.get $x
    i32.const 255
    i32.and
    local.get $s
    i32.shr_u
    i32.const 256
    i32.lt_u)
  (func (export "zero") (param $x i32) (result i32)
    local.get $x
    i32.const 255
    i32.and
    i32.const 0
    i32.shr_u
    i32.const 256
    i32.lt_u))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-dynamic-shr-maxbits-boundary-probe.wat -o -
```

Observed Binaryen output:

- The dynamic shift amount shape stays as `i32.lt_u(i32.shr_u(i32.and(local.get x, 255), local.get s), 256)`.
- The constant-zero shift amount shape folds to `i32.const 1`, apparently after the normal zero-shift identity path exposes the masked maxBits proof.

## Starshine slice

Added boundary/status coverage in `src/passes/optimize_instructions_test.mbt` with `optimize-instructions keeps dynamic unsigned-shift masked maxBits boundary`. The test asserts that Starshine keeps the dynamic-shift compare and the `i32.shr_u` child rather than generalizing the covered constant-shift maxBits proof.

This is not a red-first implementation slice; it is a source-backed OI-D boundary classification. Although WebAssembly masks i32 shift amounts modulo 32 and the dynamic shape could be proven smaller-range with additional reasoning, this slice intentionally matches Binaryen's observed `version_130` behavior until dynamic-shift range reasoning is deliberately implemented and justified as a Starshine win.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-dynamic-shr-maxbits-boundary-probe.wat -o -` passed and showed the dynamic/zero split described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*dynamic unsigned-shift masked maxBits boundary*'` passed `1/1`.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

Dynamic-shift range reasoning remains open. If a future slice treats dynamic `shr_u` over already-bounded nonnegative values as a Starshine-win fold, it should add explicit semantic proof, size/performance evidence, and focused effect-preservation coverage rather than silently widening the current constant-shift-only Binaryen parity surface.
