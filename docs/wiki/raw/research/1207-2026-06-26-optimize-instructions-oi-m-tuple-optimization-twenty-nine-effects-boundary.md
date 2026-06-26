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

# Optimize-instructions OI-M tuple-optimization twenty-nine-effect boundary

## Question

Extend the public `optimize-instructions` + `tuple-optimization` neighbor boundary by one more non-selected result lane. The probe uses a public multivalue block that returns the selected `i32` parameter followed by twenty-nine non-selected `i32` call results, then drops every non-selected result.

## Binaryen oracle

Probe file: `.tmp/oi-m-tuple-optimization-twenty-nine-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-nine-effects-probe.wat -o -
```

Observed behavior:

- Binaryen accepts the public multivalue fixture.
- Binaryen localizes the block through `tuple.make 30` plus tuple/scalar scratch-local traffic.
- The non-selected calls remain effect-preserved.

## Starshine coverage

Added focused boundary/status test:

- `optimize-instructions intentionally keeps public multivalue block with twenty-nine later effects through tuple-optimization boundary`

The test asserts the current Starshine public WAT pipeline keeps the block/drop/call/local.get spelling and does not introduce temp `local.set` traffic. This is not tuple-optimization parity; it is explicit boundary evidence until tuple-scratch reconstruction/localization exists locally.

## Validation

- `wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-twenty-nine-effects-probe.wat -o -` passed and localized through `tuple.make 30` plus scratch locals.
- `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*twenty-nine later effects through tuple-optimization*'` passed `1/1`.

## Remaining work

OI-M remains incomplete. Multi-result selected/sibling tuple-scratch localization and broader `tuple-optimization` / `simplify-locals` neighbor parity are still open.
