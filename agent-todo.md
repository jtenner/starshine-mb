# Agent Tasks

## Scope
- Keep only unreleased work.
- Group work by release target.
- Use explicit slice ids so future agents can execute in dependency order.
- Keep each slice actionable enough to implement directly without re-deriving the architecture.
- Move completed work to `CHANGELOG.md`.

## v0.1.0 Active Slice

### IR2 - 000 - Architecture Rules
- Goal:
  Lock the optimizer architecture around exactly two owned representations: boundary module form and hot function IR.
- Why this slice exists:
  Future slices need stable ownership, mutation, verification, and pass contracts before adding analyses or passes.
- Concrete deliverables:
  - Canonical architecture ADR under `docs/`.
  - `src/ir/README.md` with module map and ownership rules.
  - Public docs and package-map text updated to stop implying deleted optimizer ownership layers.
- Detailed implementation tasks:
  - State that `HotFunc` is the only owned optimizer body representation.
  - State that CFG, dominance, liveness, use-def, effects, loop info, and SSA are derived overlays keyed by `revision`.
  - Define pass contract: `lift -> verify -> analyze -> mutate -> verify -> lower`.
  - Define mutation contract: semantic mutation must go through public mutation APIs and bump `revision`.
  - Define package split for `src/ir` so later work lands in dedicated modules instead of one growing file.
  - Define TDD rule for every later slice.
- Required utilities / APIs:
  - `hot_revision_current(func)`.
  - Pass descriptor helpers declaring required analyses and invalidations.
- Invariants / correctness rules:
  - No new owned optimizer IR beside hot IR.
  - Boundary decode/encode/validation/debug remain boundary-form only.
  - No compatibility API for deleted recursive optimizer bodies.
- Dependencies:
  - None.
- Exit criteria:
  - Architecture ADR exists and matches the intended code layout.
  - Public docs no longer claim deleted ownership layers.
- Suggested tests:
  - README/API sync coverage catches deleted typed-tree wording.
  - Repository grep/assert test catches forbidden deleted optimizer names.
  - Contract test verifies pass descriptors expose requirement/invalidation metadata.

### IR2 - 010 - Hot IR Core
- Goal:
  Define the stable dense-array `HotFunc` and `HotNode` storage model.
- Why this slice exists:
  Every later builder, walker, verifier, and pass relies on one canonical core storage contract.
- Concrete deliverables:
  - `src/ir/hot_core.mbt`.
  - `src/ir/hot_core_test.mbt`.
  - Minimal hot debug dump helper for core state.
- Detailed implementation tasks:
  - Split core types out of `src/ir/hot.mbt`.
  - Keep dense arrays for `nodes`, `children`, `roots`, `locals`, `types`, `labels`, side tables, `revision`, and optional `free_nodes`.
  - Add `HOT_NONE_NODE` and any other documented sentinels.
  - Add `hot_node_count`, `hot_child_storage_count`, `hot_root_storage_count`, `hot_body_result_type_get/set`.
  - Define whether free-list reuse is enabled initially; if yes, define id reuse semantics explicitly.
  - Add `hot_node_is_live` and `hot_node_is_tombstone` if deletion support exists.
- Required utilities / APIs:
  - `hot_node_count(func)`.
  - `hot_child_storage_count(func)`.
  - `hot_root_storage_count(func)`.
  - `hot_body_result_type(func)`.
  - `hot_body_result_type_set(func, ty)`.
  - `hot_node_is_live(func, node_id)`.
- Invariants / correctness rules:
  - `HotNode.child_base` and `child_count` always describe a contiguous span in `children`.
  - `body_result_type` always refers to a valid interned `TypeId`.
  - Live nodes are never confused with tombstones.
- Dependencies:
  - IR2 - 000 - Architecture Rules.
- Exit criteria:
  - Core storage lives in its own module and exposes stable count/access policies.
  - Tests cover id allocation and liveness behavior.
- Suggested tests:
  - Dense node allocation yields predictable ids.
  - Root and child storage counters update correctly.
  - Body result type roundtrips through accessor APIs.

### IR2 - 020 - Hot IR Flags Model
- Goal:
  Centralize structural and raw-effect flag derivation for all opcodes.
- Why this slice exists:
  Builders, CFG, effect summaries, and passes need constant-time canonical node classification.
- Concrete deliverables:
  - `src/ir/hot_flags.mbt`.
  - `src/ir/hot_flags_test.mbt`.
- Detailed implementation tasks:
  - Define flag bits for `CONTROL`, `TERMINATOR`, `VALUE`, `SIDE_EFFECT`, `MAY_TRAP`, `BRANCH`, `CALL`, `LOAD`, `STORE`, `THROWS`, `HAS_EXCEPTIONAL_SUCC`, and optional `TOMBSTONE`.
  - Add a central opcode metadata table or `hot_default_flags_for_op(op)`.
  - Replace handwritten flag literals in builders/lift with the central source.
  - Add fast helpers for `hot_is_control_node`, `hot_is_terminator_node`, `hot_has_side_effect`, `hot_may_trap`, `hot_is_branch`, `hot_has_exceptional_succ`.
- Required utilities / APIs:
  - `hot_default_flags_for_op(op)`.
  - `hot_node_flags(func, node_id)`.
  - `hot_node_has_flag(func, node_id, flag)`.
  - `hot_is_control_node(func, node_id)`.
  - `hot_is_terminator_node(func, node_id)`.
  - `hot_node_may_throw_exception(func, node_id)`.
- Invariants / correctness rules:
  - Raw flags are local opcode facts, not subtree summaries.
  - Impossible flag combinations are rejected.
  - Terminator flags must agree with CFG semantics.
- Dependencies:
  - IR2 - 010 - Hot IR Core.
- Exit criteria:
  - All node construction uses one canonical flag source.
  - Control, call, memory, branch, and throw families are covered by tests.
- Suggested tests:
  - Representative opcodes classify into the expected flag sets.
  - Replaced nodes retain canonical flags.
  - Invalid flag combinations are rejected.

### IR2 - 030 - Hot IR Type Interning
- Goal:
  Implement fast deterministic type interning and result-type queries.
- Why this slice exists:
  Node types, block result types, label arity, and SSA all depend on stable `TypeId` behavior.
- Concrete deliverables:
  - `src/ir/hot_types.mbt`.
  - `src/ir/hot_types_test.mbt`.
- Detailed implementation tasks:
  - Keep `HotTypeInfo` variants for `VoidType`, `BlockResult`, `Value`, and `Results`.
  - Replace the current linear scan interning path with deterministic canonical interning.
  - Add `hot_type_intern_void`, `hot_type_intern_value`, `hot_type_intern_block_result`, `hot_type_intern_results`.
  - Add `hot_type_get`, `hot_type_result_arity`, `hot_type_is_void`, `hot_type_results`.
  - Add local metadata helpers `hot_param_count`, `hot_local_count`, `hot_local_type`.
- Required utilities / APIs:
  - `hot_type_intern_void(func)`.
  - `hot_type_intern_value(func, val_type)`.
  - `hot_type_intern_block_result(func, block_type)`.
  - `hot_type_intern_results(func, result_types)`.
  - `hot_type_get(func, type_id)`.
  - `hot_type_result_arity(func, type_id)`.
  - `hot_local_type(func, local_id)`.
- Invariants / correctness rules:
  - Equivalent payloads intern to the same `TypeId`.
  - `HotNode.ty` always points to a valid interned type.
  - Label branch arity agrees with the interned result type.
- Dependencies:
  - IR2 - 010 - Hot IR Core.
- Exit criteria:
  - Type creation is fully centralized and deterministic.
  - Arity and local type queries exist for later slices.
