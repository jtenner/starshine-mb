# 0195 - Binaryen `remove-unused` / historical upstream `remove-unused-functions` research

Date: 2026-04-21

_Superseded for raw-source provenance and Starshine status by [`0339-2026-04-25-remove-unused-source-bridge.md`](0339-2026-04-25-remove-unused-source-bridge.md) and [`../binaryen/2026-04-25-remove-unused-primary-sources.md`](../binaryen/2026-04-25-remove-unused-primary-sources.md). This note remains the original folder-creation and lineage-research record._

## Scope

This thread continued the recursive Binaryen pass wiki campaign after the main no-DWARF queue, the saved generated-artifact `-O4z` queue, and the first large upstream-only registry expansion wave were already dossier-covered.

I re-read:

- `docs/README.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

and then looked for a pass-shaped documentation gap that still existed in the local registry.

The candidate that stood out was the boundary-only local name `remove-unused`.

That name was still present in:

- `src/passes/optimize.mbt`
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md`

but it had **no dedicated living folder** under `docs/wiki/binaryen/passes/`, and the tracker did not yet explain what upstream Binaryen surface it actually referred to.

## Candidate selection result

Chosen pass-shaped target: local registry alias `remove-unused`

Why this was eligible even though the current public upstream name is gone:

1. it is still a real Starshine-facing registry name
2. it is still listed in the local Batch 4 map
3. the tracker had no dedicated row for it yet
4. the surrounding removal-family dossiers (`remove-unused-module-elements`, `remove-unused-non-function-elements`, `remove-unused-types`, `remove-unused-names`, `remove-unused-brs`) made the remaining ambiguous short name more misleading, not less
5. official Binaryen history shows that this was once a real upstream pass family entry point under the name `remove-unused-functions`, and official Binaryen later replaced it with the broader `remove-unused-module-elements`

So this is a justified tracker expansion about **lineage and supersession**, not a claim that `version_129` still exposes a public pass literally named `remove-unused`.

## Backlog slice check

`agent-todo.md` has **no dedicated `remove-unused` slice**.

That absence matters because the local registry name is currently ambiguous:

- a future porter could mistake it for a shorthand alias of current `remove-unused-module-elements`
- or for a still-public upstream pass
- or for a request to implement a new bespoke Starshine-only removal pass

The historical Binaryen evidence says the safest interpretation is different:

- the local name is best understood as a stale shorthand for the old upstream **function-only** pass family, not as a current public Binaryen pass name

## Official Binaryen sources reviewed

### Current `version_129` / current-main sources

- `src/passes/pass.cpp`
- `src/passes/passes.h`
- `test/lit/help/wasm-opt.test`
- `test/lit/help/wasm-metadce.test`
- `test/lit/help/wasm2js.test`

Durable result:

- current Binaryen registers:
  - `remove-unused-brs`
  - `remove-unused-module-elements`
  - `remove-unused-nonfunction-module-elements`
  - `remove-unused-names`
  - `remove-unused-types`
- current Binaryen does **not** register:
  - `remove-unused`
  - `remove-unused-functions`

### Historical upstream sources from the official Binaryen git history

- commit `5881b541a4b276dcd5576aa065e4fb860531fc7b`
  - `src/passes/pass.cpp`
  - `src/passes/RemoveUnusedFunctions.cpp`
  - `src/passes/passes.h`
- commit `98e9e604c7e2e4f928abe8f05691df90cddf09e4`
  - `src/passes/pass.cpp`
  - `src/passes/RemoveUnusedModuleElements.cpp`
  - `src/passes/passes.h`

Durable result:

- older Binaryen did publicly register `remove-unused-functions`
- that pass only removed unreachable **functions**
- Binaryen later removed that public pass and replaced it with `remove-unused-module-elements`

## Main historical finding

The key lineage is:

1. old Binaryen had `remove-unused-functions`
2. that pass rooted:
   - the start function
   - exported functions
   - all functions listed in table segments
3. it then ran a direct call graph analysis from those roots
4. it removed unreachable functions and updated the function map
5. later Binaryen replaced this pass with `remove-unused-module-elements`
6. current Binaryen `version_129` no longer exposes `remove-unused-functions` or `remove-unused`

This means the local registry entry `remove-unused` is **not** well described by any of the following shortcuts:

