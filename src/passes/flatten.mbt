///|
pub fn flatten_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("flatten", invalidates=[
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
pub fn flatten_summary() -> String {
  "Sequence nested values through explicit locals to establish Binaryen Flat IR."
}

///|
/// Analysis-only summary of Binaryen Flat IR contract violations in one HOT function.
pub(all) struct FlattenFlatnessReport {
  mut rich_operand_count : Int
  mut value_control_count : Int
  mut local_tee_count : Int
  mut control_local_set_count : Int
  mut body_value_flow_count : Int
  mut unsupported_count : Int
} derive(Eq, Debug)

///|
pub fn FlattenFlatnessReport::empty() -> FlattenFlatnessReport {
  {
    rich_operand_count: 0,
    value_control_count: 0,
    local_tee_count: 0,
    control_local_set_count: 0,
    body_value_flow_count: 0,
    unsupported_count: 0,
  }
}

///|
pub fn FlattenFlatnessReport::is_flat(self : FlattenFlatnessReport) -> Bool {
  self.rich_operand_count == 0 &&
  self.value_control_count == 0 &&
  self.local_tee_count == 0 &&
  self.control_local_set_count == 0 &&
  self.body_value_flow_count == 0 &&
  self.unsupported_count == 0
}

///|
fn flatten_op_is_control_structure(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
fn flatten_node_is_simple_operand(func : @ir.HotFunc, node_id : Int) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::Unreachable
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::GlobalGet => true
    @ir.HotOp::Unary =>
      @ir.hot_node_exact_instr(func, node_id) ==
      Some(@lib.Instruction::ref_as_non_null())
    _ => false
  }
}

///|
fn flatten_operand_slot_count(func : @ir.HotFunc, node_id : Int) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Try | @ir.HotOp::TryTable => 0
    @ir.HotOp::Loop =>
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, node_id),
      )
    @ir.HotOp::If => 1
    _ => @ir.hot_child_count(func, node_id)
  }
}

///|
fn flatten_op_is_unsupported(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
/// Classify the current HOT function without mutating it.
pub fn flatten_classify_hot(func : @ir.HotFunc) -> FlattenFlatnessReport {
  let report = FlattenFlatnessReport::empty()
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    if flatten_op_is_unsupported(node.op) {
      report.unsupported_count += 1
    }
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If | @ir.HotOp::Try =>
        if @ir.hot_type_result_arity(func, node.ty) > 0 {
          report.value_control_count += 1
        }
      @ir.HotOp::LocalTee => report.local_tee_count += 1
      @ir.HotOp::LocalSet =>
        if @ir.hot_child_count(func, node_id) == 1 {
          let child = @ir.hot_node_get(
            func,
            @ir.hot_child_get(func, node_id, 0),
          )
          if flatten_op_is_control_structure(child.op) {
            report.control_local_set_count += 1
          }
        }
      _ => ()
    }
    for slot = 0
        slot < flatten_operand_slot_count(func, node_id)
        slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
        let local_set_value_is_allowed = match node.op {
          @ir.HotOp::LocalSet =>
            !flatten_op_is_control_structure(
              @ir.hot_node_get(func, child_id).op,
            )
          _ => false
        }
        if !local_set_value_is_allowed &&
          !flatten_node_is_simple_operand(func, child_id) {
          report.rich_operand_count += 1
        }
      }
    }
  }
  let root_count = @ir.hot_root_count(func)
  if root_count > 0 {
    let tail = @ir.hot_root_get(func, root_count - 1)
    if @ir.hot_node_is_live(func, tail) &&
      @ir.hot_node_result_arity(func, tail) > 0 {
      report.body_value_flow_count = 1
    }
  }
  report
}

///|
fn flatten_value_type_is_defaultable(value_type : @lib.ValType) -> Bool {
  match value_type {
    @lib.RefTypeValType(ref_type) => @lib.RefType::is_defaultable(ref_type)
    @lib.BotValType => false
    _ => true
  }
}

///|
priv struct FlattenRewriteState {
  break_temps : Array[Int]
  terminal_payloads : Array[Int]
  sequenced_root_holders : Array[Int]
  sequenced_root_nodes : Array[Int]
}

