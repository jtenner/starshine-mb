# Binaryen `i64-to-i32-lowering` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/i64-to-i32-lowering/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `i64-to-i32-lowering` provenance and Starshine status follow-up.
It is intentionally provenance-heavy rather than explanatory.
Use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/i64-to-i32-lowering/index.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/flatness-helpers-and-boundaries.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/abi-surface-and-opcode-coverage.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/wat-shapes.md`
- `docs/wiki/binaryen/passes/i64-to-i32-lowering/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Neighboring 2026-04-24 pass ingests observed GitHub showing the publish timestamp as **2026-04-01 14:31**; this follow-up keeps `version_129` as the release oracle for the source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `I64ToI32Lowering.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/I64ToI32Lowering.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/I64ToI32Lowering.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/I64ToI32Lowering.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/I64ToI32Lowering.cpp>
- `pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `passes.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
- `pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>

### Official helper and dependency files consulted

- `abi/js.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/abi/js.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/abi/js.h>
- `asmjs/shared-constants.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/asmjs/shared-constants.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/asmjs/shared-constants.h>
- `ir/flat.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/flat.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/flat.h>
- `ir/iteration.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/iteration.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/iteration.h>
- `ir/memory-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/memory-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/memory-utils.h>
- `ir/module-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/module-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/module-utils.h>
- `ir/names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>

### Official test files consulted

- `flatten_i64-to-i32-lowering.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_i64-to-i32-lowering.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/flatten_i64-to-i32-lowering.wast>

## Durable observations from the captured sources

- `i64-to-i32-lowering` is a real public Binaryen pass, registered in `src/passes/pass.cpp`, with a factory declaration in `src/passes/passes.h`.
- The owner file is `src/passes/I64ToI32Lowering.cpp`. The reviewed strategy is a non-function-parallel, effect-adding, whole-module AST legalization pass rather than a function-local peephole.
- The pass rewrites module-level ABI surfaces: defined `i64` globals, function params and locals, direct and indirect call signatures, `ref.func` signatures, and `i64` results.
- Function bodies must already be flat: the owner calls `Flat::verifyFlatness(func)`, and the dedicated lit file invokes `--flatten --i64-to-i32-lowering` together.
- The core value model is low-half-visible / high-half-hidden: most lowered expressions visibly produce an `i32` low half while the high half is tracked through temp locals.
- Former `i64` function returns use the synthetic mutable high-half global declared through Binaryen's shared constants; the pass does not use multivalue for that return ABI.
- Helper dependencies are part of the real contract. Reinterpret and selected atomic lowering routes use wasm2js helper declarations in `abi/js.h`, and the reinterpret path can force memory materialization through `memory-utils.h`.
- The pass is intentionally not a universal arbitrary-`i64` legalizer. Imported `i64` globals, `i64`-result `return_call` / `return_call_indirect`, direct `i64` atomic load/store splitting, `i64` atomic cmpxchg, and several hard arithmetic families are still unsupported or expected to have been simplified before this pass.
- A narrow 2026-04-24 current-`main` source revisit did not add a new teaching-relevant contract to the dossier. This is intentionally a narrow freshness note, not a whole-repository equivalence proof.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `i64-to-i32-lowering` is a preserved **boundary-only** registry name, not an active HOT or module pass.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-24 Starshine follow-up research note.
