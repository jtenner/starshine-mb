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
- `bitset.mbt`: shared dense `UInt64`-backed mutable bitsets with strict bounds checks, in-place set algebra, and deterministic set-bit iteration for later dataflow overlays.
- `cfg.mbt`: deterministic CFG overlay builder with synthetic entry/exit blocks, explicit edge lists, node and region-root block mappings, structured label-target resolution, and exceptional-exit tracking for later dominator and dataflow slices.
- `cfg_contract.mbt`: normative block-boundary, structured-control successor, terminator edge-kind, and exceptional-edge policy helpers so CFG construction and later analyses stop guessing hot-IR control-flow rules.
- `cfg_order.mbt`: shared deterministic CFG preorder/postorder/reverse-postorder helpers, reverse-exit traversals, exceptional-edge-inclusive order variants, direct-region block ordering, and worklist seed policy so later analyses stop reimplementing block visitation order and unreachable-block handling.
- `dominators.mbt`: reachable-block dominator overlay with immediate dominators, dominator-tree children, dominance frontiers, interval-based dominance queries, and a debug dump surface built over the normal-flow CFG edge policy.
- `effects.mbt`: conservative derived effect-mask summaries for nodes, blocks, and regions, combining raw hot flags with exact-instruction refinement so passes can ask purity, memory, throw, trap, and state-behavior questions through one shared API.
- `liveness.mbt`: locals-only backward dataflow overlay with block `live_in` / `live_out` bitsets and direct local liveness queries, using the current non-exceptional CFG edge policy so SSA v1 stays aligned with normal-flow dominance.
- `loop_info.mbt`: natural-loop overlay with loop headers, loop bodies, latch sets, exit edges, parent nesting, block depths, block-to-innermost-loop mapping, and a debug dump surface built from CFG plus dominance.
- `postdominators.mbt`: reverse-flow post-dominator overlay with explicit normal and exceptional exit roots, immediate post-dominators, post-dominator-tree children, post-dominance frontiers, interval-free post-dominance queries, and a debug dump surface for later control rewrites.
- `ssa_policy.mbt`: local SSA overlay policy helpers covering SSA value and phi ids, entry-definition origins, overlay-only phi ownership, pruned dominance-frontier phi placement, and the locked rename/destruction/exclusion rules for SSA v1.
- `ssa_local.mbt`: local SSA construction overlay with synthetic entry defs, block-entry phi placement/materialization, dominator-tree renaming for `LocalGet` / `LocalSet` / `LocalTee`, predecessor-aligned phi inputs, and direct def/use query helpers for later SSA-assisted rewrites.
- `use_def.mbt`: node-use and locals-only block def/use overlay with distinct root-slot vs child-slot tracking, local read/write node queries, and CFG-ordered per-block summaries for later liveness, DCE, and SSA work.
- `hot_core.mbt`: owned dense storage model, storage counters, body-result accessors, and the minimal core debug dump surface. Deleted nodes are tracked as tombstones, and free-list reuse remains disabled for now.
- `hot_flags.mbt`: canonical per-op raw flag table plus fast node classification helpers for control, branch, effect, trap, and exceptional-edge queries, including the conservative `Heap` family contract for GC/reference boundary ops that still preserve exact opcode identity through payload side tables.
- `hot_types.mbt`: canonical keyed type interning plus result-arity, result-type, and local-metadata queries for later label, CFG, and SSA slices.
- `hot_labels.mbt`: stable label ownership, branch-arity, and control-region slot metadata so later analyses stop decoding control immediates directly.
- `hot_side_tables.mbt`: typed side-table alloc/get helpers for const payloads, memargs, branch tables, catches, call signatures, and exact boundary instruction payloads so hot IR no longer depends on an untyped payload bucket and later lift/lower work can preserve concrete opcode identity across generic families.
- `hot_builders.mbt`: canonical safe node constructors that allocate labels, region wrappers, and side-table payload ids without raw field assembly, including the `Heap` family helper used for boundary GC/reference instructions.
- `hot_mutate.mbt`: canonical root, node, child-span, deletion, and revision-bump mutation helpers so later rewrites stop writing `HotFunc` storage directly.
- `hot_query.mbt`: canonical read-only node-family, exact-instruction, type, branch, span, local-metadata, and tombstone queries so analyses stop decoding raw storage layout directly.
- `hot_walk.mbt`: stable root, child, subtree, region, control-region, worklist, and rewrite-by-slot traversal helpers with explicit `Continue` / `Skip` / `Stop` / `Error` control flow.
- `hot_region_edit.mbt`: one structured region reference plus root/body/then/else/catch splice helpers so passes can rewrite top-level and nested bodies through one mutation contract.
- `hot_module_context.mbt`: shared boundary-module context resolution for function signatures, type-index block results, memories, tables, globals, tags, element segments, data segments, and aggregate field metadata so lift/lower and later analyses stop depending on validator-private lookups.
- `hot_verify.mbt`: structured core/control verification plus placeholder CFG/dominance/SSA hooks and debug abort helpers so lift/lower and later passes fail fast on corruption.
- `hot_lift.mbt`: validator-backed boundary-to-hot lifting for function bodies and module functions, including module-context resolution, label metadata allocation, typed side-table payload preservation, and structured lift errors.
- `hot_lower.mbt`: verified hot-to-boundary lowering for function bodies and `@lib.Func` definitions, including label-depth remapping, exact-instruction recovery, and stack-aware emission for shared branch payload values.
- `hot.mbt`: compatibility lift entry points plus the remaining unsplit legacy helper logic.
- `float_compat.mbt`: Wasm-compatible float helper surface used by hot lifting/lowering.

## Planned Split

Later slices should land in dedicated modules instead of growing `hot.mbt` further:
- `hot_module_context.mbt`
- `hot_region_edit.mbt`
