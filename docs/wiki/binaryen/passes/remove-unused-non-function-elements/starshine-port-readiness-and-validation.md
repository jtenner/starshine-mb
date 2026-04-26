---
kind: concept
status: supported
last_reviewed: 2026-04-26
sources:
  - ../../../raw/binaryen/2026-04-26-remove-unused-non-function-elements-port-readiness-primary-sources.md
  - ../../../raw/research/0408-2026-04-26-remove-unused-non-function-elements-port-readiness.md
  - ../../../raw/binaryen/2026-04-24-remove-unused-non-function-elements-primary-sources.md
  - ../../../raw/research/0328-2026-04-24-remove-unused-non-function-elements-primary-sources-and-starshine-followup.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/remove_unused_module_elements.mbt
  - ../../../../../src/passes/remove_unused_module_elements_test.mbt
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-rooting-and-defined-vs-imported-functions.md
  - ./module-shapes.md
  - ./starshine-strategy.md
  - ../remove-unused-module-elements/index.md
  - ../remove-unused-module-elements/starshine-hot-ir-strategy.md
---

# Starshine port readiness and validation for `remove-unused-non-function-elements`

## Current local truth

Starshine does not implement this sibling today.

The current in-tree facts are:

- local boundary-only registry spelling: `remove-unused-non-function-elements`
- upstream Binaryen public spelling: `remove-unused-nonfunction-module-elements`
- active module dispatcher case: none
- dedicated owner file: none
- reusable sibling substrate: active full [`remove-unused-module-elements`](../remove-unused-module-elements/index.md)

The exact current code anchors are in [`./starshine-strategy.md`](./starshine-strategy.md). The short version is:

