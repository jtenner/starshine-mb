# Starshine Node Package

ESM-first Node package: `@jtenner/starshine`.

## Install

```bash
npm install @jtenner/starshine
```

## Runtime
- Node.js 25+ with WebAssembly GC and JS string builtins.

## API Surface
- `binary`: decode / encode `.wasm`.
- `cli`: parse flags and config formats.
- `cmd`: run packaged CLI and expose the public command fuzz harness.
- `validate`: module validation helpers.
- `lib`: module constructors.
- `index`: public re-export surface.
- `wast` / `wat`: text parsing and printing.

## Node Parity Notes
- The checked-in `cmd` wrapper now prefers the MoonBit parity names `CmdFuzzStats`, `runCmdFuzzHarness(...)`, and `runCmdFuzzHarnessProfile(...)`.
- Legacy `WasmSmithFuzzStats`, `runWasmSmithFuzzHarness(...)`, and `runWasmSmithFuzzHarnessProfile(...)` exports remain as documented compatibility aliases for older Node consumers.
- `CmdIO.printTextModule` and `CmdRunSummary.closedWorld` are now carried in the public Node contract for MoonBit-surface parity. The current checked-in JS command bridge does not yet route pipeline work through `printTextModule`, but `CmdRunSummary.closedWorld` now reflects the cmd wrapper's resolved config/env/CLI state. The separate `node/cli` wrapper still lags the full MoonBit closed-world parser surface.

## Quick Usage

```js
import { binary, validate, wast } from '@jtenner/starshine';

const parsed = wast.wastToBinaryModule('(module (func (export "run")))');
if (!parsed.ok) throw new Error(parsed.display ?? 'failed to parse');

if (!validate.validateModule(parsed.value).ok) throw new Error('invalid module');
const encoded = binary.encodeModule(parsed.value);
if (!encoded.ok) throw new Error(encoded.display ?? 'failed to encode');
```

## Build Note
- `npm run build` regenerates the JS/TS package surface and refreshes the checked-in WASI CLI artifact under `node/internal/`.
- The compatibility/staging `src/node_api` adapter surface is not rebuilt as part of the current node package flow.
- CLI optimization flags run through the live command pass pipeline: `--optimize` / `--shrink` use the active hot preset, while legacy pass names are still surfaced for diagnostics but are not executable in the active registry.
