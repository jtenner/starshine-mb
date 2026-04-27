# `minify-imports` port readiness

_Date:_ 2026-04-27  
_Status:_ absorbed into living wiki pages

## Question

How should Starshine explain and eventually stage a faithful implementation of Binaryen's plain `minify-imports` pass after the 2026-04-26 source correction showed that the pass mutates import declarations rather than merely reporting imported functions?

## Sources read

- `docs/README.md`
- `docs/wiki/binaryen/passes/minify-imports/index.md`
- `docs/wiki/binaryen/passes/minify-imports/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports/env-wasi-json-map-and-module-merge.md`
- `docs/wiki/binaryen/passes/minify-imports/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/minify-imports/wat-shapes.md`
- `docs/wiki/binaryen/passes/minify-imports/starshine-strategy.md`
- `docs/wiki/binaryen/passes/minify-imports-and-exports/starshine-port-readiness-and-validation.md`
- `docs/wiki/raw/binaryen/2026-04-26-minify-imports-current-main-source-correction.md`
- `docs/wiki/raw/binaryen/2026-04-27-minify-imports-port-readiness-primary-sources.md`
- Official Binaryen `version_129` and current-main `MinifyImportsAndExports.cpp`, `pass.cpp`, `passes.h`, `name.h`, and the sibling minify lit fixture listed in the raw manifest.
- Starshine source surfaces listed in the raw manifest: pass registry, module dispatcher, `Import` / `ImportSec` records, binary import decode/encode, and WAT import lowering.

## Findings

- The existing dossier already had the corrected overview, Binaryen strategy, shape catalog, and Starshine status page, but it lacked the newer implementation-readiness bridge used by many other pass folders.
- The faithful local port is module-scoped. It rewrites `ImportSec` names and emits or captures a JSON map; it cannot be represented as a HOT peephole.
- Registry behavior is the first decision point. Today `minify-imports` is absent and therefore rejected as an unknown pass; a future port must intentionally choose between keeping it unknown, adding a boundary-only entry, or adding an active module pass.
- The first safe mutating slice should target only the plain pass contract: `env` / `wasi_` import base names across import kinds, no export-name mutation, no module-name mutation, and separate JSON-output parity checks.
- Exact minified names and JSON formatting remain Binaryen-revision-sensitive. Examples in the wiki are teaching aids, not conformance fixtures.

## Living-page changes made

- Added `docs/wiki/binaryen/passes/minify-imports/starshine-port-readiness-and-validation.md`.
- Refreshed the minify-imports landing page, Binaryen strategy, implementation/test map, WAT shapes, and Starshine strategy to point at the new bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Follow-up questions

- If Starshine implements this family, should reporting passes return a richer pass-result object instead of writing JSON to stdout?
- Should the plain pass be implemented before or after `minify-imports-and-exports`, given that the sibling has broader existing documentation but the plain pass has the narrower ABI contract?
- Should upstream-only ABI-minification passes remain excluded from presets permanently, even after implementation?
