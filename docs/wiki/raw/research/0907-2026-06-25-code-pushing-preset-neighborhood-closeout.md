# 0907 - code-pushing preset neighborhood closeout

Date: 2026-06-25

## Question

After the user-directed direct `code-pushing` blockers were closed, is the public preset/neighborhood gap for scheduling direct `code-pushing` still active?

## Answer

No. The current Starshine public `optimize` and `shrink` presets already schedule direct `code-pushing` in the Binaryen-shaped neighborhood:

```text
pick-load-signs -> precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals -> remove-unused-brs
```

The direct prerequisites that previously made this scheduling unsafe are now implemented or preserved as narrow boundaries:

- default trap timing, `--traps-never-happen`, and distinct `--ignore-implicit-traps` semantics remain separate;
- exact `binaryen-intrinsics` / `call.without.effects` sinking is implemented without type/arity heuristics;
- `ref-into-if` now performs the required local type weakening/refinalization;
- broader shared-GC fixture work remains separate and is only active if a source-backed useful CP surface requires it.

This closeout is status/documentation-only because the scheduling and ordered-neighborhood tests were already present in the codebase by this slice.

## Evidence in source/tests

- `src/passes/optimize.mbt` includes `precompute`, `code-pushing`, `tuple-optimization`, and `simplify-locals-nostructure` in both `optimize_preset_passes(...)` and `shrink_preset_passes(...)`.
- `src/passes/registry_test.mbt` locks preset expansion to active pass names and includes the direct `code-pushing` slot.
- `src/passes/optimize_test.mbt` locks the exact `precompute -> code-pushing -> tuple-optimization -> simplify-locals-nostructure -> vacuum` ordering for both public presets.
- `src/passes/simplify_locals_nostructure_test.mbt` replays the exact ordered helper lane and checks trace ordering through `code-pushing`, `tuple-optimization`, `simplify-locals-nostructure`, `vacuum`, and `reorder-locals`.

## Validation

Focused proof commands:

```sh
moon test --target native src/passes/optimize_test.mbt -f 'tuple-optimization exact preset prereqs place code-pushing before the tuple slot'
moon test --target native src/passes/optimize_test.mbt -f 'simplify-locals-nostructure exact slot helper exposes the ordered replay lane'
moon test --target native src/passes/simplify_locals_nostructure_test.mbt -f 'simplify-locals-nostructure exact slot replays code-pushing and tuple cleanup before vacuum and reorder-locals'
moon test --target native src/passes/registry_test.mbt -f 'preset expansion stays on implemented active pass names'
```

All four focused commands passed `1/1`.

## Remaining work

No remaining useful user-directed `code-pushing` gap is known after this closeout. Do not reinterpret the historical `0892`, `0901`, or `0903` stop conditions as invalid; they are preserved as historical audits and superseded only by the later user-directed blocker cleanup goal that is now resolved.

Reopen only for a new Binaryen-positive/source-backed CP family, generated/direct semantic mismatch, validation failure attributable to CP, explicit shared-GC fixture requirement for a useful CP surface, or preset-neighborhood drift from the documented order.
