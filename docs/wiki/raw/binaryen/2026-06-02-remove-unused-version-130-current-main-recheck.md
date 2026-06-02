# Binaryen `remove-unused` version_130 current-main recheck

_Capture date:_ 2026-06-02  
_Status:_ immutable current-main / release-horizon freshness manifest for the historical `remove-unused` alias story

## Scope

This capture rechecks the official Binaryen sources that matter to the local `remove-unused` lineage question.
It asks one question: does the current `version_130` release horizon still expose a public short spelling named `remove-unused` or `remove-unused-functions`?

The answer on the reviewed surfaces is still no.

## Official sources reviewed

- Binaryen `src/passes/pass.cpp`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/src/passes/pass.cpp>
  - `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
  - Reviewed surfaces: the public pass-registration block still exposes modern `remove-unused-module-elements` / `remove-unused-nonfunction-module-elements`, and the reviewed block does **not** register a public `remove-unused` or `remove-unused-functions` spelling.
- Binaryen `test/lit/help/wasm-opt.test`
  - `version_130`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_130/test/lit/help/wasm-opt.test>
  - Reviewed surfaces: the help listing includes `--remove-unused-module-elements`, `--remove-unused-nonfunction-module-elements`, and `--remove-unused-types`; it does **not** list `--remove-unused`.

## Durable observations

- The current `version_130` release horizon still matches the older lineage story: Binaryen exposes the modern module-element cleanup names, not the short `remove-unused` alias.
- The `remove-unused` dossier should therefore stay framed as a legacy registry / alias issue, not as an active upstream public pass spelling.
- This recheck does **not** change the historical contract of old `remove-unused-functions`; it only confirms the public spelling gap remains.

## Caveats

- This is a source freshness check, not a full re-audit of adjacent helper code or the entire Binaryen release train.
- The absence claim is limited to the reviewed registration/help surfaces listed above.
