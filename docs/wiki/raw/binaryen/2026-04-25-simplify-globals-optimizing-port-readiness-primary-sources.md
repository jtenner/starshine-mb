# Binaryen `simplify-globals-optimizing` port-readiness primary-source bridge

_Capture date:_ 2026-04-25  
_Status:_ immutable focused source bridge for the `docs/wiki/binaryen/passes/simplify-globals-optimizing/` dossier

## Scope

This file captures the official online sources rechecked for the 2026-04-25 `simplify-globals-optimizing` port-readiness refresh. It complements, rather than replaces, the broader 2026-04-24 manifest at `docs/wiki/raw/binaryen/2026-04-24-simplify-globals-optimizing-primary-sources.md`.

Use the living dossier pages for explanations:

- `docs/wiki/binaryen/passes/simplify-globals-optimizing/index.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/linear-traces-read-only-to-write-and-reruns.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/wat-shapes.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-strategy.md`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/starshine-port-readiness-and-validation.md`

## Primary online sources rechecked

Official Binaryen current-`main` sources:

- `src/passes/SimplifyGlobals.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyGlobals.cpp>
  - Source locations reviewed: shared `SimplifyGlobals` phase order; `GlobalUseScanner` over function bodies plus module code; `removeUnneededWrites`; `preferEarlierImports`; startup propagation; runtime `ConstantGlobalApplier`; `GlobalSetRemover`; factory functions for plain, optimizing, and startup-only variants.
- `src/passes/pass.cpp`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Source locations reviewed: public registration for `simplify-globals` and `simplify-globals-optimizing`; late post-pass placement that chooses the optimizing sibling for `-O2` / `-Os2`-class settings and then runs `remove-unused-module-elements`.
- `src/pass.h`
  - <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
  - Source locations reviewed: nested `PassRunner` constructor, `addDefaultFunctionOptimizationPasses()`, and `runOnFunction(...)` declarations that explain the optimizing sibling's per-function cleanup hook.

Official tagged source oracle retained from the prior manifest:

- `version_129` `SimplifyGlobals.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyGlobals.cpp>
- `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `version_129` `pass.h`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>

## Durable observations from this focused recheck

- No teaching-relevant current-`main` drift was found beyond the 2026-04-24 dossier contract.
- Current `main` still keeps one shared `SimplifyGlobals.cpp` engine for `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally`.
- The reviewed source still confirms the important phase order: analyze global traffic, fold single-use global initializers, remove useless writes, prefer earlier immutable ancestors, propagate constants to later globals/segment offsets, then propagate constants through simple runtime code traces.
- The reviewed source still confirms the optimizing-specific hook in two changed-function paths: after replacing global reads with constants and after replacing removable `global.set`s with `drop(value)`, Binaryen constructs a nested pass runner, adds the default function optimization passes, and runs those passes on the changed function.
- `pass.cpp` still registers the plain and optimizing pass names separately and still schedules `simplify-globals-optimizing` in the late post-pass cluster before `remove-unused-module-elements` when optimization or shrink level is high enough.
- `pass.h` still exposes the nested-runner mechanics required to understand why the optimizing sibling is more than a shared-engine alias.

## Starshine-specific reason this source bridge exists

The 2026-04-24 wiki work made the source structure and local status clear. This 2026-04-25 bridge adds the implementation-readiness layer: how a future Starshine port should split the minimum viable work so it can preserve Binaryen's global rewrite semantics, exact changed-function set, nested default-function rerun, and late-tail handoff to `remove-unused-module-elements` without accidentally copying the different `precompute-propagate`-prefixed rerun shape used by nearby optimizing passes.

## Uncertainties and non-claims

- This was a focused current-`main` teaching-drift and port-readiness recheck, not a full semantic audit of every helper header.
- It does not claim Starshine has implemented the pass. Current Starshine still only tracks the name as boundary-only and rejects active requests.
- It does not decide the final Starshine architecture. The living port-readiness page records plausible slice order and validation requirements, not a completed design.
