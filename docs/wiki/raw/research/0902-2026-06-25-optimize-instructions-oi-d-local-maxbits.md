# Optimize Instructions OI-D Local MaxBits Facts

Date: 2026-06-25

## Question

Does Binaryen `version_130` carry simple `Bits::getMaxBits`-style facts through straight-line locals for `optimize-instructions`, and should Starshine cover a narrow local-scanner subset?

## Oracle probe

Probe: `.tmp/oi-d-maxbits-local-probe.wat`

```wat
(module
  (func (export "local_and") (param i32) (result i32)
    (local i32)
    local.get 0
    i32.const 255
    i32.and
    local.set 1
    local.get 1
    i32.const 256
    i32.lt_u)
  (func (export "local_shr_spelling") (param i64) (result i32)
    (local i64)
    local.get 0
    i64.const 8
    i64.shr_u
    local.set 1
    local.get 1
    i64.const 42
    i64.ge_s))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-maxbits-local-probe.wat -o -
```

Observed Binaryen output:

- `local_and` keeps the local write of `(i32.and (local.get 0) (i32.const 255))` and folds the later `i32.lt_u(local.get 1, 256)` to `i32.const 1`.
- `local_shr_spelling` keeps the local write of `(i64.shr_u (local.get 0) (i64.const 8))` and rewrites the later `i64.ge_s(local.get 1, 42)` spelling to `i64.ge_u`.

## Starshine slice

Implemented a narrow straight-line unsigned max local fact scan in `src/passes/optimize_instructions.mbt`:

- non-param integer locals start with the zero-value max fact;
- direct `local.set` / `local.tee` roots update i32/i64 local max facts when the assigned expression is a covered direct fact producer;
- `local.get` nodes receive the current fact in per-node scratch arrays;
- covered fact producers are deliberately the same local subset already used by direct compare folds: nonnegative constants, `and` with nonnegative masks, positive constant `shr_u`, nested covered producers, and unsigned loads;
- structured control invalidates facts conservatively rather than attempting CFG/phi/select reasoning.

Added focused public-pipeline coverage in `src/passes/optimize_instructions_test.mbt` with `optimize-instructions folds local unsigned maxBits compares`. The assertion initially exposed the behavior gap before implementation in the local development loop: Starshine kept the local-carried compare before this slice. The final focused run passed after implementation.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-maxbits-local-probe.wat -o -` passed and showed the local maxBits fold/spelling rewrite described above.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*local unsigned maxBits compares*'` passed `1/1` after implementation.

Full required slice validation is recorded in the commit that cites this note.

## Remaining work

This is not full Binaryen `LocalScanner` parity. Remaining OI-D/maxBits gaps include CFG/phi/select facts, dynamic/zero shifts, broader producer families, signed range facts beyond the existing direct nonnegative subset, and interaction with broader local-scanner fact invalidation across control/effects.
