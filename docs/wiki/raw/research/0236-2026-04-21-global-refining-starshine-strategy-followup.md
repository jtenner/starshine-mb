# Binaryen / Starshine `global-refining` follow-up: local strategy map, code locations, and dossier health

_Date:_ 2026-04-21  
_Status:_ absorbed into the living `docs/wiki/binaryen/passes/global-refining/` dossier in this same change  
_Related living pages:_
- `docs/wiki/binaryen/passes/global-refining/index.md`
- `docs/wiki/binaryen/passes/global-refining/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/global-refining/exports-public-types-and-retagging.md`
- `docs/wiki/binaryen/passes/global-refining/wat-shapes.md`
- `docs/wiki/binaryen/passes/global-refining/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/parity.md`

## Why this follow-up existed

The `global-refining` folder already covered the upstream Binaryen side well, but it still had one practical gap for Starshine contributors:

- the folder taught the upstream `version_129` pass and its boundary matrix,
- and it had a parity page describing the current local subset,
- but it did **not** yet have a dedicated living page that mapped the current Starshine strategy back to exact MoonBit owner files and pass wiring.

That gap mattered because the surrounding implemented-pass dossiers already treat the stable folder shape as:

- landing page,
- Binaryen strategy page,
- shape page,
- Starshine strategy page,
- and parity / helper notes.

`global-refining` was still one of the implemented-pass exceptions.

## Process followed

I re-read:

