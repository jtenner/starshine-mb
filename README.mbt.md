# Starshine

Starshine is a MoonBit toolkit for working with WebAssembly text, binary modules, validation, typed IR, and module rewriting.

This README is MoonBit-first. If you want the JavaScript/npm package, see [node/README.md](./node/README.md).

## Install In MoonBit

The package name is `jtenner/starshine`. This project has not been released yet, so consumers usually pin a local checkout or another source they already control.

Minimal `moon.mod.json` shape:

```json
{
  "deps": {
    "jtenner/starshine": "<pin-or-local-source>"
  }
}
```

## What You Can Do With It

- Parse WAT/WAST text into Starshine's `Module` model.
- Validate modules and lift function bodies to typed IR.
- Decode and encode binary wasm modules.
- Build modules directly with constructor-based APIs.
- Walk and rewrite modules with the transformer framework.
- Drive the packaged CLI from MoonBit or from the bundled Node wrapper.

## Package Map

| Package | Purpose |
| --- | --- |
| `jtenner/starshine/wast` | Parse and print WAT/WAST text. |
| `jtenner/starshine/wat` | Text-format wasm helpers. |
| `jtenner/starshine/validate` | Validation and typed IR conversion. |
| `jtenner/starshine/binary` | Binary decode/encode and LEB128 helpers. |
| `jtenner/starshine/lib` | Core Wasm model types and constructors. |
| `jtenner/starshine/ir` | CFG/SSA/use-def/liveness utilities. |
| `jtenner/starshine/transformer` | Event-driven traversal and rewrite hooks. |
| `jtenner/starshine/cli` | CLI parsing, config, globbing, and flag resolution. |
| `jtenner/starshine/cmd` | Command execution, fuzz helpers, and host adapters. |

## First Pipeline

```mbt
using @binary { encode_module }
using @validate { validate_module }
using @wast { wast_to_binary_module }

fn parse_validate_encode(source : String) -> Bool {
  let mod = match wast_to_binary_module(source, filename="input.wat") {
    Ok(mod) => mod
    Err(_) => return false
  }

  match validate_module(mod) {
    Ok(()) => ()
    Err(_) => return false
  }

  match encode_module(mod) {
    Ok(_) => true
    Err(_) => false
  }
}
```

## CLI Compatibility Note

The optimization pipeline is currently being refactored. CLI optimization and pass flags are still accepted for compatibility, but they behave as no-ops for now.

## Development Checks

Preferred local check sequence:

```bash
moon info
moon fmt
moon test
```
