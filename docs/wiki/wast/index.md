---
kind: concept
status: supported
last_reviewed: 2026-05-20
sources:
  - ../raw/wasm/2026-05-19-wast-control-flow-sources.md
  - ../raw/wasm/2026-05-19-wast-call-and-function-sources.md
  - ../raw/wasm/2026-05-19-wast-resource-declaration-sources.md
  - ../raw/wasm/2026-05-20-wast-gc-typeuse-and-subtype-sources.md
  - ../raw/wasm/2026-05-20-constant-expression-validation-sources.md
  - ../../README.md
related:
  - function-call-and-module-authoring.md
  - resource-declaration-authoring.md
  - gc-type-authoring.md
  - control-flow-authoring.md
  - reference-instruction-authoring.md
  - memory-instruction-authoring.md
  - ../validate/module-validation-phases.md
  - ../fuzzing/generator-coverage-ledger.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
---

# WAST Authoring Index

## Overview

This directory is the living guide for writing, reducing, and widening Starshine WAST fixtures. WAST is WebAssembly's text format as it appears in `.wat` / `.wast` files; Starshine's WAST layer parses human-readable text into the core `src/lib` module model, prints modules back to text, feeds the validator, and supplies fixture surfaces for passes and fuzzing.

Use this page when you know the kind of fixture you want but not the right focused page. Each child page owns one durable authoring contract and links onward to the exact parser, lowerer, core instruction, binary codec, validator, generator, arbitrary-WAST, pass, and raw-source evidence for that family.

## Layer Model

A WAST change usually crosses several layers. Keep the owner of each fact clear:

| Layer | Typical files | What it proves |
| --- | --- | --- |
| Text keywords and parser | [`src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`src/wast/parser.mbt`](../../../src/wast/parser.mbt) | The spelling is accepted and converted into WAST AST nodes. |
| WAST lowering and printing | [`src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt) | Source ids, labels, type uses, memory arguments, and module fields become core indices and can roundtrip through text. |
| Core and binary model | [`src/lib/types.mbt`](../../../src/lib/types.mbt), [`src/binary/decode.mbt`](../../../src/binary/decode.mbt), [`src/binary/encode.mbt`](../../../src/binary/encode.mbt) | The instruction or module field exists independent of text syntax and has stable binary behavior. |
| Validation | [`src/validate/validate.mbt`](../../../src/validate/validate.mbt), [`src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt) | The module is semantically valid or rejected with the intended diagnostic family. |
| Generation and fuzzing | [`src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt), [`src/wast/arbitrary.mbt`](../../../src/wast/arbitrary.mbt) | Random or coverage-forced surfaces can produce the shape; WAST arbitrary is a text-shape generator, not a full semantic oracle. |
| Optimizer and CFG | [`src/ir/`](../../../src/ir/), [`src/passes/`](../../../src/passes/) | A pass can safely move, delete, or rewrite the shape without invalidating control, stack, index, trap, or metadata invariants. |

Do not treat success in one layer as proof for another. For example, core/binary support for an instruction does not imply human-authored WAST text support; parse success does not imply validator acceptance; and generator coverage does not imply WAST arbitrary can print the same family.

## Where To Start

### Module structure and declarations

- [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md) — `(func ...)`, inline and explicit function imports/exports, `(start ...)`, direct `call`, and the function/type side of `call_indirect`.
- [`resource-declaration-authoring.md`](resource-declaration-authoring.md) — table, memory, and global declarations/imports/exports, global initializers, imported-prefix resource indices, and current memory64/shared text caveats.
- [`exception-tag-authoring.md`](exception-tag-authoring.md) — tag declarations and exception instructions, including `throw_ref` nullable operands and catch payloads.
- [`identifier-name-and-annotation-authoring.md`](identifier-name-and-annotation-authoring.md) — `$` source identifiers, name-section metadata, function annotations, and pass rewrite obligations.
- [`static-assertion-harness.md`](static-assertion-harness.md) — `.wast` script assertions, static-only evaluation, and pass/skip/fail policy for spec-runner use.

### Types, references, and GC proposal surfaces

- [`gc-type-authoring.md`](gc-type-authoring.md) — function/struct/array/rec types, `sub` / `final`, type-use syntax, flat type indices, and descriptor metadata caveats.
- [`reference-instruction-authoring.md`](reference-instruction-authoring.md) — `ref.null`, `ref.func`, null tests, equality, casts, reference branches, and current text gaps for ordinary `ref.test` / `ref.cast` / `br_on_*` forms.
- [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md) — struct constructors/gets, local descriptor constructors, i31 operations, and the current core/binary-only status of many `array.*` and `struct.set` forms.
- [`string-instruction-authoring.md`](string-instruction-authoring.md) — `string.const` plus Starshine's currently supported array-backed string helper operations.

### Control and calls

- [`control-flow-authoring.md`](control-flow-authoring.md) — `block`, `loop`, `if`, `br`, `br_if`, `br_table`, `return`, `unreachable`, label-depth lowering, and stack-polymorphic unreachable code.
- [`parametric-instruction-authoring.md`](parametric-instruction-authoring.md) — `drop`, untyped `select`, typed `select (result ...)`, reference-select, and local multi-value typed-select portability caveats.
- [`tail-call-authoring.md`](tail-call-authoring.md) — `return_call`, `return_call_indirect`, and `return_call_ref` across text, core, binary, validation, CFG, and generator layers.

