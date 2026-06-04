# WAST Text-Surface Gap Ledger Source Bridge

Capture date: 2026-06-04

Purpose: support the living WAST text-surface gap ledger at `docs/wiki/wast/text-surface-gap-ledger.md`. This bridge consolidates official WebAssembly text/syntax/validation sources, threads-proposal atomic text evidence, focused wiki pages, and current Starshine WAST implementation evidence. It is a routing source, not a replacement for the focused family pages.

## Primary external sources rechecked

- WebAssembly Core 3.0 text instructions, dated 2026-06-04: <https://webassembly.github.io/spec/core/text/instructions.html>
  - Rechecked official text forms for ordinary `ref.test` / `ref.cast`, aggregate `struct.set` and `array.*` instruction families, table/memory instruction spellings, structured control, tail-call forms, `try_table`, and folded instruction conventions.
- WebAssembly Core 3.0 syntax instructions, dated 2026-06-04: <https://webassembly.github.io/spec/core/syntax/instructions.html>
  - Rechecked that `br_on_null`, `br_on_non_null`, `br_on_cast`, `br_on_cast_fail`, ordinary `call_ref`, tail-call variants, table instructions, memory instructions, and exception instructions are core instruction families independent of any one implementation's WAST parser.
- WebAssembly Core 3.0 validation instructions, dated 2026-06-04: <https://webassembly.github.io/spec/core/valid/instructions.html>
  - Rechecked reference cast/test validation, memory/table address-width typing, `memory.fill` / `memory.copy` / `memory.init`, and `table.copy` / `table.init` positional operand-width rules.
- WebAssembly Core 3.0 text modules, dated 2026-06-04: <https://webassembly.github.io/spec/core/text/modules.html>
  - Rechecked inline import/export abbreviations for resources and functions plus element segment text forms, including typed passive/active/declarative `elem` grammar and the `declare` mode.
- WebAssembly Threads draft core spec, current public draft surfaced at <https://webassembly.github.io/threads/core/> and syntax page <https://webassembly.github.io/threads/core/syntax/instructions.html>
  - Rechecked linear-memory atomic text families (`i32.atomic.load`, atomic stores/RMW/cmpxchg, `memory.atomic.wait*`, `memory.atomic.notify`, and standalone `atomic.fence`).

## Focused Starshine wiki/raw sources reused

- `docs/wiki/wast/index.md`
- `docs/wiki/wast/reference-instruction-authoring.md`
- `docs/wiki/wast/function-call-and-module-authoring.md`
- `docs/wiki/wast/gc-aggregate-instruction-authoring.md`
- `docs/wiki/wast/atomic-memory-instruction-authoring.md`
- `docs/wiki/wast/memory-argument-authoring.md`
- `docs/wiki/wast/memory-instruction-authoring.md`
- `docs/wiki/wast/table-instruction-authoring.md`
- `docs/wiki/wast/resource-declaration-authoring.md`
- `docs/wiki/wast/element-segment-authoring.md`
- `docs/wiki/wast/code-metadata-and-function-annotations.md`
- `docs/wiki/fuzzing/wast-arbitrary-parity-plan.md`
- `docs/wiki/fuzzing/generator-coverage-ledger.md`
- `docs/wiki/validate/memory-table-address-widths.md`
- `docs/wiki/validate/local-spec-divergence-ledger.md`
- `docs/wiki/raw/wasm/2026-06-04-reference-call-and-cast-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-struct-atomic-get-sources.md`
- `docs/wiki/raw/wasm/2026-06-04-linear-atomics-fence-unshared-reconciliation.md`
- `docs/wiki/raw/wasm/2026-06-04-linear-memory-threads-shared-memory-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-memory-table-address-width-validation-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-element-segment-current-refresh.md`
- `docs/wiki/raw/wasm/2026-06-04-custom-name-annotation-current-refresh.md`

## Repository evidence rechecked

- `src/wast/keywords.mbt`
  - Current keyword table registers `return_call`, `return_call_indirect`, `return_call_ref`, `ref.null`, `ref.is_null`, `ref.func`, `ref.eq`, `ref.as_non_null`, string helper names, `any.convert_extern`, `extern.convert_any`, `ref.i31`, `i31.get_s`, `i31.get_u`, `struct.new*`, `struct.get*`, focused `struct.atomic.get*`, descriptor local forms, table instructions, ordinary scalar memory instructions, `memory.copy` / `memory.init` / `data.drop`, numeric/SIMD/variable instructions, and static script assertions.
  - It does not register ordinary `call_ref`, ordinary `ref.test` / `ref.cast`, `br_on_*`, `struct.set`, `array.*`, or linear-memory atomic text keywords.
- `src/wast/parser.mbt`
  - Current parser has focused cases for `struct.atomic.get*`, descriptor reference forms, return-call forms, resource declarations, and narrow declarative element abbreviation parsing through `declare func`.
  - The annotation lane parses `(@...)` before module fields and only function/func-import attachment is supported downstream; official placement-aware `@name`, `@custom`, and expression-level code metadata are not modeled as their official effects.
- `src/wast/lower_to_lib.mbt`
  - Lowering resolves supported WAST text surfaces into core `@lib.Instruction` and module-section carriers, including return calls, descriptor forms, and `struct.atomic.get*`.
- `src/wast/module_wast.mbt`
  - Printing mirrors supported local WAST surfaces such as return calls, descriptor forms, and focused `struct.atomic.get*`; unsupported core/binary-only instruction families have no high-level WAST print guarantee.
- `src/lib/types.mbt`, `src/binary/decode.mbt`, `src/binary/encode.mbt`, `src/validate/typecheck.mbt`, and `src/validate/gen_valid.mbt`
  - Core, binary, validator, and valid-generator support are wider than WAST text for several families: ordinary reference casts/branches, `call_ref`, aggregate arrays and `struct.set`, linear-memory atomics, memory64/table64 resource behavior, and data/element-backed GC-array operations.

## Durable conclusions

1. Starshine needs a dedicated WAST text-surface gap ledger because the existing validator divergence ledger intentionally does not list every parser/printer gap.
2. The correct maintenance unit is a cross-linking ledger that routes each gap to a focused owner page and source bridge, not another full explanation of every instruction's semantics.
3. A WAST text gap is not evidence that Starshine lacks core, binary, validation, generator, or optimizer support. The ledger should teach fixture authors where to use WAST, direct core builders, binary bytes, generator evidence, or a parser/lowerer/printer widening slice.
4. When a text gap closes, update the focused family page first, then this ledger, `docs/wiki/wast/index.md`, `docs/wiki/fuzzing/wast-arbitrary-parity-plan.md` when arbitrary text generation is affected, and `docs/wiki/log.md`.
