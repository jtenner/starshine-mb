# Binaryen `remove-unused` / historical `remove-unused-functions` primary-source capture

_Capture date:_ 2026-04-25  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/remove-unused/` lineage dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-25 refresh of the local Starshine `remove-unused` dossier.
The important point is that this is **not** a current upstream `version_129` public pass. The dossier preserves the lineage of the local boundary-only alias by comparing:

- historical Binaryen `remove-unused-functions` at commit `5881b541a4b276dcd5576aa065e4fb860531fc7b`;
- the supersession commit `98e9e604c7e2e4f928abe8f05691df90cddf09e4`, which introduced `RemoveUnusedModuleElements.cpp` and replaced the public registration;
- current Binaryen `version_129` and `main`, which expose `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `remove-unused-brs`, `remove-unused-names`, and `remove-unused-types`, but no `remove-unused` / `remove-unused-functions` spelling.

Use the living pages for explanation:

- `docs/wiki/binaryen/passes/remove-unused/index.md`
- `docs/wiki/binaryen/passes/remove-unused/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused/historical-lineage-and-modern-supersession.md`
- `docs/wiki/binaryen/passes/remove-unused/module-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused/starshine-strategy.md`

## Provenance

### Official Binaryen historical sources consulted

- Historical `RemoveUnusedFunctions.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
  - Key reviewed locations:
    - file comment frames the pass as removing functions that are never used;
    - root collection from module start, exported functions, and all functions named in table segments;
    - `DirectCallGraphAnalyzer analyzer(module, root)` as the reachability engine;
    - erasure of unreachable entries from `module->functions` followed by `module->updateFunctionsMap()`;
    - `createRemoveUnusedFunctionsPass()` factory.
- Historical `pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
  - Key reviewed locations:
    - public `remove-unused-functions` registration;
    - default optimization and global optimization pass lists that scheduled `remove-unused-functions` after duplicate-function elimination.
- Historical `passes.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
  - Key reviewed location: historical public factory declarations around the removal-family pass roster.

### Official Binaryen supersession sources consulted

- Supersession commit
  - URL: <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
  - Key reviewed signal: commit title and diff show a new `RemoveUnusedModuleElements.cpp` pass family replacing the older function-only pass surface.
- `RemoveUnusedModuleElements.cpp` at the supersession commit
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
  - Key reviewed locations:
    - file comment broadens scope to unused module elements, initially functions and globals;
    - `ReachabilityAnalyzer` tracks `Function` and `Global` module elements;
    - roots include start, exported functions/globals, and table-segment functions;
    - the rewrite removes unreachable functions, globals, and relevant imports, then calls `module->updateMaps()`.
- Supersession `pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/pass.cpp>
  - Key reviewed location: public registration changed to `remove-unused-module-elements` and scheduler calls switched to the broader replacement.
- Supersession `passes.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/passes.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/passes.h>
  - Key reviewed location: factory surface changed from the old function-only pass to the broader module-elements pass.

### Official Binaryen current sources consulted

- Current tagged pass registry, `version_129/src/passes/pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - Key reviewed locations:
    - registrations for `remove-unused-brs`, `remove-unused-module-elements`, `remove-unused-nonfunction-module-elements`, `remove-unused-names`, and `remove-unused-types`;
    - no public registration for `remove-unused` or `remove-unused-functions`;
    - default global optimization pre-pass and post-global cleanup use `remove-unused-module-elements`, not the old function-only spelling.
- Current `main/src/passes/pass.cpp`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Key reviewed location: the same removal-family registration surface still appears on the current `main` view checked on 2026-04-25; no teaching-relevant resurrection of `remove-unused` / `remove-unused-functions` was observed.
- Current tagged factory declarations, `version_129/src/passes/passes.h`
  - GitHub: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
  - Raw: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/passes.h>
  - Key reviewed location: current normal-pass factory roster lacks `createRemoveUnusedFunctionsPass()`.
- Current help-test surfaces
  - `wasm-opt`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-opt.test>
  - `wasm-metadce`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-metadce.test>
  - `wasm2js`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm2js.test>
  - Key reviewed role: these are current CLI-oracle surfaces for public pass spellings; they support teaching `remove-unused` as a local legacy-alias problem rather than a missing current upstream pass.

### Official Binaryen overview source consulted

- Binaryen README, current `main`
  - URL: <https://github.com/WebAssembly/binaryen>
  - Key reviewed location: the public optimization overview describes `RemoveUnusedModuleElements` as global DCE that removes imports, functions, globals, and so on when unused. This supports the successor relationship, but the source files above remain the authority for exact pass names and historical lineage.

## Durable observations from the captured sources

- Historical Binaryen exposed a public pass named `remove-unused-functions`.
- That historical pass was function-only: it rooted start/export/table-segment functions, followed direct calls, erased unreachable functions, and rebuilt the function map.
- The supersession commit introduced `RemoveUnusedModuleElements.cpp` and changed the public registration/scheduler/factory surface to the broader `remove-unused-module-elements` pass.
- Current `version_129` and current `main` expose the modern removal-family names, but not `remove-unused` or `remove-unused-functions`.
- Starshine currently tracks the short local name `remove-unused` as boundary-only in `src/passes/optimize.mbt`; active requests are rejected by registry expansion before dispatch.
- Starshine's implemented modern replacement is `remove-unused-module-elements`, whose owner is `src/passes/remove_unused_module_elements.mbt`; it is not the same as implementing the historical function-only alias.

## Uncertainty and caveats

- No direct historical source was found that spells the Starshine local alias `remove-unused` as an intentional alias for upstream `remove-unused-functions`. The relation is an evidence-backed inference from local naming, Batch 4 grouping, and the upstream historical pass lineage.
- The historical `RemoveUnusedModuleElements.cpp` at commit `98e9e604...` was much smaller than modern `version_129` RUME. Use the dedicated RUME dossier for current multi-kind Starshine/Binaryen behavior; use this dossier only for local alias lineage.
- The current `main` spot check was narrow: pass registration and scheduler references were checked for teaching drift, not every helper or test file in the modern RUME implementation.
- If Starshine removes or renames the boundary-only `remove-unused` entry later, this dossier should remain as the migration/supersession explanation and should point users to `remove-unused-module-elements` for current parity work.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living `remove-unused` dossier pages. Do not make this raw source file the explanatory destination.
