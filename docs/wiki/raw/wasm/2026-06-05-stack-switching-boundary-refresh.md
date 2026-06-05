# Stack Switching Boundary Refresh

Date: 2026-06-05

Purpose: support a living Stack Switching / typed-continuations boundary page and refresh the shared WebAssembly feature-status router so `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, `switch`, continuation heap/type forms, and resumable control-tag semantics are not confused with current Starshine exception handling, tail calls, JSPI host APIs, ordinary stack-polymorphic validation, Binaryen pass fixture evidence, or generator feature gates.

## Primary Sources Checked

- WebAssembly proposals tracker, current public README: <https://github.com/WebAssembly/proposals>
  - The active tracker currently lists **Stack Switching** in Phase 3, under the implementation phase bucket. It is not in the finished-proposals table or Core-3.0-only bucket.
  - This bridge supersedes older same-day routing shorthand that left Stack Switching inside a generic active-row bucket or stale adjacent-page notes. Preserve older raw captures as historical evidence, but use this focused bridge for current Stack Switching routing.
- WebAssembly Stack Switching proposal repository: <https://github.com/WebAssembly/stack-switching>
  - The repository describes itself as the proposal home for adding stack-switching support to WebAssembly and links the proposal explainer.
- Stack Switching proposal explainer: <https://github.com/WebAssembly/stack-switching/blob/main/proposals/stack-switching/Explainer.md>
  - The explainer frames the proposal as typed stack-switching for multiple execution stacks in one WebAssembly instance, with language-facing use cases such as coroutines, async/await, generators, lightweight threads, and other non-local control-flow idioms.
  - The proposal adds a continuation type form `(cont $ft)`, continuation heap-type family (`cont` / `nocont`), and control tags that may have result types. This differs from Starshine's current exception tag validation, which rejects non-empty tag result lists.
  - The visible instruction surface is `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, and `switch`, with handler clauses for ordinary tag-to-label handling and tag-to-switch handling.
  - The explainer currently assigns binary instruction opcodes `0xe0` through `0xe6` to the seven new instructions and introduces new binary encodings for continuation composite and heap types. These are proposal bytes, not Starshine decode/encode support.
- WasmFX typed-continuations explainer and core-extension pages: <https://wasmfx.dev/specs/explainer/> and <https://wasmfx.dev/specs/core/>
  - These are useful readable mirrors for the typed-continuations/effect-handler vocabulary. They support the same high-level instruction families, but for Starshine wiki routing the official WebAssembly proposal repository remains the primary source.
- `src/lib/types.mbt`
  - Current Starshine `Instruction` variants include ordinary control, tail calls, `Throw`, `ThrowRef`, and `TryTable`, but no continuation type carrier and no `cont.new`, `cont.bind`, `suspend`, `resume`, `resume_throw`, `resume_throw_ref`, or `switch` instruction variants.
  - Current `TagType` exists for exception tags and indexes a function type, but the validator treats tag result lists as invalid today.
- `src/validate/validate.mbt`
  - `Validate for TagType` resolves a function type and returns `"Tag type must have empty result list"` for non-empty results. That is correct for current local exception support and explicitly not Stack Switching's control-tag extension.
- `src/binary/decode.mbt` and `src/binary/encode.mbt`
  - Current binary instruction decode/encode handles `0x1f` as `try_table` and ordinary local opcodes such as `0x20`-`0x22`. No `0xe0`-`0xe6` Stack Switching instruction arms are present.
- `src/wast/keywords.mbt` and `src/wast/types.mbt`
  - Current WAST keyword and opcode tables include ordinary control, tail calls, exceptions, `try_table`, reference, string, GC, memory, table, numeric, and SIMD families. No Stack Switching keywords/opcodes are present.
- `src/validate/gen_valid.mbt`
  - Current `GenValidProposalFeature` gates include GC, function references, tail calls, exceptions, SIMD, relaxed SIMD, ordinary atomics, bulk memory, multi-memory, memory64, extended const, and reference types. There is no Stack Switching gate.
- Existing wiki pages checked for routing:
  - `docs/wiki/wasm-feature-status-and-proposal-boundaries.md`
  - `docs/wiki/wasm-jspi-host-async-boundary.md`
  - `docs/wiki/wast/exception-tag-authoring.md`
  - `docs/wiki/wast/tail-call-authoring.md`
  - `docs/wiki/validate/stack-polymorphism-and-bottom.md`
  - `docs/wiki/binary/instruction-and-expression-encoding.md`
  - `docs/wiki/fuzzing/generator-coverage-ledger.md`

## Durable Conclusions

1. Stack Switching is active Phase-3 proposal evidence as of the 2026-06-05 recheck. It is not finished/Core-3.0 evidence and not local Starshine support by itself.
2. The proposal is a Core-module type/instruction/control-flow surface, not a JavaScript host wrapper API. JSPI remains the separate host-async JavaScript API boundary.
3. Current Starshine has no documented Stack Switching support across core AST/types, binary decode/encode, WAST keyword/parser/printer, validator, generator, or pass/effect model. Binaryen fixtures that mention Stack Switching remain upstream oracle evidence only.
4. Current Starshine exception tags and `try_table` do not implement Stack Switching control tags. In particular, Starshine still validates tags as empty-result function types, while the Stack Switching proposal admits result-bearing control tags.
5. Future implementation must start with representation and validation design, not with a pass-only tweak: continuation composite/heap/reference types, tag-result validation policy, instruction variants, binary `0xe0`-`0xe6` handling, WAST syntax/lowering/printing, generator gates, effect/terminator modeling, and external-tool feature-gating all need explicit tests and docs.
6. Whole-wiki health checks should route future `cont.new`, `cont.bind`, `resume`, `resume_throw`, `resume_throw_ref`, `suspend`, `switch`, continuation-type, and stack-switching label-liveness mentions to the focused boundary page unless the page is only preserving historical Binaryen source context.
