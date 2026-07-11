# Binaryen `gufa` content-oracle implementation source refresh

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source bridge for the living `docs/wiki/binaryen/passes/gufa/` dossier

## Scope

This refresh closes a source-map gap in the older GUFA captures: they cited the public `PossibleContents` / `ContentOracle` header but omitted the companion implementation file, `src/ir/possible-contents.cpp`. It rechecks the current Binaryen pass owner, registration, oracle header **and implementation**, and the three public GUFA-family fixtures.

The bridge is intentionally narrow. It establishes the current owner map and the public family boundaries; it is **not** a line-by-line `version_130`-to-`main` diff, a new Binaryen execution run, or Starshine parity evidence.

## Official sources rechecked

### Binaryen `main`

- `src/passes/GUFA.cpp`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GUFA.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/GUFA.cpp>
- `src/passes/pass.cpp`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `src/ir/possible-contents.h`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-contents.h>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/possible-contents.h>
- `src/ir/possible-contents.cpp`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/ir/possible-contents.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/ir/possible-contents.cpp>
- `test/lit/passes/gufa.wast`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gufa.wast>
- `test/lit/passes/gufa-optimizing.wast`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-optimizing.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gufa-optimizing.wast>
- `test/lit/passes/gufa-cast-all.wast`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gufa-cast-all.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/gufa-cast-all.wast>

### Current tagged-release anchor

- `version_130` `GUFA.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/GUFA.cpp>
- `version_130` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/passes/pass.cpp>
- `version_130` `possible-contents.h`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/possible-contents.h>
- `version_130` `possible-contents.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_130/src/ir/possible-contents.cpp>
- `version_130` GUFA-family fixtures: <https://github.com/WebAssembly/binaryen/tree/version_130/test/lit/passes>
- Official release: <https://github.com/WebAssembly/binaryen/releases/tag/version_130>

## Durable observations

- `gufa`, `gufa-optimizing`, and `gufa-cast-all` remain distinct public registrations backed by the shared `GUFA.cpp` pass family; `type-refining-gufa` remains a related but separate public client of the contents-analysis idea.
- The source ownership of the oracle has two parts: `possible-contents.h` exposes `PossibleContents` and `ContentOracle` types and queries, while `possible-contents.cpp` implements the analysis machinery. A future port should not treat the header's result-kind vocabulary as the complete algorithm.
- The public pass owner still consumes a module-level contents oracle and applies the established narrow rewrite families: generic unreachable/known-content replacement plus dedicated `ref.eq`, `ref.test`, and existing-`ref.cast` handling. The public siblings still separate post-rewrite cleanup (`gufa-optimizing`) from fresh cast insertion (`gufa-cast-all`).
- The current fixture split remains useful as a public proof map: `gufa.wast` for the base oracle/rewrite surface, `gufa-optimizing.wast` for cleanup behavior, and `gufa-cast-all.wast` for cast materialization.
- The current repository evidence still classifies all three Starshine spellings as boundary-only. `src/passes/optimize.mbt` lists them in `pass_registry_boundary_only_names()`, `src/passes/pass_manager.mbt` has no GUFA dispatch case, and `scripts/lib/pass-fuzz-compare-task.ts` does not admit `--gufa` to `SUPPORTED_PASS_FLAGS`.

## Correction and uncertainty

The older 2026-04-24 and 2026-05-05 manifests are still useful historical provenance, but their source maps were incomplete because they named only `possible-contents.h`. This bridge supersedes them **for oracle implementation ownership**, not for every historical explanation.

No full source diff or upstream test execution was performed in this refresh. Therefore it does not claim that every internal analysis detail or every `version_130`-to-`main` fixture change is behavior-identical. Reopen the living contract if a complete source diff, a new Binaryen release, or a direct differential result finds a behavior-bearing change.

## Consumability rule

Use this capture for the current owner-map and uncertainty statement. Use the living `gufa` pages for explanations, WAT shapes, Starshine port planning, and future validation requirements.
