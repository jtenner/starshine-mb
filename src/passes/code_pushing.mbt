///|
pub fn code_pushing_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("code-pushing", invalidates=[
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
pub fn code_pushing_summary() -> String {
  "Sink safe local computations into the control-flow arm that actually consumes them."
}

///|
fn code_pushing_exact_instr_can_trap(instr : @lib.Instruction?) -> Bool {
  match instr {
    Some(@lib.Instruction::I32DivS)
    | Some(@lib.Instruction::I32DivU)
    | Some(@lib.Instruction::I32RemS)
    | Some(@lib.Instruction::I32RemU)
    | Some(@lib.Instruction::I64DivS)
    | Some(@lib.Instruction::I64DivU)
    | Some(@lib.Instruction::I64RemS)
    | Some(@lib.Instruction::I64RemU) => true
    _ => false
  }
}

///|
fn code_pushing_node_is_movable_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if code_pushing_exact_instr_can_trap(@ir.hot_node_exact_instr(func, node_id)) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let movable_shape = match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract =>
      @ir.effects_is_pure(@ir.effects_for_node(func, node_id))
    @ir.HotOp::GlobalGet => true
    _ => false
  }
  movable_shape
}

///|
fn code_pushing_node_is_global_get(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::GlobalGet => true
    _ => false
  }
}

///|
fn code_pushing_node_is_local_get(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet => true
    _ => false
  }
}

///|
fn code_pushing_effects_safe_to_cross_for_value(mask : UInt) -> Bool {
  (
    mask &
    (
      @ir.EFFECT_MASK_CALL |
      @ir.EFFECT_MASK_GLOBAL_STATE |
      @ir.EFFECT_MASK_MEMORY_WRITE
    )
  ) ==
  0U
}

///|
fn code_pushing_node_safe_to_cross_for_value(
  func : @ir.HotFunc,
  node_id : Int,
  value_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if code_pushing_node_is_global_get(func, value_id) {
    code_pushing_effects_safe_to_cross_for_value(
      @ir.effects_for_node(func, node_id),
    )
  } else if code_pushing_node_is_local_get(func, value_id) {
    let (_, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func,
      node_id,
      @ir.hot_node_get(func, value_id).imm0,
      0,
      0,
    )
    writes == 0
  } else {
    true
  }
}

///|
fn code_pushing_node_writes_local_deep_limited(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  depth : Int,
) -> Bool {
  if depth <= 0 || node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id =>
      return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_pushing_node_writes_local_deep_limited(
        func,
        @ir.hot_child_get(func, node_id, slot),
        local_id,
        depth - 1,
      ) {
      return true
    }
  }
  let region_has_write = fn(region_ref : @ir.HotRegionRef) -> Bool {
    for idx = 0
        idx < @ir.hot_region_root_count(func, region_ref)
        idx = idx + 1 {
      if code_pushing_node_writes_local_deep_limited(
          func,
          @ir.hot_region_get(func, region_ref, idx),
          local_id,
          depth - 1,
        ) {
        return true
      }
    }
    false
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      region_has_write(@ir.hot_region_body_ref(func, node_id))
    @ir.HotOp::If => {
      if region_has_write(@ir.hot_region_then_ref(func, node_id)) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => region_has_write(else_ref)
        None => false
      }
    }
    _ => false
  }
}

///|
fn code_pushing_count_local_gets_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut count = match node.op {
    @ir.HotOp::LocalGet if node.imm0 == local_id => 1
    _ => 0
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    count += code_pushing_count_local_gets_in_node(
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_gets_writes_in_node_bounded(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return (0, 0)
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut gets = match node.op {
    @ir.HotOp::LocalGet if node.imm0 == local_id => 1
    _ => 0
  }
  let mut writes = match node.op {
    @ir.HotOp::LocalSet if node.imm0 == local_id => 1
    @ir.HotOp::LocalTee if node.imm0 == local_id => 1
    _ => 0
  }
  if gets > max_gets || writes > max_writes {
    return (gets, writes)
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let (child_gets, child_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_id,
      max_gets - gets,
      max_writes - writes,
    )
    gets += child_gets
    writes += child_writes
    if gets > max_gets || writes > max_writes {
      break
    }
  }
  (gets, writes)
}

///|
fn code_pushing_count_local_gets_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
) -> Int {
  let mut count = 0
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    count += code_pushing_count_local_gets_in_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      local_id,
    )
  }
  count
}

