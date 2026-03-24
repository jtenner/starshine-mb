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
- Preserve Binaryen-style function annotations in WAT/WAST text and lowered modules.
- Validate modules and enforce wasm typing and section rules.
- Decode and encode WebAssembly binaries.
- Build modules with `lib` constructors and hot-IR helpers.
- Lift function bodies into the current hot function IR and lower them back to boundary form.
- Use CLI and Node wrappers.

## Package Map

| Package | Purpose |
| --- | --- |
| `jtenner/starshine/wast` | Parse and print WAT/WAST text. |
| `jtenner/starshine/wat` | Text-format wasm helpers. |
| `jtenner/starshine/validate` | Validation, type matching, and valid-module generation helpers. |
| `jtenner/starshine/binary` | Binary encoding/decoding + LEB128 helpers. |
| `jtenner/starshine/lib` | Core Wasm types and constructors. |
| `jtenner/starshine/ir` | Hot function IR lift/lower and direct mutation helpers. |
| `jtenner/starshine/cli` | CLI parsing, config, globbing, and flags. |
| `jtenner/starshine/cmd` | Command execution and host adapters. |
| `jtenner/starshine/diff` | Myers diff helpers used by diagnostics and tooling. |
| `jtenner/starshine/fs` | Small filesystem helpers for host-facing code. |
| `jtenner/starshine/fuzz` | Fuzz harness entrypoints and support code. |
| `jtenner/starshine/spec_runner` | WAST spec-harness execution helpers. |
| `jtenner/starshine/validate_trace` | Validation trace entrypoints and fixtures. |

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

- `--optimize` and `--shrink` still resolve through the current command-layer compatibility pipeline while the IR2 pass registry is being rebuilt.
- Legacy explicit pass flags, including unknown names, are still accepted by the command surface for compatibility and reporting, but module execution remains identity/no-op today.
- Pass scheduling and capping behavior for names like `--vacuum`, `--optimize`, and `--shrink` is still covered by command tests even before real hot-pass replacements land.

## Prerequisites

- [bun](https://bun.sh) (for project scripts in `package.json`)
- [MoonBit toolchain (`moon`)](https://www.moonbitlang.com/docs/zh/getting-started/installing-moonbit/) (for building and testing MoonBit packages)
- Optional: [Node.js](https://nodejs.org/) if you also run `node/` package tooling

Install script dependencies after installing `bun` and `moon` (run from repo root):

```bash
bun install
```

## Build, Test, and Fuzz

Run the full project checks (same as CI defaults):

```bash
bun validate full --profile ci --target wasm-gc
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
bun fuzz run --profile <profile> --suite <suite> --output jsonl
bun fuzz run --suite=<suite> --profile=<profile> --seed=<seed> --target=<target> --output=<text|jsonl>
bun fuzz run --list-suites
bun fuzz run --list-profiles
bun fuzz run --help
bun validate coverage
bun validate readme-api-sync
```
