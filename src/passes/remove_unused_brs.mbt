///|
pub fn remove_unused_brs_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("remove-unused-brs", invalidates=[
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
pub fn remove_unused_brs_summary() -> String {
  "Remove tail branches and returns that already flow to the surrounding continuation."
}

///|
priv enum RemoveUnusedBrsTailTarget {
  NoTarget
  ReturnTarget
  BranchTarget(Int)
}

///|
priv struct RemoveUnusedBrsValueIfSelectRewrite {
  replacement : Int
  then_holder : Int
  else_holder : Int
}

///|
priv struct RemoveUnusedBrsHotVoidReturnLadderShape {
  mut call_count : Int
  mut local_set_count : Int
  mut local_tee_count : Int
  mut void_if_count : Int
  mut value_if_count : Int
  mut return_count : Int
  mut select_count : Int
  mut br_if_count : Int
  mut block_count : Int
  mut loop_count : Int
  mut br_count : Int
}

///|
fn remove_unused_brs_scan_hot_void_return_ladder_shape(
  func : @ir.HotFunc,
  shape : RemoveUnusedBrsHotVoidReturnLadderShape,
) -> Unit {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Call
      | @ir.HotOp::CallIndirect
      | @ir.HotOp::CallRef
      | @ir.HotOp::ReturnCall
      | @ir.HotOp::ReturnCallIndirect
      | @ir.HotOp::ReturnCallRef => shape.call_count = shape.call_count + 1
      @ir.HotOp::LocalSet => shape.local_set_count = shape.local_set_count + 1
      @ir.HotOp::LocalTee => shape.local_tee_count = shape.local_tee_count + 1
      @ir.HotOp::Return => shape.return_count = shape.return_count + 1
      @ir.HotOp::Select => shape.select_count = shape.select_count + 1
      @ir.HotOp::BrIf => shape.br_if_count = shape.br_if_count + 1
      @ir.HotOp::Block => shape.block_count = shape.block_count + 1
      @ir.HotOp::Loop => shape.loop_count = shape.loop_count + 1
      @ir.HotOp::Br => shape.br_count = shape.br_count + 1
      @ir.HotOp::If => {
        let node = @ir.hot_node_get(func, node_id)
        if @ir.hot_type_result_arity(func, node.ty) == 0 {
          shape.void_if_count = shape.void_if_count + 1
        } else {
          shape.value_if_count = shape.value_if_count + 1
        }
      }
      _ => ()
    }
  }
}

///|
fn remove_unused_brs_can_skip_large_void_return_ladder(
  func : @ir.HotFunc,
) -> Bool {
  let local_count = @ir.hot_local_count(func)
  let root_count = @ir.hot_root_count(func)
  let node_count = @ir.hot_node_count(func)
  if local_count < 700 {
    return false
  }
  let shape = {
    call_count: 0,
    local_set_count: 0,
    local_tee_count: 0,
    void_if_count: 0,
    value_if_count: 0,
    return_count: 0,
    select_count: 0,
    br_if_count: 0,
    block_count: 0,
    loop_count: 0,
    br_count: 0,
  }
  remove_unused_brs_scan_hot_void_return_ladder_shape(func, shape)
  let matches_wide_void_ladder = root_count >= 64 &&
    shape.call_count >= 900 &&
    shape.local_set_count >= 350 &&
    shape.local_tee_count >= 350 &&
    shape.void_if_count >= 150 &&
    shape.value_if_count == 0 &&
    shape.return_count >= 90 &&
    shape.return_count * 5 >= shape.void_if_count &&
    shape.select_count <= 4 &&
    shape.br_if_count <= 2
  let matches_compact_decision_ladder = root_count <= 8 &&
    node_count >= 8000 &&
    shape.call_count >= 1200 &&
    shape.local_set_count >= 500 &&
    shape.local_tee_count >= 350 &&
    shape.void_if_count >= 150 &&
    (shape.value_if_count <= 2 || shape.value_if_count >= 200) &&
    shape.return_count >= 120 &&
    shape.block_count >= 900 &&
    shape.loop_count <= 4 &&
    shape.br_count >= 150 &&
    shape.select_count <= 2 &&
    shape.br_if_count <= 2
  matches_wide_void_ladder || matches_compact_decision_ladder
}

///|
fn remove_unused_brs_tail_target(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> RemoveUnusedBrsTailTarget {
  if region_ref == @ir.HotRegionRef::root() {
    return ReturnTarget
  }
  let holder = region_ref.holder
  if holder < 0 || !@ir.hot_node_is_live(func, holder) {
    return NoTarget
  }
  match @ir.hot_node_get(func, holder).op {
    @ir.HotOp::Block => BranchTarget(@ir.hot_control_node_label(func, holder))
    _ => NoTarget
  }
}

///|
fn remove_unused_brs_region_tail_id(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return -1
  }
  @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
}

///|
fn remove_unused_brs_region_has_removable_tail_target(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  match remove_unused_brs_tail_target(func, region_ref) {
    NoTarget => false
    _ => true
  }
}

///|
fn remove_unused_brs_live_children(
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
fn remove_unused_brs_compute_label_refs(func : @ir.HotFunc) -> Array[Int] {
  let label_refs = Array::make(func.labels.length(), 0)
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_branch_target(func, node_id) {
      Some(label_id) if label_id >= 0 && label_id < label_refs.length() =>
        label_refs[label_id] = label_refs[label_id] + 1
      _ => ()
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::BrTable =>
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          if label_id >= 0 && label_id < label_refs.length() {
            label_refs[label_id] = label_refs[label_id] + 1
          }
        }
      @ir.HotOp::TryTable => {
        let info = @ir.hot_catch_info_get(func, node.imm1)
        for catch_ in info.catches {
          let label_id = match catch_ {
            @ir.HotCatchArm::CatchArm(_, label_id)
            | @ir.HotCatchArm::CatchRefArm(_, label_id)
            | @ir.HotCatchArm::CatchAllArm(label_id)
            | @ir.HotCatchArm::CatchAllRefArm(label_id) => label_id
          }
          if label_id >= 0 && label_id < label_refs.length() {
            label_refs[label_id] = label_refs[label_id] + 1
          }
        }
      }
      _ => ()
    }
  }
  label_refs
}

///|
fn remove_unused_brs_delete_unused_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  pass_delete_detached_nodes(ctx, func, node_ids)
}

///|
fn remove_unused_brs_replace_with_nop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let detached : Array[Int] = []
  let replacement = @ir.hot_build_nop(func)
  detached.push(replacement)
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  true
}

///|
fn remove_unused_brs_replace_with_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  child_id : Int,
) -> Bool {
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  let detached : Array[Int] = [child_id]
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, child_id))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  true
}

///|
fn remove_unused_brs_replace_with_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  replacement_id : Int,
  detached? : Array[Int] = [],
) -> Bool {
  if replacement_id < 0 || !@ir.hot_node_is_live(func, replacement_id) {
    return false
  }
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement_id))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, [replacement_id] + detached)
  true
}

///|
fn remove_unused_brs_splice_tail_with_children(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  tail_id : Int,
) -> Bool {
  let replacement : Array[Int] = []
  for child_idx = 0
      child_idx < @ir.hot_child_count(func, tail_id)
      child_idx = child_idx + 1 {
    let child_id = @ir.hot_child_get(func, tail_id, child_idx)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      return false
    }
    replacement.push(child_id)
  }
  remove_unused_brs_splice_tail_roots(
    ctx, func, region_ref, tail_id, replacement,
  )
}

///|
fn remove_unused_brs_splice_tail_roots(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  tail_id : Int,
  replacement : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  let tail_idx = root_count - 1
  if @ir.hot_region_get(func, region_ref, tail_idx) != tail_id {
    return false
  }
  let removed = pass_splice_region(
    ctx, func, region_ref, tail_idx, 1, replacement,
  )
  let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
  for removed_id in removed {
    @ir.hot_replace_node(func, removed_id, nop_node)
  }
  true
}

///|
fn remove_unused_brs_reorder_cache_resize(
  cache : Array[Int],
  node_id : Int,
) -> Unit {
  while cache.length() <= node_id {
    cache.push(-1)
  }
}

