---
kind: concept
status: supported
last_reviewed: 2026-09-02
sources:
  - ../simplify-locals/index.md
  - ../../../raw/binaryen/2026-07-11-simplify-locals-nonesting-current-main-recheck.md
  - ./index.md
  - ../../../../../src/passes/optimize.mbt
  - ../../../../../src/passes/pass_manager.mbt
  - ../../../../../src/passes/simplify_locals.mbt
  - ../../../../../src/passes/simplify_locals_variants_test.mbt
  - ../../../../../src/passes_perf_long/simplify_locals_multivalue_perf_test.mbt
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

> **Binaryen-v131 renewal (2026-07-27):** The released owner contract is unchanged from v130. Current executable evidence is recorded in [`index.md`](./index.md) and the family [fuzzing closeout](../simplify-locals/fuzzing.md); older v129/v130 labels below are retained only as historical provenance, not as the current oracle.


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
- [x] Dedicated aggregate and leaf profiles.
- [x] Complete official-family fixture translation for the agreed v131 scope.
- [x] Four-lane behavior closeout and renewed 10,000-case regular/dedicated evidence.
- [x] Timing and neighborhood signoff.

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

## 2026-09-02 completion record

The active implementation checklist is complete. The regular explicit-v131 renewal is `10000/10000` normalized. The dedicated aggregate compares all `10000/10000` cases as `5026` normalized plus `4974` canonically smaller Starshine outputs, with zero validation, property, generator, command, or canonical-size-loss failures. The residual partition is fully profile-backed: flat-parent removes Binaryen-retained `nop`s, and family-coverage removes the same debris plus untargeted void-loop wrappers while preserving ordered local writes.

Production timing closes the fixed command gate at `2,467.228ms` versus Binaryen v131 `1,254.875ms` (`1.966x`); pass-local is `459.349ms` versus `754.346ms` (`0.609x`). The reusable 2,048-function benchmark records `10.80ms +/- 113.06us` and locks the zero-mutation breadth envelope. Output remains the accepted 4,961,908-byte SHA-256 `b5dc28fea9588a3bc219f181b83a6a644e1fba807159f472e9042f9ef7c8ee0d`. The remaining canonical size gap is explicitly tracked outside this wall-time closeout.