- Suggested tests:
  - Duplicate type payloads reuse one `TypeId`.
  - Arity queries cover void, single-result, and multi-result cases.
  - Local metadata queries return correct parameter/local types.

### IR2 - 040 - Hot IR Label/Control Metadata
- Goal:
  Make control labels and control-child layout explicit and queryable.
- Why this slice exists:
  Branch target queries, CFG construction, and lowering need stable label ownership and region-slot contracts.
- Concrete deliverables:
  - `src/ir/hot_labels.mbt`.
  - `src/ir/hot_labels_test.mbt`.
- Detailed implementation tasks:
  - Keep `HotLabelKind` and `HotLabelInfo` as the stable control metadata surface.
  - Add `hot_label_alloc`, `hot_label_get`, `hot_label_owner`, `hot_label_result_type`, `hot_label_branch_arity`, `hot_label_kind`.
  - Add control-slot helpers for `Block`, `Loop`, `If`, `Try`, and `TryTable`.
  - Add `hot_control_node_label(func, node_id)` and control-region-slot metadata APIs.
  - Hide raw `imm0` interpretation behind this module.
- Required utilities / APIs:
  - `hot_label_get(func, label_id)`.
  - `hot_label_owner(func, label_id)`.
  - `hot_label_kind(func, label_id)`.
  - `hot_label_result_type(func, label_id)`.
  - `hot_label_branch_arity(func, label_id)`.
  - `hot_control_node_label(func, node_id)`.
  - `hot_control_region_slot_info(op)`.
- Invariants / correctness rules:
  - Every non-region label owner is a live control node.
  - Control nodes own exactly the labels documented for that opcode family.
  - Branch arity and result type stay consistent.
- Dependencies:
  - IR2 - 010 - Hot IR Core.
  - IR2 - 030 - Hot IR Type Interning.
- Exit criteria:
  - Later code can query label ownership and region slots without decoding raw immediates.
- Suggested tests:
  - Nested `block`/`loop`/`if` label ownership.
  - `loop` branch arity semantics vs `block`.
  - `try`/`try_table` region-slot metadata stability.

### IR2 - 050 - Hot IR Side Tables
- Goal:
  Replace generic/implied payload handling with dedicated typed side tables.
- Why this slice exists:
  Memory args, branch tables, call signatures, catches, constants, and family immediates need explicit typed ownership.
- Concrete deliverables:
  - `src/ir/hot_side_tables.mbt`.
  - `src/ir/hot_side_tables_test.mbt`.
- Detailed implementation tasks:
  - Keep typed side tables for const payloads, memargs, branch tables, catches, and call signatures.
  - Replace generic `HotExtra` with dedicated typed storage or documented inline-immediate rules.
  - Add alloc/get APIs for every side table family.
  - Add multi-target branch-table query helpers.
  - Define which op families use side-table ids versus inline enum/immediate payloads.
- Required utilities / APIs:
  - `hot_alloc_const`, `hot_const_get`.
  - `hot_alloc_memarg`, `hot_memarg_get`.
  - `hot_alloc_branch_table`, `hot_branch_table_targets`, `hot_branch_table_default_target`.
  - `hot_alloc_catch_info`, `hot_catch_info_get`.
  - `hot_alloc_call_sig`, `hot_call_sig_get`.
  - `hot_side_table_kind_for_op(op)`.
- Invariants / correctness rules:
  - Side-table ids are only interpreted through the matching opcode family.
  - Branch table targets/default target are always valid labels.
  - Catch payloads only reference valid catch-region labels.
- Dependencies:
  - IR2 - 010 - Hot IR Core.
  - IR2 - 040 - Hot IR Label/Control Metadata.
- Exit criteria:
  - No final hot IR family depends on an untyped “extra payload” bucket.
- Suggested tests:
  - Typed alloc/get for every side-table family.
  - `BrTable` target/default queries.
  - Call/memory/catch payload roundtrip correctness.

### IR2 - 060 - Hot IR Builders / Constructors
- Goal:
  Provide family-specific safe builders for valid hot IR node creation.
- Why this slice exists:
  Future passes need canonical node construction without manually reconstructing flags, labels, or side-table wiring.
- Concrete deliverables:
  - `src/ir/hot_builders.mbt`.
  - `src/ir/hot_builders_test.mbt`.
- Detailed implementation tasks:
  - Keep one low-level builder plus family-specific builders for constants, locals/globals, branches, calls, memory/table ops, numeric ops, tuple ops, and exception ops.
  - Add structured control builders for `Block`, `Loop`, `If`, `Try`, and `TryTable`.
  - Ensure builders allocate labels, child spans, and side-table payloads correctly.
  - Ensure builders source flags from `hot_flags` and types from `hot_types`.
- Required utilities / APIs:
  - `hot_build_const_*`.
  - `hot_build_local_get/set/tee`.
  - `hot_build_branch_*`.
  - `hot_build_call_*`.
  - `hot_build_block/loop/if/try/try_table`.
  - `hot_build_drop`, `hot_build_unreachable`, `hot_build_return`.
- Invariants / correctness rules:
  - Builders never emit mismatched child counts or missing label metadata.
  - Structured control builders fully own region/label setup.
- Dependencies:
  - IR2 - 020 - Hot IR Flags Model.
  - IR2 - 030 - Hot IR Type Interning.
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 050 - Hot IR Side Tables.
- Exit criteria:
  - New nodes can be created through public family builders instead of raw field assembly.
- Suggested tests:
  - Typed `if` builder correctness.
  - Memory/call builder side-table wiring.
  - Peephole replacement using builder-created nodes.

### IR2 - 070 - Hot IR Direct Mutation Primitives
- Goal:
  Implement the authoritative low-level mutation layer for roots, nodes, child spans, side tables, deletion, and revision bumps.
- Why this slice exists:
  Every later rewrite, cache invalidation, and verification rule depends on one mutation surface.
- Concrete deliverables:
  - `src/ir/hot_mutate.mbt`.
  - `src/ir/hot_mutate_test.mbt`.
- Detailed implementation tasks:
  - Add root APIs: count/get/set/append/insert/remove/splice.
  - Add child APIs: count/get/set/span/alloc/replacement.
  - Add node APIs: get/set/replace/alloc/delete and free-list reuse if enabled.
  - Centralize `hot_revision_bump(func)`.
  - Define tombstone and free-list behavior explicitly.
  - Add debug assertions for bounds and deleted-node misuse.
- Required utilities / APIs:
  - `hot_root_count/get/set/append/remove/insert/splice`.
  - `hot_child_count/get/set`.
  - `hot_alloc_child_span(func, count)`.
  - `hot_replace_child_span(func, node_id, new_children)`.
  - `hot_node_get/set/replace`.
  - `hot_alloc_node(func, node)`.
  - `hot_delete_node(func, node_id)`.
  - `hot_revision_current(func)`.
  - `hot_revision_bump(func)`.
- Invariants / correctness rules:
  - Every semantic mutation bumps `revision`.
  - Pure reads never bump `revision`.
  - Deleted nodes are never referenced from roots or child spans.
- Dependencies:
  - IR2 - 010 - Hot IR Core.
  - IR2 - 020 - Hot IR Flags Model.
  - IR2 - 050 - Hot IR Side Tables.
- Exit criteria:
  - All direct writes to `HotFunc` storage are encapsulated.
- Suggested tests:
  - Root and child replacement revision rules.
  - Child-span replacement with different lengths.
  - Node deletion rejects stale references.

### IR2 - 080 - Hot IR Structural Query Utilities
- Goal:
  Export fast structural queries over hot IR shape, metadata, side tables, locals, and branches.
- Why this slice exists:
  Passes and analyses should not decode raw fields or side-table layout themselves.
- Concrete deliverables:
  - `src/ir/hot_query.mbt`.
  - `src/ir/hot_query_test.mbt`.