///|
fn FlattenRewriteState::new(func : @ir.HotFunc) -> FlattenRewriteState {
  {
    break_temps: Array::make(func.labels.length(), -1),
    terminal_payloads: [],
    sequenced_root_holders: [],
    sequenced_root_nodes: [],
  }
}

///|
fn flatten_br_table_targets_label(
  func : @ir.HotFunc,
  table_id : Int,
  label_id : Int,
) -> Bool {
  if @ir.hot_branch_table_default_target(func, table_id) == label_id {
    return true
  }
  for target in @ir.hot_branch_table_targets(func, table_id) {
    if target == label_id {
      return true
    }
  }
  false
}

///|
fn flatten_terminal_branch_targets_label(
  func : @ir.HotFunc,
  node_id : Int,
  label_id : Int,
  allow_scalar_payload : Bool,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br if node.imm0 == label_id =>
      @ir.hot_child_count(func, node_id) == 0 ||
      (allow_scalar_payload && @ir.hot_child_count(func, node_id) == 1)
    @ir.HotOp::BrTable if flatten_br_table_targets_label(
        func,
        node.imm0,
        label_id,
      ) =>
      @ir.hot_child_count(func, node_id) == 1 ||
      (allow_scalar_payload && @ir.hot_child_count(func, node_id) == 2)
    _ => false
  }
}

