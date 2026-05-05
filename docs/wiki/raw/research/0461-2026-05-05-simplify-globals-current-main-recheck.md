# 0461 - simplify-globals current-main recheck

## Question

Did Binaryen current `main` drift in a way that changes the living Starshine dossier for plain `simplify-globals`?

## What I re-read

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/simplify-globals/`
- `docs/wiki/binaryen/passes/simplify-globals-optimizing/`
- `docs/wiki/binaryen/passes/propagate-globals-globally/`
- `docs/wiki/raw/research/`
- the official current-main Binaryen `SimplifyGlobals.cpp`, `pass.cpp`, `pass.h`, helper headers, and clustered `simplify-globals*` / `propagate-globals-globally.wast` tests
- the existing plain `simplify-globals` dossier and the neighboring optimizing / startup-only sibling dossiers

## Findings

- Current `main` still presents the same shared `SimplifyGlobals.cpp` family split as the tagged `version_129` contract used by the existing wiki pages.
- The public pass split remains the same: plain `simplify-globals`, `simplify-globals-optimizing`, and `propagate-globals-globally` are still separate names over one shared engine.
- The plain-pass teaching story still needs the same corrections already captured in the wiki: whole-module global facts, startup-vs-runtime separation, actual-node matching for `read-only-to-write`, and `drop(value)` preservation for dead writes.
- No teaching-relevant current-main drift was found on the reviewed surfaces.

## Filing result

This research was filed back into the wiki as a freshness bridge for the plain dossier. The main durable outcome is that the plain-pass page set can now cite a 2026-05-05 current-main recheck without changing the upstream contract.
