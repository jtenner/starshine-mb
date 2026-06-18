///|
pub fn ssa_nomerge_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("ssa-nomerge", invalidates=[
    @ir.HotAnalysis::cfg(),
    @ir.HotAnalysis::dominance(),
    @ir.HotAnalysis::liveness(),
    @ir.HotAnalysis::use_def(),
    @ir.HotAnalysis::effects(),
    @ir.HotAnalysis::loop_info(),
    @ir.HotAnalysis::ssa(),
  ])
}

///|
pub fn ssa_nomerge_summary() -> String {
  "Freshen single-source locals and materialize defaults while preserving merge traffic."
}

///|
/// Planned local-write action for Binaryen-style `ssa-nomerge` rewriting.
pub(all) enum SsaNoMergeWriteDecision {
  Freshen(@ir.LocalId)
  KeepCanonical
} derive(Eq, Debug)

///|
/// Planned local-get action for Binaryen-style `ssa-nomerge` rewriting.
pub(all) enum SsaNoMergeGetDecision {
  Retarget(@ir.LocalId)
  MaterializeDefault
  KeepCanonical
} derive(Eq, Debug)

///|
/// Analysis-only write rewrite entry. This does not mutate the function.
pub(all) struct SsaNoMergeWriteRewrite {
  write_id : @ir.NodeId
  original_local : @ir.LocalId
  influenced_gets : Array[@ir.NodeId]
  decision : SsaNoMergeWriteDecision
} derive(Eq, Debug)

///|
/// Analysis-only get rewrite entry. This does not mutate the function.
pub(all) struct SsaNoMergeGetRewrite {
  get_id : @ir.NodeId
  original_local : @ir.LocalId
  decision : SsaNoMergeGetDecision
} derive(Eq, Debug)

///|
/// Analysis-only no-merge rewrite plan built from `HotLocalGraph` facts.
pub(all) struct SsaNoMergeRewritePlan {
  write_rewrites : Array[SsaNoMergeWriteRewrite]
  get_rewrites : Array[SsaNoMergeGetRewrite]
} derive(Eq, Debug)

///|
fn ssa_nomerge_fresh_local_for_write(
  writes : Array[SsaNoMergeWriteRewrite],
  write_id : @ir.NodeId,
) -> @ir.LocalId? {
  for rewrite in writes {
    if rewrite.write_id == write_id {
      match rewrite.decision {
        SsaNoMergeWriteDecision::Freshen(local_id) => return Some(local_id)
        SsaNoMergeWriteDecision::KeepCanonical => return None
      }
    }
  }
  None
}

///|
fn ssa_nomerge_plan_get_decision(
  graph : @ir.HotLocalGraph,
  writes : Array[SsaNoMergeWriteRewrite],
  get_id : @ir.NodeId,
) -> SsaNoMergeGetDecision {
  if @ir.local_graph_get_is_merge(graph, get_id) {
    return SsaNoMergeGetDecision::KeepCanonical
  }
  let sources = @ir.local_graph_reaching_sources_for_get(graph, get_id)
  if sources.length() != 1 {
    return SsaNoMergeGetDecision::KeepCanonical
  }
  match sources[0] {
    @ir.HotLocalGraphSource::SetSource(write_id) =>
      match ssa_nomerge_fresh_local_for_write(writes, write_id) {
        Some(local_id) => SsaNoMergeGetDecision::Retarget(local_id)
        None => SsaNoMergeGetDecision::KeepCanonical
      }
    @ir.HotLocalGraphSource::EntrySource(local_id) =>
      if @ir.local_graph_entry_source_has_legal_default(graph, local_id) {
        SsaNoMergeGetDecision::MaterializeDefault
      } else {
        SsaNoMergeGetDecision::KeepCanonical
      }
  }
}

///|
fn ssa_nomerge_note_loop_local_access(
  first_accesses : Array[Int],
  local_id : @ir.LocalId,
  access : Int,
) -> Unit {
  if local_id >= 0 &&
    local_id < first_accesses.length() &&
    first_accesses[local_id] == 0 {
    first_accesses[local_id] = access
  }
}

