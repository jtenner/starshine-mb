---
kind: concept
status: supported
last_reviewed: 2026-07-19
sources:
  - ./index.md
  - ./starshine-strategy.md
  - ../../../../../src/passes/inlining.mbt
  - ../../../../../src/passes/inlining_test.mbt
  - ../../../../../src/passes/inlining_wbtest.mbt
  - ../../../../../src/cli/cli_test.mbt
  - ../../../../../src/cmd/cmd_wbtest.mbt
related:
  - ../inlining-optimizing/starshine-port-readiness-and-validation.md
  - ../inline-main/fuzzing.md
---

# `inlining`: readiness and validation

## Verdict

The represented Binaryen v131 direct-inliner surface is implemented and signed off. This page is now a reopening guide, not a port plan.

## Required behavior matrix

| Family | Current evidence |
| --- | --- |
| tiny / one-caller / exported-root survival | focused black-box tests |
| shrinking and may-grow trivial instructions | generic HOT child analysis plus scalar, memory, table, SIMD, GC, call, constant, duplicate-operand, and tuned-threshold tests |
| O3 flexible policy | direct-call, indirect/ref-call, loop, shrink, and threshold tests |
| toolchain and no-inline policy | Never/Always, no/full/partial, wildcard, stripped names, clone survival, and deduplication tests |
| combined-size policy | strict 2.5-byte estimate, configurable limit, and repeated callsite tests |
| Pattern A/B splitting | leading guard, multiple guards, returned values, terminal traps, max-if, and policy tests |
| locals and types | parameters, numeric/vector/nullable/nonnullable locals, scalar/multivalue types, synthesized block types |
| tail and EH repair | direct/indirect/ref tail sites, non-tail lowering, operand spills, `try_table` hoisting, table64 target typing, branch/catch depth repair |
| roots and removal | exports, start, elements, table/global initializers, helper compaction, recursive/cyclic families |
| metadata | function/annotation remap, caller local names, untouched label names, stale rewritten-label removal |
| plain stop point | tests prove plain mode does not run the optimizing nested pipeline |

## Current validation

- `moon info`: success;
- `moon fmt`: success;
- CLI parser: `54/54`;
- command tests: `107/107`;
- focused inlining: `120/120`;
- white-box inlining: `14/14`;
- full `moon test`: `9452/9452`.

Official Binaryen v131 compare:

```text
.tmp/pass-fuzz-inlining-v131-closeout-10000
10000/10000 compared
10000 normalized matches
0 mismatches
0 validation/property/generator/command failures
```

The optimizing sibling has the same `10000/10000` result in `.tmp/pass-fuzz-inlining-optimizing-v131-closeout-10000`.

## Non-pass boundaries

Do not reopen direct inlining solely for:

- legacy `try_delegate` syntax/representation;
- expression-level branch hints or other code metadata;
- source-map offset repair;
- copied callee debug-name synthesis;
- speculative indirect/ref callee recovery;
- raw WAT or byte differences without a measured Starshine regression.

## Reopening criteria

Reopen only with one of:

1. a minimized semantic mismatch against explicit official v131;
2. a Starshine validation failure;
3. a source-backed v131 transform family missing from the represented surface;
4. a size-losing divergence with no compensating Starshine benefit;
5. a pass-local performance regression beyond the accepted target;
6. a new shared representation capability that makes one of the documented metadata/legacy-EH boundaries implementable.