///|
fn flatten_label_uses_are_routed_scalar_brs(
  func : @ir.HotFunc,
  label_id : Int,
) -> Bool {
  let mut saw_target = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br if node.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 0 {
          return false
        }
      }
      @ir.HotOp::BrIf if node.imm0 == label_id => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 1 {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if node.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          node.imm0,
          label_id,
        ) => {
        saw_target = true
        if @ir.hot_child_count(func, node_id) != 1 {
          return false
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_try_route_scalar_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  block_id : Int,
) -> Int? {
  let block = @ir.hot_node_get(func, block_id)
  match block.op {
    @ir.HotOp::Block => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, block.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  let label_is_used = pass_label_is_used(
    label_id,
    pass_compute_label_used(func),
  )
  let routed_local = if label_is_used {
    if label_id < 0 ||
      label_id >= state.break_temps.length() ||
      state.break_temps[label_id] < 0 ||
      !flatten_label_uses_are_routed_scalar_brs(func, label_id) {
      return None
    }
    state.break_temps[label_id]
  } else {
    -1
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let mut body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return None
  }
  let mut tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
  if body_count >= 2 && state.terminal_payloads.contains(tail_id) {
    let branch_id = @ir.hot_region_get(func, body_ref, body_count - 2)
    if flatten_terminal_branch_targets_label(func, branch_id, label_id, false) {
      ignore(pass_splice_region(ctx, func, body_ref, body_count - 1, 1, []))
      body_count -= 1
      tail_id = branch_id
    }
  }
  let tail_has_fallthrough_value = @ir.hot_node_result_arity(func, tail_id) == 1
  if !tail_has_fallthrough_value &&
    !flatten_terminal_branch_targets_label(func, tail_id, label_id, false) {
    return None
  }
  let local_id = if routed_local >= 0 {
    routed_local
  } else {
    @ir.hot_append_body_local(func, result_types[0])
  }
  if tail_has_fallthrough_value {
    ignore(
      pass_splice_region(ctx, func, body_ref, body_count - 1, 1, [
        @ir.hot_build_local_set(func, local_id, tail_id),
      ]),
    )
  }
  @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_try_route_scalar_loop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  loop_id : Int,
) -> Int? {
  let loop_node = @ir.hot_node_get(func, loop_id)
  match loop_node.op {
    @ir.HotOp::Loop => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, loop_node.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, loop_id)
  if @ir.hot_label_branch_arity(func, label_id) != 0 ||
    pass_label_is_used(label_id, pass_compute_label_used(func)) {
    return None
  }
  let body_ref = @ir.hot_region_body_ref(func, loop_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return None
  }
  let tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
  if @ir.hot_node_result_arity(func, tail_id) != 1 {
    return None
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  ignore(
    pass_splice_region(ctx, func, body_ref, body_count - 1, 1, [
      @ir.hot_build_local_set(func, local_id, tail_id),
    ]),
  )
  @ir.hot_control_result_type_set(func, loop_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_try_route_scalar_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  if_id : Int,
) -> Int? {
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return None
  }
  let result_types = @ir.hot_type_results(func, if_node.ty)
  if result_types.length() != 1 ||
    !flatten_value_type_is_defaultable(result_types[0]) {
    return None
  }
  let label_id = @ir.hot_control_node_label(func, if_id)
  if pass_label_is_used(label_id, pass_compute_label_used(func)) {
    return None
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return None
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  if then_count == 0 || else_count == 0 {
    return None
  }
  let then_tail = @ir.hot_region_get(func, then_ref, then_count - 1)
  let else_tail = @ir.hot_region_get(func, else_ref, else_count - 1)
  if @ir.hot_node_result_arity(func, then_tail) != 1 ||
    @ir.hot_node_result_arity(func, else_tail) != 1 {
    return None
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  ignore(
    pass_splice_region(ctx, func, then_ref, then_count - 1, 1, [
      @ir.hot_build_local_set(func, local_id, then_tail),
    ]),
  )
  ignore(
    pass_splice_region(ctx, func, else_ref, else_count - 1, 1, [
      @ir.hot_build_local_set(func, local_id, else_tail),
    ]),
  )
  @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
  Some(local_id)
}

///|
fn flatten_try_route_scalar_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
) -> Int? {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block =>
      flatten_try_route_scalar_block(ctx, func, state, node_id)
    @ir.HotOp::Loop => flatten_try_route_scalar_loop(ctx, func, node_id)
    @ir.HotOp::If => flatten_try_route_scalar_if(ctx, func, node_id)
    _ => None
  }
}

///|
fn flatten_target_can_route_scalar_branches(
  func : @ir.HotFunc,
  label_id : Int,
  target_type : @lib.ValType,
) -> Bool {
  let owner_id = @ir.hot_label_owner(func, label_id)
  let owner = @ir.hot_node_get(func, owner_id)
  match owner.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let body_ref = @ir.hot_region_body_ref(func, owner_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return false
  }
  let tail_id = @ir.hot_region_get(func, body_ref, body_count - 1)
  if @ir.hot_node_result_arity(func, tail_id) != 1 &&
    !flatten_terminal_branch_targets_label(func, tail_id, label_id, true) {
    return false
  }
  let mut saw_target = false
  for branch_id = 0
      branch_id < @ir.hot_node_count(func)
      branch_id = branch_id + 1 {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    let branch = @ir.hot_node_get(func, branch_id)
    match branch.op {
      @ir.HotOp::Br if branch.imm0 == label_id => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 0 {
          continue
        }
        if child_count != 1 {
          return false
        }
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, @ir.hot_child_get(func, branch_id, 0)).ty,
        )
        if value_types.length() != 1 || value_types[0] != target_type {
          return false
        }
      }
      @ir.HotOp::BrIf if branch.imm0 == label_id => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 1 {
          continue
        }
        if child_count != 2 {
          return false
        }
        let value_id = @ir.hot_child_get(func, branch_id, 0)
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
        )
        if value_types.length() != 1 ||
          !flatten_value_type_is_defaultable(value_types[0]) {
          return false
        }
      }
      @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate if branch.imm0 == label_id => return false
      @ir.HotOp::BrTable if flatten_br_table_targets_label(
          func,
          branch.imm0,
          label_id,
        ) => {
        saw_target = true
        let child_count = @ir.hot_child_count(func, branch_id)
        if child_count == 1 {
          continue
        }
        if child_count != 2 {
          return false
        }
        let value_id = @ir.hot_child_get(func, branch_id, 0)
        let value_types = @ir.hot_type_results(
          func,
          @ir.hot_node_get(func, value_id).ty,
        )
        if value_types.length() != 1 || value_types[0] != target_type {
          return false
        }
      }
      _ => ()
    }
  }
  saw_target
}

