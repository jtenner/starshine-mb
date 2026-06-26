---
kind: research
status: supported
date: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions.mbt
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-D i64.extend_i32_u maxBits coverage

## Question

Can Starshine use Binaryen-style unsigned range facts through `i64.extend_i32_u` for the narrow OI-D maxBits compare surface?

## Evidence

Probe: `.tmp/oi-d-i64-extend-i32-u-maxbits-probe.wat`

```wat
(module
  (memory 1)
  (func $source (param $p i32) (result i32)
    (i64.lt_s
      (i64.extend_i32_u (local.get $p))
      (i64.const -1)))
  (func $effect (result i32)
    (i64.ge_s
      (i64.extend_i32_u
        (i32.load8_u (i32.const 0)))
      (i64.const 0))))
```

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-extend-i32-u-maxbits-probe.wat -o -
```

Binaryen `version_130` folds the pure `i64.extend_i32_u(local.get)` `<_s -1` comparison to `i32.const 0`. The load case is additionally affected by Binaryen's load-extension rewrite, so this slice uses it only as a source-backed reminder that the unsigned extension is a nonnegative producer; the implemented Starshine test focuses on pure extension and signed-spelling rewrite behavior.

## Starshine coverage

Added red-first coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds i64.extend_i32_u unsigned maxBits compares`

The focused test failed before implementation because Starshine kept `i64.lt_s` over `i64.extend_i32_u`. The implementation extends the unsigned maxBits fact helper so `i64.extend_i32_u` produces a conservative `u32::MAX` upper bound and also propagates narrower i32 unsigned facts when present. Existing maxBits compare folding then folds out-of-range signed/unsigned comparisons or rewrites nonnegative signed comparisons to unsigned spelling.

## Classification

Parity implementation slice. This narrows OI-D maxBits producer coverage for `i64.extend_i32_u` without changing dynamic shift boundaries or the mixed signed-constant relational rules.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i64-extend-i32-u-maxbits-probe.wat -o -` passed and showed the pure extension comparison folding to `i32.const 0`.
- Red-first focused `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i64.extend_i32_u unsigned maxBits*'` failed before implementation, then passed `1/1` after implementation.
