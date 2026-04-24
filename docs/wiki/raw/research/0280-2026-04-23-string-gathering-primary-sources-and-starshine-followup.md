---
kind: research
status: supported
last_reviewed: 2026-04-23
sources:
  - ../binaryen/2026-04-23-string-gathering-primary-sources.md
  - ../../binaryen/passes/string-gathering/index.md
  - ../../binaryen/passes/string-gathering/binaryen-strategy.md
  - ../../binaryen/passes/string-gathering/implementation-structure-and-tests.md
  - ../../binaryen/passes/string-gathering/reuse-naming-and-ordering.md
  - ../../binaryen/passes/string-gathering/wat-shapes.md
  - ../../binaryen/passes/string-gathering/starshine-strategy.md
  - ../../binaryen/passes/reorder-globals/index.md
  - ../../strings/string-const-surface.md
  - ../../../../src/passes/optimize.mbt
  - ../../../../src/binary/encode.mbt
  - ../../../../src/binary/decode.mbt
  - ../../../../src/binary/tests.mbt
  - ../../../../src/wast/lower_to_lib.mbt
  - ../../../../agent-todo.md
  - ../../../../docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md
---

# `string-gathering` primary-source and Starshine follow-up

## Why this follow-up exists

The existing `string-gathering` dossier already had the required living overview, Binaryen strategy page, implementation/test map, and transformed-shape coverage.
However, it still had three durable gaps:

- it lacked an immutable raw primary-source manifest
- it lacked the required dedicated Starshine strategy page
- the touched catalogs still left the local story scattered between a backlog slice, a scheduler doc, and one honest-but-isolated registry-bookkeeping caveat

This follow-up closes the provenance gap, adds the missing local strategy page, and refreshes the touched catalog wording so the dossier is usable from beginner orientation through future Starshine planning.

## Primary sources rechecked in this run

Captured immutably in:

- `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md`

The most important reviewed surfaces were:

- the official Binaryen GitHub release page for `version_129`
- the GitHub releases index
- `StringLowering.cpp` on `version_129` and `main`
- `pass.cpp`
- `passes.h`
- `string-utils.{h,cpp}`
- `module-utils.h`
- `wasm-traversal.h`
- the dedicated lit file `string-gathering.wast`
- the neighboring late-global interaction file `propagate-globals-globally.wast`

## Local Starshine code and planning surfaces rechecked

- `src/passes/optimize.mbt`
- `src/binary/encode.mbt`
- `src/binary/decode.mbt`
- `src/binary/tests.mbt`
- `src/wast/lower_to_lib.mbt`
- `docs/wiki/strings/string-const-surface.md`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
- `agent-todo.md`
- the neighboring living dossier for `reorder-globals`

## Durable findings

### 1. The Binaryen side mostly needed provenance and freshness anchors, not another algorithm rewrite

The existing upstream pages were still broadly correct after the 2026-04-20 and 2026-04-21 research wave.
The missing piece was provenance:

- on 2026-04-23 the official Binaryen `version_129` release page showed publish date **2026-04-01**
- the new raw manifest now records the exact release, source, helper, and test URLs rechecked in this run
- a narrow current-`main` spot check did not surface a new teaching-relevant drift beyond the existing strategy, implementation/test, focused mechanics, and WAT-shape pages

So the right maintenance action was to add an immutable source manifest and thread that provenance into the living pages, not to replace the already-correct Binaryen explanation.

### 2. The real local gap was the missing Starshine page, even though there is still no in-tree pass implementation

`string-gathering` is still unimplemented in Starshine, but the repo already had a real local strategy surface for it in the broader sense:

- `agent-todo.md` already tracks concrete future slices `SG]001` and `SG]002`
- `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md` already records the exact no-DWARF late-tail slot between `remove-unused-module-elements` and `reorder-globals`
- `src/binary/encode.mbt` and `src/binary/decode.mbt` already implement deterministic `string.const` / `stringrefs` plumbing that a future pass would rely on
- `src/binary/tests.mbt` and `src/wast/lower_to_lib.mbt` already lock the current literal roundtrip and lowering surface in tests
- `docs/wiki/strings/string-const-surface.md` already documented that `string-gathering` was the next durable follow-up after literal-plumbing work

Before this run, that story was scattered across code, tests, and docs.
The new Starshine page turns it into one explicit teachable path.

