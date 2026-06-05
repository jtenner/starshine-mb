---
kind: concept
status: supported
last_reviewed: 2026-06-05
sources:
  - raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md
  - raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md
  - raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md
  - wast/code-metadata-and-function-annotations.md
  - binary/custom-and-name-sections.md
  - ../../src/lib/types.mbt
  - ../../src/wast/parser.mbt
  - ../../src/wast/lower_to_lib.mbt
  - ../../src/binary/decode.mbt
  - ../../src/binary/encode.mbt
  - ../../src/passes/no_inline.mbt
  - ../../src/passes/inlining.mbt
related:
  - wasm-feature-status-and-proposal-boundaries.md
  - wast/code-metadata-and-function-annotations.md
  - binary/custom-and-name-sections.md
  - binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md
---

# WebAssembly Compilation Hints Boundary

## Overview

Use this page when a fixture, external source, pass note, or future implementation plan mentions **Compilation Hints** or proposal names such as:

- `metadata.code.compilation_priority`
- `metadata.code.instr_freq`
- `metadata.code.call_targets`
- `never_opt`, `always_opt`, hotness, profile, or likely-call-target hints

Compilation Hints is an **active Phase-2 WebAssembly proposal** as of the 2026-06-05 source check, not stable Core 3.0 and not current Starshine optimizer behavior. The source bridge is [`raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md`](raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md).

For beginners: a compilation hint is metadata that tells a compiler how important or hot some code is likely to be. It should not change what the program computes. That makes it very different from a normal instruction such as `i32.add`, and it also makes it dangerous for optimizer docs: a pass may be allowed to ignore a hint, but if it uses a hint to rewrite code, the rewrite still needs a normal semantic proof.

## What The Proposal Adds

The proposal extends the code-metadata family with custom sections named `metadata.code.*`. The current overview describes three first-version hint families:

| Hint family | Shape | Intended meaning | Current Starshine status |
| --- | --- | --- | --- |
| `metadata.code.compilation_priority` | Function-level hint at byte offset `0`. | Suggests compile order and optional optimization priority / hotness for a function. | No first-class parser, binary model, validator, generator, or optimizer consumer. |
| `metadata.code.instr_freq` | Instruction-location hint. | Suggests relative execution frequency for calls, `call_ref`, `call_indirect`, or loops. | No instruction-offset metadata model or pass consumer. |
| `metadata.code.call_targets` | Instruction-location hint with target function indices plus frequencies. | Suggests likely dynamic targets for `call_ref` / `call_indirect`. | No target-list parser/model, no remap rules, and no inliner/directizer consumer. |

The proposal gives both binary custom-section forms and WAT annotation-style examples. Those examples are proposal evidence only until Starshine implements the exact layer being claimed.

## Boundary Against Similar Metadata

