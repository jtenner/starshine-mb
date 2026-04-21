# Binaryen / Starshine `global-struct-inference` follow-up: local strategy map, code locations, and dossier health

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/global-struct-inference/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/global-struct-inference/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/closed-world-analysis-and-unnesting.md`
- `docs/wiki/binaryen/passes/global-struct-inference/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-struct-inference/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/parity.md`

## Why this follow-up existed

The `global-struct-inference` folder was already a good Binaryen-side dossier, but it still had one practical gap for Starshine contributors:

- the folder taught the upstream `version_129` pass well,
- and it had a parity page explaining that the local MoonBit implementation is smaller,
- but it did **not** yet have a dedicated living page that mapped the current Starshine strategy back to concrete code locations in this repository.

That gap mattered because the folder-level schema used elsewhere in the wiki already treated active implemented pass dossiers as stable homes for:

- an overview / landing page,
- a Binaryen strategy page,
- a WAT-shape page,
- a Starshine strategy page,
- and parity or helper notes.

`global-struct-inference` was one of the remaining implemented-pass exceptions.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/global-struct-inference/` folder
- `src/passes/global_struct_inference.mbt`
- `src/passes/global_struct_inference_test.mbt`
- the local registry / preset / dispatch locations in `src/passes/optimize.mbt`, `src/passes/pass_manager.mbt`, and `src/passes/registry_test.mbt`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen `version_129` `src/passes/GlobalStructInference.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/gsi.wast`

These were used to keep the Starshine page honest about what is local subset versus what belongs to the full upstream contract.

Useful source locations from the official repo:

- `GlobalStructInference::run(...)`
- `analyzeClosedWorld(...)`
- `optimize(...)`
- the `visitStructGet`, `visitRefGetDesc`, and optional `visitRefCast` surface in the nested optimizer
- `pass.cpp` registration text for `gsi`

I also checked the current `main` copies of the owning source and dedicated lit file only narrowly, to keep the existing “no meaningful semantic drift from `version_129` on these checked surfaces” note honest.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/global_struct_inference.mbt:2`
  - summary string
- `src/passes/global_struct_inference.mbt:110`
  - `gsi_candidate_field_values(...)`
- `src/passes/global_struct_inference.mbt:151`
  - `gsi_candidate_global_values(...)`
- `src/passes/global_struct_inference.mbt:249`
  - `gsi_folded_global_field_expr(...)`
- `src/passes/global_struct_inference.mbt:309`
  - `gsi_rewrite_instrs(...)`
- `src/passes/global_struct_inference.mbt:418`
  - `gsi_instrs_may_rewrite(...)`
- `src/passes/global_struct_inference.mbt:496`
  - `global_struct_inference_run_module_pass(...)`
- `src/passes/global_struct_inference_test.mbt:2`
  - positive closed-world direct-global fold test
- `src/passes/global_struct_inference_test.mbt:43`
  - non-global-producer bailout test
- `src/passes/pass_manager.mbt:8645`
  - dispatch site
- `src/passes/optimize.mbt:237`
  - registry entry
- `src/passes/optimize.mbt:245`
  - preset placement after `global-refining`

## Main findings

### 1. The local pass is best taught as a closed-world direct-global fold

The old folder already hinted at this in `parity.md`, but the new dedicated page makes it the primary local teaching rule:

- Starshine returns unchanged when `closed_world` is false,
- records candidates only from immutable top-level `struct.new*` globals,
- and rewrites only immediate `global.get` + `struct.get*` instruction pairs.

That is narrower than the full Binaryen pass in three different ways at once:

- no open-world direct-global layer,
- no `typeGlobals` closed-world map,
- no local/param/subtype-origin reasoning.

### 2. The local materialization vocabulary is small and syntax-driven

The local helpers can materialize only a compact set of replacement expressions:

- literals,
- `v128.const`,
- `ref.null`,
- `ref.func`,
- immutable `global.get`,
- `string.const`,
- default values for defaultable field types,
- and packed-field results rebuilt from `i32.const` payloads.

That is enough for the current direct-global subset, but it is much smaller than Binaryen's `PossibleConstantValues` plus fresh-global un-nesting story.

### 3. The dossier had a real schema-health inconsistency before this change

`docs/wiki/binaryen/passes/index.md` explicitly says active implemented pass folders are stable homes for:

- `wat-shapes.md`
- `binaryen-strategy.md`
- `starshine-hot-ir-strategy.md`

But `global-struct-inference` was still missing the Starshine page while other active implemented passes such as:

- `memory-packing`
- `dead-code-elimination`
- `pick-load-signs`
- `precompute`

already had one.

So this was not only pass-coverage expansion.
It also fixed a small but real touched-area wiki-health inconsistency.

### 4. The parity message is now easier for beginners to verify directly in code

Before this follow-up, the folder's parity page said the local implementation was a smaller subset.
That was true, but readers still had to reconstruct the local subset by hand from the MoonBit file.

The new Starshine strategy page now makes the code-backed differences explicit:

- hard closed-world gate,
- no subtype propagation,
- no `select(ref.eq(...))` synthesis,
- no fresh-global un-nesting,
- no `ref.get_desc` or `gsi-desc-cast` surface,
- no Binaryen-style refinalization machinery.

## Durable conclusions filed back into the living wiki

- `global-struct-inference` now has the full active-implemented-pass dossier shape used elsewhere in the pass wiki.
- The correct local teaching headline is: **Starshine currently implements a closed-world direct-global fold, not the full Binaryen origin-analysis pass.**
- The touched area is healthier because the pass folder, pass-folder map, tracker entry, and top-level wiki index now all describe the same dossier shape.
- The upstream source remains the right oracle for the Binaryen side of the folder; the new page exists to keep the local subset equally concrete.

## Files updated in this change

- `docs/wiki/raw/research/0234-2026-04-21-global-struct-inference-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/global-struct-inference/index.md`
- `docs/wiki/binaryen/passes/global-struct-inference/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/global-struct-inference/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Source links

- Binaryen `version_129` `GlobalStructInference.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalStructInference.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `gsi.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/gsi.wast>
- Binaryen current `main` `GlobalStructInference.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalStructInference.cpp>
- Binaryen current `main` `gsi.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/gsi.wast>