///|
fn code_pushing_count_local_gets_writes_in_region_prefix_bounded(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
  end_idx : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  let mut gets = 0
  let mut writes = 0
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let stop_idx = if end_idx < root_count { end_idx } else { root_count }
  for idx = 0; idx < stop_idx; idx = idx + 1 {
    let (root_gets, root_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      local_id,
      max_gets - gets,
      max_writes - writes,
    )
    gets += root_gets
    writes += root_writes
    if gets > max_gets || writes > max_writes {
      break
    }
  }
  (gets, writes)
}

///|
fn code_pushing_count_local_gets_writes_in_region_bounded(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  code_pushing_count_local_gets_writes_in_region_prefix_bounded(
    func,
    region_ref,
    local_id,
    @ir.hot_region_root_count(func, region_ref),
    max_gets,
    max_writes,
  )
}

///|
fn code_pushing_count_local_gets_in_if_arms(
  func : @ir.HotFunc,
  if_id : Int,
  local_id : Int,
) -> (Int, Int) {
  let then_gets = code_pushing_count_local_gets_in_region(
    func,
    @ir.hot_region_then_ref(func, if_id),
    local_id,
  )
  let else_gets = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) =>
      code_pushing_count_local_gets_in_region(func, else_ref, local_id)
    None => 0
  }
  (then_gets, else_gets)
}

///|
fn code_pushing_count_total_local_gets_writes_bounded(
  func : @ir.HotFunc,
  local_id : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  code_pushing_count_local_gets_writes_in_region_bounded(
    func,
    @ir.HotRegionRef::root(),
    local_id,
    max_gets,
    max_writes,
  )
}

///|
fn code_pushing_make_local_set_clone(
  func : @ir.HotFunc,
  local_id : Int,
  value_id : Int,
) -> Int {
  @ir.hot_build_local_set(func, local_id, value_id)
}

///|
fn code_pushing_node_has_branch(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_pushing_node_has_branch(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn code_pushing_node_has_unreachable(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unreachable => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_pushing_node_has_unreachable(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn code_pushing_region_has_leading_unreachable_before(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  end_idx : Int,
) -> Bool {
  if end_idx <= 0 || @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let root_id = @ir.hot_region_get(func, region_ref, 0)
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return false
  }
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Unreachable => true
    _ => false
  }
}

///|
fn code_pushing_try_flatten_dead_block_before_unreachable(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  block_idx : Int,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, block_idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let block_has_neighboring_unreachable = if block_idx + 1 < root_count {
    let next_id = @ir.hot_region_get(func, region_ref, block_idx + 1)
    if next_id >= 0 && @ir.hot_node_is_live(func, next_id) {
      match @ir.hot_node_get(func, next_id).op {
        @ir.HotOp::Unreachable => true
        _ => false
      }
    } else {
      false
    }
  } else {
    false
  }
  if !block_has_neighboring_unreachable &&
    !code_pushing_region_has_leading_unreachable_before(
      func, region_ref, block_idx,
    ) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return false
  }
  let mut unreachable_idx = -1
  for idx = 0; idx < body_count; idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Unreachable => {
        if unreachable_idx >= 0 {
          return false
        }
        unreachable_idx = idx
      }
      _ => ()
    }
  }
  if unreachable_idx != 0 && unreachable_idx != body_count - 1 {
    return false
  }
  let replacement : Array[Int] = Array::new(capacity=body_count)
  let append_body_root = fn(idx : Int) -> Bool {
    let root_id = @ir.hot_region_get(func, body_ref, idx)
    if code_pushing_node_has_branch(func, root_id) {
      return false
    }
    if idx != unreachable_idx && @ir.hot_node_result_arity(func, root_id) > 1 {
      return false
    }
    replacement.push(root_id)
    true
  }
  if unreachable_idx == 0 {
    for idx = 1; idx < body_count; idx = idx + 1 {
      if !append_body_root(idx) {
        return false
      }
    }
    if !append_body_root(0) {
      return false
    }
  } else {
    for idx = 0; idx < body_count; idx = idx + 1 {
      if !append_body_root(idx) {
        return false
      }
    }
  }
  ignore(pass_splice_region(ctx, func, region_ref, block_idx, 1, replacement))
  @ir.hot_region_replace_body(func, body_ref, [])
  true
}

