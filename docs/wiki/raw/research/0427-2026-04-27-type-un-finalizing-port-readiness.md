# `type-un-finalizing` port-readiness bridge

_Date:_ 2026-04-27  
_Status:_ absorbed into living wiki pages

## Question

The `type-un-finalizing` folder already had source-backed Binaryen strategy, shape, implementation/test-map, and Starshine status pages. The remaining gap was the now-standard port-readiness bridge: which local Starshine surfaces would a future implementation need, what should the first safe slices be, and how should validation prove it did not accidentally become `type-finalizing`, `remove-unused-types`, `type-merging`, or `unsubtyping`?

## Sources reviewed

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/binaryen/passes/type-un-finalizing/`
- `docs/wiki/binaryen/passes/type-finalizing/starshine-port-readiness-and-validation.md`
- `docs/wiki/raw/research/`
- `docs/wiki/raw/binaryen/2026-04-24-type-un-finalizing-primary-sources.md`
- `docs/wiki/raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md`
- Official Binaryen current-main sources recorded in that raw manifest.
- Local Starshine source surfaces recorded in that raw manifest.

## Findings

- The upstream contract did not drift in a teaching-relevant way from the 2026-04-24 dossier.
- The pass remains a GC-gated module/type-section rewrite over private heap types.
- The sibling split is the key beginner-to-advanced fact:
  - `type-finalizing` finalizes only private leaves.
  - `type-unfinalizing` reopens private heap types and intentionally does not require a leaf proof.
- Starshine currently has only the local boundary-only spelling `type-un-finalizing`; Binaryen's public spelling is `type-unfinalizing`.
- Starshine already has final/open subtype representation and parser/printer/validator/binary surfaces, but it lacks a documented private-type classifier and a `GlobalTypeRewriter`-equivalent helper.
- Therefore the next useful implementation artifact is not a HOT visitor. It is module/type-graph infrastructure plus conservative private-type visibility tests.

## Wiki changes made

- Added `docs/wiki/raw/binaryen/2026-04-27-type-un-finalizing-port-readiness-primary-sources.md`.
- Added `docs/wiki/binaryen/passes/type-un-finalizing/starshine-port-readiness-and-validation.md`.
- Refreshed the overview, Binaryen strategy, implementation/test-map, focused boundary guide, WAT-shape catalog, and Starshine strategy so the port-readiness bridge is discoverable from every maintained page.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, and `docs/wiki/log.md`.

## Durable conclusion

Future work should keep `type-un-finalizing` boundary-only until Starshine can prove all of these at once:

1. direct requests run a real module pass instead of the boundary-only error;
2. no-GC modules no-op;
3. public types stay unchanged;
4. private final and private open types both become/open remain open;
5. private non-leaf types are allowed to reopen;
6. function heap types participate;
7. globals, locals, function signatures, block types, and GC instruction type references remain valid after the rewrite;
8. binary encode/decode preserves the final/open bit;
9. docs and tracker record the local-vs-upstream spelling policy explicitly.

## Follow-up questions

- Should Starshine accept the upstream spelling `type-unfinalizing` as an alias when this pass becomes active, or preserve only the current local `type-un-finalizing` spelling?
- Should the future shared owner file be `type_finality.mbt`, shared with `type-finalizing`, or should each sibling start separate until a common type remapper exists?
- What is the correct local definition of a private heap type, especially around exports, imports, descriptors, JS-facing annotations, and future custom-descriptor surfaces?
