---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - ../raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md
  - ../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md
  - ../raw/wasm/2026-06-04-wast-text-surface-gap-ledger-source-bridge.md
  - ../raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md
  - ../raw/wasm/2026-06-04-struct-atomic-get-sources.md
  - ../raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md
  - ../raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - ../raw/wasm/2026-06-04-element-segment-current-refresh.md
  - ../raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md
  - ../../../src/wast/keywords.mbt
  - ../../../src/wast/parser.mbt
  - ../../../src/wast/lower_to_lib.mbt
  - ../../../src/wast/module_wast.mbt
  - ../../../src/lib/types.mbt
  - ../../../src/validate/typecheck.mbt
  - ../../../src/validate/gen_valid.mbt
related:
  - index.md
  - reference-instruction-authoring.md
  - function-call-and-module-authoring.md
  - gc-aggregate-instruction-authoring.md
  - atomic-memory-instruction-authoring.md
  - memory-argument-authoring.md
  - resource-declaration-authoring.md
  - element-segment-authoring.md
  - data-segment-authoring.md
  - code-metadata-and-function-annotations.md
  - ../fuzzing/wast-arbitrary-parity-plan.md
  - ../validate/local-spec-divergence-ledger.md
---

# WAST Text-Surface Gap Ledger

## Overview

Use this ledger when a fixture, reducer, fuzz corpus entry, or pass regression needs a WebAssembly shape that exists in Starshine's core model but may not be authorable as human-written WAST text today.

For beginners: **WAST** is a text syntax. Starshine has several deeper layers after text parsing: a core module/instruction model, binary encode/decode, validation, generators, and optimizer passes. A shape can be real in those deeper layers while still missing from the high-level WAST keyword/parser/printer path. When that happens, use a direct core builder, binary fixture, or generated module until a WAST widening slice lands.

The source bridge for this ledger is [`../raw/wasm/2026-06-04-wast-text-surface-gap-ledger-source-bridge.md`](../raw/wasm/2026-06-04-wast-text-surface-gap-ledger-source-bridge.md). It rechecked current WebAssembly Core 3.0 text/syntax/validation pages, the threads atomic draft, focused Starshine WAST pages, and current `src/wast` keyword/parser/lowerer/printer evidence. Numeric data-segment payload syntax is separately routed through [`../raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md`](../raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md) because it is active-proposal text, not a Core-vs-local layer gap.

This page is deliberately a **navigation layer**. Keep detailed semantics on focused family pages. Keep validator semantic divergences on [`../validate/local-spec-divergence-ledger.md`](../validate/local-spec-divergence-ledger.md).

## How To Classify A Shape

| If the needed shape is... | Use first | Why |
| --- | --- | --- |
| Accepted by `src/wast` and the goal is text/lowering/debuggability | WAST fixture | Parser, lowerer, printer, and validator all see the source structure. |
| In `src/lib/types.mbt` / binary / validator but absent from `src/wast/keywords.mbt` | Direct core fixture, binary fixture, or `gen_valid` | It is current Starshine behavior, but not current WAST text behavior. |
| Accepted by WAST parser but rejected by validation | WAST negative or local/spec-divergence fixture | Parser support is not semantic support. Route through the validator page that owns the rejection. |
| Official WebAssembly text exists, but Starshine WAST lacks it | WAST widening task first | Add keyword/parser/lowerer/printer/tests before treating it as ordinary text fixture evidence. |
| Only Binaryen or proposal text uses it | Binaryen/proposal-source page | Do not describe it as Starshine WAST support without local code evidence. |

## Current Ledger

