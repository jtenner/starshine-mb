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
- `hot_core.mbt`: owned dense storage model, storage counters, body-result accessors, and the minimal core debug dump surface. Deleted nodes are tracked as tombstones, and free-list reuse remains disabled for now.
- `hot_flags.mbt`: canonical per-op raw flag table plus fast node classification helpers for control, branch, effect, trap, and exceptional-edge queries.
- `hot_types.mbt`: canonical keyed type interning plus result-arity, result-type, and local-metadata queries for later label, CFG, and SSA slices.
- `hot_labels.mbt`: stable label ownership, branch-arity, and control-region slot metadata so later analyses stop decoding control immediates directly.
- `hot_side_tables.mbt`: typed side-table alloc/get helpers for const payloads, memargs, branch tables, catches, and call signatures so hot IR no longer depends on an untyped payload bucket.
- `hot_builders.mbt`: canonical safe node constructors that allocate labels, region wrappers, and side-table payload ids without raw field assembly.
- `hot_mutate.mbt`: canonical root, node, child-span, deletion, and revision-bump mutation helpers so later rewrites stop writing `HotFunc` storage directly.
- `hot_query.mbt`: canonical read-only node-family, type, branch, span, local-metadata, and tombstone queries so analyses stop decoding raw storage layout directly.
- `hot_walk.mbt`: stable root, child, subtree, region, control-region, worklist, and rewrite-by-slot traversal helpers with explicit `Continue` / `Skip` / `Stop` / `Error` control flow.
- `hot_region_edit.mbt`: one structured region reference plus root/body/then/else/catch splice helpers so passes can rewrite top-level and nested bodies through one mutation contract.
- `hot.mbt`: current hot-IR lift/lower and still-unsplit helper logic that now builds on `hot_core.mbt`.
- `float_compat.mbt`: Wasm-compatible float helper surface used by hot lifting/lowering.

## Planned Split

Later slices should land in dedicated modules instead of growing `hot.mbt` further:
- `hot_region_edit.mbt`
- `hot_verify.mbt`
- `hot_lift.mbt`
- `hot_lower.mbt`
