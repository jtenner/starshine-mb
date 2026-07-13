# Multi-value Core boundary recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source and local-source bridge for [`../../wasm-multivalue-core-boundary.md`](../../wasm-multivalue-core-boundary.md).

## Question

What does ordinary WebAssembly multi-value mean in the current Core specification, how is it represented in binary and text, and which Starshine layers prove support?

## Primary sources checked

1. WebAssembly Core Specification, **Types**, current 3.0 source: <https://webassembly.github.io/spec/core/syntax/types.html>.
   - Function types carry ordered parameter and result vectors. Multi-value is therefore ordinary function typing, not a separate runtime value kind.
2. WebAssembly Core Specification, **Instructions** syntax/text/validation, current 3.0 sources: <https://webassembly.github.io/spec/core/syntax/instructions.html>, <https://webassembly.github.io/spec/core/text/instructions.html>, and <https://webassembly.github.io/spec/core/valid/instructions.html>.
   - Structured control has block types; validation consumes an input vector, assigns block/if labels their result vector and loop labels their parameter vector, and checks complete branch payload vectors.
3. WebAssembly Core Specification, **Binary Types** and **Binary Instructions**, current 3.0 sources: <https://webassembly.github.io/spec/core/binary/types.html> and <https://webassembly.github.io/spec/core/binary/instructions.html>.
   - Function types encode parameter/result vectors. A block type is either the empty marker, one value type, or a signed type-index immediate; multi-result or parameterized blocks consequently use a referenced function type.
4. WebAssembly proposals, finished-proposals table, checked 2026-07-11: <https://github.com/WebAssembly/proposals/blob/main/finished-proposals.md>.
   - The historical Multi-Value proposal is a finished/Core feature, not an active-proposal gate.

## Starshine sources checked

- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt) defines `FuncType(Array[ValType], Array[ValType])`, `BlockType::{VoidBlockType, ValTypeBlockType, TypeIdxBlockType}`, structured-control instructions, and `Select(Array[ValType]?)`.
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) parses repeated `(result ...)` values and control `TypeUse`s. Its one-token control shorthand represents only one result; multi-result and parameterized control use `(type ...)`, `(param ...)`, or `(result ...)` type-use syntax.
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt) resolves a referenced function type for a block type, uses the compact void/single-result core encodings when possible, and appends a function type before emitting `TypeIdxBlockType` for parameterized or multi-result inline control.
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt) and [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt) decode/encode void, single-value, and signed type-index block types symmetrically.
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt) expands block types into `(params, results)`, pops/pushes entire type arrays for blocks, branches, returns, direct/indirect/reference calls, and checks loop labels against params but block/if labels against results.
- [`../../../../src/validate/gen_valid.mbt`](../../../../src/validate/gen_valid.mbt), [`../../../../src/validate/validate.mbt`](../../../../src/validate/validate.mbt), and [`../../../../src/validate/invalid_fuzzer.mbt`](../../../../src/validate/invalid_fuzzer.mbt) expose `MultivalueControlFlow` valid-generation facts plus a focused invalid `br_table` multi-value payload-arity mutation.
- [`../../../../src/binary/tests.mbt`](../../../../src/binary/tests.mbt) locks a raw high-type-index multi-value loop roundtrip; [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt) locks parsing a type with multiple results.

## Reconciled conclusions

- **Multi-value is an ordered stack-vector contract.** It does not create one tuple value in core Wasm. A function, call, block, branch, or return consumes/pushes an ordered list of independently typed stack values.
- **Block parameters and multiple results use function types.** The compact binary block-type forms can encode only void or one result value directly. Any block type with parameters or more than one result is represented by a function type and encoded as its signed type index.
- **Branch labels differ by construct.** `block` and `if` labels expect the result vector; `loop` labels expect the parameter vector. This distinction applies to every lane, not only to the first result.
- **Starshine implements ordinary multi-value across core, WAST, binary, validator, and generators.** A local raw optimization skip or a narrow optimizer pass is not evidence that the underlying Core feature is absent.
- **Do not conflate multi-value with Starshine-local multi-value typed `select`.** The latter is a local regression surface whose portability caveat remains in [`../../wast/parametric-instruction-authoring.md`](../../wast/parametric-instruction-authoring.md). Nor should Binaryen's internal tuple IR be presented as an on-wire Wasm tuple.

## Boundaries retained

- This recheck does not settle the local tail-call result-subtyping divergence; use [`../../wast/tail-call-authoring.md`](../../wast/tail-call-authoring.md) and its July 11 source reconciliation.
- This recheck does not claim that all Starshine optimization passes handle arbitrary multi-value shapes. Each pass needs its own control/payload/effect proof.
- Binaryen's feature-off `tuple-optimization` scheduler gate is an upstream pass policy, not a claim that current Core multi-value itself is experimental or disabled in Starshine.
