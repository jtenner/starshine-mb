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

# Optimize-instructions OI-M tuple-optimization thirty-three-effect boundary

## Question

Extend the public `optimize-instructions` plus `tuple-optimization` multivalue neighbor boundary by one later non-selected effect after the thirty-two-effect probe. The goal is to keep the tuple-scratch localization gap explicitly measured, not to claim closure for OI-M.

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-thirty-three-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-thirty-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-thirty-three-effects-probe.out.wat
```

Observed behavior:

- Binaryen succeeds on the 34-result public multivalue block.
- Binaryen materializes the block results through `tuple.make 34`.
- Binaryen introduces tuple scratch plus scalar scratch locals to preserve and drop the later non-selected effects while returning the selected value.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions intentionally keeps public multivalue block with thirty-three later effects through tuple-optimization boundary`

The test uses a generated public WAT fixture for the thirty-three-effect shape, then asserts Starshine keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce `local.set` traffic. This is boundary/status coverage only. The retained mismatch remains a tuple-scratch reconstruction/localization gap shared with the preceding public effect-count ladder.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-thirty-three-effects-probe.wat -o .tmp/oi-m-tuple-optimization-thirty-three-effects-probe.out.wat` passed and produced `tuple.make 34` plus tuple/scalar scratch locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*thirty-three later effects through tuple-optimization*'` passed `1/1`.

## Remaining work

OI-M still needs implementation work for tuple-scratch reconstruction/localization, multi-result selected children and non-selected siblings, multi-use tuple proofs where safe, and broader neighbor interactions with dedicated `tuple-optimization` / `simplify-locals` lanes. This note only records the probed thirty-three-effect public boundary.
