# Binaryen `rse` current-main recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable current-main primary-source bridge for the `docs/wiki/binaryen/passes/rse/` dossier

## Scope

This focused reread refreshes the **upstream** freshness claim made by the older 2026-05-05 bridge. It does not replace the living Starshine implementation, parity, or performance evidence recorded in the RSE dossier and its linked research notes.

The reread compares the official Binaryen `main` owner, registration, and dedicated test surfaces with the still-useful `version_129` contract captured in [`2026-04-26-rse-cfg-source-correction.md`](2026-04-26-rse-cfg-source-correction.md) and the prior current-main bridge [`2026-05-05-rse-current-main-recheck.md`](2026-05-05-rse-current-main-recheck.md).

## Official sources rechecked

### Binaryen `main`

- `src/passes/RedundantSetElimination.cpp`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/RedundantSetElimination.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/RedundantSetElimination.cpp>
- `src/passes/pass.cpp`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/src/passes/pass.cpp>
- `test/passes/rse_all-features.wast`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/rse_all-features.wast>
- `test/passes/rse_all-features.txt`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/passes/rse_all-features.txt>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/passes/rse_all-features.txt>
- `test/lit/passes/rse-gc.wast`
  - Source: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/rse-gc.wast>
  - Raw source: <https://raw.githubusercontent.com/WebAssembly/binaryen/main/test/lit/passes/rse-gc.wast>

### Tagged comparison anchor

- `version_129` `RedundantSetElimination.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/RedundantSetElimination.cpp>
- `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- `version_129` `rse_all-features.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/rse_all-features.wast>
- `version_129` `rse-gc.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/rse-gc.wast>

## Durable observations

The inspected `main` surfaces retain the contract taught by the living dossier:

- public registration still exposes `rse` / `redundant-set-elimination` through the same pass owner;
- the owner remains a `CFGWalker`-based local analysis with collected `LocalGet` / `LocalSet` sites, per-block start/end facts, a deferred fixed-point flow phase, and an optimization rescan;
- same-value `local.set` and `local.tee` shells remain the deletion target; non-tee removal preserves RHS evaluation through a drop-like replacement;
- strict-subtype equivalent-local `local.get` retargeting and conditional `ReFinalize` remain part of the owner contract;
- the dedicated ordinary all-features and GC/refinement fixtures remain the reviewed proof surfaces;
- no `LocalGraph` / liveness-backed generic dead-store transform, global/memory/heap-store deletion, or new teaching-relevant transform family appeared on the inspected surfaces.

The only visible owner-file difference in the reviewed version-to-main comparison is a comment spelling correction (`vaccum` to `vacuum`); it is not behavior-bearing.

## Scope and uncertainty

This is a narrow source reread, not a full commit-history audit or a new parity run. It supersedes the **freshness claim** of the 2026-05-05 bridge, while preserving that capture and the 2026-04-26 correction as historical provenance. Reopen the living contract if a later owner/test source change, a Binaryen release, or a direct RSE mismatch demonstrates behavior-bearing drift.

## Consumability rule

Cite this manifest for the 2026-07-11 current-main provenance claim, then route explanation to the living RSE pages rather than treating this capture as the primary tutorial.