- `AGENTS.md`
- `docs/README.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- the existing `docs/wiki/binaryen/passes/global-refining/` folder
- `src/passes/global_refining.mbt`
- `src/passes/global_refining_test.mbt`
- the local registry / preset / dispatch surfaces in `src/passes/optimize.mbt` and `src/passes/pass_manager.mbt`

I also checked `git status` first.
The worktree was clean aside from branch metadata, so there was no unrelated-local-change blockage.

## Primary online sources reviewed

Primary official Binaryen sources reviewed for this follow-up:

- Binaryen `version_129` `src/passes/GlobalRefining.cpp`
- Binaryen `version_129` `src/passes/pass.cpp`
- Binaryen `version_129` `test/lit/passes/global-refining.wast`

These were used to keep the new Starshine page honest about what is local subset versus what belongs to the full upstream contract.

Useful source locations from the official repo:

- `GlobalRefining::run(...)` for the GC gate, `global.set` collection, `LUBFinder` aggregation, export/public-type legality rules, and `GetUpdater`
- the `PublicTypeValidator`-guarded export branch and the final `runOnModuleCode(...)` retagging call in `GlobalRefining.cpp`
- `pass.cpp` registration and default global-prepass placement of `global-refining`
- the dedicated `global-refining.wast` cases that prove nullable exact refinements, exported-boundary behavior, and dependent `global.get` repair

I also did a narrow official-source freshness check against the current GitHub `main` copies only to keep the existing no-drift claim honest.

## Main local code locations captured in the new living page

The new Starshine strategy page now points readers directly to the in-tree owner sites:

- `src/passes/global_refining.mbt:2`
  - summary string and current local scope statement
- `src/passes/global_refining.mbt:57`
  - `gr_expr_result_type(...)`: initializer classification for `ref.null`, immutable `global.get`, and `ref.func`
- `src/passes/global_refining.mbt:232`
  - `gr_join_reftypes(...)`: local LUB-like join over heap type, nullability, and exactness
- `src/passes/global_refining.mbt:280`
  - `gr_scan_candidate_sets(...)`: cheap instruction pre-scan before HOT lifting
- `src/passes/global_refining.mbt:317`
  - `gr_collect_func_global_sets(...)`: HOT-side `global.set` value collection
- `src/passes/global_refining.mbt:367`
  - `global_refining_run_module_pass(...)`: exported-global skip, initializer seeding, per-function collection, and declaration rewrite
- `src/passes/global_refining_test.mbt:17`
  - private narrowing positive
- `src/passes/global_refining_test.mbt:46`
  - exported-global bailout
- `src/passes/global_refining_test.mbt:73`
  - sibling-write join case
- `src/passes/pass_manager.mbt:8643`
  - active module-pass dispatch site
- `src/passes/optimize.mbt:235`
  - pass registry entry
- `src/passes/optimize.mbt:245`
  - default preset placement between `once-reduction` and `global-struct-inference`

## Main findings

### 1. The local pass is best taught as a private-global declaration-tightening subset

The strongest local headline is:

- **Starshine currently refines only non-exported defined reference globals.**

That is narrower than upstream Binaryen in two important ways:

- all exported globals are skipped locally, even the open-world immutable exported-public cases that official Binaryen can refine
- there is no local `PublicTypeValidator`-style boundary split or `closed_world` parameter on this pass

So the local implementation is not “the Binaryen pass but written in MoonBit.”
It is a smaller private-global subset.

### 2. The local algorithm is still recognizably Binaryen-shaped

Even though the boundary matrix is smaller, the local implementation mirrors the main upstream idea in a compact way:

- seed candidate types from global initializers,
- collect assigned value types from `global.set`,
- join them conservatively,
- and rewrite only the global declaration when the new type is a subtype of the old one.

The MoonBit version does this with:

- `gr_expr_result_type(...)`
- `gr_join_heaptypes(...)` / `gr_join_reftypes(...)`
- `gr_scan_candidate_sets(...)`
- `gr_collect_func_global_sets(...)`
- `global_refining_run_module_pass(...)`

### 3. The local implementation is HOT-assisted instead of AST-retagging-based

Official Binaryen uses:

- `FindAll<GlobalSet>` on AST functions,
- direct declaration mutation,
- then `GetUpdater` plus `ReFinalize` and `runOnModuleCode(...)` to retag cached `global.get` types.

Starshine instead:

- lifts only functions that actually mention candidate globals,
- collects write-side value types from HOT nodes,
- rewrites only the boundary global declarations,
- and relies on the local representation not caching Binaryen-style expression result types.

That is a real architectural divergence worth keeping explicit for future parity work.

### 4. The dossier had a small schema-health inconsistency before this change

`docs/wiki/binaryen/passes/index.md` explicitly teaches that active implemented folders are stable homes for:

- `binaryen-strategy.md`
- `wat-shapes.md`
- `starshine-hot-ir-strategy.md`

But `global-refining` still lacked the Starshine page while neighboring implemented folders already had one.

So this change was both:

- pass-coverage work,
- and a touched-area wiki-health fix.

## Durable conclusions filed back into the living wiki

- `global-refining` now has the full implemented-pass dossier shape used elsewhere in the pass wiki.
- The correct local teaching headline is: **Starshine currently implements a private-global declaration-tightening subset, not the full Binaryen exported-boundary contract.**
- The touched area is healthier because the pass folder, pass-folder map, tracker entry, and top-level wiki index now advertise the same dossier shape.
- The upstream Binaryen source remains the oracle for the Binaryen side; the new Starshine page exists so contributors can verify the local subset directly in MoonBit.

## Files updated in this change

- `docs/wiki/raw/research/0236-2026-04-21-global-refining-starshine-strategy-followup.md`
- `docs/wiki/binaryen/passes/global-refining/index.md`
- `docs/wiki/binaryen/passes/global-refining/starshine-hot-ir-strategy.md`
- `docs/wiki/binaryen/passes/global-refining/parity.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Source links

- Binaryen `version_129` `GlobalRefining.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/GlobalRefining.cpp>
- Binaryen `version_129` `pass.cpp`: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Binaryen `version_129` `global-refining.wast`: <https://github.com/WebAssembly/binaryen/blob/version_129/test/lit/passes/global-refining.wast>
- Binaryen current `main` `GlobalRefining.cpp`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/GlobalRefining.cpp>
- Binaryen current `main` `global-refining.wast`: <https://github.com/WebAssembly/binaryen/blob/main/test/lit/passes/global-refining.wast>
