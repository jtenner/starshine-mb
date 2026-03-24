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
- `hot_core.mbt`: owned dense storage model, storage counters, body-result accessors, and the minimal core debug dump surface. Free-list reuse remains disabled for now, so node ids are dense append-only allocations.
- `hot.mbt`: current hot-IR lift/lower and still-unsplit helper logic that now builds on `hot_core.mbt`.
- `float_compat.mbt`: Wasm-compatible float helper surface used by hot lifting/lowering.

## Planned Split

Later slices should land in dedicated modules instead of growing `hot.mbt` further:

- `hot_flags.mbt`
- `hot_types.mbt`
- `hot_labels.mbt`
- `hot_side_tables.mbt`
- `hot_builders.mbt`
- `hot_mutate.mbt`
- `hot_query.mbt`
