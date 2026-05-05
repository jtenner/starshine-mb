# 0455 - Pick Load Signs Current-Main Recheck

## Question

Did official Binaryen `main` drift from the existing `pick-load-signs` dossier on the reviewed source and test surfaces, and what durable wiki updates should follow?

## Finding

The 2026-05-05 current-main recheck found no teaching-relevant drift on the reviewed `PickLoadSigns.cpp`, `pass.cpp`, `opt-utils.h`, `properties.h`, and dedicated test surfaces.
The upstream pass still matches the narrow `version_129` contract already taught in the living dossier.

## Durable updates made

- Added `docs/wiki/raw/binaryen/2026-05-05-pick-load-signs-current-main-recheck.md`.
- Refreshed the living `pick-load-signs` dossier pages with the new freshness bridge.
- Added a dedicated Starshine strategy page so the folder now separates upstream semantics from current in-tree status more cleanly.

## Remaining nuance

Starshine's current implementation remains broader than upstream `version_129` on the i64 signedness surface.
That divergence is intentional enough to document, but still worth keeping explicit in the living dossier.