///|
fn remove_unused_brs_node_is_reorder_safe(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  cache : Array[Int],
) -> Bool {
  let _ = ctx
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  remove_unused_brs_reorder_cache_resize(cache, node_id)
  match cache[node_id] {
    0 => return false
    1 => return true
    _ => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::Nop
    | @ir.HotOp::Drop => ()
    @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract => ()
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let child_limit = match node.op {
    @ir.HotOp::If => 1
    _ => @ir.hot_child_count(func, node_id)
  }
  for slot = 0; slot < child_limit; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    if !remove_unused_brs_node_is_reorder_safe(ctx, func, child_id, cache) {
      cache[node_id] = 0
      return false
    }
  }
  let safe = match node.op {
    @ir.HotOp::If => {
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => else_ref
        None => {
          cache[node_id] = 0
          return false
        }
      }
      if @ir.hot_region_root_count(func, then_ref) != 1 ||
        @ir.hot_region_root_count(func, else_ref) != 1 {
        cache[node_id] = 0
        return false
      }
      let then_root = @ir.hot_region_get(func, then_ref, 0)
      let else_root = @ir.hot_region_get(func, else_ref, 0)
      remove_unused_brs_node_is_reorder_safe(ctx, func, then_root, cache) &&
      remove_unused_brs_node_is_reorder_safe(ctx, func, else_root, cache)
    }
    _ => true
  }
  cache[node_id] = if safe { 1 } else { 0 }
  safe
}

///|
fn remove_unused_brs_build_select(
  func : @ir.HotFunc,
  result_type : @lib.ValType,
  if_true : Int,
  if_false : Int,
  condition : Int,
) -> Int {
  @ir.hot_build_select(func, result_type, if_true, if_false, condition)
}

///|
fn remove_unused_brs_build_i32_eqz(func : @ir.HotFunc, operand : Int) -> Int {
  remove_unused_brs_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    operand,
  )
}

///|
fn remove_unused_brs_trim_trailing_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  while @ir.hot_region_root_count(func, region_ref) > 0 {
    let idx = @ir.hot_region_root_count(func, region_ref) - 1
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      _ => break
    }
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
    pass_delete_detached_nodes(ctx, func, removed)
    changed = true
  }
  changed
}

///|
fn remove_unused_brs_tail_is_nonfallthrough(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let tail = @ir.hot_node_get(func, tail_id)
  match tail.op {
    @ir.HotOp::If => {
      let else_ref = match @ir.hot_region_else_ref(func, tail_id) {
        Some(else_ref) => else_ref
        None => return false
      }
      remove_unused_brs_tail_is_nonfallthrough(
        func,
        @ir.hot_region_then_ref(func, tail_id),
      ) &&
      remove_unused_brs_tail_is_nonfallthrough(func, else_ref)
    }
    _ => {
      let edge_kinds = @ir.cfg_terminator_edge_kinds(tail.op)
      if edge_kinds.length() == 0 {
        return false
      }
      for edge_kind in edge_kinds {
        match edge_kind {
          @ir.CfgEdgeKind::FallthroughEdge => return false
          _ => ()
        }
      }
      true
    }
  }
}

///|
fn remove_unused_brs_region_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Array[Int] {
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  roots
}

///|
fn remove_unused_brs_expand_payload_children(
  func : @ir.HotFunc,
  payload_roots : Array[Int],
  result_arity : Int,
) -> Array[Int]? {
  let values : Array[Int] = []
  let mut seen_arity = 0
  for root_id in payload_roots {
    let root_arity = @ir.hot_node_result_arity(func, root_id)
    if root_arity <= 0 {
      return None
    }
    for dup_idx = 0; dup_idx < root_arity; dup_idx = dup_idx + 1 {
      let _ = dup_idx
      values.push(root_id)
    }
    seen_arity += root_arity
  }
  if seen_arity != result_arity {
    return None
  }
  Some(values)
}

///|
fn remove_unused_brs_build_tail_return_if_arm_body(
  func : @ir.HotFunc,
  arm_ref : @ir.HotRegionRef,
  return_arity : Int,
) -> Array[Int]? {
  if remove_unused_brs_tail_is_nonfallthrough(func, arm_ref) {
    return Some(remove_unused_brs_region_roots(func, arm_ref))
  }
  let (prefix, payload) = match
    remove_unused_brs_region_split_payload_roots(func, arm_ref, return_arity) {
    Some(split) => split
    None => return None
  }
  let return_values = match
    remove_unused_brs_expand_payload_children(func, payload, return_arity) {
    Some(values) => values
    None => return None
  }
  Some(prefix + [@ir.hot_build_return(func, return_values)])
}

///|
fn remove_unused_brs_try_voidify_tail_return_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_idx = @ir.hot_region_root_count(func, region_ref) - 1
  let tail_id = @ir.hot_region_get(func, region_ref, tail_idx)
  let tail = @ir.hot_node_get(func, tail_id)
  let (idx, remove_count, if_id, return_arity) = match tail.op {
    @ir.HotOp::Return if tail.child_count >= 1 => {
      let candidate = @ir.hot_child_get(func, tail_id, 0)
      for child_idx = 1; child_idx < tail.child_count; child_idx = child_idx + 1 {
        if @ir.hot_child_get(func, tail_id, child_idx) != candidate {
          return false
        }
      }
      (tail_idx, 1, candidate, tail.child_count)
    }
    @ir.HotOp::Return if tail.child_count == 0 && tail_idx > 0 => {
      let value_id = @ir.hot_region_get(func, region_ref, tail_idx - 1)
      (
        tail_idx - 1,
        2,
        value_id,
        @ir.hot_type_result_arity(func, @ir.hot_body_result_type(func)),
      )
    }
    _ => return false
  }
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) == 0 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  if return_arity == 1 &&
    (
      !remove_unused_brs_tail_is_nonfallthrough(func, then_ref) ||
      !remove_unused_brs_tail_is_nonfallthrough(func, else_ref)
    ) {
    return false
  }
  let then_body = match
    remove_unused_brs_build_tail_return_if_arm_body(
      func, then_ref, return_arity,
    ) {
    Some(body) => body
    None => return false
  }
  let else_body = match
    remove_unused_brs_build_tail_return_if_arm_body(
      func, else_ref, return_arity,
    ) {
    Some(body) => body
    None => return false
  }
  if then_body.is_empty() || else_body.is_empty() {
    return false
  }
  if return_arity > 1 {
    let return_cache : Array[Int] = []
    for root_id in then_body {
      if remove_unused_brs_subtree_has_return(func, root_id, return_cache) {
        return false
      }
    }
    for root_id in else_body {
      if remove_unused_brs_subtree_has_return(func, root_id, return_cache) {
        return false
      }
    }
  }
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, if_id, 0),
    then_body,
    else_body=Some(else_body),
  )
  let unreachable_id = @ir.hot_build_unreachable(func)
  let removed = pass_splice_region(ctx, func, region_ref, idx, remove_count, [
    replacement, unreachable_id,
  ])
  let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
  for removed_id in removed {
    @ir.hot_replace_node(func, removed_id, nop_node)
  }
  @ir.hot_replace_node(func, if_id, nop_node)
  @ir.hot_replace_node(func, then_ref.holder, nop_node)
  @ir.hot_replace_node(func, else_ref.holder, nop_node)
  true
}

///|
fn remove_unused_brs_try_voidify_exit_only_value_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, node_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_ref) != 1 ||
    @ir.hot_region_root_count(func, else_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let else_root = @ir.hot_region_get(func, else_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  let else_node = @ir.hot_node_get(func, else_root)
  match then_node.op {
    @ir.HotOp::Return => ()
    @ir.HotOp::Br if then_node.child_count == 0 => ()
    _ => return false
  }
  match else_node.op {
    @ir.HotOp::Return => ()
    @ir.HotOp::Br if else_node.child_count == 0 => ()
    _ => return false
  }
  let void_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, node_id, 0),
    remove_unused_brs_region_roots(func, then_ref),
    else_body=Some(remove_unused_brs_region_roots(func, else_ref)),
  )
  let replacement = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(
      @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))[0],
    ),
    [void_if, @ir.hot_build_unreachable(func)],
  )
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    replacement,
    then_ref.holder,
    else_ref.holder,
  ])
  true
}

