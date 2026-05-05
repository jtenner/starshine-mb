# Binaryen `type-merging` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/type-merging/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `type-merging` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in `docs/wiki/raw/binaryen/2026-04-24-type-merging-primary-sources.md`.
Use the living pages for the teachable contract:

- `docs/wiki/binaryen/passes/type-merging/index.md`
- `docs/wiki/binaryen/passes/type-merging/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/type-merging/dfa-partitions-casts-and-refinalization.md`
- `docs/wiki/binaryen/passes/type-merging/wat-shapes.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-strategy.md`
- `docs/wiki/binaryen/passes/type-merging/starshine-port-readiness-and-validation.md`

## Official sources rechecked

### Binaryen `main`

- `TypeMerging.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeMerging.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/TypeMerging.cpp>
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- Dedicated lit test `type-merging.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-merging.wast>
  - Raw URL: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/type-merging.wast>

### Tagged comparison anchor

- `TypeMerging.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/TypeMerging.cpp>
- `pass.cpp` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `type-merging.wast` at `version_129`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/type-merging.wast>

## Durable observations

- Current `main` still exposes `type-merging` through the same public pass name and the same dedicated lit file.
- The reviewed `main` diff against `version_129` on the source surface was non-semantic for this dossier: the only surfaced change was a comment typo fix in `TypeMerging.cpp`.
- The current-main check did not surface any teaching-relevant contract drift from the existing `version_129` story: the pass still reads as a closed-world GC heap-type compaction pass with cast observability, descriptor-chain handling, partition refinement, and whole-module rewrite/refinalization.
- The local Starshine status remains boundary-only and unimplemented; this bridge exists so the new port-readiness page can point at a fresh 2026-05-05 source anchor instead of only the original tagged capture.

## Consumability rule

If future wiki pages restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
