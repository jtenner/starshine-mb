---
kind: concept
status: supported
last_reviewed: 2026-07-17
sources:
  - ../../../raw/research/1571-2026-07-17-simplify-locals-family-transform-inventory.md
  - ../../../raw/binaryen/2026-07-11-simplify-locals-nonesting-current-main-recheck.md
  - ../../../raw/research/0407-2026-04-26-simplify-locals-nonesting-port-readiness.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_variants_test.mbt
  - ../../../../../src/passes/registry_test.mbt
  - ../../../../../scripts/lib/pass-fuzz-compare-task.ts
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-strategy.md
  - ./fuzzing.md
  - ../simplify-locals/index.md
  - ../simplify-locals/transform-family-inventory.md
  - ../tracker.md
---

# Starshine `simplify-locals-nonesting` implementation and validation

## Implementation state

The initial port is active.

- [x] Canonical `simplify-locals-nonesting` registry entry.
- [x] Tested `simplify-locals-no-nesting` compatibility alias.
- [x] Shared policy engine with tee, structure, and nesting disabled.
- [x] Flat copy-chain retargeting.
- [x] Non-copy movement into direct `local.set` value positions.
- [x] Parent-position rejection for non-copy `drop` and call consumers.
- [x] No structure-result synthesis.
- [x] Harness admission and Binaryen alias normalization.
- [x] Initial regular GenValid smoke.
- [ ] Dedicated aggregate and leaf profiles.
- [ ] Complete official-family fixture translation.
- [ ] Four-lane and 10,000-case closeout.
- [ ] Timing and neighborhood signoff.

## Code surfaces

| Surface | Current implementation |
| --- | --- |
| Registry | Both names are active hot entries in `src/passes/optimize.mbt`; the compatibility alias is no longer removed. |
| Dispatcher | Both names route to `simplify_locals_nonesting_run(...)`. |
| Policy | `SimplifyLocalsPolicy::new(false, false, false)`. |
| Sink legality | Copy values are eligible without added depth; non-copy values require a direct `local.set` parent-position fact. |
| Structure | `simplify_locals_run_with_options(...)` does not execute structure rewrites. |
| Tee creation | Multi-use sink-created tees are disabled. |
| Lowered cleanup | The broader exact locals cleanup is skipped for this sibling so it cannot erase flat source carriers under ordinary consumers. |
| Compare harness | Both names are accepted; the alias invokes Binaryen's canonical `--simplify-locals-nonesting`. |

## Why the parent-position fact matters

Binaryen's `allowNesting = false` rule permits a special flat rewrite when the local read is already the direct child of a `local.set`. It also permits copy retargeting because replacing one `local.get` with another does not deepen the expression.

Starshine represents that distinction explicitly in the HOT inline helpers. This avoids either bad extreme:

- routing the pass to full SimplifyLocals and nesting computations under arbitrary consumers; or
- using a broad fail-closed skip that loses valid flat copy and set-value rewrites.

## Existing red-first tests

The focused variant suite covers:

- positive flat copy retargeting;
- positive computed-value movement into another local set;
- negative computed-value movement under `drop`;
- negative computed-value movement into a call;
- negative `if` result synthesis;
- compatibility alias behavior.

Before registry and implementation changes, all six nonesting tests failed: five with an unknown canonical pass and one because the alias was removed. After implementation, the complete variant file passes `10/10`.

## Validation completed for the initial slice

- `moon info`: passed with existing unrelated warnings.
- `moon fmt`: passed.
- focused variant tests: `10/10`.
- registry tests: `10/10`.
- full `src/passes` suite: `5840/5840`.
- native release build: passed.
- regular GenValid smoke: `1000/1000` normalized matches, zero mismatches or failures.

Artifacts: `.tmp/pass-fuzz-simplify-locals-nonesting-genvalid-1000-initial`.

## Required remaining test families

Add source-backed tests before final closeout for:

- multi-use non-copy temps that would require a tee;
- arithmetic, branch-payload, return, select, and control-condition consumers;
- copy retargeting through each allowed consumer family;
- flat set-value rewrites separated by legal pure statements;
- equivalent-local canonicalization without direct set removal;
- dead-write cleanup after flat retargeting;
- effect, trap, memory, global, table, atomic, and EH barriers;
- loops, blocks, `if`, `try`, and `try_table` with structure synthesis disabled;
- explicit input tees versus lift-fused set/get traffic;
- nested rerun idempotence.

## Oracle and closeout ladder

1. Translate the official dedicated WAST/TXT families into focused local fixtures.
2. Add a deterministic aggregate GenValid profile and family leaf profiles.
3. Run regular, low-feature, trap/effect, and stress lanes with the fresh native binary.
4. Repair mismatches by family; do not classify a difference as safe merely because both outputs validate.
5. Run the final 10,000-case aggregate lane.
6. Check `flatten -> simplify-locals-nonesting` and the documented DFO/Souperify neighborhood without scheduling this pass in a preset.
7. Measure pass-local wall time against Binaryen.

Final closeout requires zero validation, property, generator, and command failures, plus either normalized parity or source-backed measured justification for every remaining output-shape difference.
