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
fn ssa_nomerge_has_loop_param_control(func : @ir.HotFunc) -> Bool {
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
  if ssa_nomerge_has_loop_param_control(func) ||
    ssa_nomerge_has_dropped_local_increment(func) {
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
