---
kind: raw-source
status: supported
last_reviewed: 2026-05-05
sources:
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp
  - https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast
related:
  - ../research/0485-2026-05-05-merge-locals-current-main-recheck.md
  - ../../binaryen/passes/merge-locals/index.md
---

# Binaryen `merge-locals` current-main recheck

_Capture date:_ 2026-05-05  
_Status:_ immutable current-main source bridge for the `docs/wiki/binaryen/passes/merge-locals/` dossier

## Scope

This file records the primary online sources rechecked for the 2026-05-05 `merge-locals` wiki-health pass.
It extends, rather than replaces, the earlier tagged-source manifest in [`2026-04-25-merge-locals-current-main-source-correction.md`](./2026-04-25-merge-locals-current-main-source-correction.md) and the 2026-05-04 freshness bridge in [`2026-05-04-merge-locals-current-main-recheck.md`](./2026-05-04-merge-locals-current-main-recheck.md).

## Official sources consulted

### Binaryen `main`

- `MergeLocals.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/MergeLocals.cpp>
  - Reviewed lines: the pass comment and `invalidatesDWARF()` contract (`#L761-L839`), the copy instrumentation / trivial tee insertion path (`#L847-L905`), the eager `LocalGraph` snapshot and influence solve (`#L915-L928`), and the post-graph rollback verification (`#L1080-L1145`).
- `pass.cpp`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Reviewed lines: public registration (`#L2769-L2770`) and the late-local scheduler gate that only adds `merge-locals` when `optimizeLevel >= 3 || shrinkLevel >= 2` (`#L3524-L3528`).
- `merge-locals.wast`
  - URL: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/merge-locals.wast>
  - Reviewed lines: the dedicated `between-unreachable` regression and its `--merge-locals -all -S` harness (`#L301-L349`).

## Durable observations

- Current `main` still teaches the same copy-shaped local-balancing contract captured by the living dossier: instrument a `local.set` / `local.get` copy with a trivial `local.tee`, compute an eager `LocalGraph`, choose an orientation, and roll back bad candidates after post-graph verification.
- `merge-locals` still invalidates DWARF because it changes local identity.
- The scheduler story is unchanged: the pass remains late-local cleanup for stronger optimize/shrink levels, not a no-DWARF default slot.
- The official lit file still centers the conservative `between-unreachable` boundary and does not suggest a broader one-set-local model.
- No teaching-relevant drift was found on the reviewed current-main surfaces.

## Consumability rule

If future wiki pages need to restate the source-backed conclusions, cite this raw capture together with the living dossier pages instead of treating this file itself as the explanatory destination.
