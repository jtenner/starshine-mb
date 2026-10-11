# Starshine for MoonBit

Starshine parses, validates, encodes, and optimizes WebAssembly modules.
This first Mooncakes release is `jtenner/starshine@0.2.0`.

Add the exact version to an empty MoonBit project:

```sh
moon add jtenner/starshine@0.2.0
```

Import `jtenner/starshine/wast`, `jtenner/starshine/binary`,
`jtenner/starshine/validate`, and `jtenner/starshine/passes` in `moon.pkg`.
The text parser returns `Result[Module, String]`; binary encoding and module
validation also return results. Opaque compiler/optimizer internals remain
implementation details.

See the [package map and API](https://github.com/jtenner/starshine-mb/blob/master/README.mbt.md),
[optimizer/runtime boundaries](https://github.com/jtenner/starshine-mb/blob/master/docs/wiki/tooling/node-package-surface.md),
and [release workflow](https://github.com/jtenner/starshine-mb/blob/master/docs/wiki/tooling/release-process.md).
The separate JavaScript package requires Node.js 25 or newer and loads WasmGC
through JavaScript APIs.

The module's Apache-2.0 declaration preserves upstream terms. The accompanying
`LICENSE` scopes Joshua Tenner's MIT grant to his original code and modifications;
`NOTICE` and `licenses/` retain dependency and Binaryen rights and terms.

This release prioritizes correct behavior. Known optimizer parity gaps and resource
costs remain tracked in the repository; performance and size gains are not universal.
