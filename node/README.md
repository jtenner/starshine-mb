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
- `cmd`: run packaged CLI.
- `validate`: module validation helpers.
- `lib`: module constructors.
- `index`: public re-export surface.
- `wast` / `wat`: text parsing and printing.

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
- The deleted `src/node_api` wasm-gc adapter is not rebuilt as part of the current node package flow.
- CLI optimization flags mirror the current command compatibility surface: `--optimize` / `--shrink` select the compatibility preset path, while explicit legacy pass names are still accepted for compatibility and reporting but do not yet map to rebuilt hot-IR pass implementations.