///|
fn code_pushing_try_sink_set_before_later_barrier(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let set_id = @ir.hot_region_get(func, region_ref, set_idx)
  if set_id < 0 || !@ir.hot_node_is_live(func, set_id) {
    return false
  }
  let set_node = @ir.hot_node_get(func, set_id)
  match set_node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, set_id) != 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, set_id, 0)
  if !code_pushing_node_is_movable_value(func, value_id) {
    return false
  }
  if !code_pushing_node_is_global_get(func, value_id) {
    return false
  }
  let local_id = set_node.imm0
  let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
    func, local_id, 1_000_000, 2,
  )
  if total_writes != 1 || total_gets == 0 {
    return false
  }

  let mut barrier_idx = -1
  let mut idx = set_idx + 1
  let max_idx = set_idx + 32
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= max_idx {
    let candidate_id = @ir.hot_region_get(func, region_ref, idx)
    let (gets, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func, candidate_id, local_id, 1, 0,
    )
    if writes != 0 {
      return false
    }
    if gets != 0 ||
      !code_pushing_node_safe_to_cross_for_value(func, candidate_id, value_id) {
      barrier_idx = idx
      break
    }
    idx += 1
  }
  if barrier_idx <= set_idx + 1 {
    return false
  }
  if barrier_idx < 0 {
    return false
  }
  let pushed_set = code_pushing_make_local_set_clone(func, local_id, value_id)
  ignore(
    pass_splice_region(ctx, func, region_ref, barrier_idx, 0, [pushed_set]),
  )
  let nop = @ir.hot_build_nop(func)
  pass_replace_node(ctx, func, set_id, @ir.hot_node_get(func, nop))
  true
}

///|
fn code_pushing_try_sink_local_get_set_after_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let set_id = @ir.hot_region_get(func, region_ref, set_idx)
  if set_id < 0 || !@ir.hot_node_is_live(func, set_id) {
    return false
  }
  let set_node = @ir.hot_node_get(func, set_id)
  match set_node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, set_id) != 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, set_id, 0)
  if !code_pushing_node_is_local_get(func, value_id) {
    return false
  }
  let source_local = @ir.hot_node_get(func, value_id).imm0
  let dest_local = set_node.imm0
  if source_local == dest_local {
    return false
  }
  let mut idx = set_idx + 1
  let max_idx = set_idx + 32
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= max_idx {
    let candidate_id = @ir.hot_region_get(func, region_ref, idx)
    let (dest_gets, dest_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func, candidate_id, dest_local, 1, 0,
    )
    if dest_gets != 0 || dest_writes != 0 {
      return false
    }
    if !code_pushing_node_safe_to_cross_for_value(func, candidate_id, value_id) {
      return false
    }
    let (_, source_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func, candidate_id, source_local, 0, 0,
    )
    if source_writes != 0 {
      return false
    }
    match @ir.hot_node_get(func, candidate_id).op {
      @ir.HotOp::If => {
        if @ir.hot_node_result_arity(func, candidate_id) != 0 {
          return false
        }
        if code_pushing_node_has_branch(func, candidate_id) ||
          code_pushing_node_has_unreachable(func, candidate_id) {
          return false
        }
        if code_pushing_node_writes_local_deep_limited(
            func, candidate_id, source_local, 8,
          ) {
          return false
        }
        let pushed_set = code_pushing_make_local_set_clone(
          func, dest_local, value_id,
        )
        ignore(
          pass_splice_region(ctx, func, region_ref, idx + 1, 0, [pushed_set]),
        )
        let nop = @ir.hot_build_nop(func)
        pass_replace_node(ctx, func, set_id, @ir.hot_node_get(func, nop))
        return true
      }
      _ => ()
    }
    idx += 1
  }
  false
}

