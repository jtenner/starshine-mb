# `type-refining` primary-source capture and Starshine follow-up

_Date:_ 2026-04-24  
_Status:_ absorbed into living wiki pages; keep as numbered research provenance

## Question

The existing `docs/wiki/binaryen/passes/type-refining/` dossier already covered the required overview, Binaryen strategy, implementation/test map, fixup mechanics, and transformed WAT shapes. The remaining wiki-health gap was provenance and local follow-along:

- no immutable raw primary-source manifest captured the official Binaryen URLs reviewed for the dossier
- no dedicated Starshine strategy/status page explained exactly where the local pass name is tracked and why no transform exists yet
- catalogs still described the dossier as working/upstream-only without the newer 2026-04-24 source capture and local status bridge

## Sources reviewed

Primary captured source manifest:

- [`../binaryen/2026-04-24-type-refining-primary-sources.md`](../binaryen/2026-04-24-type-refining-primary-sources.md)

Existing research and living pages re-read:

- [`0150-2026-04-21-type-refining-binaryen-research.md`](0150-2026-04-21-type-refining-binaryen-research.md)
- [`../../binaryen/passes/type-refining/index.md`](../../binaryen/passes/type-refining/index.md)
- [`../../binaryen/passes/type-refining/binaryen-strategy.md`](../../binaryen/passes/type-refining/binaryen-strategy.md)
- [`../../binaryen/passes/type-refining/implementation-structure-and-tests.md`](../../binaryen/passes/type-refining/implementation-structure-and-tests.md)
- [`../../binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md`](../../binaryen/passes/type-refining/normal-vs-gufa-and-fixups.md)
- [`../../binaryen/passes/type-refining/wat-shapes.md`](../../binaryen/passes/type-refining/wat-shapes.md)

Local code surfaces reviewed:

- [`../../../../src/passes/optimize.mbt`](../../../../src/passes/optimize.mbt)
- [`../../../../src/passes/registry_test.mbt`](../../../../src/passes/registry_test.mbt)
- [`../../../../src/lib/types.mbt`](../../../../src/lib/types.mbt)
- [`../../../../src/wast/parser.mbt`](../../../../src/wast/parser.mbt)
- [`../../../../src/wast/lower_to_lib.mbt`](../../../../src/wast/lower_to_lib.mbt)
- [`../../../../src/validate/env.mbt`](../../../../src/validate/env.mbt)
- [`../../../../src/validate/typecheck.mbt`](../../../../src/validate/typecheck.mbt)
- [`../../../../src/binary/encode.mbt`](../../../../src/binary/encode.mbt)
- [`../../../../src/binary/decode.mbt`](../../../../src/binary/decode.mbt)
- [`../../../../agent-todo.md`](../../../../agent-todo.md)

Primary online sources captured:

- Binaryen `version_129` release page: <https://github.com/WebAssembly/binaryen/releases/tag/version_129>
- Binaryen source and lit files listed in [`../binaryen/2026-04-24-type-refining-primary-sources.md`](../binaryen/2026-04-24-type-refining-primary-sources.md)

## Findings

### Upstream contract stayed the same on the reviewed surfaces

The 2026-04-24 source check keeps the previous `version_129` teaching contract intact:

- `type-refining` is a closed-world, GC-only private struct-field refiner
- the normal pass infers field contents from direct struct traffic and limited copy recognition
- `type-refining-gufa` uses `ContentOracle` for stronger whole-program field-content inference
- both variants share the same public/private legality and read/write repair pipeline
- read repair and write repair are mandatory parts of correctness, not optional cleanup

The current-`main` spot check was intentionally narrow. It did not find a teaching-relevant drift in `TypeRefining.cpp`, `pass.cpp`, helper headers, or the dedicated `type-refining*` lit files, but this note should not be treated as a whole-Binaryen equivalence proof.

### Local Starshine status is boundary-only, not a hidden partial port

`src/passes/optimize.mbt` currently includes `"type-refining"` in `pass_registry_boundary_only_names()`. Boundary-only names become registry entries, but `run_hot_pipeline_expand_passes(...)` rejects active requests with a boundary-only error instead of running a no-op transform.

The local registry does **not** separately list the upstream companion spelling `type-refining-gufa` today. That sibling is documented because the Binaryen source makes it part of the real type-refining topic, but it is not a Starshine pass flag yet.

No local owner file such as `src/passes/type_refining.mbt` exists, and `agent-todo.md` has no dedicated `type-refining` slice today.

### Future porting is module/type-graph work

A faithful port would need to cross several local surfaces:

- registry and preset behavior in `src/passes/optimize.mbt`
- heap-type, rec-group, field-type, mutability, exactness, and struct-op representation in `src/lib/types.mbt`
- WAT fixture parsing/lowering in `src/wast/parser.mbt` and `src/wast/lower_to_lib.mbt`
- validation of struct ops, subtyping, exact refs, and ref casts in `src/validate/*`
- binary opcode emission/decoding for struct ops in `src/binary/*`

This is not a HOT peephole. It needs closed-world field-content analysis, public/private heap-type policy, module-wide type rewriting, instruction repair, and final validation/refinalization.

## Changes made in living pages

- Added [`../binaryen/2026-04-24-type-refining-primary-sources.md`](../binaryen/2026-04-24-type-refining-primary-sources.md).
- Added [`../../binaryen/passes/type-refining/starshine-strategy.md`](../../binaryen/passes/type-refining/starshine-strategy.md).
- Refreshed the `type-refining` landing, Binaryen strategy, implementation/test-map, fixup, and WAT-shape pages to cite the raw source manifest and Starshine status page.
- Updated `docs/wiki/binaryen/passes/index.md`, `docs/wiki/binaryen/passes/tracker.md`, `docs/wiki/index.md`, and `docs/wiki/log.md` so the catalogs no longer imply the local follow-along gap remains open.
- Updated `CHANGELOG.md` with the docs change.

## Open questions

- What should Starshine's explicit closed-world option surface be for GC/type-cluster passes?
- Should `type-refining`, `remove-unused-types`, `minimize-rec-groups`, `type-merging`, `unsubtyping`, `signature-pruning`, and `signature-refining` share one module/type-graph rewrite framework?
- Should a future local port expose `type-refining-gufa` as a separate boundary-only name before implementing it, or keep it documented only as an upstream sibling until GUFA infrastructure exists locally?
- Should Starshine first fill the WAT `struct.set` parser/lowerer gap for text fixtures, or start the port with binary/library-level fixtures that already exercise `@lib.StructSet`?

## Bottom line

The durable wiki state is now complete for this pass: readers can start at the overview, inspect transformed shapes, follow the Binaryen source strategy through a raw primary-source manifest, and then switch to the Starshine status page to see exactly why current local behavior is boundary-only and which code surfaces a real port would have to modify.