- “the same as modern RUME”
- “a current public Binaryen pass name”
- “a synonym for `remove-unused-types`”
- “a synonym for the local `remove-unused-non-function-elements` sibling”

The best source-backed explanation is:

> `remove-unused` is a stale local shorthand that most likely points at the old upstream `remove-unused-functions` family, which Binaryen replaced in 2016 with the broader `remove-unused-module-elements` pass.

## What the old upstream pass actually did

The old `RemoveUnusedFunctions.cpp` implementation was small and direct.

It:

- built an initial root set from:
  - `module->start`
  - exported functions
  - table segment entries
- ran `DirectCallGraphAnalyzer` from that root set
- erased functions not marked reachable
- called `module->updateFunctionsMap()`

Important limitations of that historical pass:

- it was **function-only**
- it did not remove unused globals, memories, tables, tags, element segments, or data segments
- it rooted all functions callable through table segments conservatively
- it was based on direct-call reachability, not the later stronger/reference-only module-element graph model used by modern RUME

So even historically, this pass was smaller than modern `remove-unused-module-elements`.

## What changed when Binaryen added `remove-unused-module-elements`

Commit `98e9e604...` is the key transition point.

That commit:

- added `RemoveUnusedModuleElements.cpp`
- changed pass registration from `remove-unused-functions` to `remove-unused-module-elements`
- changed the public factory name in `passes.h`
- updated default scheduler uses accordingly

This is the real supersession event.

The practical meaning is:

- if a future Starshine port wants current Binaryen behavior, it should look at `remove-unused-module-elements`
- if a future Starshine registry cleanup wants accurate historical naming, it should describe `remove-unused` as a legacy alias of the old function-only pass lineage

## Current upstream absence matters

The current `version_129` help tests and `pass.cpp` registration are important because they prove this is not merely a missing wiki page for a still-public pass.

The modern public removal-family surface is explicitly split into separate passes:

- `remove-unused-brs`
- `remove-unused-module-elements`
- `remove-unused-nonfunction-module-elements`
- `remove-unused-names`
- `remove-unused-types`

There is no generic catch-all `remove-unused` entry anymore.

So the living wiki should teach the absence explicitly.

## Beginner-facing correction

The easiest wrong mental model is:

- `remove-unused` probably means the current module-wide dead-declaration pass

The source-backed correction is:

- historically, upstream Binaryen's relevant older pass was `remove-unused-functions`
- that old pass only removed unreachable functions
- modern Binaryen replaced it with `remove-unused-module-elements`
- the local short name `remove-unused` is therefore ambiguous and should be treated as a **legacy historical alias**, not as a current public upstream spelling

## Porting / registry consequences for Starshine

A future Starshine cleanup should preserve these conclusions:

1. do **not** document `remove-unused` as if it were a current upstream `version_129` pass
2. do **not** treat it as a synonym for current `remove-unused-module-elements` without explaining the historical lineage
3. if the local registry keeps the entry, document it as a historical alias of old upstream `remove-unused-functions`
4. if the local registry eventually removes or renames it, point users at:
   - `remove-unused-module-elements` for modern module-wide cleanup
   - `remove-unused-non-function-elements` for the rooted-defined-functions sibling
   - `remove-unused-types` for private GC type cleanup
   - `remove-unused-names` and `remove-unused-brs` for function-body cleanup

## Living-doc consequences

This research justifies:

- adding a dedicated `docs/wiki/binaryen/passes/remove-unused/` folder
- adding a tracker row for `remove-unused`
- explicitly marking it as a **legacy local registry alias** tied to historical upstream `remove-unused-functions`, superseded by modern `remove-unused-module-elements`

## Source URLs

Current upstream surfaces:

- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-opt.test>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm-metadce.test>
- <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/help/wasm2js.test>
- <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>

Historical upstream surfaces:

- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/RemoveUnusedFunctions.cpp>
- <https://github.com/WebAssembly/binaryen/blob/5881b541a4b276dcd5576aa065e4fb860531fc7b/src/passes/passes.h>
- <https://github.com/WebAssembly/binaryen/commit/98e9e604c7e2e4f928abe8f05691df90cddf09e4>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/pass.cpp>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/RemoveUnusedModuleElements.cpp>
- <https://github.com/WebAssembly/binaryen/blob/98e9e604c7e2e4f928abe8f05691df90cddf09e4/src/passes/passes.h>
