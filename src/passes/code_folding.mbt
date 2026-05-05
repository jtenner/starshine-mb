///|
pub fn code_folding_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("code-folding", invalidates=[
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
pub fn code_folding_summary() -> String {
  "Hoist identical void code tails out of matching structured control arms."
}

///|
fn code_folding_node_is_void(func : @ir.HotFunc, node_id : Int) -> Bool {
  node_id >= 0 &&
  @ir.hot_node_is_live(func, node_id) &&
  @ir.hot_type_result_arity(func, @ir.hot_node_get(func, node_id).ty) == 0
}

///|
fn code_folding_node_has_control_or_exit(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    _ => {
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        if code_folding_node_has_control_or_exit(
            func,
            @ir.hot_child_get(func, node_id, slot),
          ) {
          return true
        }
      }
      false
    }
  }
}

///|
fn code_folding_nodes_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
) -> Bool {
  if left_id == right_id {
    return true
  }
  if left_id < 0 ||
    right_id < 0 ||
    !@ir.hot_node_is_live(func, left_id) ||
    !@ir.hot_node_is_live(func, right_id) {
    return false
  }
  let left = @ir.hot_node_get(func, left_id)
  let right = @ir.hot_node_get(func, right_id)
  if left.op != right.op ||
    left.ty != right.ty ||
    left.flags != right.flags ||
    left.imm1 != right.imm1 ||
    left.child_count != right.child_count {
    return false
  }
  match left.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull =>
      if @ir.hot_const_get(func, left.imm0) !=
        @ir.hot_const_get(func, right.imm0) {
        return false
      }
    _ => if left.imm0 != right.imm0 { return false }
  }
  for slot = 0; slot < left.child_count; slot = slot + 1 {
    if !code_folding_nodes_equal(
        func,
        @ir.hot_child_get(func, left_id, slot),
        @ir.hot_child_get(func, right_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_region_prefix_has_exit(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  end_idx : Int,
) -> Bool {
  for idx = 0; idx < end_idx; idx = idx + 1 {
    if code_folding_node_has_control_or_exit(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return true
    }
  }
  false
}

///|
fn code_folding_common_void_suffix_len(
  func : @ir.HotFunc,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef,
) -> Int {
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  let limit = if then_count < else_count { then_count } else { else_count }
  let mut count = 0
  while count < limit {
    let then_id = @ir.hot_region_get(func, then_ref, then_count - 1 - count)
    let else_id = @ir.hot_region_get(func, else_ref, else_count - 1 - count)
    if !code_folding_node_is_void(func, then_id) ||
      code_folding_node_has_control_or_exit(func, then_id) ||
      code_folding_node_has_control_or_exit(func, else_id) ||
      !code_folding_nodes_equal(func, then_id, else_id) {
      break
    }
    count += 1
  }
  count
}

///|
fn code_folding_node_always_exits(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable => true
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      code_folding_node_always_exits(func, @ir.hot_child_get(func, node_id, 0))
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for i = 0; i < @ir.hot_region_root_count(func, body_ref); i = i + 1 {
        if code_folding_node_always_exits(
            func,
            @ir.hot_region_get(func, body_ref, i),
          ) {
          return true
        }
      }
      false
    }
    @ir.HotOp::If => {
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(ref_) => ref_
        None => return false
      }
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      let then_count = @ir.hot_region_root_count(func, then_ref)
      let else_count = @ir.hot_region_root_count(func, else_ref)
      if then_count == 0 || else_count == 0 {
        false
      } else {
        let mut then_exits = false
        for i = 0; i < then_count; i = i + 1 {
          if code_folding_node_always_exits(
              func,
              @ir.hot_region_get(func, then_ref, i),
            ) {
            then_exits = true
          }
        }
        let mut else_exits = false
        for i = 0; i < else_count; i = i + 1 {
          if code_folding_node_always_exits(
              func,
              @ir.hot_region_get(func, else_ref, i),
            ) {
            else_exits = true
          }
        }
        then_exits && else_exits
      }
    }
    _ => false
  }
}