///|
fn flatten_try_route_scalar_br(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  match branch.op {
    @ir.HotOp::Br if @ir.hot_child_count(func, node_id) == 1 => ()
    _ => return false
  }
  let label_id = branch.imm0
  if label_id < 0 ||
    label_id >= state.break_temps.length() ||
    @ir.hot_label_branch_arity(func, label_id) != 1 {
    return false
  }
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::BlockLabel => ()
    _ => return false
  }
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let value_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
  )
  if target_types.length() != 1 ||
    value_types.length() != 1 ||
    target_types[0] != value_types[0] ||
    !flatten_value_type_is_defaultable(target_types[0]) ||
    !flatten_target_can_route_scalar_branches(func, label_id, target_types[0]) {
    return false
  }
  let local_id = if state.break_temps[label_id] >= 0 {
    state.break_temps[label_id]
  } else {
    let fresh = @ir.hot_append_body_local(func, target_types[0])
    state.break_temps[label_id] = fresh
    fresh
  }
  preludes.push(@ir.hot_build_local_set(func, local_id, value_id))
  ignore(@ir.hot_replace_child_span(func, node_id, []))
  true
}

///|
fn flatten_replace_flowing_value_uses(
  func : @ir.HotFunc,
  branch_id : Int,
  value_id : Int,
  local_id : Int,
) -> Bool {
  let mut replacement = -1
  let mut replaced = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let child_count = @ir.hot_child_count(func, node_id)
    for slot = 0; slot < child_count; slot = slot + 1 {
      if node_id == branch_id && slot == 0 {
        continue
      }
      if @ir.hot_child_get(func, node_id, slot) == value_id {
        if replacement < 0 {
          replacement = @ir.hot_build_local_get(func, local_id)
        }
        @ir.hot_child_set(func, node_id, slot, replacement)
        replaced = true
      }
    }
  }
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    if @ir.hot_root_get(func, root_idx) == value_id {
      if replacement < 0 {
        replacement = @ir.hot_build_local_get(func, local_id)
      }
      @ir.hot_root_set(func, root_idx, replacement)
      replaced = true
    }
  }
  replaced
}

///|
fn flatten_try_route_scalar_br_if(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  match branch.op {
    @ir.HotOp::BrIf if @ir.hot_child_count(func, node_id) == 2 => ()
    _ => return false
  }
  let label_id = branch.imm0
  if label_id < 0 ||
    label_id >= state.break_temps.length() ||
    @ir.hot_label_branch_arity(func, label_id) != 1 {
    return false
  }
  match @ir.hot_label_kind(func, label_id) {
    @ir.HotLabelKind::BlockLabel => ()
    _ => return false
  }
  let target_types = @ir.hot_type_results(
    func,
    @ir.hot_label_result_type(func, label_id),
  )
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let value_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
  )
  if target_types.length() != 1 ||
    value_types.length() != 1 ||
    !flatten_value_type_is_defaultable(target_types[0]) ||
    !flatten_value_type_is_defaultable(value_types[0]) ||
    !flatten_target_can_route_scalar_branches(func, label_id, target_types[0]) {
    return false
  }
  let local_id = if state.break_temps[label_id] >= 0 {
    state.break_temps[label_id]
  } else {
    let fresh = @ir.hot_append_body_local(func, target_types[0])
    state.break_temps[label_id] = fresh
    fresh
  }
  let flow_local = if target_types[0] == value_types[0] {
    local_id
  } else {
    @ir.hot_append_body_local(func, value_types[0])
  }
  ignore(
    flatten_replace_flowing_value_uses(func, node_id, value_id, flow_local),
  )
  if flow_local == local_id {
    preludes.push(@ir.hot_build_local_set(func, local_id, value_id))
  } else {
    preludes.push(@ir.hot_build_local_set(func, flow_local, value_id))
    preludes.push(
      @ir.hot_build_local_set(
        func,
        local_id,
        @ir.hot_build_local_get(func, flow_local),
      ),
    )
  }
  let condition_id = @ir.hot_child_get(func, node_id, 1)
  ignore(@ir.hot_replace_child_span(func, node_id, [condition_id]))
  true
}

///|
fn flatten_unique_br_table_targets(
  func : @ir.HotFunc,
  table_id : Int,
) -> Array[Int] {
  let unique : Array[Int] = []
  for target in @ir.hot_branch_table_targets(func, table_id) {
    if !unique.contains(target) {
      unique.push(target)
    }
  }
  let default_target = @ir.hot_branch_table_default_target(func, table_id)
  if !unique.contains(default_target) {
    unique.push(default_target)
  }
  unique
}

