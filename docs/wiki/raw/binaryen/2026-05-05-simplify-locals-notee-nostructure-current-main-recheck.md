---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.wast
  - https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.txt
related:
  - ../research/0489-2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md
  - ../../binaryen/passes/simplify-locals-notee-nostructure/index.md
---

# Binaryen `simplify-locals-notee-nostructure` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/simplify-locals-notee-nostructure/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `simplify-locals-notee-nostructure` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`2026-04-25-simplify-locals-notee-nostructure-primary-sources.md`](./2026-04-25-simplify-locals-notee-nostructure-primary-sources.md).

## Official sources consulted

### Binaryen `main`

- `SimplifyLocals.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
  - Reviewed lines: the shared-template variant gate and no-tee/no-structure policy (`#L2524-L2598`), plus the late equivalent-get / dead-set cleanup path still guarded by the same policy tuple (`#L3805-L3819`).
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed lines: public registration (`#L3156-L3162`) and the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude gate (`#L3422-L3435`).
- `test/passes/simplify-locals-notee-nostructure.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.wast>
  - Reviewed lines: the dedicated multi-use-local contrast fixture and its no-fresh-tee boundary.
- `test/passes/simplify-locals-notee-nostructure.txt`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-notee-nostructure.txt>
  - Reviewed lines: the golden output that still keeps the multi-use local explicit.

## Durable observations

- Current `main` still teaches the same source-backed contract already captured by the living dossier: the pass is the shared `SimplifyLocals` engine with `allowTee = false`, `allowStructure = false`, and default `allowNesting = true`.
- The dedicated public spelling remains a real `pass.cpp` registration entry and still sits in the aggressive `flatten -> simplify-locals-notee-nostructure -> local-cse` prelude, not in the ordinary no-DWARF `-O` / `-Os` path.
- The reviewed current-main surfaces still show the same useful cleanup families: direct single-use sinking, late equivalent-get canonicalization, dead-overwrite cleanup, final dead-set cleanup, and refinalization when types become more precise.
- The dedicated test pair still centers the same visible boundary: multi-use locals remain explicit, and no new tee or structure carrier is invented.
- No teaching-relevant drift was found on the reviewed current-main surfaces.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
