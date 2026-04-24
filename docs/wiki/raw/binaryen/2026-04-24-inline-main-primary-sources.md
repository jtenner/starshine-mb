# Binaryen `inline-main` primary-source capture

_Capture date:_ 2026-04-24  
_Status:_ immutable source manifest for the `docs/wiki/binaryen/passes/inline-main/` dossier

## Scope

This file captures the primary online sources consulted for the 2026-04-24 `inline-main` provenance and Starshine status follow-up. It is provenance-heavy rather than explanatory; use the living dossier pages for interpretation:

- `docs/wiki/binaryen/passes/inline-main/index.md`
- `docs/wiki/binaryen/passes/inline-main/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/inline-main/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/inline-main/special-case-contract-and-boundaries.md`
- `docs/wiki/binaryen/passes/inline-main/wat-shapes.md`
- `docs/wiki/binaryen/passes/inline-main/starshine-strategy.md`

## Provenance

### Official release pages consulted

- Binaryen GitHub release `version_129`
  - URL: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
  - Page observed on 2026-04-24.
  - Neighboring 2026-04-24 pass ingests observed GitHub showing the publish timestamp as **2026-04-01 14:31**; this follow-up keeps `version_129` as the release oracle for the source reading.
- Binaryen GitHub releases index
  - URL: <https://github.com/WebAssembly/binaryen/releases>
  - Page observed on 2026-04-24 in the pass-ingest campaign.

### Official source files consulted

- `src/passes/Inlining.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/Inlining.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/Inlining.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/Inlining.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/Inlining.cpp>
- `src/passes/pass.cpp`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/pass.cpp>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>

### Official helper and dependency files consulted

These files matter because `inline-main` reuses the ordinary low-level inlining helper from `Inlining.cpp`, not because they contain a separate `inline-main` chooser:

- `src/pass.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/pass.h>
- `src/passes/opt-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/passes/opt-utils.h>
- `src/ir/branch-utils.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/branch-utils.h>
- `src/ir/find_all.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/find_all.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/find_all.h>
- `src/ir/metadata.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/metadata.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/metadata.h>
- `src/ir/names.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/names.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/names.h>
- `src/ir/type-updating.h`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/type-updating.h>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/src/ir/type-updating.h>

### Official test files consulted

- `test/lit/passes/inline-main.wast`
  - `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/inline-main.wast>
  - raw `version_129`: <https://raw.githubusercontent.com/WebAssembly/binaryen/version_129/test/lit/passes/inline-main.wast>
  - `main`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/inline-main.wast>
  - raw `main`: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/inline-main.wast>

## Durable observations from the captured sources

- `inline-main` is a real public Binaryen pass in `version_129`, registered in `src/passes/pass.cpp` beside `inlining` and `inlining-optimizing` with a description specifically about inlining `__original_main` into `main`.
- The implementation lives in `src/passes/Inlining.cpp`, but the `InlineMainPass` chooser is much smaller than the ordinary inlining planner: it looks up exactly `main` and `__original_main`, rejects imported endpoints, scans only direct `Call` nodes in `main`, requires exactly one target call, and then calls shared `doInlining(...)`.
- The upstream comment ties the pass to the Clang/LLVM `main` / `__original_main` wrapper pattern rather than to a generic inlining heuristic.
- The shared helper still matters: successful `inline-main` rewrites inherit body copying, parameter/local remapping, return-to-break rewriting, label-uniqueness repair, refinalization, and nondefaultable-local repair from the ordinary inlining machinery.
- The dedicated `inline-main.wast` lit file proves the acceptance and bailout matrix: one-call positive, already-inlined no-op, missing endpoint no-ops, multi-call bailout, imported-`main` bailout, and imported-`__original_main` bailout.
- A narrow 2026-04-24 current-`main` spot check on the `InlineMainPass` section did not reveal a teaching-relevant drift in the chooser contract. This is not a full audit of all shared inlining helper behavior on trunk.
- Starshine-specific follow-up in this run did not find a local implementation file. The durable local fact is that `inline-main` is a **boundary-only** registry name and explicit requests are rejected before any hot/module pass executes.

## Uncertainties and contradictions

- The earlier research note's core source reading still matches this follow-up. This capture supersedes the older note for primary-source provenance because it gives the dossier an immutable raw manifest and records the 2026-04-24 Starshine status bridge.
- `InlineMainPass` passes `insideATry = true` to `InliningAction`. The practical effect for ordinary non-`return_call` wrapper shapes appears limited because the pass only scans direct `Call` nodes, but the exact reason is inherited shared-helper behavior rather than a dedicated source comment. Living pages should keep that as an inference, not as a directly documented upstream design note.
- This capture focuses on official Binaryen `version_129` source/tests plus a narrow current-main spot check. It does not claim exhaustive equivalence between the release tag and current trunk.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages and the 2026-04-24 Starshine follow-up research note.