| Family | Official / upstream shape | Current Starshine WAST text status | Deeper Starshine status | Fixture and maintenance route |
| --- | --- | --- | --- | --- |
| Ordinary reference casts and branches | `ref.test`, `ref.cast`, `br_on_null`, `br_on_non_null`, `br_on_cast`, `br_on_cast_fail` | Missing as ordinary WAST text keywords. Descriptor-local `ref.test_desc*` / `ref.cast_desc_eq*` are separate supported forms. | Core, binary, validator, and valid-generator know these families. | Use core/binary/generated fixtures; route semantics through [`reference-instruction-authoring.md`](reference-instruction-authoring.md). Add WAST keyword/parser/lowerer/printer coverage before widening WAST arbitrary. |
| Ordinary non-tail reference calls | `call_ref` | Missing as ordinary WAST text. `return_call_ref` text is supported. | Core, binary, validator, and generator support ordinary `call_ref`; `ref.func` declaration rules remain separate. | Use core/binary/generated fixtures; route call semantics through [`function-call-and-module-authoring.md`](function-call-and-module-authoring.md) and tail forms through [`tail-call-authoring.md`](tail-call-authoring.md). |
| GC aggregate mutation and arrays | `struct.set`, `array.new*`, `array.get*`, `array.set`, `array.len`, `array.fill`, `array.copy`, `array.init_*` | Missing as high-level WAST text. Struct constructors/gets, i31, conversions, descriptor constructors, `ref.get_desc`, and focused `struct.atomic.get*` are supported. | Core, binary, validator, valid-generator, and several passes use many of these instructions. | Use core/binary/generated fixtures; route through [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md). For data/element-backed arrays also use [`data-segment-authoring.md`](data-segment-authoring.md), [`element-segment-authoring.md`](element-segment-authoring.md), and [`../validate/data-count-and-code-data-indices.md`](../validate/data-count-and-code-data-indices.md). |
| Linear-memory atomics | `i32.atomic.load`, atomic stores/RMW/cmpxchg, `memory.atomic.wait*`, `memory.atomic.notify`, `atomic.fence` | Missing as WAST keywords/parser cases. | Core/binary/validator/generator support the current local subset. `atomic.fence` is no-memory/no-`MemArg`; `MemArg` atomics use the local shared-memory gate. | Use core/binary/generated fixtures; route through [`atomic-memory-instruction-authoring.md`](atomic-memory-instruction-authoring.md). Do not confuse this with supported shared-GC `struct.atomic.get*` text on [`gc-aggregate-instruction-authoring.md`](gc-aggregate-instruction-authoring.md). |
| Memory64/table64 declarations and selected resource text | memory64/table64 resource declarations, nonzero selected memories in text memory ops, broad multi-memory text | Narrow current WAST declaration and memarg support; many memory64/table64 positives need core/binary/generator fixtures. | Core/resource/binary and parts of validator represent `I64Limits` and address-width behavior; some validator table/memory instruction gaps remain documented. | Route declaration text through [`resource-declaration-authoring.md`](resource-declaration-authoring.md), memargs through [`memory-argument-authoring.md`](memory-argument-authoring.md), runtime stack widths through [`memory-instruction-authoring.md`](memory-instruction-authoring.md) / [`table-instruction-authoring.md`](table-instruction-authoring.md), and validator status through [`../validate/memory-table-address-widths.md`](../validate/memory-table-address-widths.md). |
| Inline resource import shorthand and inline memory-data abbreviation | `(memory (import ...))`, `(table (import ...))`, `(global (import ...))`, memory-data abbreviation syntax | Function/tag paths differ, but table/memory/global inline import shorthand and inline memory-data abbreviation are not current Starshine fixture surfaces. | Explicit import fields, explicit exports, separate memory/data fields, and lowered resource index spaces work. | Prefer explicit import/export and separate data fields; route through [`resource-declaration-authoring.md`](resource-declaration-authoring.md) and [`data-segment-authoring.md`](data-segment-authoring.md). |
| Numeric data-segment payload groups | Active Phase-2 proposal spellings such as `(i8 ...)`, `(i32 ...)`, `(f32 ...)`, and `v128` groups inside `(data ...)` | Not current Starshine WAST parser/printer syntax; current data payload text is string-token concatenation. | Core/binary data payloads are byte vectors, so equivalent bytes can be represented without proposal text. | Use escaped strings, core builders, or binary fixtures; route proposal status and future widening tests through [`data-segment-authoring.md`](data-segment-authoring.md) and [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). |
| Typed declarative element text and mode preservation | Broader typed declarative element lists plus declarative mode | Parser supports narrow `elem declare func ...`; current WAST lowering still has a declarative-mode preservation gap and no proven broad typed-declarative text surface. | Core/binary/generator can represent declarative mode and typed element payloads more broadly. | Use direct core/binary fixtures when the mode/header is the evidence; route through [`element-segment-authoring.md`](element-segment-authoring.md). |
| Official name/custom annotations and expression-level code metadata | `@name`, `@custom`, `@metadata.code.*`, `metadata.code.branch_hint` | Current `(@...)` lane attaches only to function definitions/imports and lowers to `FuncAnnotationSec`; it does not implement official name/custom placement, placement-aware custom sections, or expression metadata effects. | Official custom annotation syntax and branch hints are finished/Core-3.0 metadata surfaces, but Starshine only has binary custom/name sections plus local function annotations today. Binaryen metadata behavior remains source-oracle evidence unless local code is cited. | Route local function annotations through [`code-metadata-and-function-annotations.md`](code-metadata-and-function-annotations.md), binary name/custom behavior through [`../binary/custom-and-name-sections.md`](../binary/custom-and-name-sections.md), and feature-status wording through [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). |
| Stringref proposal breadth | Full active stringref proposal instruction family | Starshine WAST supports `string.const` plus a supported array-backed helper subset, not the full active proposal. | Core/binary/string-section behavior is local/proposal-shaped and not stable Core 3.0. | Route through [`string-instruction-authoring.md`](string-instruction-authoring.md), [`../strings/string-const-surface.md`](../strings/string-const-surface.md), and [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md). |

