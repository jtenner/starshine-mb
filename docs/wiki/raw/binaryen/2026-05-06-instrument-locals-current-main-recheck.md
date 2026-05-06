# Binaryen `instrument-locals` current-main recheck

_Capture date:_ 2026-05-06  
_Status:_ immutable current-main freshness recheck for the `docs/wiki/binaryen/passes/instrument-locals/` dossier

## Scope

This capture updates the earlier `instrument-locals` source manifest with one narrow question: did current Binaryen `main` drift in a way that changes the wiki contract?

The answer from the checked primary sources is: no teaching-relevant drift was found. Current Binaryen `main` still implements `instrument-locals` as an effect-adding `PostWalker` plus module helper-import injection. The public help text still sounds broader than the owner file, so the wiki should keep that contradiction visible.

## Official current-main sources consulted

- Binaryen `InstrumentLocals.cpp`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/InstrumentLocals.cpp>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/InstrumentLocals.cpp>
  - Key checked regions in the flattened raw view:
    - lines 1-5 still show the helper-name surface, `addsEffects()`, supported `local.get` / `local.set` rewriting, and module-level import injection;
    - `get_i64` / `set_i64` helper names are still declared even though the visitors still leave ordinary `i64` local traffic unchanged;
    - the pass is still effectful and still uses `env` helper imports.
- Binaryen `pass.cpp`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Key checked region:
    - the public pass registration still exposes `instrument-locals` with the same broad "intercept all loads and stores" wording.
- Binaryen `instrument-locals_all-features_disable-gc.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_all-features_disable-gc.wast>
  - Key checked facts:
    - the expected import roster still includes scalar, nullable `funcref` / `externref`, and `v128` helpers;
    - expected output still leaves ordinary `i64` local traffic unwrapped;
    - shared call-id sequencing is still visible across mixed get/set traffic.
- Binaryen `instrument-locals_effects.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals_effects.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals_effects.wast>
  - Key checked fact: the test still proves that `--instrument-locals` invalidates previously generated global-effects knowledge because the pass inserts imported calls.
- Binaryen `instrument-locals-eh-legacy.wast`
  - raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/instrument-locals-eh-legacy.wast>
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/instrument-locals-eh-legacy.wast>
  - Key checked fact: the EH boundary still exists to preserve `Pop` payload behavior.

## Durable observations

- Current Binaryen `main` still matches the existing teaching contract for `instrument-locals`.
- The pass name's public help text remains easy to misread because it mentions loads and stores while the owner file is specifically about local reads and writes.
- The source-backed rewrite surface remains narrower than the helper roster: helper imports for ordinary `i64` are still injected, but ordinary `i64` local traffic still returns early in the visitors.
- The first Starshine port slice should stay a module pass that only handles scalar `i32` / `f32` / `f64` local traffic plus helper-import injection.
- A HOT-only first slice would be misleading: wrapping local traffic without creating helper imports and function types would not produce a valid module-level transform.

## Uncertainties and caveats

- GitHub raw rendering keeps the source readable here, but exact line anchoring is still less stable than the committed raw capture itself.
- No local implementation work was performed in this recheck; the status remains upstream-only documentation.
- A future local product decision may still choose to keep `instrument-locals` unsupported instead of adding a debug-instrumentation pass to the optimizer registry.
