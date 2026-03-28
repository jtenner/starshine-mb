# 0070 - Remove Unused Brs Binaryen Comparison

## Scope

- Compare Binaryen's `RemoveUnusedBrs` implementation against the current MoonBit hot pass.
- Use Binaryen's source as the oracle for phase structure, not just corpus diffs.
- Land the next missing rewrite in a way that matches Binaryen's pass organization closely enough to improve parity without reopening the large perf cliff.

## Primary Source

- Binaryen source:
  `https://codebrowser.dev/dart_sdk/dart_sdk/third_party/binaryen/src/src/passes/RemoveUnusedBrs.cpp.html`
- Relevant areas in that file:
  - front fixpoint walker and flow tracking around lines 117-336
  - loop cleanup and block sinking / jump threading around lines 700-900
  - final optimizer block rewrites around lines 901-1188
  - local-set arm rewrites around lines 1190-1334
  - `tablify` around lines 1336-1516

## Binaryen Phase Structure

Binaryen is not just a bag of peepholes here. The pass has distinct stages:

1. A repeated postwalk fixpoint that tracks flowing unconditional branches / returns and removes them when they reach the same continuation.
2. Loop-specific cleanup plus block sinking / branch threading after the main flow cleanup has simplified the CFG.
3. A final optimizer over simplified blocks that does:
   - block-end `if br else br` to `br_if + fallthrough`
   - adjacent branch merging
   - `tablify`
   - `restructureIf`
   - `selectify`
   - `optimizeSetIf`

That matters because several remaining MoonBit parity gaps are not "tail branch removal" gaps. They are final-shape cleanup gaps that Binaryen intentionally runs only after earlier simplification.

## Current MoonBit Coverage

The MoonBit port already covers substantial parts of Binaryen's behavior:

- trailing redundant `br` / `return` stripping
- one-armed `if` to `br_if`
- many tail `if` branch-exit rewrites
- root return-context stripping
- value-`if` to `select`
- local-set copy-arm / branch-arm rewrites
- several targeted perf bailouts for large exact-match no-op families

## Missing / Weaker Areas

The comparison against Binaryen's source shows three important mismatches:

- There was no distinct equivalent of Binaryen's `restructureIf` phase.
  Binaryen rewrites a block whose first operation is a conditional branch to the block label into an outer `if` / `select` form when that reduces the branch structure.
- MoonBit had been trying to recover some of those shapes later through broader nested-region scans.
  Those scans could hit the oracle families, but they were too expensive on the large corpus.
- MoonBit's current `i32.eqz` helper is implemented as a `select(0, 1, cond)`.
  That is semantically fine, but it means some Binaryen-style "flip the condition" rewrites lower to a different internal normal form until later passes.

## Why The Earlier Attempts Were Slow

- The rejected parity slices were discovering Binaryen's final-shape opportunities by scanning many nested regions during the main walk.
- Binaryen does not do that discovery the same way.
  It reaches those opportunities after earlier simplification has already exposed them in direct block-local positions.
- In MoonBit, broad nested-region probing amplified HOT mutations and revisit cost.
  That is why the local fixes for families like `$1105` / `$1106` were real but too slow to keep.

## Evaluated Slice

- I implemented a narrow MoonBit analogue of Binaryen's `restructureIf` family:
  scalar result blocks whose first root is a `br_if` to the block label, followed by the dropped payload root and a single fallthrough result root.
- Local focused tests passed, but the real self-opt compare did not justify keeping it.
  The slice regressed pass time and did not make the still-known remaining oracle families like `$1105` / `$1106` exact.
- Because of that, the code change was backed out.
  The useful outcome is the comparison itself: `restructureIf` is definitely a real missing Binaryen phase, but the current MoonBit pipeline needs a cheaper discriminator before that phase can land safely.

## Comparison Outcome

- Binaryen's pass structure explains why the remaining parity families were resisting ad hoc tail-only work.
- The evaluated slice was sourced from Binaryen's final optimizer rather than from corpus-specific guesswork, but it was not keepable yet.
- The next likely parity work should continue in that direction:
  - extend `restructureIf` coverage carefully
  - only after that reconsider broader branch-payload families

## Validation

- Required local checks for this slice:
  - `moon info && moon fmt`
  - `moon test src/passes/remove_unused_brs_test.mbt`
  - `moon test`
- Oracle follow-up:
  - rerun `bun scripts/self-optimize-compare.ts tests/node/dist/starshine-debug-wasi.wasm --remove-unused-brs`
  - inspect whether a revised final-phase rewrite closes any of the previously stable remaining exact mismatches without regressing the current perf band
