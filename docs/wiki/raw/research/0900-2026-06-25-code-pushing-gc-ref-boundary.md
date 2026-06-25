# 0900 - code-pushing GC/ref boundary

Date: 2026-06-25

## Question

Can Starshine close `[CP-BINREP-005]` by implementing or explicitly resolving the remaining Binaryen GC/ref into-if and `br_on` lit surfaces?

## Answer

Yes, as a narrow mixed closeout: the already implemented direct-pass audit covers the GC/ref movement families Starshine can currently represent safely, while two remaining Binaryen lit surfaces stay accepted boundaries until specific representation prerequisites exist.

Implemented / already covered:

- the atomics/GC `struct.get` family from `code-pushing-atomics.wast`, where a non-null `struct.get` can move past atomic loads but not atomic stores, is documented and tested through HOT fixtures;
- ref-valued pure movement such as `ref.func` is already admitted by the movable-value gate;
- the reduced `br_on_cast` / `br_on_cast_fail` / `br_on_non_null` movement families implemented in the direct-pass audit cover Starshine-representable dropped one-result-block and related block-label cases.

Accepted current boundaries:

- `code-pushing_into_if.wast` `ref-into-if`: Binaryen pushes a `(ref any)` local set into the reachable `if` arm and changes the local to nullable because the moved set no longer dominates every non-nullable use in the wasm validation sense. Starshine's current `code-pushing` mutates HOT roots but does not perform this local-type weakening/refinalization step.
- `code-pushing-gc.wast` broader official GC syntax remains only partially represented locally. The reduced `br_on` positive overlaps Starshine's existing `br_on_cast` movement family, but full shared-GC WAT parity and local refinalization are not claimed.

This resolves `[CP-BINREP-005]` without new behavior. It does not weaken the old `[O4Z-AUDIT-CP]` closeout: the direct-pass closeout already listed GC/ref fixture and future source-drift reopening criteria.

## Source-backed lit surface

Local source files fetched from Binaryen `version_130`:

- `.tmp/binaryen-lit/code-pushing_into_if.wast`
- `.tmp/binaryen-lit/code-pushing-gc.wast`

Relevant shapes:

- `ref-into-if`: Binaryen sinks `(local.set $1 (local.get $0))` into the reachable else arm, then the output declares `$1` as nullable `anyref` so the post-if `ref.as_non_null (local.get $1)` remains valid.
- `br_on`: Binaryen moves `local.set $x (ref.func $br_on)` after a dropped `br_on_cast` inside a result block when all uses are inside the block suffix.
- `br_on_no`: Binaryen keeps the set stationary when a `local.get $x` remains outside the block.

## Starshine status

Current Starshine support is intentionally narrower than Binaryen's full GC/ref lit surface:

- `code_pushing_node_is_movable_value(...)` admits `RefNull`, `RefIsNull`, and `RefFunc` if their effects are pure.
- The direct-pass audit already added reduced `br_on_non_null`, `br_on_cast`, and `br_on_cast_fail` movement/boundary tests for locally representable block-label and dropped-label shapes.
- The atomics/GC slice admits only a non-null `struct.get` from a `local.get` source and blocks intervening memory writes.
- There is no code-pushing-local refinalization pass that can weaken a moved local's type solely because sinking changes dominance. Implementing `ref-into-if` safely requires explicit local type update plus validation-focused tests.

## Decision

Mark `[CP-BINREP-005]` complete as an explicit boundary/coverage closeout for the current replacement follow-up. No behavior change landed in this slice and no red/green TDD test was added because the remaining positive surface requires local-type refinalization or broader GC WAT/HOT representation work.

Reopening criteria:

- add a local type weakening/refinalization helper suitable for code-pushing into-if movement;
- add red-first lit-derived coverage for `ref-into-if`, proving the moved local remains validation-correct after type weakening;
- expand the WAT/HOT fixture surface for official shared-GC syntax and replay `code-pushing-gc.wast` directly;
- discover a generated/direct mismatch attributable to a missing GC/ref movement family not already covered by atomics/GC `struct.get` or the existing `br_on_*` slices.

## Validation

Docs/status slice only. Evidence commands:

```sh
grep -n "ref-into-if\|br_on\|struct\|array\|ref\." .tmp/binaryen-lit/code-pushing-gc.wast .tmp/binaryen-lit/code-pushing_into_if.wast
```

Manual source review checked `src/passes/code_pushing.mbt` and the existing code-pushing wiki/research notes for the current `RefFunc`, `br_on_*`, and atomics/GC `struct.get` coverage.