///|
fn flatten_try_route_scalar_br_table(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  let branch = @ir.hot_node_get(func, node_id)
  match branch.op {
    @ir.HotOp::BrTable if @ir.hot_child_count(func, node_id) == 2 => ()
    _ => return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let value_types = @ir.hot_type_results(
    func,
    @ir.hot_node_get(func, value_id).ty,
  )
  if value_types.length() != 1 ||
    !flatten_value_type_is_defaultable(value_types[0]) {
    return false
  }
  let targets = flatten_unique_br_table_targets(func, branch.imm0)
  if targets.length() == 0 {
    return false
  }
  for target in targets {
    if target < 0 ||
      target >= state.break_temps.length() ||
      @ir.hot_label_branch_arity(func, target) != 1 {
      return false
    }
    match @ir.hot_label_kind(func, target) {
      @ir.HotLabelKind::BlockLabel => ()
      _ => return false
    }
    let target_types = @ir.hot_type_results(
      func,
      @ir.hot_label_result_type(func, target),
    )
    if target_types.length() != 1 ||
      target_types[0] != value_types[0] ||
      !flatten_target_can_route_scalar_branches(func, target, value_types[0]) {
      return false
    }
  }
  let value_local = @ir.hot_append_body_local(func, value_types[0])
  preludes.push(@ir.hot_build_local_set(func, value_local, value_id))
  for target in targets {
    let target_local = if state.break_temps[target] >= 0 {
      state.break_temps[target]
    } else {
      let fresh = @ir.hot_append_body_local(func, value_types[0])
      state.break_temps[target] = fresh
      fresh
    }
    preludes.push(
      @ir.hot_build_local_set(
        func,
        target_local,
        @ir.hot_build_local_get(func, value_local),
      ),
    )
  }
  state.terminal_payloads.push(value_id)
  let selector_id = @ir.hot_child_get(func, node_id, 1)
  ignore(@ir.hot_replace_child_span(func, node_id, [selector_id]))
  true
}

///|
fn flatten_node_is_admitted_terminal_control_effect(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br | @ir.HotOp::BrTable => true
    _ => false
  }
}

///|
fn flatten_place_unreachable_control_placeholder(
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  preludes : Array[Int],
) -> Bool {
  if !flatten_node_is_admitted_terminal_control_effect(func, child_id) {
    return false
  }
  let mut already_sequenced = false
  for idx = 0; idx < state.sequenced_root_nodes.length(); idx = idx + 1 {
    if state.sequenced_root_holders[idx] == owner_region.holder &&
      state.sequenced_root_nodes[idx] == child_id {
      already_sequenced = true
    }
  }
  if !already_sequenced {
    preludes.push(child_id)
  }
  @ir.hot_child_set(func, parent_id, slot, @ir.hot_build_unreachable(func))
  true
}

///|
fn flatten_spill_scalar_operand(
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  child_id : Int,
  preludes : Array[Int],
) -> Bool {
  let child = @ir.hot_node_get(func, child_id)
  let parent = @ir.hot_node_get(func, parent_id)
  let child_is_tee = match child.op {
    @ir.HotOp::LocalTee => true
    _ => false
  }
  let parent_allows_rich_value = match parent.op {
    @ir.HotOp::LocalSet => !flatten_op_is_control_structure(child.op)
    _ => false
  }
  if flatten_node_is_simple_operand(func, child_id) ||
    @ir.hot_node_kind_is_control(func, child_id) ||
    child_is_tee ||
    parent_allows_rich_value {
    return false
  }
  let result_types = @ir.hot_type_results(func, child.ty)
  if result_types.length() != 1 {
    return false
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  preludes.push(@ir.hot_build_local_set(func, local_id, child_id))
  @ir.hot_child_set(
    func,
    parent_id,
    slot,
    @ir.hot_build_local_get(func, local_id),
  )
  true
}

///|
fn flatten_try_lower_region_root_tee(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  root_idx : Int,
  node_id : Int,
) -> Int? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 => ()
    _ => return None
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  let replacement = match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Unreachable => [value_id]
    _ =>
      [
        @ir.hot_build_local_set(func, node.imm0, value_id),
        @ir.hot_build_local_get(func, node.imm0),
      ]
  }
  let removed = pass_splice_region(
    ctx, func, region_ref, root_idx, 1, replacement,
  )
  pass_delete_detached_nodes(ctx, func, removed)
  Some(replacement.length())
}

