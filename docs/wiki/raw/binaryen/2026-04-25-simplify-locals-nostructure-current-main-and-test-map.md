# Binaryen `simplify-locals-nostructure` Current-Main And Test-Map Bridge

- **Captured:** 2026-04-25
- **Pass:** `simplify-locals-nostructure`
- **Scope:** focused current-main recheck, implementation/test-map bridge, and Starshine code-location refresh for the existing living dossier.
- **Status:** immutable raw-source manifest. Keep living conclusions in `docs/wiki/binaryen/passes/simplify-locals-nostructure/`.

## Primary upstream sources

### Binaryen `version_129`

- Release tag: <https://github.com/WebAssembly/binaryen/tree/version_129>
- Pass implementation / shared locals-family engine: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/SimplifyLocals.cpp>
- Pass registration and scheduler: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/pass.cpp>
- Pass factory declarations: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/passes.h>
- Post-pass validation/fixup contract: <https://github.com/WebAssembly/binaryen/blob/version_129/src/pass.h>
- Nested optimization helpers: <https://github.com/WebAssembly/binaryen/blob/version_129/src/passes/opt-utils.h>
- Supporting helper surfaces:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/local-utils.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/effects.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/equivalent_sets.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/linear-execution.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/properties.h>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/src/ir/branch-utils.h>
- Dedicated no-structure proof files:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nostructure.txt>
- Neighbor variant proof files used only for contrast:
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-notee-nostructure.txt>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.wast>
  - <https://github.com/WebAssembly/binaryen/blob/version_129/test/passes/simplify-locals-nonesting.txt>

### Current-main spot check

- Pass implementation on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/SimplifyLocals.cpp>
- Pass registration and scheduler on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/pass.cpp>
- Pass factory declarations on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/passes.h>
- Post-pass validation/fixup contract on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/pass.h>
- Nested optimization helpers on `main`: <https://github.com/WebAssembly/binaryen/blob/main/src/passes/opt-utils.h>
- Dedicated no-structure proof files on `main`:
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.wast>
  - <https://github.com/WebAssembly/binaryen/blob/main/test/passes/simplify-locals-nostructure.txt>

The 2026-04-25 current-main recheck found no teaching-relevant drift from the reviewed `version_129` contract. The public registration still exposes `simplify-locals-nostructure`; the scheduler still places it after `tuple-optimization` and before `vacuum` / `reorder-locals`; the implementation still uses the shared `SimplifyLocals<allowTee, allowStructure, allowNesting>` family, with structure-building code gated by `allowStructure`; and the dedicated proof pair still shows the contrast shape where no-structure mode may create a `local.tee` and sink into existing consumers while preserving branch-created local carriers.

## Source-backed implementation map

`src/passes/SimplifyLocals.cpp` owns the transform. For the no-structure variant, the important implementation responsibilities are:

- define the `SimplifyLocals<allowTee, allowStructure, allowNesting>` walker family;
- maintain a linear-trace `sinkables` map keyed by local index;
- count `local.get` uses with `LocalGetCounter`;
- run a special first cycle that avoids tee-producing multi-use sinks;
- run later cycles where teeing is allowed for this variant;
- invalidate sinkables with `EffectAnalyzer::orderedAfter(...)` plus explicit throwing-value barriers for `try` / `try_table`;
- gate block / `if` / loop result-building helpers behind `allowStructure`, which is false for `simplify-locals-nostructure`;
- still run late equivalent-local cleanup and final dead-set cleanup;
- run `ReFinalize` when type refinement makes it necessary.

`src/passes/pass.cpp` owns two public-contract surfaces:

- registration of the public pass name `simplify-locals-nostructure` with the no-structure constructor;
- top-level scheduler placement in the no-DWARF optimization path after `tuple-optimization` and before `vacuum` / `reorder-locals`, with the inline comment warning not to create `if` / block result values yet.

`src/pass.h` contributes a less visible but important postcondition: ordinary passes default `requiresNonNullableLocalFixups()` to true, so the pass runner may repair nondefaultable-local dominance after code motion. The no-structure dossier should not imply that `SimplifyLocals.cpp` alone is the entire validation contract.

`src/passes/opt-utils.h` matters mainly for nested optimizer reruns: it reuses the default function-optimization sequence after inlining. That makes the locals family part of both visible top-level scheduling and nested cleanup sequences.

## Test-surface map

The dedicated `simplify-locals-nostructure.wast` / `.txt` pair is the strongest proof surface for this specific variant.
It directly demonstrates or guards:

- tee-enabled no-structure behavior (`$contrast` turns the first read into `local.tee`);
- single-use sinks into existing `drop(...)` consumers;
- block-valued local carriers sinking into existing consumers;
- preserved `if` / block structures where full `simplify-locals` could have created result values;
- implicit-trap and global-effect barriers;
- unreachable and no-unreachable cases;
- the practical split from neighboring `simplify-locals-notee-nostructure` and full `simplify-locals` output.

Neighbor tests (`simplify-locals*`) are still useful for family context, but they should not be cited as the direct proof for no-structure-only behavior unless the page is explicitly comparing variants.

## Starshine local source map checked

The local status remains unimplemented but concrete:

- `src/passes/optimize.mbt:143-151` keeps `simplify-locals-no-structure` in the removed-name registry.
- `src/passes/optimize.mbt:377-381` keeps `tuple_optimization_exact_slot_prereqs_ready()` false until `simplify-locals-no-structure` becomes an active hot pass.
- `src/passes/optimize.mbt:385-407` keeps public optimize/shrink presets honest by not scheduling `tuple-optimization` through the exact Binaryen slot while the no-structure neighbor is missing.
- `src/passes/optimize_test.mbt:202-209` locks the slot-blocker regression under the current test name `tuple-optimization exact preset slot remains unavailable while no-structure neighbor is missing`.
- `src/passes/pass_manager.mbt:8701-8704` dispatches active neighboring hot passes (`code-pushing`, `tuple-optimization`, `simplify-locals`, `merge-blocks`) but has no dispatcher case for `simplify-locals-no-structure`.
- `src/passes/simplify_locals.mbt:2-16` exposes the current full-`simplify-locals` descriptor and summary; it is the nearest landed local implementation surface, not the missing variant.
- `src/passes/simplify_locals.mbt:70-227` owns the current HOT sinkable/effect-conflict structures that a future no-structure port would likely narrow and reuse.
- `src/passes/simplify_locals.mbt:995-1012`, `src/passes/simplify_locals.mbt:2416-2508`, and `src/passes/simplify_locals.mbt:4132-4162` show the current full-pass conflict invalidation, structured-control boundary handling, and per-function main-cycle setup.
- `agent-todo.md:284-293` still names slice `SLNS` and its deliverables.

## Uncertainties and caveats

- This capture did not perform a full semantic diff of `version_129` and `main`; it was a focused source and proof-surface recheck. Treat `version_129` as the stable oracle and `main` as no-teaching-drift for the checked surfaces only.
- Starshine still has no separate `simplify-locals-nostructure` owner file, pass descriptor, dispatcher arm, or focused regression suite. Current local references are registry, tuple-slot guard, backlog, and neighboring full-`simplify-locals` infrastructure.
- The Starshine full `simplify-locals` pass has artifact-specific raw-skip and writeback guards that are not evidence of a correct no-structure variant. Future docs should keep those as prerequisite context, not as proof that `SLNS` is implemented.
