---
kind: concept
status: supported
last_reviewed: 2026-04-21
sources:
  - ../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
---

# `string-lowering`: JSON custom sections and magic imports

This page covers the most non-obvious part of Binaryen `string-lowering`: how literal payloads survive after defining string globals stop being real `StringConst` initializers.

## The problem this page answers

After gathering, Binaryen has canonical defining globals like:

```wat
(global $g (ref string) (string.const "foo"))
```

But lowering wants to remove the wasm string feature from the module.
So it cannot keep that initializer forever.
It needs another place to remember the literal payload.

Binaryen `version_129` supports two answers:

- numbered imports plus a JSON custom section
- magic imports for well-formed strings

## Default mode: numbered imports plus `string.consts`

In the default mode, Binaryen lowers defining globals into imports with:

- module `"string.const"`
- base `"0"`, `"1"`, `"2"`, ...

and writes the literal payloads into a custom section named:

- `string.consts`

whose contents are a JSON array.

The manual `string-lowering.wast` file proves this explicitly.

## Why JSON exists here

Once the global initializer is gone, the import alone no longer contains the original literal bytes.
The custom section is therefore the side channel that preserves the literal list for consumers that understand this lowering convention.

That makes the custom section part of the real pass contract, not an incidental debugging note.

## Escaping and deduplication rules

The manual test proves several concrete details:

- repeated literals appear only once in the JSON array
- tabs, NUL, quotes, backslashes, CR/LF, and non-ASCII text are JSON-escaped correctly
- surrogate-pair and unpaired-surrogate families are represented in JSON form

The helper script `string-lowering.js` then proves those bytes can be:

- extracted from the wasm custom section
- decoded as UTF-8
- parsed with `JSON.parse`

## Magic-import mode

The public pass variant:

- `string-lowering-magic-imports`

tries to avoid JSON-backed numbered imports for literals that can safely become import names.

In that mode, Binaryen uses:

- the configured string-constants module name
- the converted UTF-8 literal text as the import base

This is more direct, but only works for literals Binaryen accepts for that path.

## Invalid-string fallback

Magic-import mode does **not** mean "all strings become magic imports".
The manual test proves the fallback rule:

- well-formed strings can use magic imports
- invalid or non-usable strings remain JSON-backed instead

That is why the `MAGIC` check in the test still expects a smaller `string.consts` custom section containing only the invalid-string cases.

## Assert mode

The public pass variant:

- `string-lowering-magic-imports-assert`

changes the fallback rule into a hard error.

Instead of falling back to JSON for invalid strings, it raises a fatal error.
The manual test proves this with the unpaired-surrogate family.

## Practical teaching rule

If someone asks "how does Binaryen keep the actual string data after lowering?", the short truthful answer is:

- default mode: numbered `string.const` imports plus JSON custom section
- magic-import mode: direct import names for good strings, JSON only for leftovers
- assert mode: direct import names or fail

## Sources

- [`../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md`](../../../raw/research/0215-2026-04-21-string-lowering-binaryen-research.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLowering.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.wast>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lowering.js>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLowering.cpp>
