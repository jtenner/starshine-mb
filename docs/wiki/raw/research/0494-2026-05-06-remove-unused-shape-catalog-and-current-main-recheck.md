# 0494 - 2026-05-06 - remove-unused shape-catalog and current-main recheck

## Question

What is the right way to keep the local `remove-unused` dossier honest now that the historical-alias pages exist, the old upstream lineage is confirmed, and the folder still lacks a more explicit shape-catalog refresh?

## Findings

- The reviewed current `main` Binaryen registration surfaces still expose modern `remove-unused-module-elements` / `remove-unused-nonfunction-module-elements`, not `remove-unused`.
- The historical `RemoveUnusedFunctions.cpp` source still supports the old function-only contract: root start / export / table-segment functions, follow direct calls, remove unreachable functions, and repair the function map.
- The supersession commit still clearly shows Binaryen replacing the old public spelling with `remove-unused-module-elements`.
- The existing `module-shapes.md` page already covers the pass's important shapes, so the wiki does **not** need a duplicate `wat-shapes.md` page just to satisfy the shape requirement.

## Decision

Keep `module-shapes.md` as the canonical shape catalog for this historical-alias folder, but refresh it so it stays clearly separated from modern RUME and points readers at the new current-main recheck.

## Follow-up

- Update the folder pages to cite the 2026-05-06 recheck.
- Expand the shape catalog with the most important positive and negative historical shapes.
- Keep the local alias story explicit: `remove-unused` is a registry-hygiene issue, not a current upstream spelling.