- Detailed implementation tasks:
  - Add fast node-kind classification for control, branch, call, local/global, memory/table, numeric, tuple, exception, SIMD, and atomic families.
  - Add result-type queries and root/child span helpers.
  - Add label owner and branch target queries.
  - Add multi-target branch-table queries.
  - Add local metadata queries for count, param/local split, and local types.
  - Add tombstone/free-list status queries if applicable.
- Required utilities / APIs:
  - `hot_node_kind_*` helpers.
  - `hot_node_type(func, node_id)`.
  - `hot_node_result_arity(func, node_id)`.
  - `hot_label_owner(func, label_id)`.
  - `hot_branch_target(func, node_id)`.
  - `hot_branch_table_targets_for_node(func, node_id)`.
  - `hot_local_count(func)`, `hot_local_type(func, local_id)`.
  - `hot_root_span(func)`, `hot_child_span(func, node_id)`.
- Invariants / correctness rules:
  - Queries are read-only and never bump `revision`.
  - Branch/label queries only expose typed valid ids or documented sentinels.
- Dependencies:
  - IR2 - 020 - Hot IR Flags Model.
  - IR2 - 030 - Hot IR Type Interning.
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 050 - Hot IR Side Tables.
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
- Exit criteria:
  - All required query categories are available through stable APIs.
- Suggested tests:
  - Mixed-body node kind and type queries.
  - `Br`/`BrIf`/`BrTable` target queries.
  - Param/local metadata queries.

### IR2 - 090 - Hot IR Traversal Utilities
- Goal:
  Provide shared walkers for roots, direct children, subtrees, region-local scans, worklists, and rewrite-by-slot traversal.
- Why this slice exists:
  Analyses and passes need reusable traversal control flow with skip/stop semantics.
- Concrete deliverables:
  - `src/ir/hot_walk.mbt`.
  - `src/ir/hot_walk_test.mbt`.
- Detailed implementation tasks:
  - Move `HotVisitCtl` and `HotRewriteCtl` into the traversal module.
  - Add root iteration, direct child iteration, subtree preorder and postorder, region-local traversal, worklist traversal, and control-region traversal helpers.
  - Add rewrite-by-slot traversal exposing parent node id and child slot.
  - Keep traversal stack-based and non-recursive where practical.
- Required utilities / APIs:
  - `hot_for_each_root`.
  - `hot_for_each_child`.
  - `hot_walk_subtree_preorder`.
  - `hot_walk_subtree_postorder`.
  - `hot_walk_region`.
  - `hot_rewrite_children_by_slot`.
  - `hot_worklist_walk`.
  - `hot_walk_control_regions`.
- Invariants / correctness rules:
  - Traversal order is documented and stable.
  - Rewrite traversal mutates only through public mutation APIs.
  - Tombstones are skipped unless explicitly requested by a debug walk.
- Dependencies:
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
  - IR2 - 080 - Hot IR Structural Query Utilities.
- Exit criteria:
  - Later analyses and passes build on shared walkers rather than ad hoc recursion.
- Suggested tests:
  - Preorder/postorder stability.
  - `Skip` and `Stop` semantics.
  - Rewrite-by-slot replacing/removing optional children safely.

### IR2 - 100 - Hot IR Region Editing Utilities
- Goal:
  Build high-level structured region insertion/removal/splice APIs.
- Why this slice exists:
  Passes need to rewrite region bodies without hand-editing root arrays or raw control child slots.
- Concrete deliverables:
  - `src/ir/hot_region_edit.mbt`.
  - `src/ir/hot_region_edit_test.mbt`.
- Detailed implementation tasks:
  - Define `HotRegionRef` or equivalent region-address abstraction.
  - Add region root count/get/set/insert/remove/splice helpers.
  - Add top-level insertion/removal helpers and nested region body replacement helpers.
  - Add helpers for replacing `then`, `else`, `catch`, and loop/block bodies through structured APIs.
  - Route all edits through low-level mutation primitives.
- Required utilities / APIs:
  - `HotRegionRef`.
  - `hot_region_root_count(func, region_ref)`.
  - `hot_region_get(func, region_ref, idx)`.
  - `hot_region_set(func, region_ref, idx, node_id)`.
  - `hot_region_insert(func, region_ref, idx, node_ids)`.
  - `hot_region_remove(func, region_ref, idx, count)`.
  - `hot_region_splice(func, region_ref, idx, remove_count, node_ids)`.
  - `hot_region_replace_body(func, region_ref, node_ids)`.
- Invariants / correctness rules:
  - Region edits preserve structured control ownership.
  - Root-level and nested region behavior follow one API contract.
  - Region edits never expose partially rewritten bodies.
- Dependencies:
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
  - IR2 - 080 - Hot IR Structural Query Utilities.
  - IR2 - 090 - Hot IR Traversal Utilities.
- Exit criteria:
  - Structured body splicing is possible without raw storage editing.
- Suggested tests:
  - Top-level root insertion/removal.
  - `if` then/else body replacement.
  - Loop or try body splicing preserving verification.

### IR2 - 110 - Hot IR Verification Utilities
- Goal:
  Implement internal verification for hot IR core, control, CFG, dominance, and SSA overlays.
- Why this slice exists:
  Every later mutation and analysis needs fast corruption detection and explicit failure modes.
- Concrete deliverables:
  - `src/ir/hot_verify.mbt`.
  - `src/ir/hot_verify_test.mbt`.
- Detailed implementation tasks:
  - Add core verification for node table consistency, child-span bounds, root validity, side-table index validity, type interning validity, and label owner consistency.
  - Add control verification for branch targets and control-child layout.
  - Add extension points for CFG, dominance, and SSA verification.
  - Return structured verification errors rather than freeform strings.
  - Add debug `verify_or_abort` helpers for test/debug flows.
- Required utilities / APIs:
  - `hot_verify_core(func)`.
  - `hot_verify_control(func)`.
  - `hot_verify_cfg(func, cfg)`.
  - `hot_verify_dominators(cfg, dom)`.
  - `hot_verify_ssa(func, cfg, ssa)`.
  - `hot_verify_all(func, cache?)`.
- Invariants / correctness rules:
  - Verification is read-only.
  - A verified function has no stale tombstone references, out-of-bounds ids, or payload-family mismatches.
  - Branch targets always reference valid labels with matching arity.
- Dependencies:
  - IR2 - 030 - Hot IR Type Interning.
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 050 - Hot IR Side Tables.
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
  - IR2 - 080 - Hot IR Structural Query Utilities.
  - IR2 - 100 - Hot IR Region Editing Utilities.
- Exit criteria:
  - Hot IR verification exists and is wired into lift, passes, and tests.
- Suggested tests:
  - Corrupt child span/root/side-table indices and verify precise failure categories.
  - Corrupt label ownership or branch targets.
  - Verify a valid function passes all enabled verification layers.

### IR2 - 120 - Boundary -> Hot Lifting
- Goal:
  Lift valid boundary function bodies into full-coverage hot IR.
- Why this slice exists:
  The current lift path handles only a minimal opcode subset.
- Concrete deliverables:
  - `src/ir/hot_lift.mbt`.
  - `src/ir/hot_lift_test.mbt`.
- Detailed implementation tasks:
  - Define a public lift entry point from boundary body plus module context.
  - Cover control, branch, call, local/global, memory/table, const/ref, numeric, tuple, SIMD, atomic, and exception families.
  - Allocate label metadata, side-table payloads, and interned types during lift.
  - Replace current `abort("unsupported instruction")` behavior with full coverage or structured errors.
  - Verify lifted functions before they enter the pass pipeline.
