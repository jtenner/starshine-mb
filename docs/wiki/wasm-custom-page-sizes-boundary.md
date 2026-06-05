---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md
  - raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md
  - raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md
  - raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md
  - ../../src/lib/types.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/validate/validate.mbt
  - ../../src/validate/match.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/lower_to_lib.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - binary/type-table-memory-global-tag-sections.md
  - validate/resource-sections-and-limits.md
  - validate/import-export-and-external-type-matching.md
  - wast/resource-declaration-authoring.md
  - wast/memory-instruction-authoring.md
  - binaryen/passes/multi-memory-lowering/index.md
  - binaryen/passes/memory64-lowering/index.md
---

# WebAssembly Custom Page Sizes Boundary

## Overview

Custom Page Sizes is a WebAssembly active proposal for linear memories whose page size is not the ordinary 64 KiB. It is related to memory32/memory64, shared memory, and selected-memory / multi-memory behavior, but it is a separate memory-type dimension; route that selected-memory axis through [`wasm-multi-memory-boundary.md`](wasm-multi-memory-boundary.md) rather than through Binaryen `multi-memory-lowering`:

- **address width** decides whether addresses and page counts use `i32` or `i64`;
- **sharedness** decides whether the memory is a threads/shared-memory memory and whether Starshine requires a maximum;
- **page size** decides how many bytes one logical page represents.

Current Starshine has explicit local representations for address width and sharedness, but **no local representation for custom page size**. Therefore custom-page-size examples are proposal-status or future-port evidence only until the core module model, binary codec, validator, WAST surface, external-type matching, generator, and pass helpers are deliberately widened.

The current source bridge is [`raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md). It rechecked the official proposals repository, the custom-page-sizes proposal repository/overview, current Core memory-type pages, and Starshine's memory type, binary, validator, WAST, and matching sources.

## Beginner model

Ordinary WebAssembly memory sizes are counted in pages. In stable Core WebAssembly, a memory declared as:

```wat
(memory 2 4)
```

means a minimum of two pages and a maximum of four pages. For ordinary pages, each page is 64 KiB, so the initial byte capacity is `2 * 65536` bytes.

Custom Page Sizes adds a proposal-facing idea: a memory may choose a different page size, currently with an intentionally narrow proposal validity set around `1` byte and `65536` bytes. That would change the byte meaning of page counts and would matter for `memory.size`, `memory.grow`, active data offsets, memory-lowering passes, and any size/profitability helper that assumes `page_count << 16`.

## Current Starshine layer map

| Layer | Current Starshine state | Why custom page sizes are not supported yet |
| --- | --- | --- |
| Core memory type | [`MemType(Limits, Bool)`](../../src/lib/types.mbt) | Stores `Limits` plus sharedness only; no page-size field. |
| Binary decode | [`Decode for Limits`](../../src/binary/decode.mbt), [`Decode for MemType`](../../src/binary/decode.mbt) | Accepts only ordinary memory32, memory64, and shared-memory flag bytes; no custom-page-size flag/immediate branch. |
| Binary encode | [`Encode for Limits`](../../src/binary/encode.mbt), [`Encode for MemType`](../../src/binary/encode.mbt) | Emits only the same ordinary/memory64/shared-memory flag matrix. |
| Resource validation | [`Validate for MemType`](../../src/validate/validate.mbt) | Checks range bounds and Starshine's shared-memory maximum rule; no page-size validation dimension. |
| External-type matching | [`Match for MemType`](../../src/validate/match.mbt) | Compares limits and sharedness only; cannot enforce page-size equality. |
| WAST declarations | [`parse_limits(...)`](../../src/wast/parser.mbt), [`wt_limits(...)`](../../src/wast/lower_to_lib.mbt) | Parses natural min/max limits and lowers through `Limits::i32`; no `(pagesize ...)` or equivalent text form. |
| Valid generator / fuzzing | [`src/validate/gen_valid.mbt`](../../src/validate/gen_valid.mbt) | Uses current `MemType`/`Limits` vocabulary; no `GenValidProposalFeature` for custom page sizes is documented. |
| Passes | Memory pass helpers and Binaryen dossiers | Some Binaryen source contracts mention matching page size, but local passes cannot inspect or preserve a page-size field that does not exist. |

## How to phrase claims

Use precise layer wording:

- “Custom Page Sizes is an active proposal; Starshine does not currently model page size in `MemType`.”
- “This Binaryen pass requires same page size upstream, but current Starshine memory types have no page-size field, so a faithful local port would need a representation decision first.”
- “A memory64 or shared-memory fixture is not custom-page-size evidence. Address width, sharedness, and page size are distinct.”
- “Current Starshine memory page arithmetic assumes ordinary 64 KiB pages unless a future custom-page-size slice says otherwise.”

Avoid wording such as “Starshine supports custom page sizes” or “this memory64/shared-memory test covers custom page sizes.”

## Future implementation checklist

A credible Starshine custom-page-size slice would need to update and test all of these together:

1. **Core representation:** add a page-size carrier to memory types and decide how it composes with `I32Limits`, `I64Limits`, and `shared`.
2. **Binary codec:** decode and encode the proposal's custom-page-size flag/immediate shape, with malformed-byte tests that keep unknown flags distinct from ordinary invalid limits.
3. **Validator:** validate allowed page sizes, keep memory limit range checks byte/page-aware, and decide how shared-memory maxima interact with custom page size.
4. **External matching:** make page size part of memory import/export compatibility once the representation exists.
5. **WAST:** add parser/lowerer/printer syntax only after choosing the local text policy; until then, use core/binary fixtures for any proposal experiments.
6. **Instructions and passes:** audit `memory.size`, `memory.grow`, active data layout, memory-packing, multi-memory-lowering, memory64-lowering, and any helper that converts pages to bytes with `<< 16`.
7. **Fuzzing and docs:** add a feature gate, generator coverage row, invalid/repro strategy, focused wiki updates, and compare-pass caveats before treating it as ordinary generated coverage.

## Related boundaries

- Memory64/table64 address-width behavior: [`validate/memory-table-address-widths.md`](validate/memory-table-address-widths.md)
- Shared linear memory and atomics: [`wast/atomic-memory-instruction-authoring.md`](wast/atomic-memory-instruction-authoring.md), [`validate/resource-sections-and-limits.md`](validate/resource-sections-and-limits.md)
- Binary resource sections and memory flags: [`binary/type-table-memory-global-tag-sections.md`](binary/type-table-memory-global-tag-sections.md)
- WAST memory declarations: [`wast/resource-declaration-authoring.md`](wast/resource-declaration-authoring.md)
- Upstream Binaryen multi-memory page-size caveat: [`binaryen/passes/multi-memory-lowering/index.md`](binaryen/passes/multi-memory-lowering/index.md)

## Sources

- Current source bridge: [`raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md`](raw/wasm/2026-06-05-custom-page-sizes-boundary-refresh.md)
- Active proposal routing bridge: [`raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md`](raw/wasm/2026-06-04-webassembly-active-proposal-routing-current-refresh.md)
- Core/resource implementation: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/validate/validate.mbt`](../../src/validate/validate.mbt), [`../../src/validate/match.mbt`](../../src/validate/match.mbt), [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt)
