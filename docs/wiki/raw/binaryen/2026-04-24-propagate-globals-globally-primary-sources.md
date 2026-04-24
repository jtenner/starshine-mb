# Binaryen `propagate-globals-globally` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/propagate-globals-globally/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `propagate-globals-globally` source correction and Starshine status follow-up. It is provenance-heavy rather than explanatory; use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/propagate-globals-globally/index.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/shared-engine-and-startup-boundaries.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/wat-shapes.md`
- `docs/wiki/binaryen/passes/propagate-globals-globally/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - GitHub showed the release timestamp as **2026-04-01 14:31** and tag commit `d0e2be9` when observed in this run.

### Official source files consulted

- `src/passes/SimplifyGlobals.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/SimplifyGlobals.cpp>
  - main correction anchors:
    - `propagateConstantsToGlobals()` source surface: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp#L533-L571>
    - broader `SimplifyGlobals::iteration()` also calls `propagateConstantsToCode()`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp#L470-L484>
    - `PropagateGlobalsGlobally` subclass calls only `propagateConstantsToGlobals()`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp#L796-L819>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/SimplifyGlobals.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - registration anchor: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp#L1428-L1432>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Official helper surfaces consulted

These helpers are not dedicated `propagate-globals-globally` implementation files, but they define the source-backed primitives that the reviewed implementation uses:

- `FindAllPointers<GlobalGet>` from `src/ir/find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
- constant-expression predicates and literal extraction helpers referenced from `SimplifyGlobals.cpp`
  - `src/ir/properties.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - `src/wasm/literal.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm/literal.h>
- builder materialization of recorded literal vectors
  - `src/wasm-builder.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/wasm-builder.h>

### Official test files consulted

- `test/lit/passes/propagate-globals-globally.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/propagate-globals-globally.wast>
  - behavior anchors:
    - run lines and explicit contrast with `simplify-globals`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast#L1-L8>
    - direct global chain and arithmetic expression examples: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast#L20-L34>
    - string/struct constant-expression example: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast#L35-L54>
    - function-body non-rewrite contrast: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/propagate-globals-globally.wast#L55-L105>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/propagate-globals-globally.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/propagate-globals-globally.wast>

## Durable observations from the captured sources

- `propagate-globals-globally` is a real public Binaryen pass in `version_129`, registered in `src/passes/pass.cpp` with the description `propagate global values to other globals (useful for tests)`.
- The implementation lives inside `src/passes/SimplifyGlobals.cpp`, not a standalone `PropagateGlobals.cpp`.
- The narrow public pass is not merely `SimplifyGlobals(false)`. It is a `PropagateGlobalsGlobally` subclass whose `run(Module*)` sets `module` and calls only `propagateConstantsToGlobals()`.
- `propagateConstantsToGlobals()` builds a map from global name to `Literals`, substitutes every matching `GlobalGet` found under a startup expression with `Builder::makeConstantExpression(...)`, scans defined globals in declaration order, records globals whose rewritten initializers pass `Properties::isConstantExpression(...)`, and then applies the same substitution to element-segment and data-segment offsets.
- The broader `simplify-globals` sibling still calls `propagateConstantsToCode()` after `propagateConstantsToGlobals()` inside its ordinary iteration. Therefore the older dossier's “`optimize = false` stop point” explanation was wrong: the public pass boundary is the subclass override, while the `optimize` flag mostly controls nested cleanup after function-body rewrites.
- The dedicated lit file proves global-to-global propagation, chained arithmetic propagation, a GC/string `struct.new` constant-expression example, and the important negative: `propagate-globals-globally` leaves ordinary function-body `global.get` instructions alone while `simplify-globals` rewrites several of them.
- A narrow current-`main` spot check on 2026-04-24 found the same public registration, same subclass boundary, and same dedicated lit-file teaching surface. This is not a full trunk-equivalence audit.

## Uncertainties and contradictions

- `docs/wiki/raw/research/0162-2026-04-21-propagate-globals-globally-binaryen-research.md` is superseded for its standalone-`PropagateGlobals.cpp` source-layout claim.
- `docs/wiki/raw/research/0196-2026-04-21-propagate-globals-globally-shared-engine-research.md` corrected the source file but is superseded for several mechanics: there is no source-confirmed `canHandleAsGlobal` / `allInputsConstant` helper pair in the reviewed release, the globals pass scans forward rather than reverse, and the public-pass stop point is the `PropagateGlobalsGlobally` subclass override rather than an `optimize = false` gate.
- The source relies on Binaryen's general `Properties::isConstantExpression(...)` predicate. This capture therefore avoids publishing a closed hand-maintained whitelist of accepted expression kinds. The lit file proves specific families, but not an exhaustive list.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-24 Starshine follow-up research note.
