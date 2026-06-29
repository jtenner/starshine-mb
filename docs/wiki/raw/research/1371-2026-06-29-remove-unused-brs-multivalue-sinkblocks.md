# RUB-Q multivalue `sinkBlocks` slice

Date: 2026-06-29

## Question

Can Starshine remove the remaining multi-result `sinkBlocks(...)` boundary after the one-result slice in `1367`, without importing Binaryen's tuple-scratch print shape wholesale?

## Source evidence

Binaryen `version_130` `RemoveUnusedBrs.cpp::sinkBlocks(...)` has no scalar-only guard. For a named block with a single `if` child, it:

- skips unreachable conditions because unreachable can satisfy otherwise incompatible block/arm result types
- rejects uses of the outer block label in the `if` condition
- picks the `then` or `else` arm when exactly the opposite arm has no uses of the outer block label
- moves the selected arm body into the block, moves the block into that arm, finalizes the block and `if`, replaces the current block with the `if`, and later runs `ReFinalize`

A reduced local Binaryen probe confirmed this applies to `(result i32 i64)` block/if sinks. Binaryen prints tuple scratch/local repair around the payload-carrying `br_if`, but the underlying transform is still the same structural sink: the outer block root becomes an `if`, and the named exit block moves inside the label-using arm.

Local source: `.tmp/binaryen-v130/RemoveUnusedBrs.cpp`, lines around `sinkBlocks(...)`.

## Decision

Implement the safe matching-result-vector subset in HOT:

- keep the existing guards for label existence/use count, no label use in the condition, exactly one label-using arm, and a multi-root target arm
- require the block and `if` result vectors to match exactly for void, one-result, and multi-result shapes
- recognize HOT's repeated-root encoding for multi-result `if` / block roots, where a single multi-result node appears multiple times in a region root span
- when replacing the outer block, replace the whole contiguous repeated block-root span with the same number of repeated `if` roots
- keep unreachable-condition sink-specific assertions, single-root branch-tail arms, and exact Binaryen branch-hint/refinalization metadata as remaining boundaries

This matches Binaryen's structural behavior while staying inside existing HOT multivalue/repeated-root representation rather than creating explicit tuple scratch locals in RUB.

## Test-first evidence

Changed the prior boundary test into the positive `remove-unused-brs sinks multi-result single-if exit blocks into the label-using arm` before implementation.

Red-first focused run:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
```

Result before implementation: failed `194/195`; the new positive kept the outer root as `Block`.

## Implementation

Updated `remove_unused_brs_try_sink_single_if_exit_block(...)` in `src/passes/remove_unused_brs.mbt`:

- replaced the arity `<= 1` check with full result-vector equality
- accepted repeated-root HOT regions whose single logical child is a multi-result `if`
- preserved the stack-condition fallback for non-repeated two-root shapes
- replaced the full contiguous repeated outer block root span with repeated `if` roots, instead of replacing only one root slot

Updated `src/passes/remove_unused_brs_test.mbt` with the multi-result positive fixture. Existing condition-label-use and both-arm-use negatives continue to guard the sinker boundaries.

## Validation

- Red-first focused run before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `194/195`; the new positive kept the outer `Block`.
- Focused rerun after implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `195/195`.
- Combined validation: `moon fmt && moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes && moon info` passed. Results: fmt finished; focused RUB tests `195/195`; `moon test src/passes` `3601/3601`; `moon info` passed with 6 pre-existing warnings.
- Native build: `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- Refreshed direct compare: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-multivalue-sinkblocks-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. Requested/compared `1000/1000`; `normalizedMatchCount=142`; `cleanupNormalizedMatchCount=858` (CLI: compare-normalized matches); `mismatchCount=0`; validation/property/generator/command failures all `0`; cache counters: wasm-smith `0/0`, Binaryen `1000/0`, Binaryen failures `0/0`.
- `git diff --check` produced no output.
- Pass-local timing was not available from this lane.

## Remaining after this slice

This removes multi-result `sinkBlocks(...)` from the RUB-Q open list for matching block/if result vectors. Remaining RUB-Q families include:

- old-`try` / HOT catch-region bodies if a binary-decoder path exposes HOT `Try`
- large mostly-default `br_table` JumpThreader beyond the current `<= 8` guard
- remaining GC `br_on_*` payload/prefix/descriptor/fallthrough/localize/unreachable forms, plus nullable disjoint `SuccessOnlyIfNull` as a Binaryen `version_130` TODO boundary
- value-carrying adjacent branch cleanup/merge boundaries
- child-less local stack-payload switch HOT shapes
- broader select/restructure/set-if value legality
- raw-gate/performance accountability and final generator/signoff freshness