- Required utilities / APIs:
  - `hot_lift_func(module, func_idx)` or equivalent.
  - `hot_lift_body(expr, locals, module_context, body_result_type)`.
  - Lift helpers for labels, control regions, constants, memargs, branch tables, catches, and call signatures.
- Invariants / correctness rules:
  - Lift preserves boundary semantics exactly.
  - Lift produces the only owned optimizer body representation.
  - Branches target hot labels, not boundary depths.
- Dependencies:
  - IR2 - 030 - Hot IR Type Interning.
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 050 - Hot IR Side Tables.
  - IR2 - 060 - Hot IR Builders / Constructors.
  - IR2 - 110 - Hot IR Verification Utilities.
- Exit criteria:
  - Lift covers the full supported boundary opcode surface.
- Suggested tests:
  - Roundtrip representative functions with memory, calls, exceptions, and branches.
  - Nested control lift metadata correctness.
  - Structured error coverage for malformed internal inputs.

### IR2 - 130 - Hot -> Boundary Lowering
- Goal:
  Lower verified hot IR back to boundary bodies deterministically.
- Why this slice exists:
  The optimizer must always return boundary-form functions for encode/validate/debug flows.
- Concrete deliverables:
  - `src/ir/hot_lower.mbt`.
  - `src/ir/hot_lower_test.mbt`.
- Detailed implementation tasks:
  - Define a full lowering entry point from `HotFunc` to boundary body.
  - Cover the same opcode families as lifting.
  - Lower structured control using control/label metadata rather than raw child-slot guesses.
  - Lower side-table payloads through typed accessors.
  - Verify before lowering in debug/test paths.
  - Ensure tombstones and internal sentinels never leak to boundary output.
- Required utilities / APIs:
  - `hot_lower_func(func, module_context?)`.
  - `hot_lower_body(func)`.
  - Lower helpers for constants, branches, calls, memargs, catches, and control regions.
- Invariants / correctness rules:
  - Lowering preserves semantics and declared block result types.
  - Only verified live nodes reachable from roots are lowered.
- Dependencies:
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 050 - Hot IR Side Tables.
  - IR2 - 080 - Hot IR Structural Query Utilities.
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 120 - Boundary -> Hot Lifting.
- Exit criteria:
  - Lift/lower roundtrips succeed for untouched and edited hot functions.
- Suggested tests:
  - Hand-built hot control lowering.
  - Lowering after region edits.
  - Tombstone/unreachable hidden storage never leaks to output.

### IR2 - 140 - CFG Contract and Block Boundary Rules
- Goal:
  Define the exact CFG semantics for hot IR block formation, terminators, exceptional edges, and node/block mappings.
- Why this slice exists:
  CFG-dependent analyses cannot be implemented correctly without a normative contract.
- Concrete deliverables:
  - CFG contract ADR under `docs/`.
  - `src/ir/cfg_contract.mbt`.
  - `src/ir/cfg_contract_test.mbt`.
- Detailed implementation tasks:
  - Define `BlockId`, `CfgEdgeKind`, and entry/exit block policy.
  - State what forms a basic-block boundary.
  - Define how `Block`, `Loop`, `If`, `Try`, and `TryTable` affect block formation.
  - Define terminators and edge generation for `Br`, `BrIf`, `BrTable`, `Return`, `Throw`, `ThrowRef`, `Delegate`, `Rethrow`, and `Unreachable`.
  - Define exceptional-edge representation and unreachable-block policy.
  - Define `NodeId -> BlockId` and region-root-slot -> block mappings as required outputs.
- Required utilities / APIs:
  - `CfgEdgeKind`.
  - `cfg_block_boundary_reason(node_id)` or equivalent.
  - `cfg_control_successor_policy(op)`.
  - `cfg_exception_target_policy(...)`.
- Invariants / correctness rules:
  - Every live region root belongs to exactly one block.
  - Value-only nodes stay inside the current block.
  - Exceptional edges are explicit CFG edges, not implicit side facts.
- Dependencies:
  - IR2 - 040 - Hot IR Label/Control Metadata.
  - IR2 - 080 - Hot IR Structural Query Utilities.
  - IR2 - 090 - Hot IR Traversal Utilities.
- Exit criteria:
  - Future agents can build CFG without guessing boundary rules.
- Suggested tests:
  - Block-boundary classification around structured control.
  - `BrIf` target/fallthrough edge policy.
  - Exceptional-edge policy under `try`/`try_table`.

### IR2 - 150 - CFG Construction
- Goal:
  Build the CFG overlay, including block arrays, edge arrays, and node/block mappings.
- Why this slice exists:
  Dominators, liveness, loop info, SSA, and CFG-aware passes all depend on a shared CFG.
- Concrete deliverables:
  - `src/ir/cfg.mbt`.
  - `src/ir/cfg_test.mbt`.
- Detailed implementation tasks:
  - Define `HotCfg`, `HotBlockInfo`, preds/succs, entry/exit blocks, optional exceptional exit, and mapping tables.
  - Build blocks from hot regions using the contract slice.
  - Record successor and predecessor edges with explicit edge kinds.
  - Compute `node_to_block` and `region_root_to_block`.
  - Run CFG verification after build.
- Required utilities / APIs:
  - `cfg_build(func)`.
  - `cfg_entry_block(cfg)`.
  - `cfg_exit_block(cfg)`.
  - `cfg_block_get(cfg, block_id)`.
  - `cfg_block_for_node(cfg, node_id)`.
  - `cfg_block_for_region_root(cfg, region_ref, slot)`.
  - `cfg_successors(cfg, block_id)`.
  - `cfg_predecessors(cfg, block_id)`.
- Invariants / correctness rules:
  - Successor and predecessor lists are symmetric.
  - Node/block mappings only cover documented execution nodes.
  - Synthetic blocks are clearly marked.
- Dependencies:
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 140 - CFG Contract and Block Boundary Rules.
- Exit criteria:
  - CFG build yields stable block ids and mappings on representative structured bodies.
- Suggested tests:
  - Nested `if`/`loop` CFG layout.
  - `try_table` exceptional/control edges.
  - Unreachable-block policy coverage.

### IR2 - 160 - CFG Traversal Order Utilities
- Goal:
  Provide stable CFG preorder, postorder, reverse postorder, reverse-exit order, and worklist seeds.
- Why this slice exists:
  Dominators, post-dominators, liveness, and other dataflow passes need shared block order helpers.
- Concrete deliverables:
  - `src/ir/cfg_order.mbt`.
  - `src/ir/cfg_order_test.mbt`.
- Detailed implementation tasks:
  - Add normal-flow and exceptional-flow-inclusive DFS order helpers.
  - Add preorder, postorder, reverse postorder, and reverse-exit postorder APIs.
  - Add region-local block order helper if a pass only wants one structured region.
  - Document unreachable-block handling.
- Required utilities / APIs:
  - `cfg_preorder(cfg)`.
  - `cfg_postorder(cfg)`.
  - `cfg_reverse_postorder(cfg)`.
  - `cfg_reverse_postorder_from_exit(cfg)`.
  - `cfg_region_blocks_in_rpo(cfg, region_ref)`.
  - `cfg_block_worklist_seed(cfg)`.
- Invariants / correctness rules:
  - Order is deterministic.
  - Exceptional-edge inclusion policy is explicit per API.
- Dependencies:
  - IR2 - 150 - CFG Construction.
- Exit criteria:
  - Later analyses can share one order implementation.
- Suggested tests:
  - Diamond RPO order.
  - Reverse-exit order on multi-exit function.
  - Exceptional-edge-inclusive order differs as expected.

### IR2 - 165 - Dataflow Bitset Utilities
- Goal:
  Provide compact reusable bitsets for liveness, dominance frontiers, and block-local def/use.
