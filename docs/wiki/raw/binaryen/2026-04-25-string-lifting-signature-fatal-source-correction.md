# Binaryen `string-lifting` signature-failure source correction

_Capture date:_ 2026-04-25  
_Status:_ immutable corrective source bridge for the `docs/wiki/binaryen/passes/string-lifting/` dossier

## Scope

This file captures a focused re-read of Binaryen `string-lifting` primary sources after a wiki health check found stale wording in the 2026-04-24 living dossier: several pages described wrong helper signatures as a no-rewrite bailout. The reviewed source instead treats a recognized `wasm:js-string` helper name with the wrong type as a fatal pass error.

Use this file together with the original manifest:

- `docs/wiki/raw/binaryen/2026-04-24-string-lifting-primary-sources.md`
- `docs/wiki/raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`

## Primary sources rechecked

- `StringLifting.cpp`, `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp>
  - focused locations: imported-helper scan in `StringLifting::run(...)`; local `checkImport(...)` helper; unknown-helper warning branch; `StringApplier::visitCall(...)` rewrite map.
  - line anchors for the reviewed region: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp#L100-L170> and <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/StringLifting.cpp#L200-L260>.
- `StringLifting.cpp`, current `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
  - focused current-main line anchors: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp#L100-L170> and <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp#L200-L260>.
- `string-lifting.wast`, `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/string-lifting.wast>
- `string-lifting.wast`, current `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>

## Correction

The helper import discovery code is a three-way classifier:

1. imports outside module `wasm:js-string` are ignored;
2. imports inside `wasm:js-string` with an unrecognized base produce a warning and are not lifted;
3. imports inside `wasm:js-string` with a recognized base but a wrong expected function type are a fatal error, not an unchanged-call bailout.

The durable corrected rule is:

- wrong module: unchanged;
- unknown helper base in the helper module: warning plus unchanged;
- recognized helper base with wrong signature: fatal pass error;
- recognized helper base with exact expected signature: helper becomes liftable and later calls rewrite to wasm string operations.

## Current-main freshness

The 2026-04-25 focused current-main recheck did not find teaching-relevant drift for this correction. Current `main` still uses the same recognized-helper wrong-type fatal behavior on the checked surface.

## Living-page impact

The earlier living dossier remains correct about the pass direction, supported helper roster, magic and JSON string-constant paths, refinalization, module-code walk, Strings feature enablement, and open cast-repair TODO. It is superseded only for the wrong-signature behavior and any validation guidance that expected wrong signatures to remain unchanged.

## Evidence caveats

- The dedicated `string-lifting.wast` lit file directly proves wrong-module / wrong-name non-lifting, but it does not appear to isolate the wrong-signature fatal case in the reviewed surface.
- The fatal wrong-signature behavior is source-confirmed from `StringLifting.cpp`; future Starshine parity tests should include an explicit wrong-signature fixture if the pass is ever tracked locally.
