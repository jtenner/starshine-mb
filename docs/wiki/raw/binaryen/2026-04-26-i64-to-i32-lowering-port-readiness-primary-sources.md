# Binaryen `i64-to-i32-lowering` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable current-main / Starshine-readiness source manifest for `docs/wiki/binaryen/passes/i64-to-i32-lowering/`

## Scope

This source capture extends the 2026-04-24 dossier with a port-readiness recheck. It does not replace the older manifest; it answers the narrower question: what should a future Starshine implementation do first, and did current Binaryen `main` change the teaching contract enough to alter that plan?

Use this with:

- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-strategy.md`
- `docs/wiki/raw/binaryen/2026-04-24-i64-to-i32-lowering-primary-sources.md`

## Official online sources rechecked

### Binaryen owner / registration / helper sources

- `src/passes/I64ToI32Lowering.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/I64ToI32Lowering.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
- `src/passes/pass.cpp`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `src/passes/passes.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- `src/abi/js.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/abi/js.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h>
- `src/asmjs/shared-constants.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/asmjs/shared-constants.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h>
- `src/ir/flat.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
- `src/ir/memory-utils.h`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/memory-utils.h>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h>

### Binaryen official tests

- `test/lit/passes/flatten_i64-to-i32-lowering.wast`
  - current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - raw current `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - tagged `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>

## Starshine source surfaces rechecked

- `src/passes/optimize.mbt`
  - `pass_registry_boundary_only_names()` currently includes `i64-to-i32-lowering` at line 137.
  - `expand_hot_pass_sequence(...)` rejects boundary-only requests at lines 470-473.
- `src/passes/pass_manager.mbt`
  - active module-pass dispatch is the match at lines 8671-8683; it has no `i64-to-i32-lowering` case.
- `src/lib/types.mbt`
  - value/index/type surfaces: `I64`, `I64NumType`, `FuncIdx`, `GlobalIdx`, `LocalIdx`, `CompType::FuncCompType` at lines 8, 27, 99-108, and 114-118.
  - instruction surfaces that a port must rewrite: calls at lines 527-532, locals/globals at lines 536-540, i64 memory traffic at lines 543-565, atomics at lines 572-585, i64 constants and numeric families at lines 589 and 603-690+.
- `src/lib/util.mbt`
  - `Locals` run normalization, indexing, and mutation helpers begin around lines 1-145 and include `Locals::push`, `append`, and `append_types` around lines 139-154.
- `src/wast/lower_to_lib.mbt`
  - WAT lowering already accepts i64 value types at line 83, i64 defaults at lines 602-603, scalar i64 opcode lowering around lines 1172-1296, and vector i64 lanes later in the file.
- `src/binary/decode.mbt`
  - binary decoding already covers i64 value type, locals, globals, calls, `ref.func`, i64 memory ops, and i64 numeric opcodes at the line ranges captured in the living port-readiness page.
- `src/binary/encode.mbt`
  - binary encoding already covers i64 value type, locals, globals, calls, memory opcodes, and atomic opcode families at the line ranges captured in the living port-readiness page.
- `src/validate/env.mbt` and `src/validate/typecheck.mbt`
  - existing validation environment and typechecker are the required final oracle for coherent function types, globals, locals, calls, `ref.func`, memory traffic, atomics, and numeric stack effects after a module rewrite.

## Durable observations

- Current Binaryen still teaches the same porting contract captured on 2026-04-24: flat-input whole-module pair lowering, hidden high-half side channel, split locals/signatures/globals, synthetic high-bits return global, helper-backed reinterpret/atomic families, and explicit unsupported boundaries.
- The official lit entry still runs `--flatten --i64-to-i32-lowering`; future Starshine work should therefore treat flatness as a first-class prerequisite rather than an incidental test detail.
- The safest Starshine first slice is **not** to move the registry name into active dispatch immediately. It is an analyzer-only / no-rewrite module-pass skeleton that classifies candidate modules and rejects unsupported families while keeping the existing boundary-only user-facing behavior unchanged.
- The first mutating slice should be deliberately narrower than Binaryen's whole owner file: scalar defined-function params/locals plus non-imported function type rewriting, without calls, globals, helper imports, atomics, reinterpret, `return_call`, or imported `i64` globals. That gives Starshine a validation-safe local/type-index substrate before the harder ABI edges are enabled.
- No contradiction was found between the 2026-04-24 dossier and this 2026-04-26 recheck. The new value is sequencing and exact local code-surface mapping, not a correction to the upstream algorithm.

## Uncertainties and cautions

- This capture did not prove full source equality between Binaryen `version_129` and current `main`; it rechecked the owner, registration, helper, flatness, and official test surfaces relevant to Starshine port sequencing.
- A faithful Starshine port may choose to expand beyond Binaryen's unsupported boundaries, but the wiki should label any such expansion as Starshine-specific behavior rather than Binaryen parity.
- Helper-import materialization, JS-interface interaction, and scratch-memory assumptions remain the highest-risk areas and should not be silently bundled into a first mutating slice.