///|
fn remove_unused_brs_try_remove_region_tail(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  reorder_cache : Array[Int],
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let tail = @ir.hot_node_get(func, tail_id)
  let rewrite_tail_child = fn(child_id : Int) -> Bool {
    match
      remove_unused_brs_match_value_if_to_select(
        ctx, func, child_id, reorder_cache,
      ) {
      Some(rewrite) => {
        if !remove_unused_brs_splice_tail_roots(
            ctx,
            func,
            region_ref,
            tail_id,
            [rewrite.replacement],
          ) {
          return false
        }
        let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
        @ir.hot_replace_node(func, child_id, nop_node)
        @ir.hot_replace_node(func, rewrite.then_holder, nop_node)
        @ir.hot_replace_node(func, rewrite.else_holder, nop_node)
        true
      }
      None =>
        remove_unused_brs_splice_tail_roots(ctx, func, region_ref, tail_id, [
          child_id,
        ])
    }
  }
  match remove_unused_brs_tail_target(func, region_ref) {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return =>
          if tail.child_count == 0 {
            remove_unused_brs_splice_tail_roots(
              ctx,
              func,
              region_ref,
              tail_id,
              [],
            )
          } else if tail.child_count == 1 {
            rewrite_tail_child(@ir.hot_child_get(func, tail_id, 0))
          } else {
            remove_unused_brs_splice_tail_with_children(
              ctx, func, region_ref, tail_id,
            )
          }
        _ => false
      }
    BranchTarget(target) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == target =>
          if tail.child_count == 0 {
            remove_unused_brs_splice_tail_roots(
              ctx,
              func,
              region_ref,
              tail_id,
              [],
            )
          } else if tail.child_count == 1 {
            rewrite_tail_child(@ir.hot_child_get(func, tail_id, 0))
          } else {
            remove_unused_brs_splice_tail_with_children(
              ctx, func, region_ref, tail_id,
            )
          }
        _ => false
      }
    NoTarget => false
  }
}

///|
fn remove_unused_brs_region_tail_control_payload_count(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target : RemoveUnusedBrsTailTarget,
  expected_payloads : Int,
) -> Int? {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return None
  }
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let tail = @ir.hot_node_get(func, tail_id)
  let stack_payloads = fn() -> Int? {
    if expected_payloads == 0 {
      return Some(0)
    }
    let roots = remove_unused_brs_region_roots(func, region_ref)
    if roots.is_empty() {
      return None
    }
    let payload_roots : Array[Int] = []
    for idx = 0; idx < roots.length() - 1; idx = idx + 1 {
      payload_roots.push(roots[idx])
    }
    match
      remove_unused_brs_split_payload_roots(
        func, payload_roots, expected_payloads,
      ) {
      Some(_) => Some(expected_payloads)
      None => None
    }
  }
  let child_payloads = fn() -> Int? {
    if tail.child_count > 1 {
      let first_id = @ir.hot_child_get(func, tail_id, 0)
      if first_id < 0 || !@ir.hot_node_is_live(func, first_id) {
        return None
      }
      let first_arity = @ir.hot_node_result_arity(func, first_id)
      if first_arity == expected_payloads {
        let mut repeated = true
        for child_idx = 1
            child_idx < tail.child_count
            child_idx = child_idx + 1 {
          if @ir.hot_child_get(func, tail_id, child_idx) != first_id {
            repeated = false
            break
          }
        }
        if repeated {
          return Some(expected_payloads)
        }
      }
    }
    let mut payloads = 0
    for child_idx = 0; child_idx < tail.child_count; child_idx = child_idx + 1 {
      let child_id = @ir.hot_child_get(func, tail_id, child_idx)
      if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
        return None
      }
      payloads += @ir.hot_node_result_arity(func, child_id)
    }
    Some(payloads)
  }
  match target {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return =>
          if tail.child_count > 0 {
            child_payloads()
          } else {
            stack_payloads()
          }
        _ => None
      }
    BranchTarget(target) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == target =>
          if tail.child_count > 0 {
            child_payloads()
          } else {
            stack_payloads()
          }
        _ => None
      }
    NoTarget => None
  }
}

///|
fn remove_unused_brs_strip_tail_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target : RemoveUnusedBrsTailTarget,
) -> Bool {
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let tail = @ir.hot_node_get(func, tail_id)
  match target {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return => ()
        _ => return false
      }
    BranchTarget(label_id) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == label_id => ()
        _ => return false
      }
    NoTarget => return false
  }
  if tail.child_count == 0 {
    remove_unused_brs_replace_with_nop(ctx, func, tail_id)
  } else if tail.child_count == 1 {
    remove_unused_brs_replace_with_child(
      ctx,
      func,
      tail_id,
      @ir.hot_child_get(func, tail_id, 0),
    )
  } else {
    remove_unused_brs_splice_tail_with_children(ctx, func, region_ref, tail_id)
  }
}

///|
fn remove_unused_brs_try_strip_tail_if_exits(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let if_node = @ir.hot_node_get(func, tail_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, tail_id)
  let else_ref = match @ir.hot_region_else_ref(func, tail_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let target = remove_unused_brs_tail_target(func, region_ref)
  match target {
    NoTarget => return false
    _ => ()
  }
  let result_arity = @ir.hot_node_result_arity(func, tail_id)
  let then_payloads = match
    remove_unused_brs_region_tail_control_payload_count(
      func, then_ref, target, result_arity,
    ) {
    Some(count) => count
    None => return false
  }
  let else_payloads = match
    remove_unused_brs_region_tail_control_payload_count(
      func, else_ref, target, result_arity,
    ) {
    Some(count) => count
    None => return false
  }
  if then_payloads != else_payloads || then_payloads != result_arity {
    return false
  }
  let mut changed = remove_unused_brs_strip_tail_control(
    ctx, func, then_ref, target,
  )
  changed = remove_unused_brs_strip_tail_control(ctx, func, else_ref, target) ||
    changed
  changed = remove_unused_brs_trim_trailing_nops(ctx, func, then_ref) || changed
  changed = remove_unused_brs_trim_trailing_nops(ctx, func, else_ref) || changed
  changed
}

///|
fn remove_unused_brs_region_result_arity(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  Some(@ir.hot_region_result_arity(func, region_ref))
}

///|
fn remove_unused_brs_try_strip_return_context_tail(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let expected_payloads = match
    remove_unused_brs_region_result_arity(func, region_ref) {
    Some(arity) => arity
    None => return false
  }
  let payloads = match
    remove_unused_brs_region_tail_control_payload_count(
      func,
      region_ref,
      ReturnTarget,
      expected_payloads,
    ) {
    Some(payloads) => payloads
    None => return false
  }
  if payloads != expected_payloads {
    return false
  }
  remove_unused_brs_strip_tail_control(ctx, func, region_ref, ReturnTarget)
}

///|
fn remove_unused_brs_try_rewrite_if_br(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  match @ir.hot_region_else_ref(func, node_id) {
    Some(_) => return false
    None => ()
  }
  let then_region = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_region) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_region, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  let condition = @ir.hot_child_get(func, node_id, 0)
  let replacement = match then_node.op {
    @ir.HotOp::Br => {
      if then_node.child_count != 0 {
        return false
      }
      @ir.hot_build_br_if(func, then_node.imm0, condition)
    }
    @ir.HotOp::BrIf => {
      if then_node.child_count != 1 {
        return false
      }
      let inner_condition = @ir.hot_child_get(func, then_root, 0)
      if !remove_unused_brs_node_is_reorder_safe(
          ctx, func, inner_condition, reorder_cache,
        ) ||
        !remove_unused_brs_node_is_reorder_safe(
          ctx, func, condition, reorder_cache,
        ) {
        return false
      }
      let zero = @ir.hot_build_const_i32(func, @lib.I32(0))
      let combined = remove_unused_brs_build_select(
        func,
        @lib.ValType::i32(),
        inner_condition,
        zero,
        condition,
      )
      @ir.hot_build_br_if(func, then_node.imm0, combined)
    }
    _ => return false
  }
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    replacement,
    then_region.holder,
    then_root,
  ])
  true
}

///|
fn remove_unused_brs_match_value_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
) -> RemoveUnusedBrsValueIfSelectRewrite? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 1 {
        return None
      }
    _ => return None
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => else_ref
    None => return None
  }
  let condition = @ir.hot_child_get(func, node_id, 0)
  let result_type = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))[0]
  let then_root = match
    remove_unused_brs_build_region_value_expr(
      ctx,
      func,
      remove_unused_brs_region_roots(func, then_ref),
      result_type,
      reorder_cache,
    ) {
    Some(expr) => expr
    None => return None
  }
  let else_root = match
    remove_unused_brs_build_region_value_expr(
      ctx,
      func,
      remove_unused_brs_region_roots(func, else_ref),
      result_type,
      reorder_cache,
    ) {
    Some(expr) => expr
    None => return None
  }
  if !remove_unused_brs_node_is_reorder_safe(
      ctx, func, condition, reorder_cache,
    ) {
    let then_node = @ir.hot_node_get(func, then_root)
    let else_node = @ir.hot_node_get(func, else_root)
    match then_node.op {
      @ir.HotOp::Const => ()
      _ => return None
    }
    match else_node.op {
      @ir.HotOp::Const => ()
      _ => return None
    }
  }
  Some({
    replacement: remove_unused_brs_build_select(
      func, result_type, then_root, else_root, condition,
    ),
    then_holder: then_ref.holder,
    else_holder: else_ref.holder,
  })
}

