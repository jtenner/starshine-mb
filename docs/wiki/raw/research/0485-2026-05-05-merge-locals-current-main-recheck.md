# `merge-locals` current-main recheck

Date: 2026-05-05

This short research note records the wiki-health conclusion from the official Binaryen current-main spotcheck.

## Conclusion

`merge-locals` still has the same source-backed contract already taught by the living dossier:
copy-shaped local traffic is instrumented with a trivial tee, `LocalGraph` decides which side should own the influenced gets, and a post-graph check rolls back unsafe candidates.

## Why the wiki update mattered

The existing `merge-locals` dossier was already source-correct, but it lacked a dedicated Starshine port-readiness bridge and a 2026-05-05 freshness layer.
This research note supports adding both without changing the upstream algorithm story.

## Primary sources

- `docs/wiki/raw/binaryen/2026-05-05-merge-locals-current-main-recheck.md`
- Binaryen `main` `MergeLocals.cpp`
- Binaryen `main` `pass.cpp`
- Binaryen `main` `test/lit/passes/merge-locals.wast`
