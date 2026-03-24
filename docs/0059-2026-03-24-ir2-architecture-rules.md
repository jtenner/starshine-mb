# 0059 - IR2 Architecture Rules

## Scope

Lock the optimizer rebuild around exactly two owned representations: boundary module form and hot function IR.

## Current Behavior

- Boundary parsing, validation, encode/decode, and debug surfaces already operate on `@lib.Module` and `@lib.Expr`.
- `src/ir/hot.mbt` already owns the current hot function body representation, but the repo had no canonical ADR stating that later work must not recreate deleted recursive ownership layers.
- Pass execution in `src/cmd/cmd.mbt` remains compatibility-only while the real hot pipeline is rebuilt.

## Architecture Rules

- `HotFunc` is the only owned optimizer body representation.
- Boundary decode/encode/validation/debug stay boundary-form only.
- Derived analyses are overlays keyed by `revision`, not owned IR:
  - CFG
  - dominance
  - liveness
  - use-def
  - effects
  - loop info
  - SSA
- Pass contract is `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Semantic mutation must go through public mutation APIs and bump `revision`.
- No compatibility API may be added for deleted recursive optimizer-body ownership.

## Package Split

The `src/ir` package should grow by dedicated modules, not by extending one monolithic file indefinitely.

- `architecture.mbt`: architecture helpers that later pass-manager and cache slices share now.
- `hot_core.mbt`: owned dense storage contract.
- `hot_flags.mbt`: opcode-local raw flag model.
- `hot_types.mbt`: deterministic type interning.
- `hot_labels.mbt`: label ownership and control-region metadata.
- `hot_side_tables.mbt`: typed side-table ownership.
- `hot_builders.mbt`: safe public constructors.
- `hot_mutate.mbt`: authoritative semantic mutation surface.
- `hot_query.mbt`: stable structural queries.

Until those slices land, `hot.mbt` remains the transitional implementation file for the already-existing behavior.

## Correctness Constraints

- No new owned optimizer IR beside `HotFunc`.
- Derived overlays must invalidate through `revision` semantics.
- Pass descriptors must truthfully declare requirements and invalidations.
- Public docs must not imply deleted typed-tree or recursive optimizer ownership layers still exist.

## Validation Plan

- Add `src/ir/architecture_test.mbt` coverage for `hot_revision_current` and pass-descriptor metadata helpers.
- Run README/API sync so the public package surface stays aligned with `pkg.generated.mbti`.
- Refresh package docs and `agent-todo.md` so the next slice starts from the agreed module map.

## Performance Impact

This slice is architectural only. Runtime impact is negligible because it adds read-only revision access and pass-descriptor metadata helpers.

## Open Questions

- Whether revision invalidation stays conservative for all semantic mutation in v1 or becomes more granular once analysis caches land.
- How much of the current `hot.mbt` file should move during `IR2 - 010` versus waiting until `IR2 - 020` and `IR2 - 030`.
