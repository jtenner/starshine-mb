# 0344 - `global-struct-inference` primary sources and code-map follow-up

## Scope

- Continue the pass-wiki maintenance loop after inspecting `AGENTS.md`, `docs/README.md`, the wiki catalog, pass tracker, log, and research archive.
- Choose an existing pass dossier that is useful but still missing source-ingest hygiene.
- Update `global-struct-inference` because it is active in Starshine, already has overview / strategy / shapes / parity pages, but still lacked an immutable raw primary-source manifest and an implementation/test-map page comparable to newer pass dossiers.

## Overlap check

Existing durable material before this note:

- `docs/wiki/binaryen/passes/global-struct-inference/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/closed-world-analysis-and-unnesting.md`
- `docs/wiki/binaryen/passes/global-struct-inference/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-struct-inference/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/parity.md`
- `docs/wiki/raw/research/0068-2026-03-25-global-struct-inference.md`
- `docs/wiki/raw/research/0140-2026-04-20-global-struct-inference-binaryen-research.md`
- `docs/wiki/raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md`
- sibling source capture `docs/wiki/raw/binaryen/2026-04-24-global-struct-inference-desc-cast-primary-sources.md`

Decision: update the existing folder and add the missing implementation/test-map page rather than creating a duplicate pass dossier.

## Primary source ingest

Added:

- `docs/wiki/raw/binaryen/2026-04-25-global-struct-inference-primary-sources.md`

The source capture records:

- official Binaryen `version_129` release provenance
- `src/passes/GlobalStructInference.cpp` owner-file structure
- current-`main` focused no-teaching-drift spot check
- `pass.cpp` and `passes.h` registration/factory surfaces
- helper headers for possible constants, subtypes, packed-field repair, module parallel analysis, name generation, and nested global reorder repair
- `test/lit/passes/gsi.wast` as the direct broad proof surface
- local Starshine registry, dispatcher, implementation, and test status

## Durable source conclusions

- Binaryen plain `gsi` is not closed-world-only. Closed world builds `typeGlobals`; the optimizer still runs afterward in all modes and includes an open-world direct immutable-global fast path.
- The pass is a small trusted-origin optimizer, not general object dataflow.
- Closed-world poisoning comes from function-local `struct.new` and nested non-top-level global `struct.new` sites.
- Candidate grouping is value-count-based, not raw-global-count-based: one unique value folds directly; two unique values need one singleton group for a single `ref.eq`-guarded `select`; larger or symmetric groups bail out.
- `PossibleConstantValues` makes immutable `global.get`s materializable but does not make arbitrary equal-looking expressions equivalent.
- Packed-field and atomic-get behavior are part of the source contract, as are refinalization and fresh-global un-nesting followed by nested `reorder-globals-always`.
- Plain `gsi` includes `ref.get_desc`; `gsi-desc-cast` remains a sibling public pass sharing the owner file.

## Starshine code-map conclusions

Current Starshine remains a narrower active module pass:

- active registry/preset entry: `src/passes/optimize.mbt`
- active module dispatcher: `src/passes/pass_manager.mbt`
- implementation: `src/passes/global_struct_inference.mbt`
- focused tests: `src/passes/global_struct_inference_test.mbt`

The local pass currently:

- exits unless `closed_world` is true
- scans defined immutable globals only
- accepts top-level `struct.new*` initializer families
- materializes simple constants, ref values, immutable `global.get`, `string.const`, and default values
- rewrites only immediate `global.get` + `struct.get*` instruction pairs
- preserves nullable-global traps with `ref.as_non_null` + `drop`
- rebuilds changed functions in the code section

It still does not implement Binaryen's:

- open-world direct-global optimization layer
- closed-world `typeGlobals` map
- subtype poisoning and upward candidate propagation
- local/param-origin rewrites
- one-vs-two-value `select(ref.eq(...))` synthesis
- non-constant operand un-nesting into fresh globals
- `ref.get_desc`
- atomic-get-specific proof cases
- sibling `gsi-desc-cast`

## Wiki updates made

- Added `docs/wiki/binaryen/passes/global-struct-inference/implementation-structure-and-tests.md`.
- Refreshed the overview, Binaryen strategy, WAT-shape catalog, closed-world/un-nesting guide, Starshine strategy, and parity page to cite the raw manifest and current source bridge.
- Updated `docs/wiki/index.md`, `docs/wiki/binaryen/passes/index.md`, and `docs/wiki/binaryen/passes/tracker.md` so the source ingest and new implementation/test-map page are discoverable.
- Updated `docs/wiki/log.md` and `CHANGELOG.md` for the durable wiki addition.
- Marked this note as superseding older source-provenance gaps in `0140` and Starshine-code-map gaps in `0234` while preserving both older notes as historical research.

## Health-check notes

- The touched folder had correct core claims but older `last_reviewed` dates and no raw source manifest reference on most pages.
- The pass index and tracker already claimed the folder was deep; this was directionally right, but the claim was weaker than neighboring dossiers because `global-struct-inference` lacked an implementation/test-map page and raw source capture.
- The health fix was therefore integrated with the main wiki-development change instead of split into a second unrelated cleanup commit.

## Follow-up questions

- If implementation work resumes, decide whether the next local increment should be the open-world direct-global fast path or the closed-world `typeGlobals` / select path. They are separate from a code-structure perspective.
- Re-run a current Binaryen `main` source diff before porting; the 2026-04-25 check was a focused web/source spot check, not a full post-`version_129` audit.