- [`src/passes/optimize.mbt`](../../../../../src/passes/optimize.mbt) lists the local name in `pass_registry_boundary_only_names()` around lines 127-139 and rejects direct lower-level requests for boundary-only entries later in pass expansion.
- [`src/passes/pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches active module passes around lines 8660-8680 and currently has a case for `remove-unused-module-elements`, but not this sibling.
- [`src/passes/remove_unused_module_elements.mbt`](../../../../../src/passes/remove_unused_module_elements.mbt) already owns the local full-RUME liveness queue, section rewrite, type cleanup, and public `rume_run_module_pass(...)` entry point.

## Binaryen contract to preserve

The Binaryen strategy page explains the upstream pass in detail: [`./binaryen-strategy.md`](./binaryen-strategy.md).

For porting, the contract is small enough to state as one policy:

> Seed every defined function as live, then run the ordinary `remove-unused-module-elements` engine.

That policy has four practical consequences:

1. Dead **defined** helper functions survive.
2. Dead **imported** functions can still be removed.
3. Dead non-function module structure can still be removed.
4. Shared full-RUME cleanup still applies: start/export roots, imported-parent segment retention, function-type cleanup, index remapping, and data-count repair are still in scope.

Do not implement this pass as a new non-function sweeper. It should be a small policy mode on the existing RUME liveness/rewrite path.

## First safe Starshine slice: policy analysis without broad mutation

Start with tests before code changes.

A safe first slice is a no-rewrite or minimally exposed policy test layer around the liveness collector:

- full RUME mode does **not** mark an unreachable defined helper live;
- sibling mode does mark that helper live;
- sibling mode still does **not** special-root an unused imported function;
- ordinary export and start roots are unchanged in both modes.

Implementation shape:

- add an internal policy, for example `RumeRootPolicy::{Ordinary, RootAllDefinedFunctions}` or a clear boolean named for upstream behavior;
- thread it into `rume_collect_liveness_with_import_parent_policy(...)` or a nearby wrapper;
- seed all defined function absolute indices only when sibling mode is selected;
- keep `rume_collect_liveness(...)` and `rume_run_module_pass(...)` on ordinary full-RUME behavior.

Avoid a public registry transition in this slice unless the tests also prove request rejection changes intentionally.

## First mutating slice: reuse RUME rewrite unchanged

Once the policy-level tests are green, expose a sibling module-pass entry point that reuses the existing rewrite pipeline:

1. collect liveness with `RootAllDefinedFunctions`;
2. call the same `rume_apply_module_rewrite(...)` used by full RUME;
3. add the new dispatcher case only after the module-pass output tests are present;
4. move the registry category from boundary-only to active module pass in the same atomic implementation change.

This shape keeps the sibling from drifting into a copied RUME fork.

## Required tests for the mutating slice

Add focused tests beside full RUME tests in [`src/passes/remove_unused_module_elements_test.mbt`](../../../../../src/passes/remove_unused_module_elements_test.mbt) or a sibling test file.

Minimum positive and negative families:

1. **Dead defined helper survives**
   - Input: an unexported, uncalled defined helper.
   - Full RUME expectation: helper can be removed.
   - Sibling expectation: helper remains.
2. **Dead defined cycle survives**
   - Input: two unexported functions that call each other.
   - Sibling expectation: both remain, proving the policy is not just direct export rooting.
3. **Dead imported function can vanish**
   - Input: an unused imported function plus an unused defined helper.
   - Sibling expectation: imported function can be pruned while the defined helper remains.
4. **Dead non-function structure still vanishes**
   - Input: unused memory/table/global/tag/data/elem declarations with no observable startup behavior.
   - Sibling expectation: removable non-function sections are still removed.
5. **Function types still compact**
   - Input: types used only by removed imports or dead declarations.
   - Sibling expectation: the shared type cleanup still runs.
6. **No-op start metadata stays separate**
   - Input: a `nop` start function.
   - Sibling expectation: the start declaration can be dropped while the defined start function body remains.
7. **Full RUME non-regression**
   - Re-run an existing full-RUME dead-helper case to prove ordinary `remove-unused-module-elements` did not inherit sibling rooting.

The shape catalog in [`./module-shapes.md`](./module-shapes.md) has beginner-friendly examples for these families.

## Validation ladder

Use a staged validation ladder rather than jumping straight to broad fuzzing.

1. **Registry honesty**
   - Before implementation, keep `remove-unused-non-function-elements` boundary-only and rejected.
   - When implemented, add tests proving it is an active module pass and no longer hidden as boundary-only.
2. **Focused unit tests**
   - Cover the seven families above.
   - Include one paired full-RUME-vs-sibling differential test.
3. **Binaryen oracle fixtures**
   - Compare local output against upstream `wasm-opt --remove-unused-nonfunction-module-elements` for the dedicated all-features fixture captured in the primary-source manifest.
   - Also run selected full-RUME sibling fixtures when they exercise inherited startup/export/segment/type behavior.
4. **Pass-fuzz compare**
   - Add an explicit pass-fuzz alias only after the CLI spelling decision is made.
   - The oracle must use Binaryen's spelling: `--remove-unused-nonfunction-module-elements`.
5. **Preset safety**
   - Do not add the pass to presets merely because it exists.
   - The current docs record no no-DWARF or saved `-O4z` role for this sibling; preset scheduling would need separate evidence.

## CLI and naming decision

The current local spelling drops `module` and hyphenates `non-function`; upstream does neither.

A future implementation should decide explicitly between:

- keeping only the existing local spelling as the Starshine public name;
- adding an upstream-compatible alias;
- or keeping the alias only inside pass-fuzz comparison tooling.

Do not silently treat `remove-unused` as a shortcut for this pass. The local `remove-unused` dossier is a separate historical-alias problem.

## Main risks

- **Rooting imported functions by accident.** The upstream sibling roots defined functions; imported functions remain ordinary reachability candidates.
- **Changing full RUME behavior.** The ordinary `rume_run_module_pass(...)` path must keep its current stricter behavior.
- **Copying the rewrite engine.** A copied implementation would likely miss remaps for imports, exports, start, data count, annotations, element/data segments, and function types.
- **Skipping inherited startup semantics.** Imported-parent active segments and startup-trapping initializers are inherited full-RUME obligations.

## Exit criteria for a future port

A future Starshine implementation is ready for signoff when:

- the sibling is an active module pass under an intentional spelling policy;
- full RUME and sibling differential tests both pass;
- imported-function and defined-function behavior are tested separately;
- non-function cleanup and type compaction remain active;
- Binaryen oracle comparison uses `--remove-unused-nonfunction-module-elements`;
- docs for the pass, tracker, and pass index are updated from boundary-only status to implemented status.
