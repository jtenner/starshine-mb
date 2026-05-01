# Binaryen `rereloop` current-main spot-check and source manifest

_Capture date:_ 2026-04-30  
_Status:_ immutable source manifest for a focused rerun of the `docs/wiki/binaryen/passes/rereloop/` dossier

## Scope

This capture records the official `main` files revisited for `rereloop`/`re-reloop` pass-contract hygiene after earlier `version_129`-anchored work.
It does **not** replace the broader primary-source manifest in
[`2026-04-24-rereloop-primary-sources.md`](2026-04-24-rereloop-primary-sources.md);
it narrows the link set for quick spot-check reproducibility.

## Consulted official `main` source URLs

- `src/passes/ReReloop.cpp` — <https://github.com/WebAssembly/binaryen/blob/main/src/passes/ReReloop.cpp>
- `src/passes/pass.cpp` — <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- `src/cfg/Relooper.h` — <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/Relooper.h>
- `src/cfg/Relooper.cpp` — <https://github.com/WebAssembly/binaryen/blob/main/src/cfg/Relooper.cpp>
- `src/ir/flat.h` — <https://github.com/WebAssembly/binaryen/blob/main/src/ir/flat.h>
- `test/lit/passes/flatten_rereloop.wast` — <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/flatten_rereloop.wast>
- `test/lit/passes/opt_flatten.wast` — <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/opt_flatten.wast>

## Durable observations from this refresh

- The official `main` spot-check URLs above cover the same contract surface as the `version_129` dossier: pass registration, flat-input gate, task-based CFG shaping, helper-label-local rendering, and post-render result-fixups.
- In this refresh, `rereloop` is still documented as a hard-`flat`-discipline upstream pass and as not yet integrated into the default in-tree pass-slot evidence from the local `Starshine` docs.
- No new upstream source evidence was added for EH support; `Try`/`Throw`/`Rethrow` remain the documented hard boundary in the local pages.
- This capture is intended for future parity/refresh comparisons and to keep the docs' raw-source provenance directly linked to official upstream head files.

## Link-forwarding guidance

When updating or auditing `rereloop` pass-doc pages, cite this file along with
[`2026-04-24-rereloop-primary-sources.md`](2026-04-24-rereloop-primary-sources.md)
for both canonical-version and latest-head provenance.
