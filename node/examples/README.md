# Node Examples

Run example scripts from `node/`:

```bash
node examples/01-barrel-roundtrip.mjs
```

## Start Points
- `01-barrel-roundtrip.mjs`: end-to-end package roundtrip.
- `02-binary-decode-detail.mjs`: low-level binary detail checks.
- `07-cmd-run-with-adapter.mjs`: CLI adapter embed.
- `15-lib-module-from-scratch-add.mjs`: module construction examples.

## What to Run
- Roundtrip baseline: `01-barrel-roundtrip.mjs`
- CLI config parsing: `04-cli-parse-help.mjs` / `05-cli-schema-and-paths.mjs`
- Binary/string decoding: `12-wast-module-roundtrip.mjs` / `13-wast-script-roundtrip.mjs`
- CLI execution: `06-cmd-help-and-version.mjs` / `07-cmd-run-with-adapter.mjs` / `08-cmd-run-filesystem.mjs`
- Module construction from scratch: `15/16/17-lib-module-from-scratch-*.mjs`
