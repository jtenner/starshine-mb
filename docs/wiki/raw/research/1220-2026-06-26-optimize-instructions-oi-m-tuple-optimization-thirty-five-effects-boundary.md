---
kind: research
status: supported
last_reviewed: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M tuple-optimization thirty-five-effect boundary

## Question

For a public `optimize-instructions` plus `tuple-optimization` multivalue block with one selected lane and thirty-five later non-selected effects, does Binaryen continue localizing through tuple scratch, and what should Starshine claim today?

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-thirty-five-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-thirty-five-effects-probe.wat -o .tmp/oi-m-tuple-optimization-thirty-five-effects-probe.out.wat
```

Result: Binaryen accepts the probe and localizes through `tuple.make 36` plus tuple/scalar scratch-local traffic. This extends the public effect-count ladder by one adjacent case.

## Starshine status

Starshine still keeps the public multivalue block/drop/call/local.get spelling and does not synthesize the Binaryen tuple scratch/local traffic. Added boundary/status coverage:

- `optimize-instructions intentionally keeps public multivalue block with thirty-five later effects through tuple-optimization boundary`

This is intentionally a boundary/status slice, not an implementation slice. The retained mismatch is the same tuple-scratch reconstruction/localization gap as the prior public `tuple-optimization` effect-count probes.

## Validation

- Binaryen oracle command above passed and showed `tuple.make 36` plus local traffic.
- Focused Starshine coverage: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*thirty-five later effects through tuple-optimization*'` passed `1/1`.

## Remaining work

Do not infer tuple-optimization parity or a general effect-count limit from this note. OI-M still needs tuple-scratch reconstruction/localization, direct-HOT or parser support for tuple text shapes, and broader multi-result sibling/selected-lane parity.
