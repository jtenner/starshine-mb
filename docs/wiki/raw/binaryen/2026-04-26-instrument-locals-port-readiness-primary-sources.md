# Binaryen `instrument-locals` port-readiness primary-source recheck

_Capture date:_ 2026-04-26  
_Status:_ immutable focused recheck for the `docs/wiki/binaryen/passes/instrument-locals/` dossier

## Scope

This capture updates the earlier 2026-04-24 source manifest for one narrow question: what is the safest future Starshine implementation slice for Binaryen's public `instrument-locals` pass, and did current Binaryen `main` drift in ways that change the existing wiki contract?

The answer from the checked primary sources is: no teaching-relevant drift was found. Current Binaryen `main` still implements `instrument-locals` as a compact effect-adding `PostWalker` plus module import injection. A future Starshine port should therefore begin with explicit module-pass/import-synthesis infrastructure rather than a HOT-only peephole.

## Official current-main sources consulted

- Binaryen `InstrumentLocals.cpp`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/InstrumentLocals.cpp>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
  - Key checked locations in the flattened raw view:
    - file header still describes interception of local reads and writes;
    - helper-name constants still include `get_i64` / `set_i64` even though the visitors still return early for ordinary `i64` local traffic;
    - `addsEffects()` still returns `true`;
    - `visitLocalGet(...)` still wraps supported gets as `call $get_TYPE(call_id, local_id, original_get)`;
    - `visitLocalSet(...)` still skips `Pop`, typed function-reference edge cases, ordinary `i64`, and unreachable values, then wraps the assigned value in `call $set_TYPE(...)`;
    - `visitModule(...)` still injects scalar helpers unconditionally, reference helpers behind reference-types, and SIMD helpers behind SIMD;
    - `addImport(...)` still creates `env` function imports.
- Binaryen `instrument-locals_all-features_disable-gc.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - Key checked facts:
    - the expected import roster still includes scalar, nullable `funcref` / `externref`, and `v128` helpers;
    - expected output still leaves ordinary `i64` local traffic unwrapped;
    - shared call-id sequencing is visible across mixed get/set traffic.
- Binaryen `instrument-locals_effects.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_effects.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
  - Key checked fact: the test still proves that `--instrument-locals` invalidates previously generated global-effects knowledge because the pass inserts imported calls.
- Binaryen `instrument-locals-eh-legacy.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals-eh-legacy.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
  - Key checked fact: the EH boundary still exists to preserve `Pop` payload behavior.

## Starshine code surfaces rechecked

- `src/passes/optimize.mbt:126-153` - boundary-only and removed pass rosters; `instrument-locals` is absent.
- `src/passes/optimize.mbt:156-267` - active pass and preset entries; `instrument-locals` is absent.
- `src/passes/optimize.mbt:363-367` - public pass-category lookup; absent names classify as unknown.
- `src/passes/optimize.mbt:446-489` - explicit pass-request expansion; absent names fail as `unknown pass flag ...`.
- `src/passes/optimize.mbt:407-421` - imported-function counting used for pipeline validation bookkeeping; this is not helper-import synthesis.
- `src/lib/types.mbt:181-185`, `430`, `8084-8085` - existing imported-function data model: `FuncExternType(TypeIdx)`, `ImportSec(Array[Import])`, and `ImportSec::new(...)`.
- `src/lib/module.mbt:146-151` - module index construction already accounts for function imports.
- `src/ir/hot_core.mbt:42-44` - HOT op kinds include `LocalGet`, `LocalSet`, and `LocalTee`.
- `src/ir/effects.mbt:134-135` - local traffic currently maps to `EFFECT_MASK_LOCAL_STATE`, not imported-call effects.
- `src/ir/hot_lift.mbt:492-580` and nearby lifting logic - `LocalGet` / `LocalSet` / `LocalTee` can enter HOT IR, but HOT lifting/lowering alone does not create module imports or helper function types.
- `src/passes/registry_test.mbt:1-90`, `134-157` - registry and preset tests have no `instrument-locals` expectation.

## Durable observations

- Current Binaryen `main` still matches the 2026-04-24 teaching contract for `instrument-locals`.
- The pass name's public help text remains easy to misread because it mentions loads and stores while the owner file is specifically about local reads and writes. Keep that contradiction visible.
- The first Starshine port slice should be a module pass that only handles scalar `i32` / `f32` / `f64` local traffic plus helper-import injection. Treat `i64`, references, SIMD, and legacy EH as explicit negative fixtures until the scalar slice validates.
- A HOT-only first slice would be misleading: wrapping local traffic without creating helper imports and function types would not produce a valid module-level transform.
- Starshine has reusable representation pieces for imports and local HOT ops, but no current pass framework that exposes Binaryen-style `addsEffects()` invalidation or helper ABI synthesis for instrumentation passes.

## Uncertainties and caveats

- GitHub's raw rendering exposed the source as long flattened lines, so this capture cites stable file URLs and checked semantic regions rather than fragile current-main line numbers.
- No local implementation work was performed in this recheck; the status remains upstream-only documentation.
- A future local product decision may still choose to keep `instrument-locals` unsupported instead of adding a debug-instrumentation pass to the optimizer registry.
