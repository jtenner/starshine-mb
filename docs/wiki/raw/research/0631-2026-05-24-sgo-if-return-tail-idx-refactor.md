# SGO if-return tail index refactor

Date: 2026-05-24

## Status

Refactor-only implementation slice for `[SGO]003`. No intended behavior broadening and no claim of full Binaryen `SimplifyGlobals.cpp` parity.

## Goal

Continue consolidating read-only-to-write exact `if return; set` tail handling. The block/no-catch-`try_table` tail helpers repeated the same wrapper-body extraction plus target-global matching for direct `const; global.set` tails and block-wrapped set tails across direct, `i32.eqz`, compare, and reverse-compare guard families.

## Implementation

Changed `src/passes/simplify_globals_optimizing.mbt` only.

Added shared helpers:

- `sgo_count_block_condition_if_return_idx_read(...)`
  - checks the existing return-guard predicate;
  - extracts the existing block or no-catch `try_table` wrapper body;
  - counts the body read for an optional target global index;
- `sgo_set_tail_idx_with_const_value(...)`
  - recognizes the existing exact `const; global.set` tail shape and returns its target global index.

Routed these exact if-return tail helpers through the shared index applier:

- direct `if return; block-wrapped-set`;
- direct `if return; const; global.set`;
- `i32.eqz` exact if-return set and block-wrapped-set;
- compare exact if-return set and block-wrapped-set;
- reverse-compare variants through the existing compare helpers.

## Preserved boundaries

This is a structural refactor only. It preserves:

- exact whole-function `if return; set` tail requirements from the top-level dispatcher;
- the return-guard predicate;
- constant-value requirement before `global.set`;
- block-wrapped-set target extraction;
- block/no-catch `try_table` wrapper-body extraction;
- caught `try_table` conservatism;
- loop-specific behavior outside this helper path.

No tests were added because this slice intentionally does not broaden behavior. Existing tests cover the exact direct, `i32.eqz`, compare, reverse-compare, block-wrapped, and no-catch `try_table` if-return tail families.

## Validation

- `moon fmt && moon test src/passes`
  - `1590/1590` tests passed.
  - Existing unrelated warnings in DAE and pass-manager white-box tests remain.
- Direct SGO fuzz:
  - command: `bun fuzz compare-pass --count 10000 --seed 0x5eed --pass simplify-globals-optimizing --max-failures 20 --keep-going-after-command-failures --out-dir .tmp/pass-fuzz-sgo-if-return-tail-idx-refactor-10k`
  - compared: `9975/10000`
  - normalized matches: `9975`
  - mismatches: `0`
  - validation failures: `0`
  - generator failures: `0`
  - Binaryen/tool command failures: `25`

## Remaining work

`[SGO]003` remains active/partial. This refactor only centralizes target-index handling for already-supported exact if-return tails. Future behavior-bearing slices still need focused Binaryen oracle support, tests-first implementation, catch/control/trapping guardrails, and direct `--pass simplify-globals-optimizing` fuzz evidence.