///|
fn flatten_rewrite_region_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let preludes : Array[Int] = []
    if flatten_rewrite_node_operands(
        ctx, func, state, region_ref, node_id, preludes,
      ) {
      changed = true
    }
    let inserted = preludes.length()
    if inserted > 0 {
      ignore(pass_splice_region(ctx, func, region_ref, idx, 0, preludes))
      changed = true
    }
    let root_idx = idx + inserted
    state.sequenced_root_holders.push(region_ref.holder)
    state.sequenced_root_nodes.push(node_id)
    match
      flatten_try_lower_region_root_tee(
        ctx, func, region_ref, root_idx, node_id,
      ) {
      Some(replacement_count) => {
        changed = true
        idx = root_idx + replacement_count
      }
      None =>
        match flatten_try_route_scalar_control(ctx, func, state, node_id) {
          Some(local_id) => {
            ignore(
              pass_splice_region(ctx, func, region_ref, root_idx, 1, [
                node_id,
                @ir.hot_build_local_get(func, local_id),
              ]),
            )
            changed = true
            idx = root_idx + 2
          }
          None => idx = root_idx + 1
        }
    }
  }
  changed
}

///|
fn flatten_try_lower_tee_operand(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  tee_id : Int,
  preludes : Array[Int],
) -> Bool {
  let tee = @ir.hot_node_get(func, tee_id)
  match tee.op {
    @ir.HotOp::LocalTee if @ir.hot_child_count(func, tee_id) == 1 => ()
    _ => return false
  }
  let value_id = @ir.hot_child_get(func, tee_id, 0)
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Unreachable => {
      preludes.push(value_id)
      @ir.hot_child_set(func, parent_id, slot, @ir.hot_build_unreachable(func))
    }
    _ => {
      preludes.push(@ir.hot_build_local_set(func, tee.imm0, value_id))
      @ir.hot_child_set(
        func,
        parent_id,
        slot,
        @ir.hot_build_local_get(func, tee.imm0),
      )
    }
  }
  pass_delete_detached_nodes(ctx, func, [tee_id])
  true
}

///|
fn flatten_rewrite_operand_slot(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  parent_id : Int,
  slot : Int,
  preludes : Array[Int],
) -> Bool {
  let child_id = @ir.hot_child_get(func, parent_id, slot)
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  let mut changed = flatten_rewrite_node_operands(
    ctx, func, state, owner_region, child_id, preludes,
  )
  if flatten_try_lower_tee_operand(
      ctx, func, parent_id, slot, child_id, preludes,
    ) {
    return true
  }
  match flatten_try_route_scalar_control(ctx, func, state, child_id) {
    Some(local_id) => {
      preludes.push(child_id)
      @ir.hot_child_set(
        func,
        parent_id,
        slot,
        @ir.hot_build_local_get(func, local_id),
      )
      changed = true
    }
    None =>
      if flatten_place_unreachable_control_placeholder(
          func, state, owner_region, parent_id, slot, child_id, preludes,
        ) {
        changed = true
      } else if flatten_spill_scalar_operand(
          func, parent_id, slot, child_id, preludes,
        ) {
        changed = true
      }
  }
  changed
}

