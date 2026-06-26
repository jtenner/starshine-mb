---
kind: research
status: supported
last_reviewed: 2026-06-26
sources:
  - ../../binaryen/2026-06-19-optimize-instructions-version-130-source-refresh.md
  - ../../../binaryen/passes/optimize-instructions/starshine-strategy.md
  - ../../../../../src/passes/optimize_instructions_test.mbt
---

# OI-M tuple-optimization forty-seven-effect boundary

## Question

What happens for the next public `optimize-instructions` plus `tuple-optimization` multivalue-block neighbor when the selected lane is followed by forty-seven later non-selected effectful results?

## Oracle

Probe: `.tmp/oi-m-tuple-optimization-forty-seven-effects-probe.wat`.

Command:

```sh
wasm-opt --all-features -S --optimize-instructions --tuple-optimization .tmp/oi-m-tuple-optimization-forty-seven-effects-probe.wat -o .tmp/oi-m-tuple-optimization-forty-seven-effects-probe.out.wat
```

Result: Binaryen `version_130` accepts the public multivalue WAT and localizes the shape through `tuple.make 48` plus tuple/scalar scratch local traffic. The emitted text includes `tuple.make 48`, the forty-seven `call $side_N` effects, and scratch `local.set` / `local.get` operations while preserving the selected first lane.

## Starshine boundary

This is boundary/status coverage only, not a parity implementation. The focused public-pipeline test
`optimize-instructions intentionally keeps public multivalue block with forty-seven later effects through tuple-optimization boundary`
uses the shared generated fixture and asserts that Starshine still keeps the public `block` / `drop` / `call` / `local.get` spelling and does not introduce tuple-scratch `local.set` traffic.

The retained mismatch is the same tuple-scratch reconstruction/localization gap as the earlier public `tuple-optimization` ladder. It is not classified as a Starshine win or semantic closure.

## Validation

- Binaryen oracle command above passed and produced `tuple.make 48` plus tuple/scalar scratch locals.
- Focused Starshine boundary test: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*forty-seven later effects through tuple-optimization*'` passed `1/1`.

## Remaining work

This extends OI-M public neighbor coverage only. Broader tuple extraction parity still needs tuple-scratch reconstruction/localization for public multivalue blocks, multi-result selected/sibling cases, and the existing direct-HOT full-simplify `InvalidChildRef` blocker before OI-M can close.
