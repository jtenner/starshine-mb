# Working On Passes

- Prioritize correctness first.
- Match Binaryen as the minimum oracle behavior.
- Target under 1 second or at least 50% of Binaryen wall time where possible.
- Verify parity at `10000` comparisons with `moon build --target native --release src/cmd` followed by `bun fuzz compare-pass ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe` or `bun scripts/pass-fuzz-compare.ts ... --jobs auto --starshine-bin target/native/release/build/cmd/cmd.exe`.
