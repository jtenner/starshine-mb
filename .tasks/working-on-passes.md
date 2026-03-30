# Working On Passes

- Prioritize correctness first.
- Match Binaryen as the minimum oracle behavior.
- Target under 1 second or at least 50% of Binaryen wall time where possible.
- Verify parity with `bun fuzz compare-pass ...` or `bun scripts/pass-fuzz-compare.ts ...` at `10000` comparisons.
