# Starshine Node Package

`@jtenner/starshine` exposes Starshine as an ESM-first Node package for parsing, validating, rewriting, and re-encoding WebAssembly modules from JavaScript.

Use the root barrel for discovery, or import a focused subpath when you only need one part of the toolkit.

## Install

```bash
npm install @jtenner/starshine
```

## Runtime Requirements

- Node.js 25 or newer with WebAssembly GC and JS string builtins available.
- Consumers of the published package only need Node.js.

## Available APIs

| API | Purpose |
| --- | --- |
| `binary` | Decode and encode `.wasm` bytes. |
| `cli` | Parse CLI flags, config files, and globs. |
| `cmd` | Run the packaged CLI from JavaScript. |
| `ir` | Inspect lower-level IR data structures. |
| `lib` | Build modules directly in code. |
| `transformer` | Walk and rewrite modules with traversal hooks. |
| `validate` | Validate modules before or after rewrites. |
| `wast` / `wat` | Parse and print text-format wasm. |

## Quick Start

```js
import { binary, validate, wast } from '@jtenner/starshine';

const parsed = wast.wastToBinaryModule('(module (func (export "run")))');
if (!parsed.ok) throw new Error(parsed.display ?? 'failed to parse');

const validated = validate.validateModule(parsed.value);
if (!validated.ok) throw new Error(validated.display ?? 'failed to validate');

const encoded = binary.encodeModule(parsed.value);
if (!encoded.ok) throw new Error(encoded.display ?? 'failed to encode');

console.log(encoded.value instanceof Uint8Array);
```

## CLI Bridge

```js
import { cmd } from '@jtenner/starshine';

console.log(cmd.cmdHelpText());
```

CLI optimization and pass flags are currently accepted for compatibility but execute as no-ops while the optimization pipeline is being rebuilt.

## Examples

See [node/examples/README.md](./examples/README.md) for the packaged examples.

## Build From Source

Node package regeneration is temporarily disabled during the optimization pipeline refactor. The previous build path depended on the removed `passes` and `node_api` packages.
