---
kind: research
status: supported
created: 2026-06-20
sources:
  - ./0776-2026-06-20-heap-store-optimization-v130-source-refresh.md
  - ./0777-2026-06-20-heap-store-optimization-hso-b-direct-baseline.md
  - ./0789-2026-06-20-heap-store-optimization-core-chain-coverage.md
  - ./0848-2026-06-20-heap-store-optimization-tee-later-chain.md
  - ./0849-2026-06-20-heap-store-optimization-many-fields-pattern-breaker.md
  - ./0850-2026-06-20-heap-store-optimization-many-news-tee-barrier.md
  - ../../binaryen/passes/heap-store-optimization/index.md
  - ../../binaryen/passes/heap-store-optimization/implementation-structure-and-tests.md
  - ../../../../src/passes/heap_store_optimization.mbt
  - ../../../../src/passes/heap_store_optimization_test.mbt
---

# `heap-store-optimization` core-chain closeout

Question: can HSO-C, the core tee/subsequent-chain slice, be considered covered after the `$tee-and-subsequent`, `$many-fields`, `$pattern-breaker`, and `$many-news` follow-ups?

## Answer

Yes for the currently source-backed Binaryen `version_130` core-chain surface. HSO-C is now classified as behavior-parity covered, with no residual debris/output-shape family observed in the latest direct lane.

The covered core-chain families are:

- immediate `local.tee(struct.new*)` folds;
- tee folds that must continue scanning later `struct.set(local.get)` roots in the same chain;
- later `local.set(struct.new*)` plus `struct.set(local.get)` chains;
- repeated same-field stores where the last value wins in the constructor;
- wrong-target-local and local-copy pattern-breaker negatives;
- independent tee-root chains in `$many-fields` and `$many-news`, including inner-block independent tee chains.

The remaining HSO audit is not closed. HSO-D/E/F/G/H/I/J still own descriptor/default/old-field combinations, remaining target-local and moved-value hazards, broader control-flow/catch negatives, broader swap/effect variants, explicit non-goal wording, allocation-heavy performance evidence, and final pass closeout.

## Debris/output-shape classification

The relevant recent direct lanes did not expose residual HSO-C output drift:

- `0777` fresh baseline: `998/1000` compared, `998` normalized matches, `0` mismatches, with only `2` Binaryen/oracle `binaryen-rec-group-zero` command failures.
- `0848` tee-plus-later-chain fix: direct `10000`-case lane normalized `10000/10000`, `0` mismatches, `0` failures.
- `0850` many-news tee-chain fix: direct `10000`-case lane normalized `10000/10000`, `0` mismatches, `0` validation/generator/property/command failures.

Agent classification: no remaining HSO-C debris/output-shape drift is currently known. This is not an argument that all future raw text differences would be acceptable; any future HSO-C-shaped drift must still be inspected and classified as a behavior-parity match, Starshine win with evidence, parity gap, tool/Binaryen failure, validation failure, or unknown/risky.

## Evidence command from this closeout slice

```sh
moon test --package jtenner/starshine/passes --file heap_store_optimization_test.mbt
```

Observed result:

```text
Total tests: 203, passed: 203, failed: 0.
```

No implementation changed in this closeout slice, so no red-first test, native rebuild, or new direct compare was required. The latest behavior-changing HSO-C slice (`0850`) already ran the native build and direct 10000-case compare.

## Status

HSO-C can be marked complete in the active backlog. Continue the recursive audit with HSO-D/E: descriptor/default/old-field combinations, remaining later-field directional barriers, and target-local moved-value hazard variants.
