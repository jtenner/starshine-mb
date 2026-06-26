---
kind: research
status: supported
created: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../../src/passes/optimize_instructions_test.mbt
related:
  - ../../binaryen/passes/optimize-instructions/index.md
  - ../../binaryen/passes/optimize-instructions/starshine-strategy.md
---

# Optimize-instructions OI-G size-39 bulk-memory boundary

## Question

Extend the tiny bulk-memory exact-lowering boundary by one adjacent size after the size-38 probe. The goal is to record what Binaryen does for this exact size, not to infer a broad large-size policy.

## Binaryen oracle

Probe file: `.tmp/oi-g-memory-copy-size39-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size39-probe.wat -o .tmp/oi-g-memory-copy-size39-probe.out.wat
```

Observed behavior:

- Binaryen keeps the size-39 `memory.copy`.
- Binaryen keeps the size-39 `memory.fill`.
- Binaryen does not synthesize scalar or SIMD load/store lanes for this probed size.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions keeps size-39 bulk-memory outside exact lowering boundary`

The test asserts Starshine keeps `memory.copy` and `memory.fill`, and does not introduce `i32`, `i64`, or `v128` load/store operations. This is boundary/status coverage only. It extends the adjacent keep-spelling ladder by one exact size without changing implementation behavior.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size39-probe.wat -o .tmp/oi-g-memory-copy-size39-probe.out.wat` passed and kept both bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-39 bulk-memory*'` passed `1/1`.

## Remaining work

OI-G still needs broader memory/load-store parity work, especially load/store canonicalization and raw-gate escapes. This note only records the probed size-39 keep-spelling boundary and must not be generalized beyond fresh oracle/source evidence.