///|
fn remove_unused_brs_try_rewrite_value_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
) -> Bool {
  match
    remove_unused_brs_match_value_if_to_select(
      ctx, func, node_id, reorder_cache,
    ) {
    Some(rewrite) =>
      remove_unused_brs_replace_with_node(
        ctx,
        func,
        node_id,
        rewrite.replacement,
        detached=[rewrite.then_holder, rewrite.else_holder],
      )
    None => false
  }
}

///|
fn remove_unused_brs_try_merge_nested_if_conditions(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, node_id) {
    Some(_) => return false
    None => ()
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_ref) != 1 {
    return false
  }
  let child_if = @ir.hot_region_get(func, then_ref, 0)
  let child = @ir.hot_node_get(func, child_if)
  match child.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, child_if) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, child_if) {
    Some(_) => return false
    None => ()
  }
  let child_then_ref = @ir.hot_region_then_ref(func, child_if)
  let child_condition = @ir.hot_child_get(func, child_if, 0)
  if !remove_unused_brs_node_is_reorder_safe(
      ctx, func, child_condition, reorder_cache,
    ) ||
    !remove_unused_brs_node_is_reorder_safe(
      ctx,
      func,
      @ir.hot_child_get(func, node_id, 0),
      reorder_cache,
    ) {
    return false
  }
  let zero = @ir.hot_build_const_i32(func, @lib.I32(0))
  let combined = remove_unused_brs_build_select(
    func,
    @lib.ValType::i32(),
    child_condition,
    zero,
    @ir.hot_child_get(func, node_id, 0),
  )
  let child_then_roots : Array[Int] = []
  for idx = 0
      idx < @ir.hot_region_root_count(func, child_then_ref)
      idx = idx + 1 {
    child_then_roots.push(@ir.hot_region_get(func, child_then_ref, idx))
  }
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    combined,
    child_then_roots,
  )
  @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, replacement))
  pass_mark_mutated(ctx, func)
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    replacement,
    then_ref.holder,
    child_if,
    child_then_ref.holder,
  ])
  true
}

///|
fn remove_unused_brs_try_rewrite_region_local_set_copy_arm(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let node_id = @ir.hot_region_get(func, region_ref, idx)
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if node.child_count != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    return false
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, value_id) != 1 {
        return false
      }
    _ => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, value_id)
  let else_ref = match @ir.hot_region_else_ref(func, value_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  if @ir.hot_region_root_count(func, then_ref) != 1 ||
    @ir.hot_region_root_count(func, else_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let else_root = @ir.hot_region_get(func, else_ref, 0)
  let else_node = @ir.hot_node_get(func, else_root)
  match else_node.op {
    @ir.HotOp::LocalGet if else_node.imm0 == node.imm0 => ()
    _ => return false
  }
  let replacement_set = @ir.hot_build_local_set(func, node.imm0, then_root)
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, value_id, 0),
    [replacement_set],
  )
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [replacement])
  remove_unused_brs_delete_unused_nodes(
    ctx,
    func,
    removed + [value_id, then_ref.holder, else_ref.holder, else_root],
  )
  true
}

///|
fn remove_unused_brs_try_rewrite_region_local_set_br_arm(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let node_id = @ir.hot_region_get(func, region_ref, idx)
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  if node.child_count != 1 {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    return false
  }
  let value = @ir.hot_node_get(func, value_id)
  match value.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, value_id) != 1 {
        return false
      }
    _ => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, value_id)
  let else_ref = match @ir.hot_region_else_ref(func, value_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  if @ir.hot_region_root_count(func, then_ref) != 1 ||
    @ir.hot_region_root_count(func, else_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  match then_node.op {
    @ir.HotOp::Br if then_node.child_count == 0 => ()
    _ => return false
  }
  let condition = @ir.hot_child_get(func, value_id, 0)
  let branch = @ir.hot_build_br_if(func, then_node.imm0, condition)
  let replacement_set = @ir.hot_build_local_set(
    func,
    node.imm0,
    @ir.hot_region_get(func, else_ref, 0),
  )
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
    branch, replacement_set,
  ])
  remove_unused_brs_delete_unused_nodes(
    ctx,
    func,
    removed + [value_id, then_ref.holder, then_root, else_ref.holder],
  )
  true
}

///|
fn remove_unused_brs_try_rewrite_two_arm_branch_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  if @ir.hot_region_root_count(func, then_ref) != 1 ||
    @ir.hot_region_root_count(func, else_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let else_root = @ir.hot_region_get(func, else_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  let else_node = @ir.hot_node_get(func, else_root)
  match then_node.op {
    @ir.HotOp::Br if then_node.child_count == 0 => ()
    _ => return false
  }
  match else_node.op {
    @ir.HotOp::Br if else_node.child_count == 0 => ()
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if then_node.imm0 == if_label || else_node.imm0 == if_label {
    return false
  }
  if then_node.imm0 == else_node.imm0 {
    let replacement = @ir.hot_build_br(func, then_node.imm0)
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
      replacement,
    ])
    let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
    for removed_id in removed {
      @ir.hot_replace_node(func, removed_id, nop_node)
    }
    @ir.hot_replace_node(func, if_id, nop_node)
    @ir.hot_replace_node(func, then_ref.holder, nop_node)
    @ir.hot_replace_node(func, then_root, nop_node)
    @ir.hot_replace_node(func, else_ref.holder, nop_node)
    @ir.hot_replace_node(func, else_root, nop_node)
    return true
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  let branch_if = @ir.hot_build_br_if(func, then_node.imm0, condition)
  let branch = @ir.hot_build_br(func, else_node.imm0)
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
    branch_if, branch,
  ])
  let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
  for removed_id in removed {
    @ir.hot_replace_node(func, removed_id, nop_node)
  }
  @ir.hot_replace_node(func, if_id, nop_node)
  @ir.hot_replace_node(func, then_ref.holder, nop_node)
  @ir.hot_replace_node(func, then_root, nop_node)
  @ir.hot_replace_node(func, else_ref.holder, nop_node)
  @ir.hot_replace_node(func, else_root, nop_node)
  true
}

///|
fn remove_unused_brs_region_split_payload_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  result_arity : Int,
) -> (Array[Int], Array[Int])? {
  remove_unused_brs_split_payload_roots(
    func,
    remove_unused_brs_region_roots(func, region_ref),
    result_arity,
  )
}

///|
fn remove_unused_brs_split_payload_roots(
  func : @ir.HotFunc,
  roots : Array[Int],
  result_arity : Int,
) -> (Array[Int], Array[Int])? {
  if result_arity <= 0 {
    return Some((roots, []))
  }
  let mut payload_arity = 0
  let mut payload_start = roots.length()
  while payload_start > 0 && payload_arity < result_arity {
    let candidate = roots[payload_start - 1]
    let candidate_arity = @ir.hot_node_result_arity(func, candidate)
    if candidate_arity <= 0 {
      return None
    }
    payload_arity += candidate_arity
    payload_start -= 1
  }
  if payload_arity != result_arity {
    return None
  }
  let prefix : Array[Int] = []
  for idx = 0; idx < payload_start; idx = idx + 1 {
    prefix.push(roots[idx])
  }
  let payload : Array[Int] = []
  for idx = payload_start; idx < roots.length(); idx = idx + 1 {
    payload.push(roots[idx])
  }
  Some((prefix, payload))
}

///|
fn remove_unused_brs_region_roots_are_reorder_safe(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  roots : Array[Int],
  reorder_cache : Array[Int],
) -> Bool {
  for root_id in roots {
    if @ir.cfg_terminator_edge_kinds(@ir.hot_node_get(func, root_id).op).length() >
      0 {
      return false
    }
    if !remove_unused_brs_node_is_reorder_safe(
        ctx, func, root_id, reorder_cache,
      ) {
      return false
    }
  }
  true
}

