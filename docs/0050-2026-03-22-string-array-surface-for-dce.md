# String Array Surface For DCE

## Scope

Land the minimal typed string instruction surface needed to unblock the
`DeadCodeElimination` string-sensitive regressions from the Binaryen research
baseline.

This slice intentionally does not attempt full `stringref` proposal coverage.
It adds:

- abstract `string` / `stringref` heap and value types
- array-backed string construction ops:
  - `string.new_utf8_array`
  - `string.new_wtf16_array`
  - `string.new_lossy_utf8_array`
  - `string.new_wtf8_array`
- array-backed string encode ops:
  - `string.encode_utf8_array`
  - `string.encode_wtf16_array`
  - `string.encode_lossy_utf8_array`
  - `string.encode_wtf8_array`

## Why This Slice

`docs/0017-2026-03-22-dead-code-elimination.md` still carried the focused
`string.new_wtf16_array` / `local.tee` regression from Binaryen's all-features
fixture, but the local typed IR did not expose any string instruction nodes.
That made the DCE follow-up impossible to port honestly.

The required local change is therefore broader than one optimizer rewrite:

- lib IR must model the string heap type and instructions
- binary encode/decode must roundtrip them
- validation must typecheck them
- raw/typed lift and lower must preserve operand order
- higher-level WAST parsing and lowering must reach them
- DCE and tree traversal must recurse through them

## Current Behavior

The local IR now models `stringref` as nullable `(ref null string)` and exposes
typed/raw instruction nodes for the eight array-backed string operators.

Validation rules implemented in `src/validate/typecheck.mbt`:

- `string.new_utf8_array`, `string.new_lossy_utf8_array`, and
  `string.new_wtf8_array` require a nullable ref to a concrete `array i8`,
  plus `i32 start` and `i32 end`, and produce `stringref`.
- `string.new_wtf16_array` requires a nullable ref to a concrete `array i16`,
  plus `i32 start` and `i32 end`, and produces `stringref`.
- `string.encode_utf8_array`, `string.encode_lossy_utf8_array`, and
  `string.encode_wtf8_array` require `stringref`, a nullable ref to a concrete
  mutable `array i8`, and `i32 start`, and produce `i32`.
- `string.encode_wtf16_array` requires `stringref`, a nullable ref to a
  concrete mutable `array i16`, and `i32 start`, and produces `i32`.
- abstract `(ref null array)` operands are rejected because these instructions
  need concrete element-storage information.

## Lift / Lower Surface

The slice now preserves these instructions across all currently modeled layers:

- `src/binary/encode.mbt` and `src/binary/decode.mbt`
  - heap type byte `0x64` for `string`
  - opcodes `0xFB 0xB0` through `0xFB 0xB7`
- `src/validate/env.mbt` and `src/lib/typed_body.mbt`
  - raw instruction to typed instruction lifting
  - typed instruction back to raw instruction lowering
- `src/wast/parser.mbt`, `src/wast/module_wast.mbt`, and
  `src/wast/lower_to_lib.mbt`
  - higher-level text parsing, printing, and lowering
  - `stringref` result and parameter spelling
  - `string` heap-type refs

`src/cmd/cmd.mbt` now also detects these instructions and heap types as
`has_strings`, which unblocks generated optimize feature plumbing for future
string-aware passes.

## DCE Impact

`src/optimization/optimization.mbt` and
`src/transformer/transformer.mbt` now recurse through the new three-child typed
string instructions. That closes the focused Binaryen-style regression where an
unreachable `local.tee` buried inside `string.new_wtf16_array` must still let
DCE preserve earlier side effects and collapse the node to unreachable.

## Validation Plan

The landed coverage includes:

- binary roundtrip tests for `string` heap types and the eight string ops
- validator tests for accepted and rejected array-storage combinations
- higher-level WAST lowering tests for `stringref`, `string.new_wtf16_array`,
  and `string.encode_utf8_array`
- generated-pipeline feature-fact coverage for `has_strings`
- DCE whitebox coverage for the `string.new_wtf16_array` / `local.tee`
  regression

## Performance Impact

The new instructions only add enum cases, type checks, and normal tree
traversal branches. No new whole-module analysis is introduced in this slice.

## Open Questions

- The broader `stringref` proposal surface is still not modeled locally.
  Notable missing areas include memory-backed string instructions,
  `string.const`, iter/view helpers, and any later pass behavior that depends on
  them.
- EH `try` / `pop` and stack-switching remain separate DCE follow-ups; this
  slice only removes the string-typed-surface blocker.
