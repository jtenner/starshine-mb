# Optimize Instructions final repair / EH-pop blocker

Date: 2026-07-06

## Question

The recursive OI fact-driven port completion criteria allow either explicit final repair / refinalization / EH-pop tracking facts or a documented representation blocker. This note records the current blocker and the source evidence needed to reopen it.

## Binaryen v130 source contract

Local source: `.tmp/binaryen-version130/OptimizeInstructions.cpp`.

- `OptimizeInstructions::doWalkFunction` first runs `LocalScanner`, then the main post-walk, then conditionally runs `ReFinalize().walkFunctionInModule(func, getModule())` when the pass-local `refinalize` flag is set. After that it runs `FinalOptimizer`, then `EHUtils::handleBlockNestedPops(func, *getModule())`.
- `replaceCurrent(Expression* rep)` sets `refinalize = true` whenever the replacement type differs from the current expression type. Several GC/reference visitors also set `refinalize` directly when they mutate a child/result type without replacing the current node.
- The EH-pop repair is explicitly post-pass repair: Binaryen comments that some OI patterns create blocks that can interfere with `catch` and `pop`, nesting the `pop` into a block and making it invalid; `EHUtils::handleBlockNestedPops` is run after final peephole cleanup.

Implication: Binaryen's OI correctness envelope is not just per-rewrite local facts. It includes a function-level `needs refinalize` fact and a post-rewrite EH-pop repair pass after all OI visitor rewrites and `FinalOptimizer`.

## Starshine representation check

Relevant Starshine sources inspected:

- `src/passes/optimize_instructions.mbt`: `optimize_instructions_run` scans integer local facts, visits roots, collapses dead suffixes, and returns `HotPassResult::changed()` / `unchanged()`. It has no pass-local `refinalize` flag, no final optimizer phase, and no EH-pop repair phase.
- `src/ir/hot_region_edit.mbt`: HOT represents `Try` / `TryTable` with explicit body and catch/catch-list regions.
- `src/ir/hot_side_tables.mbt`: `TryTable` catches live in a catch-info side table as catch arms and label ids.
- `src/lib/types.mbt` / `src/lib/show.mbt`: the public instruction enum and text printer expose exception constructs (`throw`, `throw_ref`, `try_table`, catch arms through side tables) but no first-class Binaryen-style `pop` instruction node; `pop` matches in these files are numeric `popcnt`, not EH payload pop nodes.

Implication: Starshine currently has typed HOT nodes/catch regions and validation/writeback repair elsewhere, but OI does not have a local representation matching Binaryen's expression tree `catch` + `pop` repair surface. Adding an `OiFinalRepairFact` now would be a telemetry/no-op fact unless it can point to concrete HOT or raw nodes that need repair.

## Current blocker

Document OI final repair as a representation blocker for now:

1. **Refinalization fact blocker:** Starshine OI does not maintain a Binaryen-style `refinalize` boolean keyed by type-changing replacements. Many Starshine rewrites build replacement nodes with explicit HOT types and rely on the pass manager / verifier path rather than a local full-function re-finalization pass. A source-backed implementation should first define which HOT type changes are legal to defer, which require full recomputation, and how that recomputation updates existing node ids and side tables without invalidating active traversal state.
2. **EH-pop fact blocker:** Starshine's current lib/HOT representation does not expose a first-class `pop` expression corresponding to Binaryen's EH payload pop. The relevant representation is catch regions plus catch-info side tables. Therefore `EHUtils::handleBlockNestedPops` cannot be mirrored until there is either (a) a raw/HOT EH payload-pop node/fact surface, or (b) a Starshine-specific catch-payload movement invariant that can identify the same invalid nesting class.
3. **FinalOptimizer blocker:** Binaryen runs `FinalOptimizer` after optional `ReFinalize`. Starshine OI has no equivalent pass-local final peephole pass. Reopening final repair should decide whether to add a dedicated final fact/cleanup phase inside OI or rely on downstream Starshine passes with explicit documented differences.

## Reopening criteria

Reopen this blocker when one of the following is true:

- A reduced OI or OI-neighborhood mismatch proves Starshine needs Binaryen-like post-OI type recomputation to match behavior or validation.
- HOT/lib gains an explicit EH payload-pop representation, or a catch-payload movement analysis that can prove the same invalid nested-pop class Binaryen repairs.
- A pass-manager repair API becomes available that can be invoked safely after OI rewrites without losing active traversal invariants.
- A source-backed test demonstrates a Binaryen `FinalOptimizer` cleanup that must happen inside OI rather than in an existing downstream Starshine pass.

Until then, keep OI final repair listed as a documented representation blocker rather than adding inert fact structures.