///|
fn remove_unused_brs_build_region_value_expr(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  roots : Array[Int],
  result_type : @lib.ValType,
  reorder_cache : Array[Int],
) -> Int? {
  let (prefix, payload) = match
    remove_unused_brs_split_payload_roots(func, roots, 1) {
    Some(split) => split
    None => return None
  }
  if !remove_unused_brs_region_roots_are_reorder_safe(
      ctx,
      func,
      prefix + payload,
      reorder_cache,
    ) {
    return None
  }
  if prefix.is_empty() && payload.length() == 1 {
    return Some(payload[0])
  }
  let block_roots : Array[Int] = []
  for root_id in prefix {
    block_roots.push(root_id)
  }
  for root_id in payload {
    block_roots.push(root_id)
  }
  Some(
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(result_type),
      block_roots,
    ),
  )
}

///|
fn remove_unused_brs_build_stack_exit_region_value_expr(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target : RemoveUnusedBrsTailTarget,
  result_type : @lib.ValType,
  reorder_cache : Array[Int],
) -> Int? {
  let roots = remove_unused_brs_region_roots(func, region_ref)
  if roots.is_empty() {
    return None
  }
  let tail_id = roots[roots.length() - 1]
  let tail = @ir.hot_node_get(func, tail_id)
  match target {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return => ()
        _ => return None
      }
    BranchTarget(label_id) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == label_id => ()
        _ => return None
      }
    NoTarget => return None
  }
  let payload_roots : Array[Int] = []
  for idx = 0; idx < roots.length() - 1; idx = idx + 1 {
    payload_roots.push(roots[idx])
  }
  for child_idx = 0; child_idx < tail.child_count; child_idx = child_idx + 1 {
    let child_id = @ir.hot_child_get(func, tail_id, child_idx)
    if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
      payload_roots.push(child_id)
    }
  }
  remove_unused_brs_build_region_value_expr(
    ctx, func, payload_roots, result_type, reorder_cache,
  )
}

///|
fn remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  reorder_cache : Array[Int],
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  let tail_idx = root_count - 1
  let if_id = @ir.hot_region_get(func, region_ref, tail_idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 1 {
        return false
      }
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  let target = remove_unused_brs_tail_target(func, region_ref)
  match target {
    NoTarget => return false
    _ => ()
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let result_type = @ir.hot_type_results(func, @ir.hot_node_type(func, if_id))[0]
  let try_build = fn(then_value : Int?, else_value : Int?) -> Bool {
    let then_value = match then_value {
      Some(expr) => expr
      None => return false
    }
    let else_value = match else_value {
      Some(expr) => expr
      None => return false
    }
    let replacement = remove_unused_brs_build_select(
      func, result_type, then_value, else_value, condition,
    )
    remove_unused_brs_replace_with_node(ctx, func, if_id, replacement, detached=[
      then_ref.holder,
      else_ref.holder,
    ])
  }
  if try_build(
      remove_unused_brs_build_stack_exit_region_value_expr(
        ctx, func, then_ref, target, result_type, reorder_cache,
      ),
      remove_unused_brs_build_region_value_expr(
        ctx,
        func,
        remove_unused_brs_region_roots(func, else_ref),
        result_type,
        reorder_cache,
      ),
    ) {
    return true
  }
  try_build(
    remove_unused_brs_build_region_value_expr(
      ctx,
      func,
      remove_unused_brs_region_roots(func, then_ref),
      result_type,
      reorder_cache,
    ),
    remove_unused_brs_build_stack_exit_region_value_expr(
      ctx, func, else_ref, target, result_type, reorder_cache,
    ),
  )
}

///|
fn remove_unused_brs_label_is_used(
  label_refs : Array[Int],
  label_id : Int,
) -> Bool {
  label_id >= 0 && label_id < label_refs.length() && label_refs[label_id] > 0
}

///|
fn remove_unused_brs_try_rewrite_branch_payload_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let br_id = @ir.hot_region_get(func, region_ref, idx)
  let br_node = @ir.hot_node_get(func, br_id)
  let if_id = match br_node.op {
    @ir.HotOp::Br if br_node.child_count >= 1 => {
      let candidate = @ir.hot_child_get(func, br_id, 0)
      for child_idx = 1
          child_idx < br_node.child_count
          child_idx = child_idx + 1 {
        if @ir.hot_child_get(func, br_id, child_idx) != candidate {
          return false
        }
      }
      candidate
    }
    _ => return false
  }
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) <= 0 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let result_arity = @ir.hot_node_result_arity(func, if_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let try_build = fn(
    branch_ref : @ir.HotRegionRef,
    body_ref : @ir.HotRegionRef,
    negate_condition : Bool,
  ) -> Bool {
    if @ir.hot_region_root_count(func, branch_ref) != 1 {
      return false
    }
    let branch_root = @ir.hot_region_get(func, branch_ref, 0)
    let branch_node = @ir.hot_node_get(func, branch_root)
    match branch_node.op {
      @ir.HotOp::Br if branch_node.child_count == 0 => ()
      _ => return false
    }
    if branch_node.imm0 == if_label {
      return false
    }
    let (body_prefix, body_payload) = match
      remove_unused_brs_region_split_payload_roots(func, body_ref, result_arity) {
      Some(split) => split
      None => return false
    }
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, if_id, 0))
    } else {
      @ir.hot_child_get(func, if_id, 0)
    }
    let guard_branch = @ir.hot_build_br_if(
      func,
      branch_node.imm0,
      guard_condition,
    )
    let exit_branch = @ir.hot_build_br(func, br_node.imm0, values=body_payload)
    let replacement = [guard_branch] + body_prefix + [exit_branch]
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, replacement)
    let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
    for removed_id in removed {
      @ir.hot_replace_node(func, removed_id, nop_node)
    }
    @ir.hot_replace_node(func, br_id, nop_node)
    @ir.hot_replace_node(func, if_id, nop_node)
    @ir.hot_replace_node(func, then_ref.holder, nop_node)
    @ir.hot_replace_node(func, else_ref.holder, nop_node)
    true
  }
  if try_build(else_ref, then_ref, true) {
    return true
  }
  try_build(then_ref, else_ref, false)
}

///|
fn remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_idx = @ir.hot_region_root_count(func, region_ref) - 1
  let if_id = @ir.hot_region_get(func, region_ref, tail_idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) <= 0 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let result_arity = @ir.hot_node_result_arity(func, if_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let try_build = fn(
    branch_ref : @ir.HotRegionRef,
    body_ref : @ir.HotRegionRef,
    negate_condition : Bool,
  ) -> Bool {
    if @ir.hot_region_root_count(func, branch_ref) != 1 {
      return false
    }
    let branch_root = @ir.hot_region_get(func, branch_ref, 0)
    let branch_node = @ir.hot_node_get(func, branch_root)
    match branch_node.op {
      @ir.HotOp::Br if branch_node.child_count == 0 => ()
      _ => return false
    }
    if branch_node.imm0 == if_label {
      return false
    }
    let (body_prefix, body_payload) = match
      remove_unused_brs_region_split_payload_roots(func, body_ref, result_arity) {
      Some(split) => split
      None => return false
    }
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, if_id, 0))
    } else {
      @ir.hot_child_get(func, if_id, 0)
    }
    let guard_branch = @ir.hot_build_br_if(
      func,
      branch_node.imm0,
      guard_condition,
    )
    let replacement = [guard_branch] + body_prefix + body_payload
    let removed = pass_splice_region(
      ctx, func, region_ref, tail_idx, 1, replacement,
    )
    let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
    for removed_id in removed {
      @ir.hot_replace_node(func, removed_id, nop_node)
    }
    @ir.hot_replace_node(func, if_id, nop_node)
    @ir.hot_replace_node(func, then_ref.holder, nop_node)
    @ir.hot_replace_node(func, else_ref.holder, nop_node)
    true
  }
  if try_build(else_ref, then_ref, true) {
    return true
  }
  try_build(then_ref, else_ref, false)
}

