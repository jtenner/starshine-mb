---
kind: concept
status: supported
last_reviewed: 2026-09-02
sources:
  - ./index.md
  - ../../../../../src/passes/propagate_globals_globally.mbt
  - ../../../../../src/passes/propagate_globals_globally_wbtest.mbt
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/validate/gen_valid.mbt
  - ../../../../../src/validate/gen_valid_wbtest.mbt
  - ./fuzzing.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./shared-engine-and-startup-boundaries.md
  - ./wat-shapes.md
  - ./fuzzing.md
  - ../simplify-globals/index.md
  - ../simplify-globals-optimizing/index.md
---

# Starshine strategy for `propagate-globals-globally`

## Current status

Starshine implements `propagate-globals-globally` as an active direct module pass. It has a module registry entry and dispatcher case, but no public preset slot.

## Local algorithm

[`propagate_globals_globally.mbt`](../../../../../src/passes/propagate_globals_globally.mbt) performs three bounded phases:

1. Count imported globals so defined-global facts use absolute indices.
2. Scan defined globals in declaration order, substitute earlier literal facts, and record a rewritten initializer only when its resulting encoding is one supported literal. Arithmetic compound shapes are not promoted to later facts.
3. Apply the completed literal fact table to active element and data offsets.

The implementation reuses the structurally recursive startup-expression and section rebuild helpers from `simplify-globals-optimizing`. It passes empty alias/inline/remove-set plans, so the public PGG pass does not inherit that sibling's runtime propagation, set cleanup, table rewrite, dead-global work, or nested optimization.

If no initializer or active offset changes, the original module is returned directly.

## Test map

[`propagate_globals_globally_wbtest.mbt`](../../../../../src/passes/propagate_globals_globally_wbtest.mbt) asserts:

- active module-pass registration
- direct global-chain substitution
- substitution inside an arithmetic compound initializer without folding it
- the v131 literal-only fact boundary after an arithmetic compound initializer
- string literals substituted into a GC `struct.new` initializer
- active data and element offsets
- unchanged ordinary function bodies
- imported-global and passive-data boundaries

[`gen_valid_wbtest.mbt`](../../../../../src/validate/gen_valid_wbtest.mbt) asserts that every focused profile resolves, validates internally, emits its intended trigger, varies across seeds, and that the element leaf has an empty body to avoid unrelated `nop` cleanup.

## GenValid families

The aggregate `propagate-globals-globally-all` profile gives equal weight to:

- `propagate-globals-globally-direct-global`
- `propagate-globals-globally-compound-global`
- `propagate-globals-globally-gc-compound`
- `propagate-globals-globally-data-offset`
- `propagate-globals-globally-elem-offset`

The GC leaf uses immutable i32 fields and `struct.new`, so the pinned external wasm-tools validator can admit it. The string-proposal half of the same compound-expression family remains covered by the focused pass test because the external compare toolchain used here rejects stringref binaries before either optimizer runs.

## Parity boundary

The pinned-v131 ordinary and dedicated lanes have no PGG mismatches. The random-all residuals are kept as separate representation parity gaps: every residual input lacks all PGG target sections and constant-expression variants, and the inspected differences are preexisting local/block reconstruction shapes from `remove-unused-brs-*` profiles.

No wasm-smith lane was run for this implementation because repository policy reserves the separate external-generator lane for explicit requests.
