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
  "Untangle hot locals into semi-SSA form and lower overlay phis through predecessor copies."
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
  ignore(@ir.ssa_destroy_into_hot(func, cfg, ssa))
  if @ir.hot_revision_current(func) == before_revision {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
