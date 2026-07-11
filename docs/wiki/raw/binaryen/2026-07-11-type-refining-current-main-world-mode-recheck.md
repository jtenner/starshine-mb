# Binaryen `type-refining`: current-main world-mode recheck

_Capture date:_ 2026-07-11  
_Status:_ immutable primary-source freshness manifest for the `docs/wiki/binaryen/passes/type-refining/` dossier

## Scope

This focused recheck revisits Binaryen current `main` after the older tagged `version_129` source manifest (2026-04-24) and current-main readiness capture (2026-04-27). It asks whether the published teaching contract still holds and records the one material API-shaped drift that a future Starshine port must model.

This document is provenance, not the explanatory destination. Use the maintained type-refining dossier for algorithm and port-planning guidance.

## Official sources reread

- Owner: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/TypeRefining.cpp>
- Registration/default scheduling: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Base-pass fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining.wast>
- GUFA fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa.wast>
- Exactness fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-exact.wast>
- RMW/cmpxchg fixture: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/type-refining-gufa-rmw.wast>

## Current-main result

The published semantic contract remains intact:

- The pass is GC-gated and still handles **struct fields only**; the owner retains the TODO for arrays.
- Base `type-refining` still uses direct `StructUtils::StructScanner` evidence, while `type-refining-gufa` uses `ContentOracle`; both feed the same rewrite/fixup back end.
- Ordinary reads still do not constrain inferred field contents. Invalidated reads are repaired before type rewriting, then `GlobalTypeRewriter`, `ReFinalize`, and a write-repair walker preserve validity.
- Public heap types remain frozen, hierarchy/mutability constraints remain enforced, and broad writes still receive cast or bottom/trap repair after type changes.
- The dedicated base and GUFA lit families remain the relevant behavior oracle surfaces.

## Material source-interface drift: `WorldMode` replaces the old boolean gate

Current `TypeRefining::run` no longer expresses its required analysis mode through a boolean `closedWorld` option. It now rejects only:

```text
getPassOptions().worldMode == WorldMode::Open
```

and reports that `TypeRefining` requires `--closed-world`.

This preserves the semantic rule that ordinary open-world analysis is invalid for the pass, but the API now has a richer world-mode policy. The same policy is used by:

- `ModuleUtils::getPublicHeapTypes(*module, getPassOptions().worldMode)` while deciding which declarations must remain externally stable; and
- `GlobalTypeRewriter(wasm, parent.getPassOptions().worldMode)` while rebuilding the private type graph.

A future Starshine port must therefore model **one explicit world/visibility policy** across gating, public-type classification, and global type rewriting. It must not reduce the current upstream behavior to a private boolean or assume that “not open” grants the same rewrite permissions in every future world mode.

## Current Starshine reconciliation

Local inspection remains unchanged:

- `src/passes/optimize.mbt` keeps only `type-refining` as `BoundaryOnly`.
- No local owner exists, and `type-refining-gufa` is not a registered local spelling.
- `scripts/lib/pass-fuzz-compare-task.ts` does not admit either spelling in `SUPPORTED_PASS_FLAGS`.

Those facts establish local status only; they are not transform-parity evidence.

## Supersession and limits

- This capture supersedes the 2026-04-27 **current-main freshness statement** for `type-refining`; it does not replace the `version_129` algorithm manifest or historical readiness source capture.
- The observed drift is narrow and interface-level. This review does not claim that every Binaryen helper implementation is unchanged.
- `main` is mutable. The conclusions are a dated observation and should be refreshed before implementation begins.
