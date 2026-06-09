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
fn ssa_nomerge_has_dropped_local_increment(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Drop => {
        if @ir.hot_child_count(func, node_id) != 1 {
          continue
        }
        let value_id = @ir.hot_child_get(func, node_id, 0)
        if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
          continue
        }
        let value_node = @ir.hot_node_get(func, value_id)
        match value_node.op {
          @ir.HotOp::Binary =>
            match @ir.hot_node_exact_instr(func, value_id) {
              Some(@lib.Instruction::I32Add) => {
                let lhs_id = @ir.hot_child_get(func, value_id, 0)
                let rhs_id = @ir.hot_child_get(func, value_id, 1)
                if lhs_id >= 0 &&
                  rhs_id >= 0 &&
                  @ir.hot_node_is_live(func, lhs_id) &&
                  @ir.hot_node_is_live(func, rhs_id) {
                  match
                    (
                      @ir.hot_node_get(func, lhs_id).op,
                      @ir.hot_node_get(func, rhs_id).op,
                    ) {
                    (@ir.HotOp::LocalGet, @ir.HotOp::Const) =>
                      match
                        @ir.hot_const_get(
                          func,
                          @ir.hot_node_get(func, rhs_id).imm0,
                        ) {
                        @ir.HotConstPayload::I32Const(@lib.I32(1)) =>
                          return true
                        _ => ()
                      }
                    _ => ()
                  }
                }
              }
              _ => ()
            }
          _ => ()
        }
      }
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
fn ssa_nomerge_has_nested_cfg_control_node(
  func : @ir.HotFunc,
  node_id : @ir.NodeId,
  is_region_root : Bool,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if !is_region_root &&
    (
      @ir.hot_is_control_node(func, node_id) ||
      @ir.hot_is_terminator_node(func, node_id)
    ) {
    return ssa_nomerge_subtree_has_local_or_terminator(func, node_id)
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
        func, child_id, child_is_region_root,
      ) {
      return true
    }
  }
  false
}

///|
fn ssa_nomerge_has_nested_cfg_sensitive_control(func : @ir.HotFunc) -> Bool {
  // The current SSA/no-merge local model can miss reads inside nested control
  // value regions. Keep those shapes unchanged until nested liveness is exact.
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if ssa_nomerge_has_nested_cfg_control_node(
        func,
        @ir.hot_root_get(func, root_idx),
        true,
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
  // Typed loop params are loop-carried control values on the wasm stack, not body
  // locals. HOT represents them as the Loop node's param-prefix children and as
  // branch operands on backedges (`br` / `br_if` / `br_table` children), with
  // `HotLabelInfo.branch_arity` recording the payload count.
  //
  // SSA v1's local overlay models only `LocalGet` / `LocalSet` / `LocalTee`
  // reaching definitions. It does not treat loop-param value flow as local defs,
  // and destruction only inserts predecessor copies for overlay phis on normal
  // CFG edges — not wasm branch operands that re-enter typed loop headers.
  //
  // Rewriting locals around typed loops without loop-param-aware liveness,
  // use-def, phi placement, rename, destroy, and lower can conflate a local SSA
  // version with the loop-carried param ABI. Fail closed until that stack is
  // proven together; regression tests lock the no-mutation contract.
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Loop =>
        match @ir.hot_type_get(func, node.ty) {
          @ir.HotTypeInfo::BlockResultResolved(_, params, _) =>
            if params.length() > 0 {
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
    ssa_nomerge_has_dropped_local_increment(func) ||
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
