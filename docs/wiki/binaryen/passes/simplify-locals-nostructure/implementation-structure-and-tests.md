---
kind: concept
status: supported
last_reviewed: 2026-05-08
sources:
  - ../../../raw/research/0552-2026-05-08-simplify-locals-nostructure-ordered-slot-replay.md
  - ../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md
  - ../../../raw/research/0433-2026-05-04-simplify-locals-nostructure-current-main-recheck.md
  - ../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md
  - ../../../raw/research/0263-2026-04-22-simplify-locals-nostructure-primary-sources-and-starshine-followup.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./variant-surface.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./starshine-port-readiness-and-validation.md
  - ../simplify-locals/implementation-structure-and-tests.md
  - ../simplify-locals/index.md
---

# Binaryen `simplify-locals-nostructure` Implementation Structure And Tests

## Why this page exists

The landing, strategy, variant, and WAT-shape pages explain what `simplify-locals-nostructure` does.
This page answers the follow-along question:

- which official Binaryen files and tests define that meaning?
- which Starshine files currently track the missing local port?

This is deliberately narrower than the full [`../simplify-locals/implementation-structure-and-tests.md`](../simplify-locals/implementation-structure-and-tests.md) page.
Use that sibling for the complete five-variant family; use this page when you only need the no-structure variant's owner/test map.

## Freshness note

Use Binaryen `version_129` as the stable source oracle.
The 2026-05-04 current-`main` recheck in [`../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md`](../../../raw/binaryen/2026-05-04-simplify-locals-nostructure-current-main-recheck.md) found no teaching-relevant drift for the checked no-structure surfaces: implementation file, public registration, scheduler placement, pass-runner fixup contract, nested optimization helper, and dedicated proof files.

## Upstream file map

### 1. `src/passes/SimplifyLocals.cpp`

This is the owning implementation file.
For this pass, the most important source fact is the template identity:

- `SimplifyLocals<true, false, true>`

That means:

- tee creation is enabled;
- new block / `if` / loop result-structure synthesis is disabled;
- nesting into existing expression positions is enabled.

The same file owns the mechanics visible in the no-structure output:

- `LocalGetCounter`-driven get counts;
- first-cycle single-use-only sinking;
- later-cycle tee-producing sinking;
- linear-trace sinkable sets keyed by local;
- overwrite cleanup for pending sets;
- directional effect invalidation through `EffectAnalyzer`;
- explicit throwing-value barriers around `try` / `try_table`;
- late equivalent-local canonicalization;
- final `UnneededSetRemover` cleanup;
- `ReFinalize` when a rewrite exposes sharper expression types.

When a future port disagrees with Binaryen, start here before assuming the public pass name tells the whole story.

### 2. `src/passes/pass.cpp`

This file owns two public-contract facts.

First, it registers the user-visible name `simplify-locals-nostructure` and maps it to the no-structure constructor.

Second, it places the pass in the canonical no-DWARF path after `tuple-optimization` and before `vacuum` / `reorder-locals`.
The scheduler comment matters: Binaryen runs this variant before it is willing to create the new `if` / block result shapes that the later full `simplify-locals` pass may introduce.

### 3. `src/passes/passes.h`

This file declares the public pass factory.
It is not algorithmically interesting, but it is part of the proof that `simplify-locals-nostructure` is a real public Binaryen pass rather than only a pass.cpp scheduling alias.

### 4. `src/pass.h`

This file is easy to skip but important for correctness.
Ordinary Binaryen passes default `requiresNonNullableLocalFixups()` to true, and the pass runner can repair nondefaultable-local dominance after a transform.

So the real upstream validation contract is not just:

- `SimplifyLocals.cpp` rewrites expressions.

It is:

- `SimplifyLocals.cpp` rewrites expressions;
- `ReFinalize` repairs expression types when needed;
- pass-runner fixups may repair nondefaultable locals afterward.

A Starshine port that only ports the obvious sinking logic but ignores the post-pass repair story would be incomplete.

### 5. `src/passes/opt-utils.h`

This file owns nested cleanup after inlining.
For this no-structure dossier it matters mainly as scheduler context: the simplify-locals family is reused by nested optimization helpers, so future local docs should not treat the visible top-level no-DWARF slot as the only possible family entry point.

### 6. `src/ir/local-utils.h`

This file contributes two helper families used by the shared engine:

- `LocalGetCounter`, which drives first-cycle single-use decisions and later cleanup choices;
- `UnneededSetRemover`, which performs the final dead-set cleanup.

Those helpers explain why the pass can remove more than adjacent `set` / `get` pairs.

### 7. `src/ir/effects.h`

This file owns the effect-ordering vocabulary the pass relies on.
For no-structure, it is the difference between a correct sink and an invalid reordering across:

- calls;
- mutable globals;
- memory and table effects;
- traps;
- throws;
- shared-memory ordering;
- dangling EH `pop` states.

### 8. `src/ir/equivalent_sets.h`

This file supports the late equivalent-local phase.
No-structure still runs that phase, so this helper remains in scope even though structure-building is disabled.

### 9. `src/ir/linear-execution.h`

This file explains the pass's intentionally cheap execution model.
The pass is linear-trace based with conservative invalidation at nonlinear boundaries, not a full CFG / dominance local optimizer.

### 10. `src/ir/properties.h` and `src/ir/branch-utils.h`

These are supporting surfaces for safety and control-flow questions.
They are not no-structure-specific, but they help explain edge cases where a value is not safe to move or where control-flow uses keep a shape from being rewritten.