///|
fn remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  let tail_idx = root_count - 1
  let if_id = @ir.hot_region_get(func, region_ref, tail_idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 1 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let region_prefix : Array[Int] = []
  for idx = 0; idx < tail_idx; idx = idx + 1 {
    region_prefix.push(@ir.hot_region_get(func, region_ref, idx))
  }
  let result_type = @ir.hot_type_results(func, @ir.hot_node_type(func, if_id))[0]
  let try_build = fn(
    simple_ref : @ir.HotRegionRef,
    body_ref : @ir.HotRegionRef,
    negate_condition : Bool,
  ) -> Bool {
    let (simple_prefix, simple_payload) = match
      remove_unused_brs_region_split_payload_roots(func, simple_ref, 1) {
      Some(split) => split
      None => return false
    }
    for root_id in simple_prefix {
      if @ir.cfg_terminator_edge_kinds(@ir.hot_node_get(func, root_id).op).length() >
        0 {
        return false
      }
    }
    let block_id = @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(result_type),
      [],
    )
    let target = @ir.hot_control_node_label(func, block_id)
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, if_id, 0))
    } else {
      @ir.hot_child_get(func, if_id, 0)
    }
    let exit_branch = @ir.hot_build_br(func, target, values=simple_payload)
    let guard_if = @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      guard_condition,
      simple_prefix + [exit_branch],
    )
    let block_body = region_prefix +
      [guard_if] +
      remove_unused_brs_region_roots(func, body_ref)
    @ir.hot_region_replace_body(
      func,
      @ir.hot_region_body_ref(func, block_id),
      block_body,
    )
    ignore(pass_splice_region(ctx, func, region_ref, 0, root_count, [block_id]))
    let nop_node = @ir.hot_node_get(func, @ir.hot_build_nop(func))
    @ir.hot_replace_node(func, if_id, nop_node)
    @ir.hot_replace_node(func, then_ref.holder, nop_node)
    @ir.hot_replace_node(func, else_ref.holder, nop_node)
    pass_mark_mutated(ctx, func)
    true
  }
  if try_build(then_ref, else_ref, false) {
    return true
  }
  try_build(else_ref, then_ref, true)
}

///|
fn remove_unused_brs_try_flatten_block_if_chain(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() ||
    idx < 0 ||
    idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let holder = region_ref.holder
  if holder < 0 || !@ir.hot_node_is_live(func, holder) {
    return false
  }
  match @ir.hot_node_get(func, holder).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  if @ir.hot_region_root_count(func, then_ref) != 1 {
    return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  let target = @ir.hot_control_node_label(func, holder)
  let condition = @ir.hot_child_get(func, if_id, 0)
  match then_node.op {
    @ir.HotOp::Br if then_node.imm0 == target && then_node.child_count == 0 => {
      let branch = @ir.hot_build_br_if(func, target, condition)
      let replacement = [branch]
      for root_idx = 0
          root_idx < @ir.hot_region_root_count(func, else_ref)
          root_idx = root_idx + 1 {
        replacement.push(@ir.hot_region_get(func, else_ref, root_idx))
      }
      ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
      pass_delete_detached_nodes(ctx, func, [
        if_id,
        then_ref.holder,
        then_root,
        else_ref.holder,
      ])
      true
    }
    _ => {
      if @ir.hot_region_root_count(func, else_ref) != 1 {
        return false
      }
      let else_root = @ir.hot_region_get(func, else_ref, 0)
      let else_node = @ir.hot_node_get(func, else_root)
      match else_node.op {
        @ir.HotOp::Br if else_node.imm0 == target && else_node.child_count == 0 =>
          ()
        _ => return false
      }
      let branch = @ir.hot_build_br_if(
        func,
        target,
        remove_unused_brs_build_i32_eqz(func, condition),
      )
      let replacement = [branch]
      for root_idx = 0
          root_idx < @ir.hot_region_root_count(func, then_ref)
          root_idx = root_idx + 1 {
        replacement.push(@ir.hot_region_get(func, then_ref, root_idx))
      }
      ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
      pass_delete_detached_nodes(ctx, func, [
        if_id,
        then_ref.holder,
        else_ref.holder,
        else_root,
      ])
      true
    }
  }
}

///|
fn remove_unused_brs_flatten_block_if_chains(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() {
    return false
  }
  let holder = region_ref.holder
  if holder < 0 || !@ir.hot_node_is_live(func, holder) {
    return false
  }
  match @ir.hot_node_get(func, holder).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    if remove_unused_brs_try_flatten_block_if_chain(
        ctx, func, region_ref, idx, label_refs,
      ) {
      changed = true
      continue
    }
    idx += 1
  }
  changed
}

///|
fn remove_unused_brs_is_region_child_slot(op : @ir.HotOp, slot : Int) -> Bool {
  for info in @ir.hot_control_region_slot_info(op) {
    if info.slot == slot {
      return true
    }
  }
  false
}

///|
fn remove_unused_brs_preserves_payload_context(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::LocalTee | @ir.HotOp::TupleExtract => true
    _ => false
  }
}

///|
fn remove_unused_brs_mark_seen(
  seen : Array[Int],
  node_id : Int,
  payload_context : Bool,
  return_context : Bool,
) -> Bool {
  while seen.length() <= node_id {
    seen.push(0)
  }
  let mut mode = 1
  if payload_context {
    mode = mode | 2
  }
  if return_context {
    mode = mode | 4
  }
  if (seen[node_id] & mode) == mode {
    return false
  }
  seen[node_id] = seen[node_id] | mode
  true
}

///|
fn remove_unused_brs_control_cache_resize(
  cache : Array[Int],
  node_id : Int,
) -> Unit {
  while cache.length() <= node_id {
    cache.push(-1)
  }
}

///|
fn remove_unused_brs_return_cache_resize(
  cache : Array[Int],
  node_id : Int,
) -> Unit {
  while cache.length() <= node_id {
    cache.push(-1)
  }
}

///|
fn remove_unused_brs_subtree_has_return(
  func : @ir.HotFunc,
  node_id : Int,
  cache : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  remove_unused_brs_return_cache_resize(cache, node_id)
  match cache[node_id] {
    0 => return false
    1 => return true
    _ => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut has_return = match node.op {
    @ir.HotOp::Return => true
    _ => false
  }
  if !has_return {
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      if remove_unused_brs_is_region_child_slot(node.op, slot) {
        continue
      }
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if remove_unused_brs_subtree_has_return(func, child_id, cache) {
        has_return = true
        break
      }
    }
  }
  if !has_return {
    let scan_region = fn(region_ref : @ir.HotRegionRef) -> Bool {
      for idx = 0
          idx < @ir.hot_region_root_count(func, region_ref)
          idx = idx + 1 {
        if remove_unused_brs_subtree_has_return(
            func,
            @ir.hot_region_get(func, region_ref, idx),
            cache,
          ) {
          return true
        }
      }
      false
    }
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        has_return = scan_region(@ir.hot_region_body_ref(func, node_id))
      @ir.HotOp::If => {
        has_return = scan_region(@ir.hot_region_then_ref(func, node_id))
        if !has_return {
          match @ir.hot_region_else_ref(func, node_id) {
            Some(else_ref) => has_return = scan_region(else_ref)
            None => ()
          }
        }
      }
      @ir.HotOp::Try => {
        has_return = scan_region(@ir.hot_region_body_ref(func, node_id))
        if !has_return {
          match @ir.hot_region_catch_ref(func, node_id) {
            Some(catch_ref) => has_return = scan_region(catch_ref)
            None => ()
          }
        }
      }
      @ir.HotOp::TryTable => {
        has_return = scan_region(@ir.hot_region_body_ref(func, node_id))
        if !has_return {
          has_return = scan_region(@ir.hot_region_catch_list_ref(func, node_id))
        }
      }
      _ => ()
    }
  }
  cache[node_id] = if has_return { 1 } else { 0 }
  has_return
}

///|
fn remove_unused_brs_subtree_has_embedded_control(
  func : @ir.HotFunc,
  node_id : Int,
  cache : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  remove_unused_brs_control_cache_resize(cache, node_id)
  match cache[node_id] {
    0 => return false
    1 => return true
    _ => ()
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut has_control = match node.op {
    @ir.HotOp::If
    | @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
  if !has_control {
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      if remove_unused_brs_is_region_child_slot(node.op, slot) {
        continue
      }
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if remove_unused_brs_subtree_has_embedded_control(func, child_id, cache) {
        has_control = true
        break
      }
    }
  }
  cache[node_id] = if has_control { 1 } else { 0 }
  has_control
}

///|
fn remove_unused_brs_visit_embedded_subtree(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  payload_context : Bool,
  return_context : Bool,
  control_cache : Array[Int],
  return_cache : Array[Int],
) -> Bool {
  if !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if !remove_unused_brs_subtree_has_embedded_control(
      func, node_id, control_cache,
    ) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If
    | @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable =>
      return remove_unused_brs_visit_node(
        ctx,
        func,
        node_id,
        seen,
        reorder_cache,
        label_refs,
        payload_context,
        return_context &&
        (
          remove_unused_brs_subtree_has_return(func, node_id, return_cache) ||
          @ir.hot_node_result_arity(func, node_id) > 0
        ),
        control_cache,
        return_cache,
      )
    _ => ()
  }
  let mut changed = false
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if remove_unused_brs_is_region_child_slot(node.op, slot) {
      continue
    }
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    let child_payload_context = payload_context &&
      remove_unused_brs_preserves_payload_context(node.op)
    changed = remove_unused_brs_visit_embedded_subtree(
        ctx, func, child_id, seen, reorder_cache, label_refs, child_payload_context,
        false, control_cache, return_cache,
      ) ||
      changed
  }
  changed
}

