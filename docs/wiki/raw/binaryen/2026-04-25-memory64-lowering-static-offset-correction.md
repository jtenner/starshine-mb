# Binaryen `memory64-lowering` static-offset correction

_Capture date:_ 2026-04-25  
_Status:_ immutable primary-source correction for the `docs/wiki/binaryen/passes/memory64-lowering/` dossier

## Scope

This file corrects an over-broad phrase that entered the 2026-04-25 `memory64-lowering` living pages: the prior wording said that “known constant address operands” and high active offsets become `unreachable`.
The reviewed Binaryen source and current lit output support a narrower rule:

- **dynamic address/index/count operands** lower by inserting `i32.wrap_i64(...)`, even when the operand expression is an `i64.const`;
- **large static memarg offsets** (`offset=` immediates on loads/stores/SIMD/atomics) become `unreachable` with child side effects preserved;
- **active data/element offset expressions** are lowered to the new 32-bit expression type through the segment offset rewrite path; this source check did not find evidence for a high-active-offset-to-`unreachable` special case in `Memory64Lowering.cpp`;
- `memory.grow` / `table.grow` dynamic deltas are wrapped before the lowered grow, then the lowered `i32` result is repaired so failure maps back to the wasm64 failure sentinel. This source check did not find a separate “high constant delta becomes sentinel before calling grow” rule.

Use the living pages for teaching material:

- `docs/wiki/binaryen/passes/memory64-lowering/index.md`
- `docs/wiki/binaryen/passes/memory64-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/memory64-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/memory64-lowering/static-offsets-dynamic-operands-and-grow-repair.md`
- `docs/wiki/binaryen/passes/memory64-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/memory64-lowering/starshine-strategy.md`

## Primary sources checked

### Official Binaryen current `main`

- `Memory64Lowering.cpp`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Memory64Lowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Memory64Lowering.cpp>
- `memory64-lowering.wast`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/memory64-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/memory64-lowering.wast>
- `table64-lowering.wast`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/table64-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/table64-lowering.wast>

### Tagged baseline retained for comparison

- `Memory64Lowering.cpp`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Memory64Lowering.cpp>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Memory64Lowering.cpp>
- `memory64-lowering.wast`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/memory64-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/memory64-lowering.wast>
- `table64-lowering.wast`
  - <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/table64-lowering.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/table64-lowering.wast>

## Source-backed correction

### Dynamic operands still wrap

The owner source's memory/table expression-lowering helpers wrap former `i64` address-like expressions into `i32` form. The current lit file demonstrates ordinary `i64.const` operands lowered under `i32.wrap_i64(...)` for scalar loads/stores, atomics, bulk memory operations, `call_indirect`, and table operations.

Do **not** teach this as “constant address operands narrow or trap.” In the reviewed pass, an `i64.const` expression in the address/index/count operand position is still an expression operand and is lowered through the same wrap path unless another instruction-specific rule applies.

### Static memarg offsets are the high-offset trap family

The dedicated current-main memory lit file has explicit large-`offset=` cases for scalar memory, SIMD, atomics, and side-effect preservation. Those are the cases where the pass replaces the operation with an `unreachable` shape rather than modulo-wrapping.

This distinction matters for Starshine because `MemArg.offset` is a static immediate in `src/lib/types.mbt` / validation, while the address expression is a separate stack operand.

### Active segment offsets are lowered as expressions

The owner source lowers active data and element offset expressions through the offset-expression helper. This focused source check did not find a high-active-offset special case comparable to the large static memarg offset rule, nor an official lit case proving high active offsets become `unreachable`.

The living pages should therefore say that active offsets must be rewritten to the lowered address type, and leave any future high-active-offset semantic strengthening as a source-confirmed drift item rather than current Binaryen behavior.

### Grow repair is failure-aware, but constant deltas are not preclassified here

The current lit checks show `memory.grow` and `table.grow` using a temporary for the lowered `i32` grow result, testing that result against `i32 -1`, and returning `i64 -1` on failure or `i64.extend_i32_u(...)` on success.

This confirms the failure-sentinel repair contract. It does not support the prior stronger claim that high constant grow deltas are converted directly to the 64-bit failure sentinel before the lowered grow.

## Current durable teaching rule

Use this rule in living pages and future port plans:

| Surface | Correct current teaching |
| --- | --- |
| Dynamic load/store/SIMD/atomic address operand | `i32.wrap_i64(...)` around the operand |
| `i64.const` used as an address/index/count operand | still lowered through the operand wrap path |
| Static `MemArg.offset >= 2^32` | known out-of-range operation; replace with `unreachable` while preserving children/effects |
| Active data/element offset expression | rewrite expression to 32-bit address type through segment offset repair; no reviewed high-offset trap special case |
| `memory.size` / `table.size` | lowered operation plus `i64.extend_i32_u(...)` where caller expects `i64` |
| `memory.grow` / `table.grow` | wrap delta, run lowered grow, repair `i32 -1` failure to `i64 -1`, zero-extend success |
| Max limits above wasm32 maximum | clamp to wasm32 maximum |
| Impossible minimum limits | source-level assertion / unresolved user-facing diagnostic policy |

## Supersession note

This file partially supersedes the constant/high-offset wording in:

- `docs/wiki/raw/research/0340-2026-04-25-memory64-lowering-out-of-range-recheck.md`
- `docs/wiki/raw/binaryen/2026-04-25-memory64-lowering-current-main-recheck.md`

It does **not** replace the original primary-source manifest. It only narrows the over-broad “high constant address / active offset / grow delta” claims to the source-backed static-memarg-offset and grow-result-repair facts.