## File-to-responsibility table

| File | Responsibility for this variant |
| --- | --- |
| `src/passes/SimplifyLocals.cpp` | Shared locals-family engine; no-structure template instantiation; sinks, tees, invalidation, late cleanup |
| `src/passes/pass.cpp` | Public pass registration and top-level no-DWARF scheduler placement |
| `src/passes/passes.h` | Public pass factory declaration |
| `src/pass.h` | Post-pass nondefaultable-local fixup default |
| `src/passes/opt-utils.h` | Nested cleanup scheduler context |
| `src/ir/local-utils.h` | Get counting and final dead-set cleanup helpers |
| `src/ir/effects.h` | Effect ordering and throwing/trap/memory/table/global barriers |
| `src/ir/equivalent_sets.h` | Late equivalent-local cleanup support |
| `src/ir/linear-execution.h` | Linear-trace traversal model |
| `src/ir/properties.h`, `src/ir/branch-utils.h` | Supporting safety and control-flow helper surfaces |

## Dedicated no-structure test surface

The direct proof files are:

- `test/passes/simplify-locals-nostructure.wast`
- `test/passes/simplify-locals-nostructure.txt`

They are the right first tests to read because they isolate this variant from the nearby public siblings.

The important proof families are:

### Tee-enabled no-structure contrast

The `$contrast` family shows that no-structure mode can still turn the first read of a multi-use local into a `local.tee`.
That directly prevents the common mistake of equating no-structure with no-tee.

### Single-use sinks into existing consumers

The dedicated test proves ordinary sinks into already-present consumers such as `drop(...)`.
These are positive examples because no new control-flow result shape is created.

### Block-valued local carriers sinking into existing consumers

The pass can move a block-valued producer into an existing consumer.
That remains legal because it does not synthesize a new block return to replace control-local traffic.

### Preserved branch-created carriers

The no-structure test keeps examples where full `simplify-locals` could create new `if` / block result values.
Those shapes must remain local-carrier based in this variant.

### Trap, global, and unreachable boundaries

The dedicated proof pair includes negative and edge cases around implicit traps, global effects, unreachable values, and no-unreachable variants.
These examples show that no-structure is still effect-sensitive and type-aware.

## Neighbor tests are context, not the direct proof

Nearby files are still useful:

- `simplify-locals.wast` / `.txt` for full structure-enabled cleanup;
- `simplify-locals-notee-nostructure.wast` / `.txt` for the stricter no-tee sibling;
- `simplify-locals-nonesting.wast` / `.txt` for the flatness-preserving sibling.

But when the claim is specifically about `simplify-locals-nostructure`, cite the dedicated no-structure pair first.
Use neighbor tests only for contrast.

## Starshine follow-along map

Starshine now implements this pass as an active direct hot pass.

| Local surface | Current role |
| --- | --- |
| `src/passes/optimize.mbt` | active hot entries for `simplify-locals-nostructure` and alias `simplify-locals-no-structure`; presets remain conservative |
| `src/passes/optimize_test.mbt` | regressions that the no-structure neighbor is active, the exact slot helper is explicit, and public presets still avoid premature tuple-slot scheduling |
| `src/passes/pass_manager.mbt` | dispatches both spellings to the no-structure runner and shares raw simplify-locals artifact gates |
| `src/passes/simplify_locals.mbt` | owns the no-structure descriptor, alias descriptor, summary, and runner; reuses local sink/dead cleanup while disabling structure-result rewrites |
| `src/passes/simplify_locals_nostructure_test.mbt` | focused positive and no-structure negative tests plus exact `tuple-optimization -> simplify-locals-nostructure -> vacuum -> reorder-locals` replay coverage |
| `scripts/lib/pass-fuzz-compare-task.ts` | compare-pass harness canonical/alias support |
| `scripts/lib/self-optimize-compare-task.ts` | debug-artifact compare canonical/alias support |
| `agent-todo.md` | neighboring tuple/local-cluster follow-up only; the standalone `SLNS` ordered-slot blocker is now retired |

The key local caveat is now preset scope, not direct implementation: the direct pass is oracle-checked and the exact early local slot is replay-proven, but public `optimize` / `shrink` placement still depends on neighboring tuple/local-cluster work.

## Validation checklist for Starshine preset follow-up

Direct pass proof is landed. Future preset work should add proof in this order:

1. **Variant identity tests**
   - tee-enabled multi-use positive;
   - no accidental structure-building;
   - still-nesting-into-existing-consumer positive.
2. **Safety tests**
   - calls, globals, memory, table, traps, throws, and EH `try` / `try_table` barriers;
   - type/refinalization or validator repair cases;
   - nondefaultable-local dominance repair expectations.
3. **Cleanup tests**
   - overwritten pending sets;
   - dead set/tee cleanup;
   - equivalent-local redirection.
4. **Pipeline tests**
   - `tuple-optimization -> simplify-locals-nostructure`;
   - `simplify-locals-nostructure -> vacuum`;
   - `vacuum -> reorder-locals`.
5. **Oracle comparison**
   - pass-targeted Binaryen comparison before claiming the exact no-DWARF slot.

## Sources

- [`../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/binaryen/2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
- [`../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md`](../../../raw/binaryen/2026-04-22-simplify-locals-nostructure-primary-sources.md)
- [`../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md`](../../../raw/research/0368-2026-04-25-simplify-locals-nostructure-current-main-and-test-map.md)
