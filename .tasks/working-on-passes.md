# Working On Passes

- Prioritize correctness first.
- Match Binaryen as the minimum oracle behavior.
- Target under 1 second or at least 50% of Binaryen wall time where possible.
- Build with `moon build --target native --release src/cmd`. Verify parity at `10000` GenValid comparisons with `bun fuzz compare-pass ... --jobs auto --max-subprocesses 8 --max-mismatch-artifacts 20 --wasm-opt-bin <verified-v133-wasm-opt> --require-binaryen-version 133 --starshine-bin _build/native/release/build/cmd/cmd.exe`, or the equivalent `bun scripts/pass-fuzz-compare.ts` command. Use the documented aggregate profile when one exists. See [the full pass workflow](../.pi/skills/starshine-pass-implementation/SKILL.md).
