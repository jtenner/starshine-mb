---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-signext-lowering-current-main-recheck.md
  - ../binaryen/2026-04-26-signext-lowering-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-signext-lowering-implementation-test-map-source-correction.md
  - ../binaryen/2026-04-25-signext-lowering-primary-sources.md
  - ../../binaryen/passes/signext-lowering/index.md
  - ../../binaryen/passes/signext-lowering/binaryen-strategy.md
  - ../../binaryen/passes/signext-lowering/implementation-structure-and-tests.md
  - ../../binaryen/passes/signext-lowering/wat-shapes.md
  - ../../binaryen/passes/signext-lowering/starshine-strategy.md
  - ../../binaryen/passes/signext-lowering/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/lib/show.mbt
---

# `signext-lowering` current-main refresh

## Why this follow-up exists

The `signext-lowering` dossier was already source-correct and teaching-complete, but its freshness layer was still anchored to a 2026-04-26 current-main check.
This follow-up records the 2026-05-05 source refresh and updates the living pages so the current-main bridge is visible from the canonical overview, strategy, implementation, and Starshine planning pages.

## Primary source rechecked

The refreshed source manifest rechecked official Binaryen current-main sources for:

- `src/passes/SignExtLowering.cpp`
- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/lit/passes/signext-lowering.wast`

The review did not surface teaching-relevant drift from the existing contract.
The same five-opcode, shift-pair, feature-disable model still stands.

## Durable update

The living dossier pages now point at the 2026-05-05 bridge so future maintainers can see that the pass was rechecked after the earlier 2026-04-26 planning wave.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Supersession note

This note extends the earlier 2026-04-26 `signext-lowering` source notes.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