- Why this slice exists:
  Dataflow analyses should not hand-roll mutable boolean arrays.
- Concrete deliverables:
  - `src/ir/bitset.mbt`.
  - `src/ir/bitset_test.mbt`.
- Detailed implementation tasks:
  - Implement dense bitset storage backed by word arrays.
  - Add set/clear/test/union/intersection/difference/equality/empty iteration helpers.
  - Keep API generic for locals, blocks, and SSA ids.
  - Add deterministic debug formatting.
- Required utilities / APIs:
  - `bitset_new(size)`.
  - `bitset_set/clear/contains`.
  - `bitset_union_into`.
  - `bitset_intersect_into`.
  - `bitset_difference_into`.
  - `bitset_equals`.
  - `bitset_for_each_set_bit`.
- Invariants / correctness rules:
  - Out-of-range access is rejected.
  - Non-word-aligned sizes behave correctly.
- Dependencies:
  - IR2 - 000 - Architecture Rules.
- Exit criteria:
  - Later dataflow slices can depend on one shared bitset module.
- Suggested tests:
  - Union/intersection/difference on overlapping sets.
  - Stable set-bit iteration order.
  - Edge cases at sizes `0`, `1`, `63`, `64`, and `65`.

### IR2 - 170 - Dominators
- Goal:
  Compute immediate dominators, dominator tree, dominance queries, and dominance frontiers.
- Why this slice exists:
  SSA, loop info, and CFG-aware rewrites need dominance information.
- Concrete deliverables:
  - `src/ir/dominators.mbt`.
  - `src/ir/dominators_test.mbt`.
- Detailed implementation tasks:
  - Build dominators over reachable CFG blocks using shared RPO.
  - Compute idoms and dominator-tree children.
  - Add `dominates` and `strictly_dominates` queries.
  - Compute dominance frontiers for SSA placement.
  - Add debug dump helpers and verifier integration.
- Required utilities / APIs:
  - `dom_build(cfg)`.
  - `dom_idom(dom, block_id)`.
  - `dom_children(dom, block_id)`.
  - `dom_dominates(dom, a, b)`.
  - `dom_strictly_dominates(dom, a, b)`.
  - `dom_frontier(dom, block_id)`.
- Invariants / correctness rules:
  - Entry dominates all reachable blocks.
  - Idom relations form a tree.
  - Dominance frontiers are computed from the same edge set SSA will use.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 160 - CFG Traversal Order Utilities.
  - IR2 - 165 - Dataflow Bitset Utilities.
- Exit criteria:
  - Dominance queries and frontiers are available and verified.
- Suggested tests:
  - Diamond idoms/frontiers.
  - Loop header/latch dominance.
  - Unreachable-block policy coverage.

### IR2 - 180 - Post-Dominators
- Goal:
  Compute post-dominators and post-dominance queries, including exceptional exits.
- Why this slice exists:
  Some control rewrites and effect reasoning need reverse-flow dominance.
- Concrete deliverables:
  - `src/ir/postdominators.mbt`.
  - `src/ir/postdominators_test.mbt`.
- Detailed implementation tasks:
  - Build post-dominators from reverse CFG.
  - Define normal/exceptional exit policy and implement it consistently.
  - Compute immediate post-dominators and post-dom tree.
  - Add query helpers and debug dump support.
- Required utilities / APIs:
  - `postdom_build(cfg)`.
  - `postdom_ipdom(postdom, block_id)`.
  - `postdom_children(postdom, block_id)`.
  - `postdom_postdominates(postdom, a, b)`.
  - `postdom_frontier(postdom, block_id)` if needed.
- Invariants / correctness rules:
  - Exit handling matches the documented CFG contract.
  - Overlay is keyed to the same reachable block set as consumers.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 160 - CFG Traversal Order Utilities.
  - IR2 - 165 - Dataflow Bitset Utilities.
- Exit criteria:
  - Multi-exit and exceptional-control cases are supported.
- Suggested tests:
  - Shared-return diamond.
  - Separate return/throw exit behavior.
  - Loop with side exit post-dominance.

### IR2 - 190 - Loop Info
- Goal:
  Compute loop headers, bodies, latches, exits, and nesting depth from CFG + dominance.
- Why this slice exists:
  Loop-aware passes and some SSA reasoning need explicit loop metadata.
- Concrete deliverables:
  - `src/ir/loop_info.mbt`.
  - `src/ir/loop_info_test.mbt`.
- Detailed implementation tasks:
  - Detect backedges.
  - Build natural loop bodies and exit sets.
  - Compute loop nesting and block->innermost-loop mapping.
  - Add debug dump helpers.
  - Document relationship between structured `Loop` nodes and CFG loop headers.
- Required utilities / APIs:
  - `loop_info_build(cfg, dom)`.
  - `loop_header(loop_info, loop_id)`.
  - `loop_blocks(loop_info, loop_id)`.
  - `loop_latches(loop_info, loop_id)`.
  - `loop_exits(loop_info, loop_id)`.
  - `loop_depth(loop_info, block_id)`.
  - `loop_for_block(loop_info, block_id)`.
- Invariants / correctness rules:
  - Loop header dominates all blocks in its natural loop.
  - Loop nesting forms a tree.
  - Exit sets come from CFG successors leaving the loop body.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 170 - Dominators.
  - IR2 - 165 - Dataflow Bitset Utilities.
- Exit criteria:
  - Loop metadata is usable by later optimizations.
- Suggested tests:
  - Single natural loop.
  - Nested loops.
  - Loop with early-exit branch.

### IR2 - 200 - Use-Def
- Goal:
  Build node use lists and block-local local def/use summaries.
- Why this slice exists:
  DCE, liveness, and SSA need stable use-site indexing and block-local def/use extraction.
- Concrete deliverables:
  - `src/ir/use_def.mbt`.
  - `src/ir/use_def_test.mbt`.
- Detailed implementation tasks:
  - Represent use sites as user location plus child slot or root slot.
  - Build node use lists from child edges and root slots.
  - Build per-block local def/use bitsets from `LocalGet`, `LocalSet`, and `LocalTee`.
  - Keep policy explicit: full node def-use for hot nodes, locals-only block def/use for dataflow.
  - Add use-count and local read/write query helpers.
- Required utilities / APIs:
  - `use_def_build(func, cfg?)`.
  - `node_use_sites(use_def, node_id)`.
  - `node_use_count(use_def, node_id)`.
  - `block_local_defs(use_def, block_id)`.
  - `block_local_uses(use_def, block_id)`.
  - `local_read_nodes(use_def, local_id)`.
  - `local_write_nodes(use_def, local_id)`.
- Invariants / correctness rules:
  - Every live child edge is represented once.
  - Root-slot uses are tracked distinctly from child-slot uses.
  - Block def/use respects CFG block boundaries.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 165 - Dataflow Bitset Utilities.
  - IR2 - 080 - Hot IR Structural Query Utilities.
  - IR2 - 090 - Hot IR Traversal Utilities.
- Exit criteria:
  - Use-count and block-local def/use APIs are ready for DCE, liveness, and SSA.
- Suggested tests:
  - Expression tree use-site tracking.
  - Distinct root-slot vs child-slot uses.
  - Block-local def/use on CFG join.

### IR2 - 210 - Liveness
- Goal:
  Compute block `live_in` and `live_out` sets for locals.
- Why this slice exists:
  SSA placement and dead local cleanup depend on local liveness.
- Concrete deliverables:
  - `src/ir/liveness.mbt`.
  - `src/ir/liveness_test.mbt`.
- Detailed implementation tasks:
  - Implement backward local-liveness dataflow using block defs/uses and CFG successors.
  - Keep the policy explicit that liveness is locals-only.
  - Add `local_live_in` and `local_live_out` queries.
  - Document whether exceptional edges are included and keep it consistent with SSA.
