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
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
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
fn flatten_rewrite_region_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    let preludes : Array[Int] = []
    if flatten_rewrite_node_operands(ctx, func, node_id, preludes) {
      changed = true
    }
    let inserted = preludes.length()
    if inserted > 0 {
      ignore(pass_splice_region(ctx, func, region_ref, idx, 0, preludes))
      changed = true
    }
    idx += inserted + 1
  }
  changed
}

///|
fn flatten_rewrite_operand_slot(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  parent_id : Int,
  slot : Int,
  preludes : Array[Int],
) -> Bool {
  let child_id = @ir.hot_child_get(func, parent_id, slot)
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  let mut changed = flatten_rewrite_node_operands(ctx, func, child_id, preludes)
  if flatten_spill_scalar_operand(func, parent_id, slot, child_id, preludes) {
    changed = true
  }
  changed
}

///|
fn flatten_rewrite_node_operands(
  ctx : HotPassContext,
  func : @ir.HotFunc,
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
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::Loop => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      let input_count = @ir.hot_label_branch_arity(func, label_id)
      for slot = 0; slot < input_count; slot = slot + 1 {
        if flatten_rewrite_operand_slot(ctx, func, node_id, slot, preludes) {
          changed = true
        }
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
    }
    @ir.HotOp::If => {
      if flatten_rewrite_operand_slot(ctx, func, node_id, 0, preludes) {
        changed = true
      }
      if flatten_rewrite_region_operands(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if flatten_rewrite_region_operands(ctx, func, else_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::Try => {
      if flatten_rewrite_region_operands(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        changed = true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          if flatten_rewrite_region_operands(ctx, func, catch_ref) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::TryTable => ()
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        if flatten_rewrite_operand_slot(ctx, func, node_id, slot, preludes) {
          changed = true
        }
      }
  }
  changed
}

///|
fn flatten_rewrite_root_tees(ctx : HotPassContext, func : @ir.HotFunc) -> Bool {
  let mut changed = false
  let mut idx = @ir.hot_root_count(func) - 1
  while idx >= 0 {
    let node_id = @ir.hot_root_get(func, idx)
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalTee if @ir.hot_child_count(func, node_id) == 1 => {
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
          ctx,
          func,
          @ir.HotRegionRef::root(),
          idx,
          1,
          replacement,
        )
        pass_delete_detached_nodes(ctx, func, removed)
        changed = true
      }
      _ => ()
    }
    idx -= 1
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
pub fn flatten_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  let before = flatten_classify_hot(func)
  if before.unsupported_count > 0 {
    return HotPassResult::unchanged()
  }
  let mut changed = flatten_rewrite_region_operands(
    ctx,
    func,
    @ir.HotRegionRef::root(),
  )
  if flatten_rewrite_root_tees(ctx, func) {
    changed = true
  }
  if flatten_materialize_scalar_body_result(ctx, func) {
    changed = true
  }
  if !changed {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