///|
fn flatten_rewrite_node_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  state : FlattenRewriteState,
  owner_region : @ir.HotRegionRef,
  node_id : Int,
  preludes : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  match node.op {
    @ir.HotOp::Block =>
      changed = flatten_rewrite_region_operands(
        ctx,
        func,
        state,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::Loop => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      let input_count = @ir.hot_label_branch_arity(func, label_id)
      for slot = 0; slot < input_count; slot = slot + 1 {
        if flatten_rewrite_operand_slot(
            ctx, func, state, owner_region, node_id, slot, preludes,
          ) {
          changed = true
        }
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
    }
    @ir.HotOp::If => {
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if flatten_rewrite_region_operands(ctx, func, state, else_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::Try => {
      if flatten_rewrite_region_operands(
          ctx,
          func,
          state,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          if flatten_rewrite_region_operands(ctx, func, state, catch_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::TryTable => ()
    @ir.HotOp::BrIf if @ir.hot_child_count(func, node_id) == 2 => {
      let payload_id = @ir.hot_child_get(func, node_id, 0)
      if flatten_rewrite_node_operands(
          ctx, func, state, owner_region, payload_id, preludes,
        ) {
        changed = true
      }
      if flatten_try_route_scalar_br_if(func, state, node_id, preludes) {
        changed = true
      }
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
    }
    @ir.HotOp::BrTable if @ir.hot_child_count(func, node_id) == 2 => {
      let payload_id = @ir.hot_child_get(func, node_id, 0)
      if flatten_rewrite_node_operands(
          ctx, func, state, owner_region, payload_id, preludes,
        ) {
        changed = true
      }
      if flatten_try_route_scalar_br_table(func, state, node_id, preludes) {
        changed = true
      }
      if flatten_rewrite_operand_slot(
          ctx, func, state, owner_region, node_id, 0, preludes,
        ) {
        changed = true
      }
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        if flatten_rewrite_operand_slot(
            ctx, func, state, owner_region, node_id, slot, preludes,
          ) {
          changed = true
        }
      }
  }
  if flatten_try_route_scalar_br(func, state, node_id, preludes) {
    changed = true
  }
  if flatten_try_route_scalar_br_if(func, state, node_id, preludes) {
    changed = true
  }
  if flatten_try_route_scalar_br_table(func, state, node_id, preludes) {
    changed = true
  }
  changed
}

///|
fn flatten_materialize_scalar_body_result(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let root_count = @ir.hot_root_count(func)
  if root_count == 0 {
    return false
  }
  let tail_id = @ir.hot_root_get(func, root_count - 1)
  let tail = @ir.hot_node_get(func, tail_id)
  match tail.op {
    @ir.HotOp::Return => return false
    _ => ()
  }
  if flatten_op_is_control_structure(tail.op) {
    return false
  }
  let result_types = @ir.hot_type_results(func, tail.ty)
  if result_types.length() != 1 {
    return false
  }
  let local_id = @ir.hot_append_body_local(func, result_types[0])
  let set_id = @ir.hot_build_local_set(func, local_id, tail_id)
  let get_id = @ir.hot_build_local_get(func, local_id)
  let return_id = @ir.hot_build_return(func, [get_id])
  ignore(
    pass_splice_region(ctx, func, @ir.HotRegionRef::root(), root_count - 1, 1, [
      set_id, return_id,
    ]),
  )
  true
}

///|
fn flatten_scalar_branch_payload_has_supported_origin(
  func : @ir.HotFunc,
  value_id : Int,
) -> Bool {
  if flatten_node_is_simple_operand(func, value_id) {
    return true
  }
  let value = @ir.hot_node_get(func, value_id)
  if @ir.hot_node_kind_is_control(func, value_id) {
    return false
  }
  match value.op {
    @ir.HotOp::LocalTee => return false
    _ => ()
  }
  let value_types = @ir.hot_type_results(func, value.ty)
  value_types.length() == 1 && flatten_value_type_is_defaultable(value_types[0])
}

///|
fn flatten_has_deferred_rich_branch_payload(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::BrIf => {
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count <= 1 {
          continue
        }
        if child_count != 2 ||
          !flatten_scalar_branch_payload_has_supported_origin(
            func,
            @ir.hot_child_get(func, node_id, 0),
          ) {
          return true
        }
      }
      @ir.HotOp::BrTable => {
        let child_count = @ir.hot_child_count(func, node_id)
        if child_count <= 1 {
          continue
        }
        if child_count != 2 ||
          !flatten_scalar_branch_payload_has_supported_origin(
            func,
            @ir.hot_child_get(func, node_id, 0),
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
pub fn flatten_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let before = flatten_classify_hot(func)
  if before.unsupported_count > 0 ||
    flatten_has_deferred_rich_branch_payload(func) {
    return HotPassResult::unchanged()
  }
  let state = FlattenRewriteState::new(func)
  let mut changed = flatten_rewrite_region_operands(
    ctx,
    func,
    state,
    @ir.HotRegionRef::root(),
  )
  if flatten_materialize_scalar_body_result(ctx, func) {
    changed = true
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