///|
fn remove_unused_brs_visit_generic_children(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  control_cache : Array[Int],
  return_cache : Array[Int],
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  let mut changed = false
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if remove_unused_brs_is_region_child_slot(node.op, slot) {
      continue
    }
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    changed = remove_unused_brs_visit_embedded_subtree(
        ctx, func, child_id, seen, reorder_cache, label_refs, false, false, control_cache,
        return_cache,
      ) ||
      changed
  }
  changed
}

///|
fn remove_unused_brs_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  payload_context : Bool,
  return_context : Bool,
  control_cache : Array[Int],
  return_cache : Array[Int],
) -> Bool {
  if !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if !remove_unused_brs_mark_seen(
      seen, node_id, payload_context, return_context,
    ) {
    return false
  }
  let mut changed = false
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let allow_payload_rewrites = payload_context && !return_context
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache, label_refs, return_context, control_cache,
          return_cache,
        ) ||
        changed
      let body_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, body_ref,
      )
      if return_context && body_tail_id_for_return >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id_for_return).op
        match body_tail_op {
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_strip_return_context_tail(
                ctx, func, body_ref,
              ) ||
              changed
          _ => ()
        }
      }
      if allow_payload_rewrites {
        changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
            ctx, func, body_ref, label_refs,
          ) ||
          changed
        changed = remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(
            ctx, func, body_ref, label_refs,
          ) ||
          changed
      }
      changed = remove_unused_brs_flatten_block_if_chains(
          ctx, func, body_ref, label_refs,
        ) ||
        changed
      let body_tail_id = remove_unused_brs_region_tail_id(func, body_ref)
      if body_tail_id >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id).op
        match body_tail_op {
          @ir.HotOp::If => {
            changed = remove_unused_brs_try_strip_tail_if_exits(
                ctx, func, body_ref,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                ctx, func, body_ref, reorder_cache, label_refs,
              ) ||
              changed
          }
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_voidify_tail_return_if(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
          @ir.HotOp::Nop =>
            changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
              changed
          _ => ()
        }
      }
      if body_tail_id >= 0 &&
        remove_unused_brs_region_has_removable_tail_target(func, body_ref) {
        changed = remove_unused_brs_try_remove_region_tail(
            ctx, func, body_ref, reorder_cache,
          ) ||
          changed
      }
    }
    @ir.HotOp::If => {
      changed = remove_unused_brs_visit_embedded_subtree(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 0),
          seen,
          reorder_cache,
          label_refs,
          false,
          false,
          control_cache,
          return_cache,
        ) ||
        changed
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, then_ref, seen, reorder_cache, label_refs, return_context, control_cache,
          return_cache,
        ) ||
        changed
      let then_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, then_ref,
      )
      if return_context && then_tail_id_for_return >= 0 {
        let then_tail_op = @ir.hot_node_get(func, then_tail_id_for_return).op
        match then_tail_op {
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_strip_return_context_tail(
                ctx, func, then_ref,
              ) ||
              changed
          _ => ()
        }
      }
      if payload_context && !return_context {
        changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
            ctx, func, then_ref, label_refs,
          ) ||
          changed
        changed = remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(
            ctx, func, then_ref, label_refs,
          ) ||
          changed
      }
      let then_tail_id = remove_unused_brs_region_tail_id(func, then_ref)
      if then_tail_id >= 0 {
        let then_tail_op = @ir.hot_node_get(func, then_tail_id).op
        match then_tail_op {
          @ir.HotOp::If => {
            changed = remove_unused_brs_try_strip_tail_if_exits(
                ctx, func, then_ref,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                ctx, func, then_ref, reorder_cache, label_refs,
              ) ||
              changed
          }
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_voidify_tail_return_if(
                ctx, func, then_ref, label_refs,
              ) ||
              changed
          @ir.HotOp::Nop =>
            changed = remove_unused_brs_trim_trailing_nops(ctx, func, then_ref) ||
              changed
          _ => ()
        }
      }
      if then_tail_id >= 0 &&
        remove_unused_brs_region_has_removable_tail_target(func, then_ref) {
        changed = remove_unused_brs_try_remove_region_tail(
            ctx, func, then_ref, reorder_cache,
          ) ||
          changed
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          changed = remove_unused_brs_visit_region(
              ctx, func, else_ref, seen, reorder_cache, label_refs, return_context,
              control_cache, return_cache,
            ) ||
            changed
          let else_tail_id_for_return = remove_unused_brs_region_tail_id(
            func, else_ref,
          )
          if return_context && else_tail_id_for_return >= 0 {
            let else_tail_op = @ir.hot_node_get(func, else_tail_id_for_return).op
            match else_tail_op {
              @ir.HotOp::Return =>
                changed = remove_unused_brs_try_strip_return_context_tail(
                    ctx, func, else_ref,
                  ) ||
                  changed
              _ => ()
            }
          }
          if payload_context && !return_context {
            changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
                ctx, func, else_ref, label_refs,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(
                ctx, func, else_ref, label_refs,
              ) ||
              changed
          }
          let else_tail_id = remove_unused_brs_region_tail_id(func, else_ref)
          if else_tail_id >= 0 {
            let else_tail_op = @ir.hot_node_get(func, else_tail_id).op
            match else_tail_op {
              @ir.HotOp::If => {
                changed = remove_unused_brs_try_strip_tail_if_exits(
                    ctx, func, else_ref,
                  ) ||
                  changed
                changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                    ctx, func, else_ref, reorder_cache, label_refs,
                  ) ||
                  changed
              }
              @ir.HotOp::Return =>
                changed = remove_unused_brs_try_voidify_tail_return_if(
                    ctx, func, else_ref, label_refs,
                  ) ||
                  changed
              @ir.HotOp::Nop =>
                changed = remove_unused_brs_trim_trailing_nops(
                    ctx, func, else_ref,
                  ) ||
                  changed
              _ => ()
            }
          }
          if else_tail_id >= 0 &&
            remove_unused_brs_region_has_removable_tail_target(func, else_ref) {
            changed = remove_unused_brs_try_remove_region_tail(
                ctx, func, else_ref, reorder_cache,
              ) ||
              changed
          }
        }
        None => ()
      }
      if payload_context &&
        remove_unused_brs_try_voidify_exit_only_value_if(ctx, func, node_id) {
        return true
      }
      changed = remove_unused_brs_try_rewrite_value_if_to_select(
          ctx, func, node_id, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_merge_nested_if_conditions(
          ctx, func, node_id, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_rewrite_if_br(
          ctx, func, node_id, reorder_cache,
        ) ||
        changed
    }
    @ir.HotOp::LocalSet =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        changed = remove_unused_brs_visit_embedded_subtree(
            ctx, func, child_id, seen, reorder_cache, label_refs, true, false, control_cache,
            return_cache,
          ) ||
          changed
      }
    @ir.HotOp::Drop =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        changed = remove_unused_brs_visit_embedded_subtree(
            ctx, func, child_id, seen, reorder_cache, label_refs, true, false, control_cache,
            return_cache,
          ) ||
          changed
      }
    @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::BrTable | @ir.HotOp::Return =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        let child_payload_context = match @ir.hot_node_get(func, node_id).op {
          @ir.HotOp::Br => true
          @ir.HotOp::Return => true
          @ir.HotOp::BrIf => slot < @ir.hot_child_count(func, node_id) - 1
          @ir.HotOp::BrTable => slot < @ir.hot_child_count(func, node_id) - 1
          _ => false
        }
        let child_return_context = match @ir.hot_node_get(func, node_id).op {
          @ir.HotOp::Return => true
          _ => false
        }
        changed = remove_unused_brs_visit_embedded_subtree(
            ctx, func, child_id, seen, reorder_cache, label_refs, child_payload_context,
            child_return_context, control_cache, return_cache,
          ) ||
          changed
      }
    @ir.HotOp::Try => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache, label_refs, return_context, control_cache,
          return_cache,
        ) ||
        changed
      let body_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, body_ref,
      )
      if return_context && body_tail_id_for_return >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id_for_return).op
        match body_tail_op {
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_strip_return_context_tail(
                ctx, func, body_ref,
              ) ||
              changed
          _ => ()
        }
      }
      let body_tail_id = remove_unused_brs_region_tail_id(func, body_ref)
      if body_tail_id >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id).op
        match body_tail_op {
          @ir.HotOp::If => {
            changed = remove_unused_brs_try_strip_tail_if_exits(
                ctx, func, body_ref,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                ctx, func, body_ref, reorder_cache, label_refs,
              ) ||
              changed
          }
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_voidify_tail_return_if(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
          @ir.HotOp::Nop =>
            changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
              changed
          _ => ()
        }
      }
      if body_tail_id >= 0 &&
        remove_unused_brs_region_has_removable_tail_target(func, body_ref) {
        changed = remove_unused_brs_try_remove_region_tail(
            ctx, func, body_ref, reorder_cache,
          ) ||
          changed
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          changed = remove_unused_brs_visit_region(
              ctx, func, catch_ref, seen, reorder_cache, label_refs, return_context,
              control_cache, return_cache,
            ) ||
            changed
          let catch_tail_id_for_return = remove_unused_brs_region_tail_id(
            func, catch_ref,
          )
          if return_context && catch_tail_id_for_return >= 0 {
            let catch_tail_op = @ir.hot_node_get(func, catch_tail_id_for_return).op
            match catch_tail_op {
              @ir.HotOp::Return =>
                changed = remove_unused_brs_try_strip_return_context_tail(
                    ctx, func, catch_ref,
                  ) ||
                  changed
              _ => ()
            }
          }
          let catch_tail_id = remove_unused_brs_region_tail_id(func, catch_ref)
          if catch_tail_id >= 0 {
            let catch_tail_op = @ir.hot_node_get(func, catch_tail_id).op
            match catch_tail_op {
              @ir.HotOp::If => {
                changed = remove_unused_brs_try_strip_tail_if_exits(
                    ctx, func, catch_ref,
                  ) ||
                  changed
                changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                    ctx, func, catch_ref, reorder_cache, label_refs,
                  ) ||
                  changed
              }
              @ir.HotOp::Return =>
                changed = remove_unused_brs_try_voidify_tail_return_if(
                    ctx, func, catch_ref, label_refs,
                  ) ||
                  changed
              @ir.HotOp::Nop =>
                changed = remove_unused_brs_trim_trailing_nops(
                    ctx, func, catch_ref,
                  ) ||
                  changed
              _ => ()
            }
          }
          if catch_tail_id >= 0 &&
            remove_unused_brs_region_has_removable_tail_target(func, catch_ref) {
            changed = remove_unused_brs_try_remove_region_tail(
                ctx, func, catch_ref, reorder_cache,
              ) ||
              changed
          }
        }
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache, label_refs, return_context, control_cache,
          return_cache,
        ) ||
        changed
      let body_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, body_ref,
      )
      if return_context && body_tail_id_for_return >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id_for_return).op
        match body_tail_op {
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_strip_return_context_tail(
                ctx, func, body_ref,
              ) ||
              changed
          _ => ()
        }
      }
      let body_tail_id = remove_unused_brs_region_tail_id(func, body_ref)
      if body_tail_id >= 0 {
        let body_tail_op = @ir.hot_node_get(func, body_tail_id).op
        match body_tail_op {
          @ir.HotOp::If => {
            changed = remove_unused_brs_try_strip_tail_if_exits(
                ctx, func, body_ref,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                ctx, func, body_ref, reorder_cache, label_refs,
              ) ||
              changed
          }
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_voidify_tail_return_if(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
          @ir.HotOp::Nop =>
            changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
              changed
          _ => ()
        }
      }
      if body_tail_id >= 0 &&
        remove_unused_brs_region_has_removable_tail_target(func, body_ref) {
        changed = remove_unused_brs_try_remove_region_tail(
            ctx, func, body_ref, reorder_cache,
          ) ||
          changed
      }
      let catch_list_ref = @ir.hot_region_catch_list_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, catch_list_ref, seen, reorder_cache, label_refs, return_context,
          control_cache, return_cache,
        ) ||
        changed
      let catch_list_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, catch_list_ref,
      )
      if return_context && catch_list_tail_id_for_return >= 0 {
        let catch_list_tail_op = @ir.hot_node_get(
            func, catch_list_tail_id_for_return,
          ).op
        match catch_list_tail_op {
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_strip_return_context_tail(
                ctx, func, catch_list_ref,
              ) ||
              changed
          _ => ()
        }
      }
      let catch_list_tail_id = remove_unused_brs_region_tail_id(
        func, catch_list_ref,
      )
      if catch_list_tail_id >= 0 {
        let catch_list_tail_op = @ir.hot_node_get(func, catch_list_tail_id).op
        match catch_list_tail_op {
          @ir.HotOp::If => {
            changed = remove_unused_brs_try_strip_tail_if_exits(
                ctx, func, catch_list_ref,
              ) ||
              changed
            changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                ctx, func, catch_list_ref, reorder_cache, label_refs,
              ) ||
              changed
          }
          @ir.HotOp::Return =>
            changed = remove_unused_brs_try_voidify_tail_return_if(
                ctx, func, catch_list_ref, label_refs,
              ) ||
              changed
          @ir.HotOp::Nop =>
            changed = remove_unused_brs_trim_trailing_nops(
                ctx, func, catch_list_ref,
              ) ||
              changed
          _ => ()
        }
      }
      if catch_list_tail_id >= 0 &&
        remove_unused_brs_region_has_removable_tail_target(func, catch_list_ref) {
        changed = remove_unused_brs_try_remove_region_tail(
            ctx, func, catch_list_ref, reorder_cache,
          ) ||
          changed
      }
    }
    _ =>
      changed = remove_unused_brs_visit_generic_children(
          ctx, func, node_id, seen, reorder_cache, label_refs, control_cache, return_cache,
        ) ||
        changed
  }
  changed
}

