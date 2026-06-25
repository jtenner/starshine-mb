# OptimizeInstructions OI-D i32 sign-extension relational boundary

Date: 2026-06-25

## Summary

This boundary/status slice keeps the direct i32 sign-extension range fold narrow. Binaryen `version_130` keeps signed relational comparisons such as:

```wat
local.get 0
i32.extend8_s
i32.const 128
i32.lt_s
```

and:

```wat
local.get 0
i32.extend16_s
i32.const -32769
i32.gt_s
```

even though the comparison constant lies outside the signed lane range. Starshine now has public-pipeline coverage proving it also keeps these relational forms instead of generalizing the existing i32 sign-extension equality/inequality fold.

This is coverage/status evidence, not a red-first implementation slice. It prevents the equality-specific range proof from becoming a broader signed relational rewrite without source-backed Binaryen evidence.

## Evidence

- Binaryen oracle probe: `.tmp/oi-d-i32-signext-rel-boundary-probe.wat`
- Oracle command: `wasm-opt --all-features -S --optimize-instructions .tmp/oi-d-i32-signext-rel-boundary-probe.wat -o -`
- Oracle result: Binaryen kept both `i32.lt_s(i32.extend8_s(...), i32.const 128)` and `i32.gt_s(i32.extend16_s(...), i32.const -32769)`; no constant fold was introduced.
- Starshine test: `src/passes/optimize_instructions_test.mbt`, public-pipeline test `optimize-instructions keeps i32 sign-extension relational compares outside range`
- Focused validation: `moon test --target native src/passes/optimize_instructions_test.mbt --filter '*i32 sign-extension relational*'` passed `1/1`.

## Status

- Counted as an additional OI-D scalar/compare boundary coverage slice.
- Boundary remains narrow: direct i32 `eq` / `ne` folds for out-of-range `i32.extend8_s` / `i32.extend16_s` comparisons remain covered; this note only covers signed relational comparisons over the same direct sign-extension forms.
- Broader OI-D work remains open for local-scanner width facts, signed range proofs beyond this observed keep-spelling boundary, select/phi/load/extension width facts, and broader recursive `maxBits` expressions.
