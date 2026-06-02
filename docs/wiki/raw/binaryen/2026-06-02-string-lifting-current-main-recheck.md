# Binaryen `string-lifting` current-main recheck

_Capture date:_ 2026-06-02  
_Status:_ immutable primary-source recheck for the `docs/wiki/binaryen/passes/string-lifting/` dossier

## Scope

This file records a current-main recheck of Binaryen `string-lifting` so the living dossier can keep its source freshness current without pretending the tagged `version_129` oracle changed.

Use this capture together with:

- `docs/wiki/raw/binaryen/2026-04-24-string-lifting-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-25-string-lifting-signature-fatal-source-correction.md`
- `docs/wiki/raw/binaryen/2026-04-26-string-lifting-current-main-port-readiness.md`
- `docs/wiki/raw/binaryen/2026-05-05-string-lifting-current-main-recheck.md`
- `docs/wiki/raw/research/0327-2026-04-24-string-lifting-primary-sources-and-starshine-followup.md`
- `docs/wiki/raw/research/0346-2026-04-25-string-lifting-signature-fatal-source-correction.md`
- `docs/wiki/raw/research/0385-2026-04-26-string-lifting-port-readiness.md`
- `docs/wiki/raw/research/0457-2026-05-05-string-lifting-current-main-recheck.md`

## Primary sources rechecked

- Binaryen current-main `StringLifting.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/StringLifting.cpp>
- Binaryen current-main `string-lifting.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/string-lifting.wast>
- Binaryen current-main `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

## Recheck result

The reviewed current-main surfaces still match the living dossier’s contract:

- `string-lifting` remains a module pass that lifts imported string globals and `wasm:js-string` helper calls into wasm string instructions.
- The helper-signature matrix remains the same: wrong module unchanged, unknown helper base warning plus unchanged, recognized helper base with wrong signature fatal, recognized helper base with exact signature liftable.
- The dedicated lit file still proves the main magic-import and helper-call families, while the JSON `string.consts` path remains source-confirmed from `StringLifting.cpp` rather than heavily isolated in the direct test file.
- The pass still refinalizes changed functions, walks module code, removes consumed `string.consts`, enables the Strings feature, and keeps the open cast-repair TODO visible.

## Drift note

No teaching-relevant drift was found on the checked current-main surfaces. This recheck is a freshness update, not a contract change.