///|
fn remove_unused_brs_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  return_context : Bool,
  control_cache : Array[Int],
  return_cache : Array[Int],
) -> Bool {
  let mut changed = false
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  for idx = 0; idx < roots.length(); idx = idx + 1 {
    let node_id = roots[idx]
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if !remove_unused_brs_subtree_has_embedded_control(
        func, node_id, control_cache,
      ) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Br =>
        if remove_unused_brs_try_rewrite_branch_payload_if(
            ctx, func, region_ref, idx, label_refs,
          ) {
          changed = true
          continue
        }
      @ir.HotOp::If =>
        if remove_unused_brs_try_rewrite_two_arm_branch_if(
            ctx, func, region_ref, idx,
          ) {
          changed = true
          continue
        }
      @ir.HotOp::LocalSet => {
        if remove_unused_brs_try_rewrite_region_local_set_br_arm(
            ctx, func, region_ref, idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_region_local_set_copy_arm(
            ctx, func, region_ref, idx,
          ) {
          changed = true
          continue
        }
      }
      _ => ()
    }
    let node_return_context = return_context && idx == roots.length() - 1
    changed = remove_unused_brs_visit_node(
        ctx, func, node_id, seen, reorder_cache, label_refs, false, node_return_context,
        control_cache, return_cache,
      ) ||
      changed
  }
  changed
}

///|
fn remove_unused_brs_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if remove_unused_brs_can_skip_large_void_return_ladder(func) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=large-void-if-return-ladder-noop",
    )
    return HotPassResult::unchanged()
  }
  let mut any_changed = false
  let mut changed = true
  let mut cycles = 0
  while changed && cycles < 8 {
    cycles += 1
    changed = false
    let seen : Array[Int] = []
    let reorder_cache : Array[Int] = []
    let control_cache : Array[Int] = []
    let return_cache : Array[Int] = []
    let label_refs = remove_unused_brs_compute_label_refs(func)
    changed = remove_unused_brs_visit_region(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        seen,
        reorder_cache,
        label_refs,
        true,
        control_cache,
        return_cache,
      ) ||
      changed
    changed = remove_unused_brs_flatten_block_if_chains(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        label_refs,
      ) ||
      changed
    changed = remove_unused_brs_try_strip_tail_if_exits(
        ctx,
        func,
        @ir.HotRegionRef::root(),
      ) ||
      changed
    changed = remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        reorder_cache,
        label_refs,
      ) ||
      changed
    changed = remove_unused_brs_try_voidify_tail_return_if(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        label_refs,
      ) ||
      changed
    changed = remove_unused_brs_try_remove_region_tail(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        reorder_cache,
      ) ||
      changed
    changed = remove_unused_brs_trim_trailing_nops(
        ctx,
        func,
        @ir.HotRegionRef::root(),
      ) ||
      changed
    any_changed = any_changed || changed
  }
  if any_changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