///|
fn ssa_nomerge_collect_loop_body_accesses_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  writes : @bitset.BitSet,
  first_accesses : Array[Int],
  visited : @bitset.BitSet,
) -> Unit {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    ssa_nomerge_collect_loop_body_accesses_in_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      writes,
      first_accesses,
      visited,
    )
  }
}

///|
fn ssa_nomerge_collect_loop_body_accesses_in_node(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  writes : @bitset.BitSet,
  first_accesses : Array[Int],
  visited : @bitset.BitSet,
) -> Unit {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    (node_id < visited.length() && visited[node_id]) {
    return
  }
  if node_id < visited.length() {
    visited[node_id] = true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet =>
      ssa_nomerge_note_loop_local_access(first_accesses, node.imm0, 1)
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    ssa_nomerge_collect_loop_body_accesses_in_node(
      func,
      @ir.hot_child_get(func, node_id, slot),
      writes,
      first_accesses,
      visited,
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      ssa_nomerge_collect_loop_body_accesses_in_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        writes,
        first_accesses,
        visited,
      )
    @ir.HotOp::If => {
      ssa_nomerge_collect_loop_body_accesses_in_region(
        func,
        @ir.hot_region_then_ref(func, node_id),
        writes,
        first_accesses,
        visited,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_nomerge_collect_loop_body_accesses_in_region(
            func, region_ref, writes, first_accesses, visited,
          )
        None => ()
      }
    }
    _ => ()
  }
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      if node.imm0 >= 0 && node.imm0 < writes.length() {
        writes[node.imm0] = true
      }
      ssa_nomerge_note_loop_local_access(first_accesses, node.imm0, 2)
    }
    _ => ()
  }
}

///|
fn ssa_nomerge_mark_loop_carried_locals_in_node(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  preserve_locals : @bitset.BitSet,
  visited : @bitset.BitSet,
) -> Unit {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    (node_id < visited.length() && visited[node_id]) {
    return
  }
  if node_id < visited.length() {
    visited[node_id] = true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Loop => {
      let local_count = @ir.hot_local_count(func)
      let loop_writes = @bitset.BitSet::new(local_count)
      let first_accesses = Array::make(local_count, 0)
      ssa_nomerge_collect_loop_body_accesses_in_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        loop_writes,
        first_accesses,
        @bitset.BitSet::new(@ir.hot_node_count(func)),
      )
      for local_id = 0; local_id < local_count; local_id = local_id + 1 {
        if loop_writes[local_id] && first_accesses[local_id] == 1 {
          preserve_locals[local_id] = true
        }
      }
    }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    ssa_nomerge_mark_loop_carried_locals_in_node(
      func,
      @ir.hot_child_get(func, node_id, slot),
      preserve_locals,
      visited,
    )
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      ssa_nomerge_mark_loop_carried_locals_in_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        preserve_locals,
        visited,
      )
    @ir.HotOp::If => {
      ssa_nomerge_mark_loop_carried_locals_in_region(
        func,
        @ir.hot_region_then_ref(func, node_id),
        preserve_locals,
        visited,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(region_ref) =>
          ssa_nomerge_mark_loop_carried_locals_in_region(
            func, region_ref, preserve_locals, visited,
          )
        None => ()
      }
    }
    _ => ()
  }
}

///|
fn ssa_nomerge_mark_loop_carried_locals_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  preserve_locals : @bitset.BitSet,
  visited : @bitset.BitSet,
) -> Unit {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    ssa_nomerge_mark_loop_carried_locals_in_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      preserve_locals,
      visited,
    )
  }
}

///|
pub fn ssa_nomerge_loop_carried_canonical_writes(
  func : @ir.HotFunc,
) -> @bitset.BitSet {
  let preserve_writes = @bitset.BitSet::new(@ir.hot_node_count(func))
  let preserve_locals = @bitset.BitSet::new(@ir.hot_local_count(func))
  let visited = @bitset.BitSet::new(@ir.hot_node_count(func))
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    ssa_nomerge_mark_loop_carried_locals_in_node(
      func,
      @ir.hot_root_get(func, root_idx),
      preserve_locals,
      visited,
    )
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
          if node.imm0 >= 0 &&
            node.imm0 < preserve_locals.length() &&
            preserve_locals[node.imm0] {
            preserve_writes[node_id] = true
          }
        _ => ()
      }
    }
  }
  preserve_writes
}

