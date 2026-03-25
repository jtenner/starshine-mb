///|
pub fn optimize_instructions_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "optimize-instructions",
    requires=[@ir.HotAnalysis::effects()],
    invalidates=[
      @ir.HotAnalysis::cfg(),
      @ir.HotAnalysis::dominance(),
      @ir.HotAnalysis::liveness(),
      @ir.HotAnalysis::use_def(),
      @ir.HotAnalysis::effects(),
      @ir.HotAnalysis::loop_info(),
      @ir.HotAnalysis::ssa(),
    ],
  )
}

///|
pub fn optimize_instructions_summary() -> String {
  "Fold simple exact-instruction peepholes such as constant eqz unary nodes."
}

///|
fn optimize_instructions_live_children(
  func : @ir.HotFunc,
  node_id : Int,
) -> Array[Int] {
  let children : Array[Int] = []
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    children.push(child_id)
  }
  children
}

///|
fn optimize_instructions_collect_detached(
  func : @ir.HotFunc,
  node_id : Int,
  out : Array[Int],
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  out.push(node_id)
  for child_id in optimize_instructions_live_children(func, node_id) {
    optimize_instructions_collect_detached(func, child_id, out)
  }
}

///|
fn optimize_instructions_replace_with_const_i32(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  value : @lib.I32,
) -> Unit {
  let detached : Array[Int] = []
  for child_id in optimize_instructions_live_children(func, node_id) {
    optimize_instructions_collect_detached(func, child_id, detached)
  }
  let temp = @ir.hot_build_const_i32(func, value)
  let replacement = @ir.hot_node_get(func, temp)
  @ir.hot_delete_node(func, temp)
  pass_replace_node(ctx, func, node_id, replacement)
  pass_delete_detached_nodes(ctx, func, detached)
}

///|
fn optimize_instructions_try_fold_eqz(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unary => ()
    _ => return false
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let operand_id = @ir.hot_child_get(func, node_id, 0)
  if operand_id < 0 || !@ir.hot_node_is_live(func, operand_id) {
    return false
  }
  let operand = @ir.hot_node_get(func, operand_id)
  match operand.op {
    @ir.HotOp::Const => ()
    _ => return false
  }

  let folded = match
    (
      @ir.hot_node_exact_instr(func, node_id),
      @ir.hot_const_get(func, operand.imm0),
    ) {
    (Some(@lib.Instruction::I32Eqz), @ir.HotConstPayload::I32Const(v)) =>
      Some(if v == @lib.I32(0) { @lib.I32(1) } else { @lib.I32(0) })
    (Some(@lib.Instruction::I64Eqz), @ir.HotConstPayload::I64Const(v)) =>
      Some(if v == @lib.I64(0) { @lib.I32(1) } else { @lib.I32(0) })
    _ => None
  }
  match folded {
    Some(value) => {
      optimize_instructions_replace_with_const_i32(ctx, func, node_id, value)
      true
    }
    None => false
  }
}

///|
fn optimize_instructions_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  for child_id in optimize_instructions_live_children(func, node_id) {
    changed = optimize_instructions_visit_node(ctx, func, child_id) || changed
  }
  optimize_instructions_try_fold_eqz(ctx, func, node_id) || changed
}

///|
fn optimize_instructions_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let mut changed = false
  for slot = 0; slot < @ir.hot_root_count(func); slot = slot + 1 {
    changed = optimize_instructions_visit_node(
        ctx,
        func,
        @ir.hot_root_get(func, slot),
      ) ||
      changed
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