### 3. The honest Starshine story is backlog-plus-plumbing, with a real registry bookkeeping gap

Re-reading `src/passes/optimize.mbt` sharpened the most important local correction:

- unlike many other unimplemented late passes, `string-gathering` is currently in **neither** `pass_registry_boundary_only_names()` nor `pass_registry_removed_names()`
- so the repo knows the pass from docs and backlog, but does **not** currently preserve the upstream spelling in the pass registry
- that means the local status is not “tracked and rejected” but “documented and planned, while registry wiring is still missing"

That is the most important durable local finding from this run.
It keeps future readers from overreading the mature dossier as evidence that the public pass spelling is already preserved in the implementation surface.

### 4. The strongest current local implementation bridge is the existing `string.const` plumbing

The most useful exact code map for future Starshine work is not a hidden pass owner file, because there is none.
Instead it is the current literal infrastructure:

- `src/binary/encode.mbt:72` `with_binary_encode_stringrefs_context(...)`
- `src/binary/encode.mbt:87` `encode_string_const_index(...)`
- `src/binary/encode.mbt:1580` `encode_module_stringrefs(...)`
- `src/binary/decode.mbt:148` `with_binary_decode_stringrefs_context(...)`
- `src/binary/decode.mbt:160` `decode_string_const_literal(...)`
- `src/binary/tests.mbt:1817` `module roundtrip preserves string.const literals and stringrefs section`
- `src/wast/lower_to_lib.mbt:7238` `wast_to_binary_module lowers string.const literals`

Those surfaces are not a `string-gathering` pass yet.
But they are the real current code locations that a future port would stand on, because the pass's correctness depends on stable literal identity and deterministic section behavior.

### 5. The future port boundary is now clearer: add registry + late module pass, not more literal-plumbing work

The new cross-read between the Binaryen dossier, the local string-literal plumbing, and the backlog clarifies the next local move:

- the repo does **not** need another basic `string.const` parser/encoder investigation first
- it needs registry bookkeeping for the pass spelling
- then it needs a late module pass that scans the module, canonicalizes defining globals, preserves literal identity, and stays deliberately separate from `reorder-globals`

That means the most honest future design ladder is:

1. preserve the upstream pass spelling in `src/passes/optimize.mbt`
2. add a dedicated late module pass owner file
3. keep it narrow and string-literal focused
4. validate its interaction with the already-documented downstream `reorder-globals` slot

## Files changed because of this follow-up

### New raw-source manifest

- `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md`

### New research note

- `docs/wiki/raw/research/0280-2026-04-23-string-gathering-primary-sources-and-starshine-followup.md`

### New living page

- `docs/wiki/binaryen/passes/string-gathering/starshine-strategy.md`

### Refreshed living pages and catalogs

- `docs/wiki/binaryen/passes/string-gathering/index.md`
- `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Maintenance rule going forward

If future `string-gathering` work needs a clean provenance-plus-local-status path, start with:

1. `docs/wiki/raw/binaryen/2026-04-23-string-gathering-primary-sources.md`
2. `docs/wiki/binaryen/passes/string-gathering/index.md`
3. `docs/wiki/binaryen/passes/string-gathering/binaryen-strategy.md`
4. `docs/wiki/binaryen/passes/string-gathering/implementation-structure-and-tests.md`
5. `docs/wiki/binaryen/passes/string-gathering/reuse-naming-and-ordering.md`
6. `docs/wiki/binaryen/passes/string-gathering/wat-shapes.md`
7. `docs/wiki/binaryen/passes/string-gathering/starshine-strategy.md`
8. `docs/wiki/strings/string-const-surface.md`
9. `docs/wiki/raw/research/0066-2026-03-24-binaryen-no-dwarf-default-optimize-path.md`
10. `src/passes/optimize.mbt`
11. `src/binary/encode.mbt`
12. `src/binary/decode.mbt`
13. `src/binary/tests.mbt`
14. `src/wast/lower_to_lib.mbt`
15. `agent-todo.md`

That path now gives a clean bridge from official Binaryen release/source/test surfaces to the exact current Starshine status: no pass implementation yet, no registry entry yet, a real backlog slice and scheduler slot already documented, real local literal-plumbing code already in place, and a much clearer future landing shape as a late module pass that composes with `reorder-globals` instead of replacing it.