- Required utilities / APIs:
  - `liveness_build(cfg, use_def)`.
  - `live_in(liveness, block_id)`.
  - `live_out(liveness, block_id)`.
  - `local_live_in(liveness, block_id, local_id)`.
  - `local_live_out(liveness, block_id, local_id)`.
- Invariants / correctness rules:
  - `live_in = uses ∪ (live_out - defs)`.
  - Overlay invalidates on CFG/local mutation.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 165 - Dataflow Bitset Utilities.
  - IR2 - 200 - Use-Def.
- Exit criteria:
  - Liveness works on joins and loops.
- Suggested tests:
  - Diamond join liveness.
  - Loop-carried local liveness.
  - Exceptional-edge inclusion policy coverage.

### IR2 - 220 - Effect Summaries
- Goal:
  Compute derived effect summaries for nodes, blocks, and regions.
- Why this slice exists:
  Passes need more than raw node flags to decide purity, motion safety, and exceptional behavior.
- Concrete deliverables:
  - `src/ir/effects.mbt`.
  - `src/ir/effects_test.mbt`.
- Detailed implementation tasks:
  - Define `EffectMask` categories for memory, table, global/local state, calls, throws, traps, and control effects.
  - Build per-node summaries from raw flags and typed payload knowledge.
  - Build per-block and per-region summaries.
  - Add convenience purity and may-throw predicates.
  - Keep raw flags and derived summaries as separate layers.
- Required utilities / APIs:
  - `effects_for_node(func, node_id)`.
  - `effects_for_block(func, cfg, block_id)`.
  - `effects_for_region(func, region_ref)`.
  - `effects_is_pure(mask)`.
  - `effects_may_throw(mask)`.
  - `effects_reads_memory(mask)`.
  - `effects_writes_memory(mask)`.
- Invariants / correctness rules:
  - Summaries conservatively over-approximate behavior.
  - Overlay is invalid on revision change.
  - Exceptional-edge semantics stay consistent with CFG policy.
- Dependencies:
  - IR2 - 020 - Hot IR Flags Model.
  - IR2 - 090 - Hot IR Traversal Utilities.
  - IR2 - 150 - CFG Construction.
- Exit criteria:
  - Passes can ask node/block/region purity and memory/throw properties through shared APIs.
- Suggested tests:
  - Pure arithmetic vs stateful memory ops.
  - Call/throw/trap effect categories.
  - Region/block summary aggregation.

### IR2 - 230 - SSA Design Policy
- Goal:
  Lock the local-SSA-only overlay policy so construction and destruction are unambiguous.
- Why this slice exists:
  Without a policy slice, future agents could accidentally introduce a second owned IR.
- Concrete deliverables:
  - SSA policy ADR under `docs/`.
  - `src/ir/ssa_policy.mbt`.
  - `src/ir/ssa_policy_test.mbt`.
- Detailed implementation tasks:
  - Define scope: locals-only SSA overlay, not a new owned body representation.
  - Define `SsaValueId`, `PhiId`, `HotLocalSsa`, and def/use categories.
  - Define phi placement at block entries using dominance frontiers pruned by liveness.
  - Define parameter and default-local-init entry definitions.
  - Define rename and destruction policies.
  - State what SSA v1 excludes.
- Required utilities / APIs:
  - `SsaValueId`, `PhiId`, `HotLocalSsa`.
  - `ssa_value_type(ssa, value_id)`.
  - `ssa_value_origin(ssa, value_id)`.
  - `ssa_phi_block(ssa, phi_id)`.
  - `ssa_phi_local(ssa, phi_id)`.
  - `ssa_default_init_def(local_id)`.
- Invariants / correctness rules:
  - Hot IR remains ordinary local ops plus other hot nodes.
  - Phi nodes exist only in the overlay, not as persistent hot nodes.
  - Every SSA value has one defining origin.
- Dependencies:
  - IR2 - 170 - Dominators.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
- Exit criteria:
  - SSA construction/destruction slices can execute without re-deciding scope or policy.
- Suggested tests:
  - Parameter/default-init entry-def classification.
  - Phi-placement policy on a diamond.
  - Policy rejection of permanent phi nodes in `HotFunc`.

### IR2 - 240 - Local SSA Construction
- Goal:
  Build the local SSA overlay from hot IR + CFG + dominance + liveness.
- Why this slice exists:
  SSA-assisted passes need precise reaching definitions for locals.
- Concrete deliverables:
  - `src/ir/ssa_local.mbt`.
  - `src/ir/ssa_local_test.mbt`.
- Detailed implementation tasks:
  - Place local phis using dominance frontiers pruned by liveness.
  - Create synthetic entry defs for parameters and default local initialization.
  - Run dominator-tree rename for `LocalGet`, `LocalSet`, and `LocalTee`.
  - Record phi incoming values per predecessor.
  - Record mappings from hot local nodes to SSA defs/uses.
  - Add query helpers for reaching def, phi lists, phi inputs, and uses of SSA values.
- Required utilities / APIs:
  - `ssa_build_local(func, cfg, dom, liveness, use_def)`.
  - `ssa_value_for_local_get(ssa, node_id)`.
  - `ssa_def_for_local_set(ssa, node_id)`.
  - `ssa_phis_for_block(ssa, block_id)`.
  - `ssa_phi_inputs(ssa, phi_id)`.
  - `ssa_uses_of_value(ssa, value_id)`.
- Invariants / correctness rules:
  - Every `LocalGet` maps to exactly one SSA value.
  - Every SSA value has one defining origin.
  - Phi input counts match predecessor counts under the chosen edge policy.
- Dependencies:
  - IR2 - 170 - Dominators.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
  - IR2 - 230 - SSA Design Policy.
- Exit criteria:
  - Local SSA overlay works for joins, loops, parameters, default-init locals, and `LocalTee`.
- Suggested tests:
  - Diamond local merge phi.
  - Loop-carried local phi.
  - Uninitialized-local use resolves to default-init entry def.

### IR2 - 250 - SSA Destruction
- Goal:
  Lower SSA-driven rewrites back into ordinary local ops inside hot IR.
- Why this slice exists:
  The architecture requires plain hot IR as the optimizer body after SSA-assisted work.
- Concrete deliverables:
  - `src/ir/ssa_destroy.mbt`.
  - `src/ir/ssa_destroy_test.mbt`.
- Detailed implementation tasks:
  - Lower block-entry phis to predecessor copies or structured edge-local copies.
  - Define critical-edge handling policy consistent with structured region editing.
  - Allocate fresh locals when required for safe materialization.
  - Rewrite `LocalGet` uses and insert `LocalSet` nodes as needed.
  - Remove dead local defs created during destruction.
  - Invalidate/rebuild analyses after destruction.
- Required utilities / APIs:
  - `ssa_destroy_into_hot(func, cfg, ssa, policy?)`.
  - `ssa_assign_concrete_locals(ssa, func.locals)`.
  - `ssa_insert_predecessor_copies(func, region_ref, predecessor_block, copies)`.
  - `ssa_rewrite_local_use(func, node_id, local_id)`.
  - `ssa_remove_dead_local_defs(func, dead_nodes)`.
- Invariants / correctness rules:
  - No phi artifacts remain in `HotFunc`.
  - Fresh locals have correct types and metadata.
  - Structured region semantics are preserved during copy insertion.
- Dependencies:
  - IR2 - 100 - Hot IR Region Editing Utilities.
  - IR2 - 150 - CFG Construction.
  - IR2 - 230 - SSA Design Policy.
  - IR2 - 240 - Local SSA Construction.
- Exit criteria:
  - SSA-assisted passes can reliably return to plain hot IR.
