---
kind: concept
status: supported
last_reviewed: 2026-06-02
sources:
  - ../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md
  - ../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md
  - ../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md
  - ../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md
  - ../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md
  - ../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md
  - ../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../string-lowering/index.md
---

# `string-lifting` import and call shapes

## Scope

This page catalogs the important module, global, function-import, and instruction shapes that Binaryen `string-lifting` transforms.
The examples are intentionally simplified; use them to understand the shape, then verify exact syntax against Binaryen's current printer when writing tests.

## Shape 1: magic imported string global

### Before

```wat
(module
  (global $hello (import "'" "hello") externref)
  (func (export "f") (result externref)
    (global.get $hello)))
```

### After

```wat
(module
  (func (export "f") (result externref)
    (string.const "hello")))
```

The lifted expression has string type, but an enclosing ABI type such as `externref` may remain wider unless a separate type-rewrite step changes it.

### Caveats

- The module string is configurable by `string-constants-module`; the lit test uses the magic import style.
- Literal identity comes from the import base string.
- Nonmatching import modules are not lifted.
- This is the safest first Starshine semantic slice because it only needs imported-global discovery plus currently modeled `string.const` output; see [`./starshine-port-readiness-and-validation.md`](./starshine-port-readiness-and-validation.md).

## Shape 2: numbered `string.const` global plus JSON custom section

### Before

Conceptually, default [`string-lowering`](../string-lowering/index.md) can produce imports like:

```wat
(global $s0 (import "string.const" "0") externref)
```

paired with a `string.consts` custom section that stores the JSON array of literals.

### After

A recognized `global.get $s0` becomes:

```wat
(string.const "...")
```

where the payload comes from entry `0` of the JSON array.

### Caveats

- This path is source-confirmed in `StringLifting.cpp`.
- The dedicated `string-lifting.wast` lit proof is more visually direct for magic imports than for this JSON custom-section path.
- A malformed, missing, or mismatched custom section should be treated as a correctness risk when building future tests.
- For Starshine, keep this as a separate second slice because it needs pass-facing `string.consts` custom-section parse/remove behavior.

## Shape 3: UTF-16 array to string helper

### Before

```wat
(import "wasm:js-string" "fromCharCodeArray" (func $fromCharCodeArray ...))
(func (result externref)
  (call $fromCharCodeArray ...))
```

### After

```wat
(string.new_wtf16_array ...)
```

### Caveats

- Binaryen requires the expected helper signature.
- A recognized helper name with the wrong expected signature is a fatal pass error, not an unchanged call.

## Shape 4: code point helper

### Before

```wat
(call $fromCodePoint (i32.const 65))
```

### After

```wat
(string.from_code_point (i32.const 65))
```

This is a direct value-level lift from an imported JavaScript helper into the wasm string opcode.

## Shape 5: concatenation

### Before

```wat
(call $concat
  (global.get $a)
  (global.get $b))
```

### After

```wat
(string.concat
  (string.const "a")
  (string.const "b"))
```

### Caveats

The upstream source keeps an explicit TODO around casts for string inputs.
If a child remains typed as `externref`, a future Starshine port must either preserve Binaryen's limitation honestly or add source-backed cast repair with tests.

## Shape 6: string encode back to array

### Before

```wat
(call $intoCharCodeArray
  (global.get $s)
  ...)
```

### After

```wat
(string.encode_wtf16_array
  (string.const "...")
  ...)
```

This is the opposite of the `fromCharCodeArray` family.

## Shape 7: equality, test, and compare

### Before

```wat
(call $equals (global.get $a) (global.get $b))
(call $test (global.get $x))
(call $compare (global.get $a) (global.get $b))
```

### After

```wat
(string.eq ...)
(string.test ...)
(string.compare ...)
```

### Caveats

- These rewrites depend on exact helper identity and signature.
- Do not conflate `string.test` with a generic null check; it is part of the recognized JS-string helper family.

## Shape 8: measure and indexing

### Before

```wat
(call $length (global.get $s))
(call $charCodeAt (global.get $s) (i32.const 0))
```

### After

```wat
(string.measure_wtf16 (string.const "..."))
(stringview_wtf16.get_codeunit ...)
```

Binaryen's printed names in `version_129` can expose string-view operations for indexing.
The conceptual rewrite is still helper-call-to-wasm-string-op.

## Shape 9: substring / slice

### Before

```wat
(call $substring (global.get $s) (i32.const 1) (i32.const 3))
```

### After

```wat
(stringview_wtf16.slice ...)
```

The precise wrapper shape depends on Binaryen's string-view representation and printer.
Future Starshine tests should compare normalized Binaryen output rather than relying only on hand-written syntax.

## Shape 10: wrong module negative

### Before

```wat
(import "not-wasm:js-string" "concat" (func $concat ...))
(func (call $concat ...))
```

### After

No rewrite.

### Why

`string-lifting` only recognizes the canonical helper module from `string-utils.h`.
A name match alone is insufficient.

## Shape 11: unknown helper name negative

### Before

```wat
(import "wasm:js-string" "somethingElse" (func $somethingElse ...))
(func (call $somethingElse ...))
```

### After

No rewrite.
Binaryen may warn for unknown helper names in the helper module, but it does not invent a string instruction.

## Shape 12: wrong helper signature fatal

### Before

```wat
(import "wasm:js-string" "concat" (func $concat (param i32 i32) (result i32)))
```

### After

Binaryen reports a fatal pass error for the recognized helper name with the wrong type.
There is no successful rewritten module.

### Why

The helper roster is not only name-based; recognized names must have exactly the expected imported function type. This differs from wrong modules and unknown helper names, which are preserved. The dedicated lit file directly proves wrong-module / wrong-name preservation, while this wrong-signature fatal behavior is source-confirmed from `StringLifting.cpp`.

## Mapping summary

| Input shape | Output shape | Evidence |
| --- | --- | --- |
| magic imported string global | `string.const` | source + lit |
| numbered `string.const` import plus `string.consts` JSON | `string.const` | source-confirmed |
| `fromCharCodeArray` call | `string.new_wtf16_array` | source + lit |
| `fromCodePoint` call | `string.from_code_point` | source + lit |
| `concat` call | `string.concat` | source + lit |
| `intoCharCodeArray` call | `string.encode_wtf16_array` | source + lit |
| `equals` call | `string.eq` | source + lit |
| `test` call | `string.test` | source + lit |
| `compare` call | `string.compare` | source + lit |
| `length` call | `string.measure_wtf16` | source + lit |
| `charCodeAt` call | string-view get | source + lit |
| `substring` call | string-view slice | source + lit |
| wrong module | unchanged | source + lit negatives |
| unknown helper name in `wasm:js-string` | warning plus unchanged | source + lit negatives |
| recognized helper name with wrong signature | fatal pass error | source-confirmed |

## Sources

- [`../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-06-02-string-lifting-current-main-recheck.md)
- [`../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md`](../../../raw/research/0697-2026-06-02-string-lifting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md`](../../../raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md)
- [`../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`](../../../raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md)
- [`../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md`](../../../raw/research/0385-2026-04-26-string-lifting-port-readiness.md)
- [`../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md`](../../../raw/binaryen/2026-04-24-string-lifting-primary-sources.md)
- [`../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`](../../../raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md)
- [`../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`](../../../raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md)
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