### Memory, tables, data, and elements

- [`memory-argument-authoring.md`](memory-argument-authoring.md) — `offset=`, text-byte `align=`, selected memory index behavior, memory32/memory64 address widths, and the current text nonzero-memory-index gap.
- [`memory-instruction-authoring.md`](memory-instruction-authoring.md) — scalar loads/stores, `memory.size`, `memory.grow`, `memory.fill`, `memory.copy`, `memory.init`, and `data.drop`.
- [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md) — threads-proposal atomic loads/stores/RMW/wait/notify/fence; core/binary/validator/generator support with a current WAST keyword/parser gap.
- [`table-instruction-authoring.md`](table-instruction-authoring.md) — `call_indirect`, table get/set/size/grow/fill/copy/init, `elem.drop`, and table64 caveats.
- [`data-segment-authoring.md`](data-segment-authoring.md) — active/passive `(data ...)`, offsets, string payloads, conservative emitted `DataCntSec`, and pass guidance for data-index users.
- [`element-segment-authoring.md`](element-segment-authoring.md) — active/passive/declarative element segments, function-list versus typed-expression payloads, typed empty and non-`funcref` examples, table element abbreviation behavior, and current WAST gaps around declarative-mode preservation plus typed declarative text.

### Numeric, SIMD, and variables

- [`numeric-instruction-authoring.md`](numeric-instruction-authoring.md) — scalar numeric constants, tests, comparisons, arithmetic, conversions, reinterprets, sign-extension, and saturating truncations.
- [`simd-authoring.md`](simd-authoring.md) — `v128.const`, lane bounds, shuffle, SIMD memory args, relaxed-SIMD arities/spellings, and generator-versus-WAST coverage.
- [`variable-instruction-authoring.md`](variable-instruction-authoring.md) — `local.get` / `set` / `tee`, `global.get` / `set`, local/global index spaces, and immutable-`global.get` constant-expression policy.

## Current Caveat Map

The WAST pages deliberately keep text-surface gaps visible instead of smoothing them into generic support claims:

- **Reference branch and cast text:** ordinary `ref.test`, `ref.cast`, and `br_on_*` forms are core/binary/validator/generator-visible but not all human-authored WAST text forms are available; route through [`reference-instruction-authoring.md`](reference-instruction-authoring.md).
- **Aggregate instruction text:** many official `array.*` and `struct.set` families currently need core/binary/generator fixtures; route through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md).
- **Atomic text:** `0xFE` atomic instructions are core/binary/validator/generator-visible, while WAST keywords/parser cases are still absent; route through [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md).
- **Memory and table widths:** memory64/table64 behavior is often best proved at the core/binary layer until declaration and validation widening lands; route through [`memory-argument-authoring.md`](memory-argument-authoring.md), [`memory-instruction-authoring.md`](memory-instruction-authoring.md), and [`table-instruction-authoring.md`](table-instruction-authoring.md).
- **Declarative elements:** direct core/binary/generator paths preserve declarative mode, but current text lowering has a declarative-mode preservation gap and typed declarative text is not a proven WAST surface; route through [`element-segment-authoring.md`](element-segment-authoring.md).
- **Constant expressions:** official and Starshine-local initializer/offset allow-lists differ; route through [`../validate/constant-expressions.md`](../validate/constant-expressions.md) instead of duplicating the list here.

## Maintenance Rules

1. **Prefer focused pages over near-duplicates.** If a new WAST shape belongs to an existing family, update that page, its raw-source manifest if external evidence changed, this index, and [`../log.md`](../log.md).
2. **Keep source family boundaries explicit.** Official WebAssembly sources establish portable semantics; Starshine source files establish local parser/lowerer/validator/generator behavior; Binaryen pass pages establish optimizer-oracle behavior.
3. **Pair authoring docs with validation and fuzzing.** Parser-only support is not enough for a durable fixture. Link new shapes to [`../validate/module-validation-phases.md`](../validate/module-validation-phases.md), [`../fuzzing/generator-coverage-ledger.md`](../fuzzing/generator-coverage-ledger.md), and [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) when they affect validation or generation.
4. **Preserve traps, side effects, and index spaces.** Pass docs that use WAST examples should cite the family page that owns stack order, labels, memory/table/data/element indices, name metadata, and runtime traps.
5. **Record contradictions as caveats.** If official WebAssembly, a proposal, Binaryen, and Starshine disagree, keep the split visible with dates and source links.

## Sources

This catalog did not require a new raw-source ingest: it consolidates already-reviewed focused WAST pages and their committed manifests. The broad current source families are the official WebAssembly text/syntax/validation pages captured through the focused manifests under [`../raw/wasm/`](../raw/wasm/), Starshine's WAST implementation under [`../../../src/wast/`](../../../src/wast/), core/binary definitions under [`../../../src/lib/`](../../../src/lib/) and [`../../../src/binary/`](../../../src/binary/), validator surfaces under [`../../../src/validate/`](../../../src/validate/), and fuzzing/generator surfaces under [`../../../src/fuzz/`](../../../src/fuzz/).