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

# Optimize-instructions OI-G size-37 bulk-memory boundary

## Question

Extend the exact constant-size bulk-memory boundary by one adjacent size after the size-36 probe. Starshine lowers only source-backed exact small sizes, so larger sizes need explicit oracle-backed status before any broad claim.

## Binaryen oracle

Probe file: `.tmp/oi-g-memory-copy-size37-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size37-probe.wat -o -
```

Observed behavior:

- Binaryen keeps size-37 `memory.copy`.
- Binaryen keeps size-37 `memory.fill`.
- It does not synthesize SIMD lanes, scalar lanes, or a SIMD-plus-tail lowering for this probe.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions keeps size-37 bulk-memory outside exact lowering boundary`

The test asserts Starshine keeps `memory.copy` / `memory.fill` and does not introduce scalar or SIMD load/store operations. This was not red-first implementation work; it documents the current exact-lowering boundary and must not be generalized beyond size 37 without fresh probes.

## Validation

- `wasm-opt --all-features -S --optimize-instructions .tmp/oi-g-memory-copy-size37-probe.wat -o -` passed and kept both bulk-memory operations.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*size-37 bulk-memory*'` passed `1/1`.

## Remaining work

OI-G still has broader memory/load-store parity gaps, including broader load/store canonicalization and raw-gate escapes. The exact bulk-memory lowering contract remains limited to the source-backed sizes already implemented and separately probed boundaries.
