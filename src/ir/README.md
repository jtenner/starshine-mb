# `src/ir`

IR2 owns exactly one optimizer body representation: `HotFunc`.

## Ownership Rules

- Boundary decode, encode, validation, printing, and debug-module views stay on raw `@lib.Module` / `@lib.Expr` forms.
- `HotFunc` is the only owned optimizer body representation.
- CFG, dominance, liveness, use-def, effects, loop info, and SSA are derived overlays keyed by `revision`; they do not own bodies.
- Semantic mutation must go through public hot-IR mutation APIs and must bump `revision`.
- There is no compatibility surface for deleted recursive optimizer-body ownership layers.

## Pass Contract

- Pipeline shape: `lift -> verify -> analyze -> mutate -> verify -> lower`.
- Pass descriptors must declare required analyses and invalidations.
- Every later IR2 slice follows strict TDD: add/adjust failing tests first, then implement, then rerun `moon test`.

## Module Map

- `architecture.mbt`: shared IR2 architecture types that later pass-manager slices build on now, including revision reads and pass-descriptor metadata.
- `hot.mbt`: current hot-IR storage, lift, lower, and direct mutation implementation. This file is transitional and will be split by later slices.
- `float_compat.mbt`: Wasm-compatible float helper surface used by hot lifting/lowering.

## Planned Split

Later slices should land in dedicated modules instead of growing `hot.mbt` further:

- `hot_core.mbt`
- `hot_flags.mbt`
- `hot_types.mbt`
- `hot_labels.mbt`
- `hot_side_tables.mbt`
- `hot_builders.mbt`
- `hot_mutate.mbt`
- `hot_query.mbt`
