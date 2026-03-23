# Node Examples

Run example scripts from `node/examples/`:

```bash
node examples/01-barrel-roundtrip.mjs
```

## Start Points
- `01-barrel-roundtrip.mjs`: end-to-end package roundtrip.
- `02-binary-decode-detail.mjs`: low-level binary detail checks.
- `03-binary-size-helpers.mjs`: print module size metrics from binaries.
- `06-cmd-help-and-version.mjs`: CLI help/version integration examples.
- `07-cmd-run-with-adapter.mjs`: CLI adapter embed.
- `09-cmd-differential-validation.mjs`: differential validation with JS harness.
- `15-lib-module-from-scratch-add.mjs`: module construction examples.
- `18-lib-module-function-annotations.mjs`: direct Binaryen-style function annotation construction from the `lib` API.

## What to Run
- Roundtrip baseline: `01-barrel-roundtrip.mjs`
- CLI config parsing: `04-cli-parse-help.mjs` / `05-cli-schema-and-paths.mjs`
- Binary/string decoding: `12-wast-module-roundtrip.mjs` / `13-wast-script-roundtrip.mjs`
- CLI execution and filesystem workflows: `06-cmd-help-and-version.mjs` / `07-cmd-run-with-adapter.mjs` / `08-cmd-run-filesystem.mjs`
- Differential and fuzz report helpers: `09-cmd-differential-validation.mjs` / `10-cmd-persist-fuzz-report.mjs`
- Spec harness + diagnostics: `14-wast-spec-suite.mjs`
- Module construction from scratch: `15/16/17-lib-module-from-scratch-*.mjs`
- Function annotations: `18-lib-module-function-annotations.mjs`