## Widening Workflow

When closing one of these gaps:

1. **Start with the focused page.** For example, ordinary `ref.cast` text belongs on [`reference-instruction-authoring.md`](reference-instruction-authoring.md), not in this ledger first.
2. **Add tests at the text layer before changing claims.** A complete WAST widening usually needs keyword, parser, lowering, printer, and roundtrip or WAST-to-module tests in `src/wast`, then validator tests when the shape should validate.
3. **Keep arbitrary WAST behind real text support.** Update [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md) only after supported syntax can parse and print.
4. **Keep generator evidence separate.** `gen_valid` support proves core valid-module coverage; it does not prove the text printer can emit the same shape.
5. **Update navigation together.** Refresh the focused page, this ledger when the gap status changes, [`index.md`](index.md), the top-level [`../index.md`](../index.md), and [`../log.md`](../log.md).

## Common Mistakes

- Saying “Starshine does not support `X`” when only WAST text lacks `X`. Prefer “WAST text gap; core/binary/validator support exists” when that is true.
- Treating parser success as validator success. The parser can accept local/proposal-shaped text that validation later rejects.
- Adding a WAST arbitrary token before parser/printer/lowerer support exists.
- Using Binaryen WAT examples with branch hints, ordinary `call_ref`, arrays, or atomics as Starshine text fixtures without checking `src/wast/keywords.mbt` and the focused WAST page.
- Hiding local/spec splits in a broad “Wasm supports this” sentence. Name the layer: official Core, active proposal, Binaryen oracle, Starshine WAST, Starshine core/binary, validator, generator, or pass.

## Source Map

- Code-metadata / branch-hint status bridge: [`../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](../raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md)
- Numeric data-segment proposal routing: [`../raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md`](../raw/wasm/2026-06-05-wat-numeric-data-segments-routing.md)
- Source bridge: [`../raw/wasm/2026-06-04-wast-text-surface-gap-ledger-source-bridge.md`](../raw/wasm/2026-06-04-wast-text-surface-gap-ledger-source-bridge.md)
- WAST implementation: [`../../../src/wast/keywords.mbt`](../../../src/wast/keywords.mbt), [`../../../src/wast/parser.mbt`](../../../src/wast/parser.mbt), [`../../../src/wast/lower_to_lib.mbt`](../../../src/wast/lower_to_lib.mbt), [`../../../src/wast/module_wast.mbt`](../../../src/wast/module_wast.mbt)
- Core/validator/generator evidence: [`../../../src/lib/types.mbt`](../../../src/lib/types.mbt), [`../../../src/validate/typecheck.mbt`](../../../src/validate/typecheck.mbt), [`../../../src/validate/gen_valid.mbt`](../../../src/validate/gen_valid.mbt)
- Navigation companions: [`index.md`](index.md), [`../validate/local-spec-divergence-ledger.md`](../validate/local-spec-divergence-ledger.md), [`../fuzzing/wast-arbitrary-parity-plan.md`](../fuzzing/wast-arbitrary-parity-plan.md), [`../wasm-feature-status-and-proposal-boundaries.md`](../wasm-feature-status-and-proposal-boundaries.md)
