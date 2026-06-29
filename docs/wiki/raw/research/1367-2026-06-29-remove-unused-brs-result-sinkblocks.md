# RUB-Q result-typed `sinkBlocks` slice

Date: 2026-06-29

## Question

Can Starshine narrow the remaining `sinkBlocks(...)` gap beyond the old void-only helper without taking on all Binaryen multivalue/result refinalization behavior at once?

## Source evidence

Binaryen `version_130` `RemoveUnusedBrs.cpp::sinkBlocks(...)` visits named one-child blocks. For a loop child it swaps the block into the loop body. For an `if` child, it skips unreachable conditions, rejects uses of the outer block label in the condition, picks an arm when the opposite arm has no uses of that label, assigns the old target arm as the block body, assigns the block as the target arm, finalizes both nodes, replaces the current node with the `if`, and runs `ReFinalize` after the sinker works. The source does not limit this to `Type::none`; multivalue lit evidence exists via `remove-unused-brs_enable-multivalue.wast`.

Local source link: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/RemoveUnusedBrs.cpp>.

## Decision

Implement the narrow one-result HOT subset:

- keep the existing guard that the outer named block has exactly one child and that child is an `if`
- continue rejecting unreachable conditions and condition-label uses
- continue requiring exactly one arm to use the block label and the target arm to have multiple roots, preserving the existing single-root branch-tail delegation
- allow the block/if result type to be void or one matching value type
- keep multi-result block/if sinks conservative until HOT tuple and arm/body repair are audited

This matches Binaryen's structural move for scalar result blocks while avoiding the broader multivalue tuple/local scratch repair visible in Binaryen output for a reduced multi-result example.

## Test-first evidence

Added `remove-unused-brs sinks result-typed single-if exit blocks into the label-using arm` before implementation. The focused run failed red:

```text
moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt
```

Result before implementation: `186/187` passed; the new test failed because the root remained `Block`.

Also added `remove-unused-brs boundary keeps multi-result single-if sinking conservative` as an explicit boundary test. The boundary cites Binaryen's broader multivalue support but keeps Starshine stationary until local tuple/arm repair is audited.

## Implementation

Updated `remove_unused_brs_try_sink_single_if_exit_block(...)` in `src/passes/remove_unused_brs.mbt`:

- removed the void-only block and if result-arity guards
- compared the block and if result vectors
- admitted only arity `0` or matching arity `1`
- preserved the existing label-use, unreachable-condition, target-arm, multi-root, and tail-branch guards

No public registry or CLI surface changed.

## Validation

- Red-first focused test before implementation: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` failed `186/187`; new positive kept an outer `Block`.
- Focused test after implementation and boundary addition: `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt` passed `188/188`.
- `moon fmt` passed.
- `moon info` passed with 6 pre-existing warnings.
- `moon test --package jtenner/starshine/passes --file remove_unused_brs_test.mbt && moon test src/passes` passed (`188/188`, then `3594/3594`).
- `moon build --target native --release src/cmd` passed with 27 pre-existing pass-manager unused-function warnings.
- Refreshed direct compare smoke after the behavior change: `bun scripts/pass-fuzz-compare.ts --count 1000 --seed 0x5eed --pass remove-unused-brs --normalize drop-consts --normalize unreachable-control-debris --out-dir .tmp/pass-fuzz-remove-unused-brs-rub-q-result-sinkblocks-1000 --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe --max-failures 200 --keep-going-after-command-failures` passed. Requested/compared `1000/1000`; `normalizedMatchCount=142`; `cleanupNormalizedMatchCount=858` (reported by the CLI as compare-normalized matches); `mismatchCount=0`; validation/property/generator/command failures all `0`; command failure classes `{}`; cache counters: wasm-smith `0/0`, Binaryen `1000/0`, Binaryen failures `0/0`.
- `git diff --check` produced no output.
- Pass-local timing was not available for this slice.

## Remaining after this slice

This removes the scalar result-typed `sinkBlocks` subset from the open list. Still open:

- multi-result `sinkBlocks`, blocked on a source-backed HOT tuple/local/arm-repair audit
- direct unreachable-condition sink assertions where ordinary DCE erases the shape first
- exact Binaryen branch-hint/refinalization metadata behavior, still owned by the broader branch-hint representation boundary
- all other RUB-Q backlog families not touched by this slice
