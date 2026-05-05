# `remove-unused-types` current-main recheck

## Why this follow-up exists

`remove-unused-types` already had a corrected source-backed dossier and a port-readiness bridge, but the living pages were still anchored to 2026-04-26 freshness wording.
This follow-up refreshes the folder with a 2026-05-05 current-main bridge and keeps the no-drift result explicit instead of letting older freshness wording linger.

## Primary source added

New raw source bridge:

- `docs/wiki/raw/binaryen/2026-05-05-remove-unused-types-current-main-recheck.md`

It records the official Binaryen current-main URLs checked for:

- `src/passes/RemoveUnusedTypes.cpp`
- `src/passes/pass.cpp`
- `src/ir/type-updating.h`
- `src/ir/module-utils.h`
- `test/lit/passes/remove-unused-types.wast`

## Durable findings

### 1. No teaching-relevant drift from the corrected dossier

The current-main recheck did not find evidence that the living contract needs an algorithm rewrite.
The same durable model still holds:

- the pass wrapper is tiny;
- `RemoveUnusedTypes.cpp` gates on GC and explicit closed-world mode;
- the default scheduler still places the pass only in the closed-world GC/type cluster;
- `GlobalTypeRewriter` still owns public-group anchoring, private-predecessor ordering, private rebuild, and module-wide remapping.

### 2. The main beginner hazard remains over-widening the pass

The recheck did not support teaching any of these as current Binaryen behavior:

- a pass-local used-type scanner in `RemoveUnusedTypes.cpp`;
- a pass-local private builder;
- a whole-old-rec-group preservation rule;
- a silent open-world rewrite mode;
- or a move into the current open-world no-DWARF route.

### 3. The fixture still teaches the same compact contract

The dedicated `remove-unused-types.wast` surface still proves the same families:

- unused private deletion,
- used/private retention,
- old-rec-group reshaping,
- public-boundary anchoring,
- and closed-world / no-GC boundaries.

The helper headers are still needed to explain why the pass is bigger than the wrapper file.

### 4. Starshine status is unchanged but now fresher

The recheck does not change the local status:

- `remove-unused-types` is still boundary-only in the registry,
- the active request guard still rejects it,
- there is still no owner file,
- and the existing port-readiness bridge remains the right local implementation ladder.

## Living pages refreshed

- `docs/wiki/binaryen/passes/remove-unused-types/index.md`
- `docs/wiki/binaryen/passes/remove-unused-types/binaryen-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/implementation-structure-and-tests.md`
- `docs/wiki/binaryen/passes/remove-unused-types/closed-world-visibility-and-rec-group-rewrite.md`
- `docs/wiki/binaryen/passes/remove-unused-types/wat-shapes.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-strategy.md`
- `docs/wiki/binaryen/passes/remove-unused-types/starshine-port-readiness-and-validation.md`
- `docs/wiki/binaryen/passes/index.md`
- `docs/wiki/binaryen/passes/tracker.md`
- `docs/wiki/index.md`
- `docs/wiki/log.md`
- `CHANGELOG.md`

## Follow-up rule

Future `remove-unused-types` wiki work should start from the corrected source dossier plus this 2026-05-05 bridge, not from the superseded pass-local-scanner or whole-old-rec-group mental models.