///|
fn ssa_nomerge_func_has_plain_br(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Br => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn ssa_nomerge_has_local_get(
  func : @ir.HotFunc,
  local_id : @ir.LocalId,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      let node = @ir.hot_node_get(func, node_id)
      match node.op {
        @ir.HotOp::LocalGet => if node.imm0 == local_id { return true }
        _ => ()
      }
    }
  }
  false
}

///|
fn ssa_nomerge_write_is_branch_carried_param_tee(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalTee =>
      node.imm0 >= 0 &&
      node.imm0 < @ir.hot_param_count(func) &&
      ssa_nomerge_func_has_plain_br(func) &&
      ssa_nomerge_has_local_get(func, node.imm0)
    _ => false
  }
}

///|
/// Build the analysis-only no-merge rewrite plan from LocalGraph facts.
pub fn ssa_nomerge_build_rewrite_plan(
  func : @ir.HotFunc,
  graph : @ir.HotLocalGraph,
) -> SsaNoMergeRewritePlan {
  let writes : Array[SsaNoMergeWriteRewrite] = []
  let loop_carried_canonical_writes = ssa_nomerge_loop_carried_canonical_writes(
    func,
  )
  let mut next_fresh_local = @ir.hot_local_count(func)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) ||
      !@ir.local_graph_node_is_write(graph, node_id) {
      continue
    }
    let decision = if ssa_nomerge_write_is_branch_carried_param_tee(
        func, node_id,
      ) ||
      (
        node_id < loop_carried_canonical_writes.length() &&
        loop_carried_canonical_writes[node_id] &&
        @ir.local_graph_write_has_merge_influences(graph, node_id)
      ) {
      SsaNoMergeWriteDecision::KeepCanonical
    } else if @ir.local_graph_write_is_no_merge_freshenable(graph, node_id) {
      let fresh_local = next_fresh_local
      next_fresh_local = next_fresh_local + 1
      SsaNoMergeWriteDecision::Freshen(fresh_local)
    } else {
      SsaNoMergeWriteDecision::KeepCanonical
    }
    writes.push({
      write_id: node_id,
      original_local: @ir.local_graph_write_local_id(graph, node_id),
      influenced_gets: @ir.local_graph_influenced_gets_for_write(graph, node_id),
      decision,
    })
  }
  let gets : Array[SsaNoMergeGetRewrite] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet =>
        gets.push({
          get_id: node_id,
          original_local: node.imm0,
          decision: ssa_nomerge_plan_get_decision(graph, writes, node_id),
        })
      _ => ()
    }
  }
  { write_rewrites: writes, get_rewrites: gets }
}

