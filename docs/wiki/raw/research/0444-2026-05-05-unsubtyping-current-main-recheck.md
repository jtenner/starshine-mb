# 0444 - `unsubtyping` current-main refresh and port-readiness bridge

Date: 2026-05-05  
Status: completed research ingest  
Pass: `unsubtyping`  
Local registry status: `boundary-only` in `src/passes/optimize.mbt`  
Related living dossier: `docs/wiki/binaryen/passes/unsubtyping/`

## Why this follow-up exists

The `unsubtyping` dossier was already source-correct, but it still lacked the now-standard current-main freshness bridge and a dedicated port-readiness / validation page.

This follow-up records the 2026-05-05 source refresh and supplies the missing navigation layer so future readers can move from the contract pages to the local implementation gap without relying on chat history.

## Primary online sources reviewed

- Binaryen GitHub source files on `main`:
  - `src/passes/Unsubtyping.cpp`
  - `src/passes/pass.cpp`
  - `test/lit/passes/unsubtyping.wast`
  - `test/lit/passes/unsubtyping-casts.wast`
  - `test/lit/passes/unsubtyping-cmpxchg.wast`
  - `test/lit/passes/unsubtyping-desc.wast`
  - `test/lit/passes/unsubtyping-desc-tnh.wast`
  - `test/lit/passes/unsubtyping-jsinterop.wast`
  - `test/lit/passes/unsubtyping-stack-switching.wast`
- Existing living dossier pages for `unsubtyping`

## Source-backed Binaryen conclusions

- `unsubtyping` is still the same closed-world GC/type relation-pruning pass on the reviewed surfaces.
- The contract still centers on minimal remaining subtype and descriptor edges, not generic type optimization.
- The current-main implementation shape remains consistent with the living `version_129` explanation on the reviewed surfaces.
- No teaching-relevant drift was found in the reviewed owner / registration / lit-file surfaces.

## Starshine local code map

The current local status is still boundary-only, not executable:

- `src/passes/optimize.mbt:127-139`
  - `pass_registry_boundary_only_names()` includes `unsubtyping`.
- `src/passes/optimize.mbt:519-523`
  - boundary-only requests are rejected before any hot-pipeline execution.
- `src/lib/types.mbt:29-130`
  - the local type graph representation exists, but no `unsubtyping` rewrite is implemented.
- `src/wast/module_wast_tests.mbt:308-407`
  - type-section and descriptor roundtrip fixtures are available for future regression coverage.
- `src/wast/ref_null_exact_surface_test.mbt:1-85`
  - exact and bottom descriptor refs already have parser / lowerer / validator coverage.
- `docs/0063-2026-03-24-pass-port-batches-and-registry-map.md:54-59`
  - the older batch map still groups `unsubtyping` with boundary-only type-cluster work.
- `agent-todo.md`
  - there is still no dedicated `unsubtyping` slice.

## Local status conclusion

Starshine still keeps `unsubtyping` as an honest boundary-only name. That is useful because the CLI and registry surfaces can reject it explicitly, but it is not yet a runnable transform.

## Future-port constraints

A faithful future port must preserve the closed-world + GC gate, the minimal subtype-plus-descriptor fixed point, descriptor-square completion, cast observability, JS-boundary keepalive, allocation fixups, and final refinalization.

Minimum future-port checklist:

1. keep the public `unsubtyping` registry entry separate from the neighboring GC/type cleanup passes;
2. add a real module/type-graph owner instead of a HOT peephole;
3. seed required relations from validation, casts, descriptors, JS boundaries, and public edges;
4. distinguish ordinary casts from exact casts;
5. preserve descriptor squares and descriptor-bearing allocation traps;
6. rewrite private type declarations and all affected uses consistently;
7. validate the type-section rewrite together with the downstream `remove-unused-types` combo;
8. keep the boundary-only rejection honest until the port exists.

## Living page updates from this follow-up

Updated or added:

- `docs/wiki/raw/binaryen/2026-05-05-unsubtyping-current-main-recheck.md`
- `docs/wiki/binaryen/passes/unsubtyping/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/unsubtyping/index.md`
- `docs/wiki/binaryen/passes/unsubtyping/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/unsubtyping/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/unsubtyping/starshine-strategy.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`

## Supersession note

This note extends the earlier 2026-04-24 `unsubtyping` source notes. It does not replace the existing contract pages; it only adds a current-main freshness bridge and the missing port-readiness navigation.
