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
- Legacy explicit CLI pass flags are still accepted for compatibility, including unknown values, but currently resolve as compatibility no-ops.
- `--optimize` / `--shrink` are the active compatibility path through the remaining command adapter.
- `npm run build` is currently limited by the ongoing package-surface reset.
- JS/TS adapter source regeneration is still manual.
