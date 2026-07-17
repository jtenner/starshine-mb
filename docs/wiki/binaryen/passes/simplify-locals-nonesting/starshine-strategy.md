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
  - ../../../../../agent-todo.md
related:
  - ./index.md
  - ./binaryen-strategy.md
  - ./implementation-structure-and-tests.md
  - ./flatness-variant-boundaries.md
  - ./wat-shapes.md
  - ./starshine-port-readiness-and-validation.md
  - ./fuzzing.md
  - ../simplify-locals/index.md
  - ../simplify-locals/transform-family-inventory.md
  - ../simplify-locals-notee/index.md
  - ../simplify-locals-notee-nostructure/index.md
  - ../simplify-locals-nostructure/index.md
  - ../tracker.md
---

# Starshine `simplify-locals-nonesting` strategy

## Current status

Starshine now implements Binaryen's flat `SimplifyLocals<false, false, false>` sibling as an active hot pass.

- canonical name: `simplify-locals-nonesting`
- compatibility alias: `simplify-locals-no-nesting`
- owner: [`src/passes/simplify_locals.mbt`](../../../../../src/passes/simplify_locals.mbt)
- shared policy: structure off, sink-created tees off, ordinary nesting off
- preset role: none
- compare harness: both names admitted; the alias maps to Binaryen's canonical flag

## Binaryen-specific legality rule

The nonesting variant is not merely the no-tee/no-structure sibling.
Its sink decision also uses the consumer position:

- a pending `local.get` copy may retarget through arbitrary consumers because it does not add expression depth;
- a non-copy pending value may move only when the matched local read is the direct value child of another `local.set`;
- otherwise the local shell is preserved.

Starshine carries that rule as an explicit `allow_nesting` policy axis plus a parent-position fact through the HOT inline helpers. The implementation does not rescan the function to guess the consumer after the fact.

## Internal representation caveat

HOT lifting can represent flat `local.set` / `local.get` source traffic as a tee-shaped child internally. The policy-aware inline helpers therefore gate the rewrite at the actual HOT parent position rather than treating every internally fused tee as permission to nest a computed value under `drop`, a call, arithmetic, branch payloads, or control conditions.

The lowered cleanup path also avoids the broader exact SimplifyLocals cleanup for this sibling because that cleanup intentionally performs adjacent set/get elimination that would violate the nonesting source contract.

## Active code surfaces

| Surface | Implementation |
| --- | --- |
| Descriptors and summaries | `simplify_locals_nonesting_descriptor()` and `simplify_locals_nonesting_summary()` |
| Compatibility alias | `simplify_locals_nonesting_alias_descriptor()` |
| Policy runner | `simplify_locals_nonesting_run(...)` with `SimplifyLocalsPolicy::new(false, false, false)` |
| Parent-position legality | policy-aware `simplify_locals_try_inline_*local_get*` helpers plus the main sinkable local-get gate |
| Structure gate | `simplify_locals_run_with_options(...)` skips structure rewrites |
| Dispatcher/writeback | `src/passes/pass_manager.mbt` recognizes both names and keeps nonesting out of the broader exact lowered cleanup |
| Registry | `src/passes/optimize.mbt` exposes both names as active hot passes |
| Oracle mapping | `scripts/lib/pass-fuzz-compare-task.ts` maps the compatibility alias to `--simplify-locals-nonesting` |

## Red-first evidence

The six initial nonesting tests failed before implementation because the canonical name was unknown and the compatibility alias was removed. They now prove:

1. flat local-copy retargeting;
2. computed-value movement into another `local.set` value position;
3. preservation of computed values consumed by `drop`;
4. preservation of computed values consumed by a call;
5. no `if`-result synthesis;
6. alias parity.

The focused variant file passes `10/10`, the registry file passes `10/10`, and the full `src/passes` suite passes `5840/5840` for this slice.

## Initial oracle evidence

A fresh native release binary compared `1000/1000` regular GenValid cases against Binaryen `--simplify-locals-nonesting` with:

- `1000` normalized matches;
- zero raw mismatches;
- zero validation failures;
- zero property failures;
- zero generator or command failures.

This is an implementation smoke, not final signoff.

## Remaining closeout

`[SL-FAMILY]001` still requires:

- a dedicated aggregate profile with leaf-family coverage;
- official fixture-family translation beyond the first policy tests;
- regular, low-feature, trap/effect, and stress compare lanes;
- the separate external-generator lane only when explicitly requested;
- nested rerun and flatten-neighborhood checks;
- pass-local timing and the required 10,000-case final parity lane;
- documentation of any residual output-shape difference as a measured Starshine win or an open parity gap.
