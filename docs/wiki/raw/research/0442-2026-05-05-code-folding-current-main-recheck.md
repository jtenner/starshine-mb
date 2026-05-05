---
kind: research
status: supported
last_reviewed: 2026-05-05
sources:
  - ../binaryen/2026-05-05-code-folding-current-main-recheck.md
  - ../binaryen/2026-04-25-code-folding-port-readiness-primary-sources.md
  - ../binaryen/2026-04-25-code-folding-current-main-recheck.md
  - ../binaryen/2026-04-22-code-folding-primary-sources.md
  - ../../binaryen/passes/code-folding/index.md
  - ../../binaryen/passes/code-folding/binaryen-strategy.md
  - ../../binaryen/passes/code-folding/implementation-structure-and-tests.md
  - ../../binaryen/passes/code-folding/terminating-tails.md
  - ../../binaryen/passes/code-folding/wat-shapes.md
  - ../../binaryen/passes/code-folding/starshine-strategy.md
  - ../../binaryen/passes/code-folding/starshine-port-readiness-and-validation.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/passes/pass_manager.mbt
  - ../../../../src/cli/cli_test.mbt
---

# `code-folding` current-main refresh

## Why this follow-up exists

The `code-folding` dossier was already source-correct and teaching-complete, but its freshness layer was still anchored to a 2026-04-25 current-main check.
This follow-up records the 2026-05-05 source refresh and updates the living pages so the current-main bridge is visible from the canonical overview, strategy, implementation, and Starshine planning pages.

## Primary source rechecked

The refreshed source manifest rechecked official Binaryen current-main sources for:

- `src/passes/CodeFolding.cpp`
- `src/passes/pass.cpp`
- `src/passes/opt-utils.h`
- `src/passes/passes.h`
- `test/lit/passes/code-folding.wast`

The review did not surface teaching-relevant drift from the existing contract.
The same two-family tail-sharing model still stands:

- expression-exit folding for named block exits and foldable `if` arms
- function-ending suffix sharing for `return`, `return_call*`, and `unreachable`

## Durable update

The living dossier pages now point at the 2026-05-05 bridge so future maintainers can see that the pass was rechecked after the earlier 2026-04-25 pass-planning wave.
No semantic retcon was required; this is a freshness and reference-hygiene update only.

## Supersession note

This note extends the earlier 2026-04-25 `code-folding` source notes.
It does not replace the earlier algorithm or implementation-test explanations, which remain the canonical detailed contract pages.