- Suggested tests:
  - Diamond phi destruction to predecessor copies.
  - Loop-header phi destruction.
  - Fresh temporary local allocation coverage.

### IR2 - 260 - Analysis Invalidation / Caching
- Goal:
  Provide one shared cache for derived analyses keyed to `HotFunc.revision`.
- Why this slice exists:
  CFG, dominance, liveness, effects, and SSA need safe reuse without stale overlay bugs.
- Concrete deliverables:
  - `src/ir/analysis_cache.mbt`.
  - `src/ir/analysis_cache_test.mbt`.
- Detailed implementation tasks:
  - Define cache entries for CFG, orders, dominators, post-dominators, loop info, use-def, liveness, effects, and SSA.
  - Store `built_at_revision` for each entry.
  - Add typed `get_or_build_*` helpers.
  - Use conservative invalidation on any semantic mutation for v1.
  - Add explicit cache drop/reset helpers.
- Required utilities / APIs:
  - `HotAnalysisCache`.
  - `cache_get_or_build_cfg(cache, func)`.
  - `cache_get_or_build_dom(cache, func)`.
  - `cache_get_or_build_postdom(cache, func)`.
  - `cache_get_or_build_loop_info(cache, func)`.
  - `cache_get_or_build_use_def(cache, func)`.
  - `cache_get_or_build_liveness(cache, func)`.
  - `cache_get_or_build_effects(cache, func)`.
  - `cache_get_or_build_ssa(cache, func)`.
  - `cache_invalidate_all(cache)`.
- Invariants / correctness rules:
  - Cached overlays are never reused across revision changes.
  - Mutation primitives are the only source of revision change.
  - Cache getters build dependencies internally rather than pushing that burden to passes.
- Dependencies:
  - IR2 - 150 - CFG Construction.
  - IR2 - 170 - Dominators.
  - IR2 - 180 - Post-Dominators.
  - IR2 - 190 - Loop Info.
  - IR2 - 200 - Use-Def.
  - IR2 - 210 - Liveness.
  - IR2 - 220 - Effect Summaries.
  - IR2 - 240 - Local SSA Construction.
- Exit criteria:
  - Passes can request derived analyses safely from one cache object.
- Suggested tests:
  - Reuse without mutation.
  - Rebuild after child/root mutation.
  - Reject or rebuild stale overlay use.

### IR2 - 270 - Pipeline Orchestration
- Goal:
  Replace compatibility-only pass execution with the real hot-IR pass manager and optimization pipeline.
- Why this slice exists:
  `src/cmd/cmd.mbt` still routes many pass names through compatibility expansion and no-op execution.
- Concrete deliverables:
  - `src/passes/optimize.mbt`.
  - `src/passes/pass_manager.mbt`.
  - `src/passes/optimize_test.mbt`.
  - `src/cmd/cmd.mbt` rewired to the real pipeline.
- Detailed implementation tasks:
  - Define pass descriptor, pass context, pass result, and analysis requirement metadata.
  - Implement the pipeline sequence `lift -> verify -> run passes -> verify checkpoints -> lower -> optional module validation`.
  - Support optimize/shrink presets and explicit pass lists through one registry.
  - Integrate tracing/timing hooks aligned with `docs/0001-2026-03-10-tracing.md`.
  - Remove the fiction that deleted pass layers execute real work.
- Required utilities / APIs:
  - `run_hot_pipeline(module, options, requested_passes)`.
  - `HotPassDescriptor`.
  - `hot_pass_requires(descriptor)`.
  - `hot_pass_invalidates(descriptor)`.
  - `hot_pass_run(ctx, func)`.
  - `pipeline_verify_checkpoint(policy, func/module)`.
  - `pipeline_trace_hook(pass_name, event, payload)`.
- Invariants / correctness rules:
  - Every hot pass runs on verified hot IR.
  - Analysis invalidation flows through revision/cache semantics.
  - CLI/pass reporting only describes real execution.
- Dependencies:
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 120 - Boundary -> Hot Lifting.
  - IR2 - 130 - Hot -> Boundary Lowering.
  - IR2 - 260 - Analysis Invalidation / Caching.
- Exit criteria:
  - CLI optimize paths call the real hot-IR pass manager.
- Suggested tests:
  - Real pass execution order on a small pipeline.
  - Verification checkpoint policy coverage.
  - Trace markers for hot passes.

### IR2 - 280 - Pass Migration Support
- Goal:
  Provide shared scaffolding and migration rules for porting optimizer passes onto IR2.
- Why this slice exists:
  Future agents need reusable pass helpers and a strict checklist instead of per-pass reinvention.
- Concrete deliverables:
  - `src/passes/pass_common.mbt`.
  - `src/passes/pass_test_helpers.mbt`.
  - Pass-porting checklist doc under `docs/`.
  - `src/passes/pass_common_test.mbt`.
- Detailed implementation tasks:
  - Add helpers for subtree peephole replacement, worklist rewrites, CFG-local rewrites, and SSA-assisted rewrites.
  - Add pass-author helpers for requesting analyses, marking mutation, and verify-before/after flow.
  - Add common dead-node cleanup and use-count predicates.
  - Centralize pass registry/dispatch instead of scattering it across CLI code.
  - Add shared fixture helpers for pass tests.
- Required utilities / APIs:
  - `pass_require_cfg(ctx)`.
  - `pass_require_dom(ctx)`.
  - `pass_require_liveness(ctx)`.
  - `pass_require_ssa(ctx)`.
  - `pass_mark_mutated(ctx, func)`.
  - `pass_replace_node(ctx, func, node_id, new_node)`.
  - `pass_splice_region(ctx, func, region_ref, idx, remove_count, nodes)`.
  - `pass_verify_before_after(ctx, func)`.
- Invariants / correctness rules:
  - Shared helpers only use public mutation/query APIs.
  - Pass descriptors truthfully declare requirements and invalidations.
  - CLI-visible pass ids come from one registry.
- Dependencies:
  - IR2 - 090 - Hot IR Traversal Utilities.
  - IR2 - 100 - Hot IR Region Editing Utilities.
  - IR2 - 200 - Use-Def.
  - IR2 - 220 - Effect Summaries.
  - IR2 - 260 - Analysis Invalidation / Caching.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Future pass ports can start from shared helpers instead of rebuilding boilerplate.
- Suggested tests:
  - Peephole helper mutation/invalidation behavior.
  - Missing-analysis failure behavior.
  - Shared pass harness running through public pipeline code.

### IR2 - 285 - Initial Pass Port Batches
- Goal:
  Define the concrete pass-port batches that will replace the current compatibility/no-op surface.
- Why this slice exists:
  The CLI already exposes pass names and presets; future agents need an explicit port order.
- Concrete deliverables:
  - Pass-batch mapping doc under `docs/`.
  - Pass registry coverage tests.
  - Placeholder or initial pass files under `src/passes/` for batch 1.
- Detailed implementation tasks:
  - Batch 1: hot-query/traversal/effects passes such as `vacuum`, trivial DCE, constant folding, drop/nop cleanup.
  - Batch 2: CFG/use-def/effects passes such as CFG simplification, stronger DCE, unreachable cleanup, branch cleanup.
  - Batch 3: local SSA passes such as copy propagation, local forwarding, dead local cleanup.
  - Batch 4: loop/effect-heavy passes if still desired.
  - Map every currently CLI-visible pass name to one of: real hot pass, boundary-only pass, or remove from CLI/help.
  - Define optimize/shrink preset composition against the new registry.
- Required utilities / APIs:
  - `pass_registry_all()`.
  - `pass_registry_lookup(name)`.
  - `optimize_preset_passes(options)`.
  - `shrink_preset_passes(options)`.
  - `pass_registry_category(name)`.
