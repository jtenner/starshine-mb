---
title: OptimizeInstructions OI-D signed zero-lhs constant relational coverage
date: 2026-06-26
kind: research
status: supported
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/index.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OptimizeInstructions OI-D signed zero-lhs constant relational coverage

## Summary

This slice records a narrow `version_130` `OptimizeInstructions` signed relational constant-pair subfamily: when the left operand is literal zero and the right operand is a signed integer constant, Binaryen folds the signed relational compare to `i32.const 0/1`.

This is coverage/status evidence, not a new implementation slice. Starshine already matched the probed subfamily through existing compare-to-zero / constant canonicalization machinery. The test keeps this subfamily explicit without generalizing to all signed relational constant pairs, because nearby non-zero signed constant pairs still show mixed Binaryen keep/canonicalize behavior.

## Oracle evidence

Local probes:

- `.tmp/oi-d-signed-zero-rel-probe.wat`
- `.tmp/oi-d-signed-zero-equal-probe.wat`

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-zero-rel-probe.wat -o -
wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-signed-zero-equal-probe.wat -o -
```

Observed Binaryen behavior:

- `0 <_s 5`, `0 <=_s 5` fold to `i32.const 1`.
- `0 >_s 5`, `0 >=_s 5` fold to `i32.const 0`.
- `0 <_s -5`, `0 <=_s -5` fold to `i32.const 0`.
- `0 >_s -5`, `0 >=_s -5` fold to `i32.const 1`.
- `0 <_s 0`, `0 <=_s 0`, `0 >_s 0`, and `0 >=_s 0` fold to the mathematically expected constants.

## Starshine coverage

Added public HOT coverage in `src/passes/optimize_instructions_test.mbt`:

- `optimize-instructions folds signed zero-lhs constant relational compares`

The test covers representative i32 and i64 positive/negative right-hand constants and asserts a folded `i32.const` result. It passed before implementation changes, so no source change was needed.

## Boundary

Do not infer full signed relational constant-pair parity from this slice. The neighboring probe `.tmp/oi-d-signed-rel-probe2.wat` still shows Binaryen's mixed behavior for non-zero pairs, including unsigned spelling rewrites, compare-to-zero canonicalization, and kept signed compares.
