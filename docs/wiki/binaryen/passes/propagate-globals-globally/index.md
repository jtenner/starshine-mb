---
kind: entity
status: supported
starshine_status: active
last_reviewed: 2026-09-02
sources:
  - ../../../../../src/passes/propagate_globals_globally.mbt
  - ../../../../../src/passes/propagate_globals_globally_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
  - ./fuzzing.md
  - ../tracker.md
related:
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
  - ../tracker.md
---

# `propagate-globals-globally`

## Role

`propagate-globals-globally` is an active Starshine module pass that implements Binaryen's narrow startup-only contract for supported literal initializer facts: it substitutes earlier known literal globals into later defined-global initializers and active data/element offsets, then stops before ordinary function bodies.

It is deliberately not scheduled in the public optimization presets. Users request it directly with `--propagate-globals-globally` or `--pass propagate-globals-globally`.

## Behavior

The pass scans defined globals in declaration order. Before each initializer is considered as a new fact, references to earlier known literal globals are replaced. A rewritten initializer becomes a fact for later startup expressions only when its resulting encoding is one supported literal. Arithmetic compound expressions keep Binaryen's substituted shape but are not evaluated into a later fact.

The same fact table then rewrites:

- active element-segment offsets
- active data-segment offsets

It does not rewrite:

- function bodies
- table initializers or element item expressions
- passive or declarative segment modes
- imports, global types, mutability, writes, or dead globals
- unsupported or non-evaluable initializer shapes

The Binaryen engine records declaration-time literals without filtering on mutability, but Binaryen v131 validation rejects a mutable `global.get` in a global initializer. The valid GenValid surface therefore uses immutable producers. This internal detail must not be confused with runtime value tracking after startup or after a `global.set`.

## Implementation map

- [`propagate_globals_globally.mbt`](../../../../../src/passes/propagate_globals_globally.mbt) owns declaration-order fact collection and the module rewrite.
- [`optimize.mbt`](../../../../../src/passes/optimize.mbt) registers the active module pass.
- [`pass_manager.mbt`](../../../../../src/passes/pass_manager.mbt) dispatches the public pass name.
- [`propagate_globals_globally_wbtest.mbt`](../../../../../src/passes/propagate_globals_globally_wbtest.mbt) covers direct and compound initializers, the literal-only fact boundary after an arithmetic compound initializer, GC/string constant expressions, active data/element offsets, function-body preservation, imports, and passive data.
- [`gen_valid.mbt`](../../../../../src/validate/gen_valid.mbt) owns five focused GenValid leaves plus the aggregate profile.

## Validation status

Pinned Binaryen v131 evidence is recorded in [`fuzzing.md`](./fuzzing.md). The ordinary `100000/100000` lane and dedicated `10000/10000` aggregate are normalized and canonical matches with zero generator, command, validation, property, or mismatch failures. The dedicated manifest selects every transform-family leaf roughly two thousand times.

The random-all lane has 100 retained pass-independent representation parity gaps, all from `remove-unused-brs-*` profiles with no globals, elements, data, or constant-expression variants. They are not classified as PGG wins and do not expand this pass's contract.

## Maintenance rule

Keep the public stop point explicit. Shared helpers may be reused by `simplify-globals*`, but PGG must remain startup-only and must not acquire runtime code propagation or cleanup as an incidental side effect.

## Page map

- [`binaryen-strategy.md`](./binaryen-strategy.md) - upstream algorithm and source contract.
- [`implementation-structure-and-tests.md`](./implementation-structure-and-tests.md) - upstream owner/test map.
- [`shared-engine-and-startup-boundaries.md`](./shared-engine-and-startup-boundaries.md) - the family split from `simplify-globals*`.
- [`wat-shapes.md`](./wat-shapes.md) - positive and negative input shapes.
- [`starshine-strategy.md`](./starshine-strategy.md) - current local code and validation map.
- [`fuzzing.md`](./fuzzing.md) - dedicated profiles, commands, results, and residual classification.

## Sources

- research note 0320
- research note 0459
- research note 0196 - historical; superseded for helper names, scan order, and the `optimize` explanation.
- research note 0162 - historical; superseded for the standalone-file claim.
- [`propagate_globals_globally.mbt`](../../../../../src/passes/propagate_globals_globally.mbt)
- [`propagate_globals_globally_wbtest.mbt`](../../../../../src/passes/propagate_globals_globally_wbtest.mbt)
- [`fuzzing.md`](./fuzzing.md)