///|
fn ssa_nomerge_has_local_writes(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_is_control_region_slot(op : @ir.HotOp, slot : Int) -> Bool {
  match op {
    @ir.HotOp::Block | @ir.HotOp::Loop => true
    @ir.HotOp::If => slot == 1 || slot == 2
    @ir.HotOp::Try | @ir.HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
fn ssa_nomerge_subtree_has_local_or_terminator(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if @ir.hot_is_terminator_node(func, node_id) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet | @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
      return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if ssa_nomerge_subtree_has_local_or_terminator(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_nomerge_is_simple_nested_value_block_operand(
  func : @ir.HotFunc,
  parent_id : @ir.NodeId,
  slot : Int,
  child_id : @ir.NodeId,
) -> Bool {
  @ir.ssa_simple_drop_value_block_allowed(func, parent_id, slot, child_id)
}

///|
fn ssa_nomerge_is_simple_nested_result_if_operand(
  func : @ir.HotFunc,
  parent_id : @ir.NodeId,
  slot : Int,
  child_id : @ir.NodeId,
) -> Bool {
  @ir.ssa_simple_drop_result_if_allowed(func, parent_id, slot, child_id)
}

///|
fn ssa_nomerge_if_in_supported_drop_result_if(
  func : @ir.HotFunc,
  if_id : @ir.NodeId,
) -> Bool {
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Drop =>
        if @ir.hot_child_get(func, node_id, 0) == if_id &&
          ssa_nomerge_is_simple_nested_result_if_operand(
            func, node_id, 0, if_id,
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_is_supported_result_if_condition_value_block(
  func : @ir.HotFunc,
  parent_id : @ir.NodeId,
  parent_slot : Int,
  block_id : @ir.NodeId,
) -> Bool {
  if parent_slot != 0 ||
    parent_id < 0 ||
    block_id < 0 ||
    !@ir.hot_node_is_live(func, parent_id) ||
    !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, parent_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_child_get(func, parent_id, 0) != block_id {
    return false
  }
  @ir.ssa_simple_condition_value_block_allowed(func, block_id) &&
  ssa_nomerge_if_in_supported_drop_result_if(func, parent_id)
}

///|
fn ssa_nomerge_nested_cfg_node_is_fail_closed(
  func : @ir.HotFunc,
  parent_id : @ir.NodeId,
  parent_slot : Int,
  node_id : @ir.NodeId,
) -> Bool {
  if ssa_nomerge_is_simple_nested_value_block_operand(
      func, parent_id, parent_slot, node_id,
    ) {
    return false
  }
  if ssa_nomerge_is_simple_nested_result_if_operand(
      func, parent_id, parent_slot, node_id,
    ) {
    return false
  }
  if ssa_nomerge_is_supported_result_if_condition_value_block(
      func, parent_id, parent_slot, node_id,
    ) {
    return false
  }
  ssa_nomerge_subtree_has_local_or_terminator(func, node_id)
}

///|
fn ssa_nomerge_has_nested_cfg_control_node(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  is_region_root : Bool,
  parent_id : @ir.NodeId,
  parent_slot : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if !is_region_root &&
    (
      @ir.hot_is_control_node(func, node_id) ||
      @ir.hot_is_terminator_node(func, node_id)
    ) &&
    ssa_nomerge_nested_cfg_node_is_fail_closed(
      func, parent_id, parent_slot, node_id,
    ) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    let child_is_region_root = @ir.hot_is_control_node(func, node_id) &&
      ssa_nomerge_is_control_region_slot(node.op, slot)
    if ssa_nomerge_has_nested_cfg_control_node(
        func, child_id, child_is_region_root, node_id, slot,
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_nomerge_has_nested_cfg_sensitive_control(func : @ir.HotFunc) -> Bool {
  // Operand-nested straight-line `drop(block (result t) ...)` value blocks are
  // allowed via `ssa_simple_drop_value_block_allowed(...)` and inline rename in
  // `ssa_local_visit_node`. Operand-nested `drop(if (result t) ...)` with a
  // single scalar numeric result, straight-line arms, and a straight-line
  // condition (including condition-local set/tee or one simple `block (result i32)`
  // when CFG-backed rename/use-def inline-visit the predecessor block before both
  // arms) is allowed via `ssa_simple_drop_result_if_allowed(...)` and CFG-backed
  // rename. Branches and nested control in the condition stay fail-closed. All other
  // nested value-control regions can still
  // contain local reads/writes and terminators outside SSA v1's region-root
  // model; fail closed for those shapes.
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if ssa_nomerge_has_nested_cfg_control_node(
        func,
        @ir.hot_root_get(func, root_idx),
        true,
        -1,
        -1,
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_nomerge_has_exceptional_flow(func : @ir.HotFunc) -> Bool {
  // SSA v1 is normal-flow-only. The CFG records `ExceptionalEdge` for try/try_table
  // and throw-family ops, but liveness, dominators, phi placement, rename, and destroy
  // ignore exceptional predecessors. Fail closed here (not feature support): rewriting
  // locals while skipping those edges can drop writes that must reach catch continuations.
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Try
      | @ir.HotOp::TryTable
      | @ir.HotOp::Throw
      | @ir.HotOp::ThrowRef
      | @ir.HotOp::Rethrow
      | @ir.HotOp::Delegate
      | @ir.HotOp::Catch
      | @ir.HotOp::CatchAll => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_has_loop_param_control(func : @ir.HotFunc) -> Bool {
  // Typed loop params/results are loop-carried control values on the wasm stack,
  // not body locals. HOT represents params as the Loop node's param-prefix
  // children and branch operands on backedges (`br` / `br_if` / `br_table`), with
  // `HotLabelInfo.branch_arity` recording the payload count. Result loops also
  // carry stack values across their branch/continuation ABI even when the loop has
  // no explicit params.
  //
  // SSA v1's local overlay models only `LocalGet` / `LocalSet` / `LocalTee`
  // reaching definitions. It does not treat loop-param/result value flow as local
  // defs, and destruction only inserts predecessor copies for overlay phis on
  // normal CFG edges — not wasm branch operands that re-enter typed loop headers.
  //
  // Rewriting locals around typed loops without loop-param/result-aware liveness,
  // use-def, phi placement, rename, destroy, and lower can conflate a local SSA
  // version with the loop-carried stack ABI or allocate scratch locals for values
  // Binaryen keeps in the canonical local. Fail closed until that stack is proven
  // together; regression tests lock the no-mutation contract.
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Loop =>
        match @ir.hot_type_get(func, node.ty) {
          @ir.HotTypeInfo::BlockResult(block_type) =>
            if block_type != @lib.BlockType::void_() {
              return true
            }
          @ir.HotTypeInfo::BlockResultResolved(_, params, results) =>
            if params.length() > 0 || results.length() > 0 {
              return true
            }
          _ => ()
        }
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_has_branch_heavy_void_loop_exit_mesh(func : @ir.HotFunc) -> Bool {
  // Branch-heavy void loop meshes like the sampled `moonbit.gc.free` artifact
  // (`abs=57`) currently make SSA destruction allocate more scratch locals than
  // Binaryen for multi-predecessor branch exits. This is not the typed loop-result
  // ABI gap covered above: these are ordinary void loops with many local-carrying
  // exits. Fail closed for this high-complexity shape until SSA destruction can
  // model/reuse those predecessor copies without adding unproven extra locals.
  if @ir.hot_local_count(func) < 17 {
    return false
  }
  let mut loop_count = 0
  let mut branch_count = 0
  let mut local_write_count = 0
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Loop => loop_count = loop_count + 1
      @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::BrTable =>
        branch_count = branch_count + 1
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
        local_write_count = local_write_count + 1
      _ => ()
    }
  }
  loop_count >= 4 && branch_count >= 5 && local_write_count >= 18
}

///|
fn ssa_nomerge_needs_rewrite(func : @ir.HotFunc, ssa : @ir.HotLocalSsa) -> Bool {
  if ssa.phis.length() != 0 {
    return true
  }
  for origin in ssa.value_origins {
    match origin {
      @ir.HotSsaValueOrigin::LocalSetDef(_)
      | @ir.HotSsaValueOrigin::LocalTeeDef(_) => return true
      _ => ()
    }
  }
  for node_id = 0
      node_id < ssa.local_write_defs.length()
      node_id = node_id + 1 {
    if ssa.local_write_defs[node_id] >= 0 ||
      !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => return true
      _ => ()
    }
  }
  false
}

///|
fn ssa_nomerge_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if !ssa_nomerge_has_local_writes(func) {
    return HotPassResult::unchanged()
  }
  if ssa_nomerge_has_exceptional_flow(func) ||
    ssa_nomerge_has_loop_param_control(func) ||
    ssa_nomerge_has_branch_heavy_void_loop_exit_mesh(func) ||
    ssa_nomerge_has_nested_cfg_sensitive_control(func) {
    return HotPassResult::unchanged()
  }
  let cfg = pass_require_cfg(ctx, func)
  let ssa = pass_require_ssa(ctx, func)
  if !ssa_nomerge_needs_rewrite(func, ssa) {
    return HotPassResult::unchanged()
  }
  let before_revision = @ir.hot_revision_current(func)
  let loop_carried_writes = ssa_nomerge_loop_carried_canonical_writes(func)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if node_id < loop_carried_writes.length() &&
      ssa_nomerge_write_is_branch_carried_param_tee(func, node_id) {
      loop_carried_writes[node_id] = true
    }
  }
  ignore(
    @ir.ssa_destroy_into_hot(
      func,
      cfg,
      ssa,
      preserve_write_nodes=loop_carried_writes,
    ),
  )
  if @ir.hot_revision_current(func) == before_revision {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