- Invariants / correctness rules:
  - No pass name remains silently accepted as a no-op once migrated.
  - Presets only expand to implemented or explicitly documented boundary-only behavior.
- Dependencies:
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 280 - Pass Migration Support.
- Exit criteria:
  - There is an explicit registry and batch plan for every user-visible pass name/preset.
- Suggested tests:
  - Registry lookup for implemented vs removed names.
  - Optimize/shrink preset expansion coverage.
  - No-op placeholder rejection for names marked real.

## v0.2.0 Backlog

### IR2 - 290 - Tests / Fixtures / Golden Coverage
- Goal:
  Build the shared test harness and golden coverage for hot IR, analyses, and pass execution.
- Why this slice exists:
  The IR2 rebuild spans lift/lower, CFG, dataflow, SSA, and passes; coverage needs a dedicated shared layer.
- Concrete deliverables:
  - `src/ir/test_helpers.mbt`.
  - Adjacent tests for every new `src/ir` and `src/passes` module.
  - Golden dump fixtures for CFG, dominance, liveness, SSA, and pass traces.
  - IR2 test matrix doc under `docs/`.
- Detailed implementation tasks:
  - Add fixture builders from boundary WAT/WASM or direct hot builders.
  - Add dump comparators for CFG, dominance tree, loop info, use-def, liveness, and SSA overlays.
  - Add roundtrip coverage for untouched and mutated hot functions.
  - Add negative verification corruption tests for every structural invariant family.
  - Add pass harness tests through the real registry and pipeline.
- Required utilities / APIs:
  - `ir_test_build_hot_from_wat` or equivalent.
  - `ir_test_assert_verify_and_lower`.
  - `ir_test_dump_cfg`.
  - `ir_test_dump_dom`.
  - `ir_test_dump_ssa`.
  - `ir_test_run_pass`.
- Invariants / correctness rules:
  - Golden outputs are deterministic.
  - Tests use public APIs, not deleted compatibility paths.
- Dependencies:
  - IR2 - 110 - Hot IR Verification Utilities.
  - IR2 - 120 - Boundary -> Hot Lifting.
  - IR2 - 130 - Hot -> Boundary Lowering.
  - IR2 - 150 - CFG Construction.
  - IR2 - 170 - Dominators.
  - IR2 - 240 - Local SSA Construction.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Shared fixture helpers and golden dump coverage exist across the new architecture.
- Suggested tests:
  - CFG/dominance golden dump.
  - Mutated hot roundtrip through lower + validation.
  - Real pipeline regression on representative example modules.

### IR2 - 300 - Performance Instrumentation and Profiling Support
- Goal:
  Add timers, allocation counters, traversal counters, debug dumps, and validation checkpoints for IR2 work.
- Why this slice exists:
  The rebuilt optimizer will add many overlays and rebuild opportunities; performance needs visibility early.
- Concrete deliverables:
  - `src/ir/perf.mbt` or `src/passes/perf.mbt`.
  - Instrumentation tests.
  - Pipeline trace/timing integration.
- Detailed implementation tasks:
  - Add per-pass timing hooks around lift, analysis build, pass run, verify checkpoints, lower, and final validation.
  - Add counters for node allocs, child-span allocs, side-table allocs, region splices, CFG builds, dataflow builds, and traversal visits.
  - Add optional before/after debug dumps gated by options.
  - Add validation checkpoint reporting.
  - Keep instrumentation overhead low when disabled.
- Required utilities / APIs:
  - `perf_start_timer(name)`.
  - `perf_stop_timer(name)`.
  - `perf_count_node_alloc()`.
  - `perf_count_child_span_alloc()`.
  - `perf_count_cfg_build()`.
  - `perf_count_dataflow_build(name)`.
  - `perf_dump_hot_func(func, options)`.
  - `perf_dump_cfg(cfg, options)`.
  - `perf_validation_checkpoint(name)`.
- Invariants / correctness rules:
  - Instrumentation is semantically inert.
  - Trace keys and pass names are stable.
- Dependencies:
  - IR2 - 070 - Hot IR Direct Mutation Primitives.
  - IR2 - 150 - CFG Construction.
  - IR2 - 260 - Analysis Invalidation / Caching.
  - IR2 - 270 - Pipeline Orchestration.
- Exit criteria:
  - Optimize runs can report pass and analysis timing plus key allocation counters.
- Suggested tests:
  - Counter increments on node allocation and CFG build.
  - Timing/checkpoint trace lines present in a small run.
  - Debug dumps remain opt-in.

### IR2 - 310 - Dead Code / Old Abstraction Cleanup
- Goal:
  Remove stale compatibility shims, dead public claims, and obsolete optimizer naming once IR2 replaces them.
- Why this slice exists:
  Current docs and command comments still carry compatibility/no-op language tied to deleted layers.
- Concrete deliverables:
  - `src/cmd/cmd.mbt` cleaned of obsolete no-op optimizer paths.
  - README/package map/help text aligned with the real IR2 surface.
  - Cleanup regression tests.
- Detailed implementation tasks:
  - Remove or rewrite compatibility expansion and no-op execution shims once real pass paths exist.
  - Remove stale docs/help text implying old explicit pass flags still do work when they do not.
  - Remove dead exports/imports tied to deleted recursive optimizer bodies.
  - Review `.mbti` diffs and public package descriptions.
  - Update `agent-todo.md` as slices land.
- Required utilities / APIs:
  - Registry-backed CLI/help generation.
  - README/API sync checks.
  - Repository grep/assert tests for forbidden stale names.
- Invariants / correctness rules:
  - Public docs and CLI help only describe real current behavior.
  - Cleanup never hides failures by deleting tests.
- Dependencies:
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 285 - Initial Pass Port Batches.
- Exit criteria:
  - No-op compatibility execution paths are gone or narrowed to explicit boundary-only behavior.
- Suggested tests:
  - CLI pass resolution uses the real registry.
  - README/API sync alignment.
  - Forbidden stale-name repository assertions.

### IR2 - 320 - Documentation / ADR / Handoff Notes
- Goal:
  Leave the repository with canonical IR2 planning, ADRs, and backlog references so future agents can continue slice by slice.
- Why this slice exists:
  This migration is explicitly a planning and handoff task and needs stable in-repo execution notes.
- Concrete deliverables:
  - Main IR2 plan doc under `docs/`.
  - CFG contract ADR.
  - SSA policy ADR.
  - Updated `agent-todo.md` and `src/ir/README.md` as implementation lands.
- Detailed implementation tasks:
  - Save the canonical IR2 execution plan in `docs/` using the next serial.
  - Cross-link the main plan doc to CFG and SSA ADRs.
  - Keep `agent-todo.md` active-only and slice-id driven.
  - Add a short “next slice order” and “minimum validation per slice” section to the docs plan.
  - Keep `agent-lost-and-found.md` local-only and uncommitted.
- Required utilities / APIs:
  - `bun validate readme-api-sync`.
  - Docs serial naming convention helpers/process.
- Invariants / correctness rules:
  - The `docs/` plan becomes canonical handoff material.
  - `agent-todo.md` stays active-only backlog, not historical log.
  - Public docs do not overclaim optimizer behavior.
- Dependencies:
  - IR2 - 000 - Architecture Rules.
  - IR2 - 140 - CFG Contract and Block Boundary Rules.
  - IR2 - 230 - SSA Design Policy.
  - IR2 - 270 - Pipeline Orchestration.
  - IR2 - 310 - Dead Code / Old Abstraction Cleanup.
- Exit criteria:
  - Repo contains canonical IR2 handoff docs and active backlog references.
- Suggested tests:
  - `bun validate readme-api-sync`.
  - Docs naming-convention check.
  - Manual or scripted backlog-format check referencing active slice ids only.
