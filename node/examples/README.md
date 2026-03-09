# Node Examples

Run examples from the `node/` package directory with:

```bash
node examples/01-barrel-roundtrip.mjs
```

Use this directory as a cookbook:

- Start with `01-barrel-roundtrip.mjs` for the smallest end-to-end package demo.
- Start with `07-cmd-run-with-adapter.mjs` if you want to embed the CLI in a JS application.
- Start with `11-passes-optimize-module.mjs` if you want explicit optimization pipelines.
- Start with `15-lib-module-from-scratch-add.mjs` if you want to construct modules directly.

## Choose An Example

| If you want to... | Start here | Why |
| --- | --- | --- |
| Parse text, encode it, decode it again, and validate it | `01-barrel-roundtrip.mjs` | Smallest complete roundtrip. |
| Inspect binary decoding details | `02-binary-decode-detail.mjs` | Shows trailing-offset detail from the binary adapter. |
| Use low-level size helpers | `03-binary-size-helpers.mjs` | Focused binary helper example. |
| Parse CLI flags and config-related values | `04-cli-parse-help.mjs` and `05-cli-schema-and-paths.mjs` | Best entry point for the `cli` surface. |
| Read CLI help/version or run the packaged CLI | `06-cmd-help-and-version.mjs`, `07-cmd-run-with-adapter.mjs`, `08-cmd-run-filesystem.mjs` | Covers the `cmd` bridge from simple to host-backed. |
| Build a custom optimization pipeline | `11-passes-optimize-module.mjs` | Best `passes` starting point. |
| Parse or print WAST modules and scripts | `12-wast-module-roundtrip.mjs`, `13-wast-script-roundtrip.mjs`, `14-wast-spec-suite.mjs` | Text-format and spec-harness examples. |
| Build modules from scratch | `15-lib-module-from-scratch-add.mjs`, `16-lib-module-from-scratch-memory.mjs`, `17-lib-module-from-scratch-control-flow.mjs` | `lib` builders from simple to richer control flow. |

## Common Tasks

### Parse text and validate it

- `01-barrel-roundtrip.mjs`
  teaches the `wast -> binary -> validate` flow.

### Decode existing wasm bytes

- `02-binary-decode-detail.mjs`
  shows `binary.decodeModuleWithDetail(...)` and trailing offsets.

### Run the CLI from JavaScript

- `07-cmd-run-with-adapter.mjs`
  in-memory adapter version.
- `08-cmd-run-filesystem.mjs`
  host-filesystem version.

### Build a module in code

- `15-lib-module-from-scratch-add.mjs`
  smallest constructor-based example.
- `16-lib-module-from-scratch-memory.mjs`
  memory/data-focused example.
- `17-lib-module-from-scratch-control-flow.mjs`
  control-flow-heavy builder example.

## Full List

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

## Troubleshooting

- `Cannot use import statement outside a module`:
  these examples assume modern Node ESM execution.
- A result object does not throw automatically:
  check `ok` first, then read `value`; the shared helper in `_shared.mjs` demonstrates one simple pattern.
- You only want the smallest smoke test:
  run `01-barrel-roundtrip.mjs` before moving on to the larger examples.