///|
fn code_pushing_try_sink_set_into_if_then(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let set_id = @ir.hot_region_get(func, region_ref, set_idx)
  if set_id < 0 || !@ir.hot_node_is_live(func, set_id) {
    return false
  }
  let set_node = @ir.hot_node_get(func, set_id)
  match set_node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, set_id) != 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, set_id, 0)
  if !code_pushing_node_is_movable_value(func, value_id) {
    return false
  }

  let mut if_idx = set_idx + 1
  let mut found_if = false
  while if_idx < @ir.hot_region_root_count(func, region_ref) {
    let candidate_id = @ir.hot_region_get(func, region_ref, if_idx)
    if candidate_id < 0 || !@ir.hot_node_is_live(func, candidate_id) {
      return false
    }
    match @ir.hot_node_get(func, candidate_id).op {
      @ir.HotOp::If if @ir.hot_node_result_arity(func, candidate_id) == 0 => {
        let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
          func,
          candidate_id,
          set_node.imm0,
        )
        if then_gets + else_gets > 0 {
          found_if = true
          break
        }
        if !code_pushing_node_safe_to_cross_for_value(
            func, candidate_id, value_id,
          ) {
          return false
        }
      }
      _ => {
        let (gets, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
          func,
          candidate_id,
          set_node.imm0,
          0,
          0,
        )
        if gets != 0 ||
          writes != 0 ||
          !code_pushing_node_safe_to_cross_for_value(
            func, candidate_id, value_id,
          ) {
          return false
        }
      }
    }
    if_idx += 1
  }
  if !found_if {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, if_idx)
  if @ir.hot_child_count(func, if_id) > 0 {
    let if_cond = @ir.hot_child_get(func, if_id, 0)
    if !code_pushing_node_safe_to_cross_for_value(func, if_cond, value_id) {
      return false
    }
  }
  if @ir.hot_node_result_arity(func, if_id) != 0 {
    return false
  }
  let local_id = set_node.imm0
  let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
    func, if_id, local_id,
  )
  let arm_gets = then_gets + else_gets
  if arm_gets == 0 || (then_gets > 0 && else_gets > 0) {
    return false
  }
  let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
    func, local_id, arm_gets, 1,
  )
  if total_writes != 1 || total_gets != arm_gets {
    return false
  }
  let target_ref = if then_gets > 0 {
    Some(@ir.hot_region_then_ref(func, if_id))
  } else {
    @ir.hot_region_else_ref(func, if_id)
  }
  match target_ref {
    Some(target_ref) => {
      let pushed_set = code_pushing_make_local_set_clone(
        func, local_id, value_id,
      )
      ignore(pass_splice_region(ctx, func, target_ref, 0, 0, [pushed_set]))
      let nop = @ir.hot_build_nop(func)
      pass_replace_node(ctx, func, set_id, @ir.hot_node_get(func, nop))
      true
    }
    None => false
  }
}

///|
fn code_pushing_scan_region_once(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    if code_pushing_try_flatten_dead_block_before_unreachable(
        ctx, func, region_ref, idx,
      ) {
      return true
    }
    if code_pushing_try_sink_set_before_later_barrier(
        ctx, func, region_ref, idx,
      ) {
      return true
    }
    if code_pushing_try_sink_local_get_set_after_if(ctx, func, region_ref, idx) {
      return true
    }
    if code_pushing_try_sink_set_into_if_then(ctx, func, region_ref, idx) {
      return true
    }
    idx += 1
  }

  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
      @ir.HotOp::If => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if code_pushing_scan_region_once(ctx, func, else_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) =>
            if code_pushing_scan_region_once(ctx, func, catch_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, node_id),
          ) {
          return true
        }
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_catch_list_ref(func, node_id),
          ) {
          return true
        }
      }
      _ => ()
    }
  }
  false
}

///|
fn code_pushing_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let mut changed_any = false
  let mut changed_round = true
  while changed_round {
    changed_round = code_pushing_scan_region_once(
      ctx,
      func,
      @ir.HotRegionRef::root(),
    )
    if changed_round {
      changed_any = true
    }
  }
  if changed_any {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
