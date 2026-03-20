# Starshine

MoonBit toolkit for parsing, validating, and rewriting WebAssembly.

For JavaScript/npm usage, see [node/README.md](./node/README.md).

## Install in MoonBit

```json
{
  "deps": {
    "jtenner/starshine": "<pin-or-local-source>"
  }
}
```

## What You Can Do

- Parse and print WAT/WAST.
- Validate modules and use typed-IR lifts.
- Decode and encode WebAssembly binaries.
- Build modules with `lib` constructors and IR utilities.
- Rewrite modules via the transformer framework.
- Use CLI and Node wrappers.

## Package Map

| Package | Purpose |
| --- | --- |
| `jtenner/starshine/wast` | Parse and print WAT/WAST text. |
| `jtenner/starshine/wat` | Text-format wasm helpers. |
| `jtenner/starshine/validate` | Validation + typed IR conversion. |
| `jtenner/starshine/binary` | Binary encoding/decoding + LEB128 helpers. |
| `jtenner/starshine/lib` | Core Wasm types and constructors. |
| `jtenner/starshine/ir` | CFG/SSA/use-def/liveness utilities. |
| `jtenner/starshine/transformer` | Event-driven traversal and rewrite hooks. |
| `jtenner/starshine/cli` | CLI parsing, config, globbing, and flags. |
| `jtenner/starshine/cmd` | Command execution and host adapters. |

## Quick Example

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

## Compatibility Note

- CLI optimization flags are currently accepted for compatibility but mostly no-op while the pipeline is being refactored.

## Prerequisites

- [bun](https://bun.sh) (for project scripts in `package.json`)
- [MoonBit toolchain (`moon`)](https://www.moonbitlang.com/docs/zh/getting-started/installing-moonbit/) (for building and testing MoonBit packages)
- Optional: [Node.js](https://nodejs.org/) if you also run `node/` package tooling

Install script dependencies after installing `bun` and `moon`:

Then install project script dependencies:

```bash
bun install
```

## Build, Test, and Fuzz

Install script tooling and run the full project checks:

```bash
bun validate full
```

Run the minimum local quality gate used by this repo:

```bash
moon info
moon fmt
moon test
```

Run fuzzing with default settings (suite/profile/seed/target):

```bash
bun fuzz run
```

Useful variant commands:

```bash
bun fuzz run --suite <suite> --profile <profile> --seed <seed> --target <target>
bun validate coverage
bun validate readme-api-sync
```
