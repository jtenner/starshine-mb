# 2026-05-05 reorder-types current-main recheck

Reviewed the official Binaryen `main` sources for `reorder-types` against the existing `version_129` dossier.

## What was checked

- `src/passes/ReorderTypes.cpp`
- `src/passes/pass.cpp`
- `test/lit/passes/reorder-types.wast`
- the shared `type-updating.*` / `module-utils.*` helper family already cited by the living dossier

## What stayed the same

- the pass still requires GC and `--closed-world`
- only private heap types are reorderable
- public types remain frozen
- the algorithm still uses 21 successor-weight factors from `0.0` to `1.0`
- the chosen order still minimizes encoded type-index byte cost
- the rebuilt private output still lands in one fresh private recursion group
- the hidden `reorder-types-for-testing` registration remains present alongside the public pass

## Source anchors

- `ReorderTypes.cpp`: `#L608-L625` and `#L629-L770` for the reordering engine, factor search, and byte-cost model; `#L786-L803` for the GC / `--closed-world` gate
- `pass.cpp`: `#L3060-L3064` for public registration; `#L3371-L3376` for the hidden testing sibling
- `test/lit/passes/reorder-types.wast`: unchanged official lit surface

## Conclusion

No teaching-relevant drift was found on the reviewed current-main surfaces.
The 2026-04-24 primary-source manifest remains a valid contract anchor, and the living wiki can now point at this 2026-05-05 freshness check as the newest source-confirmation layer.