| Similar surface | Why it is different |
| --- | --- |
| [`metadata.code.branch_hint`](wast/code-metadata-and-function-annotations.md#branch-hints-and-expression-annotations) | Branch hints are now routed as finished/Core-3.0 code metadata. Compilation Hints remains an active proposal and adds different payloads. |
| Starshine `(@...)` before a function/import | Current Starshine WAST lowers this narrow local lane to `FuncAnnotationSec`. It is not byte-offset code metadata and cannot attach to arbitrary instructions. |
| `(@metadata.code.inline "\00")` in Binaryen examples | Starshine can carry the spelling as a raw function annotation when attached to a function/import, but it does not implement Binaryen's full expression-level code-annotation model. |
| Starshine no-inline passes | [`src/passes/no_inline.mbt`](../../src/passes/no_inline.mbt) creates local `starshine.no-full-inline` / `starshine.no-partial-inline` annotations. [`src/passes/inlining.mbt`](../../src/passes/inlining.mbt) consumes those local markers, not proposal compilation hints. |
| Opaque custom-section preservation | [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md) documents that non-`name` custom sections can be preserved as `CustomSec`. Preserving a `metadata.code.*` payload is not the same as decoding, validating, remapping, or honoring it. |

## Current Starshine Layer Map

| Layer | Current evidence | Interpretation |
| --- | --- | --- |
| Core/in-memory module model | [`FuncAnnotationSec`](../../src/lib/types.mbt) exists, but there is no placement-bearing code-metadata table for function-body byte offsets or instruction IDs. | Function/import annotations are local metadata only. |
| WAST parser/lowerer | [`src/wast/parser.mbt`](../../src/wast/parser.mbt) accepts `(@...)` only before functions or func imports; [`src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt) lowers annotation names/args without interpreting them. | A proposal-spelled annotation before a function may be carried as raw local metadata, but structured hint grammar and instruction placement are unsupported. |
| Binary codec | [`src/binary/decode.mbt`](../../src/binary/decode.mbt) and [`src/binary/encode.mbt`](../../src/binary/encode.mbt) preserve ordinary non-`name` custom sections opaquely. | Starshine does not decode or re-encode compilation-hint payloads as typed records. |
| Validation | Custom sections are metadata; current validation has no compilation-hint phase or payload checker. | Do not cite validation success as proof that hints are understood. |
| Optimizer passes | Local inlining/no-inline code reads `FuncAnnotationSec` marker names it owns. | No pass consumes `compilation_priority`, `instr_freq`, call-target percentages, `never_opt`, or `always_opt` proposal semantics. |
| Fuzzing/generator | No dedicated `GenValidProposalFeature` gate or feature-fact row for Compilation Hints. | Any future fuzzer support needs a named metadata surface and roundtrip/remap policy first. |

## Examples

### Proposal-style function-level hint

```wat
(module
  ;; Proposal evidence only today. Starshine may carry this spelling as a raw
  ;; function annotation if the parser accepts the tokens, but it does not turn
  ;; it into a typed compilation-priority record or optimizer policy.
  (@metadata.code.compilation_priority (compilation 1) (optimization 10))
  (func $hot (result i32)
    (i32.const 1)))
```

### Proposal-style instruction-level hint

```wat
(module
  (type $sig (func (result i32)))
  (table funcref (elem $a))
  (func $a (result i32) (i32.const 1))
  (func $caller (result i32)
    ;; Proposal evidence only today: this wants to attach to the following
    ;; indirect call location, not to the whole function.
    (@metadata.code.call_targets (target $a 100))
    (i32.const 0)
    (call_indirect (type $sig))))
```

Current Starshine should not use this as an ordinary WAST positive fixture. Use a raw-source note, opaque custom-section fixture, or future focused parser/model test depending on what the task is proving.

## Implementation Requirements For Future Support

A real Starshine implementation needs to answer all of these before any optimizer consumes hints:

1. **Representation:** add a placement-bearing metadata model keyed by function index and either byte offset, instruction ID, or a stable post-parse location abstraction. Define how it survives binary decode, WAST parse, lowering, printing, and pass rewrites.
2. **Binary codec:** decode and encode the `metadata.code.compilation_priority`, `metadata.code.instr_freq`, and `metadata.code.call_targets` custom-section payloads, including malformed, overwide, truncated, out-of-range, and duplicate-entry cases.
3. **WAST parser/printer:** decide whether to support structured text payloads, binary-string payloads, or both. Tests must prove expression/instruction placement, not merely function/import annotation carriage.
4. **Validation/ignore policy:** decide whether malformed hint payloads are decode errors, validation diagnostics, or ignored metadata. Preserve the proposal invariant that hints must not alter program behavior.
5. **Remapping:** when functions, types, tables, calls, or instruction layouts change, update or clear hint entries. `call_targets` is especially sensitive because it names function indices.
6. **Pass semantics:** an optimizer may use hints only as profitability or scheduling input after it has a normal semantic proof for the rewrite. Hints must not justify an otherwise unsafe transform.
7. **Fuzz/signoff:** add corpus/generator metadata rows, roundtrip tests, pass-remap tests, and external-adapter classification for proposal-support disagreements.

## Maintenance Rules

- Use this page for Compilation Hints proposal status and future-port planning.
- Use [`wast/code-metadata-and-function-annotations.md`](wast/code-metadata-and-function-annotations.md) for Starshine's current `(@...)` lane, branch hints, Binaryen inline metadata examples, and local no-inline markers.
- Use [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md) for opaque custom-section preservation and `name`/`producers`/`target_features` routing.
- Use [`binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md`](binaryen/passes/inlining/compilation-hints-vs-no-inline-flags-and-clone-survival.md) when the question is specifically about Binaryen inlining policy and `no-inline*` behavior.
- If an external tool accepts or emits compilation hints while Starshine treats them opaquely or rejects their WAT syntax, classify the case as active-proposal/tool-support evidence first, not as a Starshine semantic bug.

## Sources

- Focused source bridge: [`raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md`](raw/wasm/2026-06-05-compilation-hints-boundary-refresh.md)
- Code metadata / branch-hint routing: [`raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md`](raw/wasm/2026-06-05-code-metadata-branch-hint-current-refresh.md), [`wast/code-metadata-and-function-annotations.md`](wast/code-metadata-and-function-annotations.md)
- Custom-section metadata routing: [`raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md`](raw/wasm/2026-06-05-tool-conventions-custom-metadata-routing.md), [`binary/custom-and-name-sections.md`](binary/custom-and-name-sections.md)
- Starshine source: [`../../src/lib/types.mbt`](../../src/lib/types.mbt), [`../../src/wast/parser.mbt`](../../src/wast/parser.mbt), [`../../src/wast/lower_to_lib.mbt`](../../src/wast/lower_to_lib.mbt), [`../../src/binary/decode.mbt`](../../src/binary/decode.mbt), [`../../src/binary/encode.mbt`](../../src/binary/encode.mbt), [`../../src/passes/no_inline.mbt`](../../src/passes/no_inline.mbt), [`../../src/passes/inlining.mbt`](../../src/passes/inlining.mbt)
