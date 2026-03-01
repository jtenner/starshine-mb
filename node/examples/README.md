# Node Examples

Run examples from the `node/` package directory with:

```bash
node examples/01-barrel-roundtrip.mjs
```

Available examples:

- `01-barrel-roundtrip.mjs`: root barrel import with parse, encode, decode, and validate.
- `02-binary-decode-detail.mjs`: binary decode with detail offsets.
- `03-binary-size-helpers.mjs`: signed and unsigned size helpers.
- `04-cli-parse-help.mjs`: CLI parsing, pass resolution, and trap-mode resolution.
- `05-cli-schema-and-paths.mjs`: config schema, glob matching, path normalization, and input-format inference.
- `06-cmd-help-and-version.mjs`: help and version text from the cmd bridge.
- `07-cmd-run-with-adapter.mjs`: custom in-memory `CmdIO` usage.
- `08-cmd-run-filesystem.mjs`: default host-backed filesystem execution.
- `09-cmd-differential-validation.mjs`: custom differential validation adapters.
- `10-cmd-persist-fuzz-report.mjs`: fuzz failure persistence hooks.
- `11-passes-optimize-module.mjs`: build an ordered optimization pipeline and append explicit pass constructors.
- `12-wast-module-roundtrip.mjs`: WAST module parsing and pretty-printing.
- `13-wast-script-roundtrip.mjs`: WAST script parsing and pretty-printing.
- `14-wast-spec-suite.mjs`: in-memory WAST spec harness execution.
- `15-lib-module-from-scratch-add.mjs`: build an exported arithmetic module from scratch, validate it, and encode it.
- `16-lib-module-from-scratch-memory.mjs`: build a memory-and-data module from scratch and exercise `U32`/`U64` memarg helpers.
- `17-lib-module-from-scratch-control-flow.mjs`: build a typed `if`-based module from scratch and validate its control-flow shape.