///|
fn code_folding_try_flatten_exiting_block_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if !code_folding_node_always_exits(func, block_id) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  let mut unreachable_idx = -1
  for body_idx = 0; body_idx < body_count; body_idx = body_idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, body_idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Unreachable => {
        if unreachable_idx >= 0 {
          return false
        }
        unreachable_idx = body_idx
      }
      _ => ()
    }
  }
  if unreachable_idx != 0 && unreachable_idx != body_count - 1 {
    return false
  }
  let roots : Array[Int] = []
  let append_body_root = fn(body_idx : Int) -> Bool {
    let root_id = @ir.hot_region_get(func, body_ref, body_idx)
    if body_idx != unreachable_idx &&
      @ir.hot_node_result_arity(func, root_id) > 1 {
      return false
    }
    roots.push(root_id)
    true
  }
  if unreachable_idx == 0 {
    for body_idx = 1; body_idx < body_count; body_idx = body_idx + 1 {
      if !append_body_root(body_idx) {
        return false
      }
    }
    if !append_body_root(0) {
      return false
    }
  } else {
    for body_idx = 0; body_idx < body_count; body_idx = body_idx + 1 {
      if !append_body_root(body_idx) {
        return false
      }
    }
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, roots))
  @ir.hot_region_replace_body(func, body_ref, [])
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="flatten-exiting-block",
  )
  true
}

///|
fn code_folding_try_remove_unreachable_after_exit_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx <= 0 {
    return false
  }
  let node_id = @ir.hot_region_get(func, region_ref, idx)
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable => ()
    _ => return false
  }
  let prev_id = @ir.hot_region_get(func, region_ref, idx - 1)
  if !code_folding_node_always_exits(func, prev_id) {
    return false
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, []))
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="unreachable-after-exit",
  )
  true
}

///|
fn code_folding_try_remove_drop_unreachable_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let node_id = @ir.hot_region_get(func, region_ref, idx)
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::Unreachable => {
      ignore(pass_splice_region(ctx, func, region_ref, idx, 1, [child_id]))
      pipeline_trace_hook(
        ctx.trace,
        ctx.descriptor.name,
        "mutated",
        payload="drop-unreachable",
      )
      true
    }
    _ => false
  }
}

///|
fn code_folding_try_fold_if_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_type_result_arity(func, if_node.ty) != 0 {
    return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(ref_) => ref_
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let suffix_len = code_folding_common_void_suffix_len(func, then_ref, else_ref)
  if suffix_len == 0 {
    return false
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  let then_start = then_count - suffix_len
  let else_start = else_count - suffix_len
  if code_folding_region_prefix_has_exit(func, then_ref, then_start) ||
    code_folding_region_prefix_has_exit(func, else_ref, else_start) {
    return false
  }

  let hoisted = pass_splice_region(
    ctx,
    func,
    then_ref,
    then_start,
    suffix_len,
    [],
  )
  ignore(pass_splice_region(ctx, func, else_ref, else_start, suffix_len, []))
  if then_start == 0 && else_start == 0 {
    let condition = @ir.hot_child_get(func, if_id, 0)
    let drop_condition = @ir.hot_build_drop(func, condition)
    let replacement = [drop_condition]
    for node_id in hoisted {
      replacement.push(node_id)
    }
    ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
  } else {
    ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, hoisted))
  }
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="if-common-suffix",
  )
  true
}

///|
fn code_folding_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      if code_folding_try_remove_drop_unreachable_at_region(
          ctx, func, region_ref, idx,
        ) ||
        code_folding_try_flatten_exiting_block_at_region(
          ctx, func, region_ref, idx,
        ) ||
        code_folding_try_remove_unreachable_after_exit_at_region(
          ctx, func, region_ref, idx,
        ) {
        changed = true
      }
      let current_id = @ir.hot_region_get(func, region_ref, idx)
      match @ir.hot_node_get(func, current_id).op {
        @ir.HotOp::Block | @ir.HotOp::Loop =>
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
            ) {
            changed = true
          }
        @ir.HotOp::If => {
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_then_ref(func, current_id),
            ) {
            changed = true
          }
          match @ir.hot_region_else_ref(func, current_id) {
            Some(else_ref) =>
              if code_folding_visit_region(ctx, func, else_ref) {
                changed = true
              }
            None => ()
          }
          if code_folding_try_fold_if_at_region(ctx, func, region_ref, idx) {
            changed = true
          }
        }
        @ir.HotOp::Try | @ir.HotOp::TryTable =>
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
            ) {
            changed = true
          }
        _ => ()
      }
    }
    idx += 1
  }
  changed
}

///|
pub fn code_folding_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if code_folding_visit_region(ctx, func, @ir.HotRegionRef::root()) {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
