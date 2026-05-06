# `simplify-locals-notee-nostructure` current-main recheck

Date: 2026-05-05

This short research note records the wiki-health conclusion from the official Binaryen current-main spotcheck.

## Conclusion

`simplify-locals-notee-nostructure` still has the same source-backed contract already taught by the living dossier:
shared `SimplifyLocals` policy mode, no fresh tees, no structure synthesis, and the same aggressive post-`flatten` placement.

## Why the wiki update mattered

The existing dossier was already correct, but it lacked a 2026-05-05 freshness layer.
This note supports refreshing the living pages without changing the upstream algorithm story.

## Primary sources

- `docs/wiki/raw/binaryen/2026-05-05-simplify-locals-notee-nostructure-current-main-recheck.md`
- Binaryen `main` `SimplifyLocals.cpp`
- Binaryen `main` `pass.cpp`
- Binaryen `main` `test/passes/simplify-locals-notee-nostructure.wast`
- Binaryen `main` `test/passes/simplify-locals-notee-nostructure.txt`
