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
- `ir`: IR data helpers.
- `lib`: module constructors.
- `transformer`: traversal + rewrite hooks.
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
- CLI optimization flags are accepted for compatibility but no-op while pipeline refactors continue.
- `npm run build` rebuilds the checked-in wasm artifacts from `src/node_api` and `src/cmd`.
- JS/TS adapter source regeneration is still manual.
