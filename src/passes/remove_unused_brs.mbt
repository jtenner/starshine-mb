///|
pub fn remove_unused_brs_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "remove-unused-brs",
    requires=[@ir.HotAnalysis::use_def()],
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
    | @ir.HotOp::Nop => ()
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
fn remove_unused_brs_is_zero_const(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(value) => value == @lib.I32(0)
        @ir.HotConstPayload::I64Const(value) => value == @lib.I64(0L)
        @ir.HotConstPayload::F32Const(value) => value == @lib.F32(0.0)
        @ir.HotConstPayload::F64Const(value) => value == @lib.F64(0.0)
        _ => false
      }
    @ir.HotOp::RefNull => true
    _ => false
  }
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
fn remove_unused_brs_try_voidify_tail_return_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) == 0 {
    return false
  }
  let tail_idx = @ir.hot_region_root_count(func, region_ref) - 1
  let tail_id = @ir.hot_region_get(func, region_ref, tail_idx)
  let tail = @ir.hot_node_get(func, tail_id)
  let (idx, remove_count, if_id) = match tail.op {
    @ir.HotOp::Return if tail.child_count >= 1 => {
      let candidate = @ir.hot_child_get(func, tail_id, 0)
      for child_idx = 1; child_idx < tail.child_count; child_idx = child_idx + 1 {
        if @ir.hot_child_get(func, tail_id, child_idx) != candidate {
          return false
        }
      }
      (tail_idx, 1, candidate)
    }
    @ir.HotOp::Return if tail.child_count == 0 && tail_idx > 0 => {
      let value_id = @ir.hot_region_get(func, region_ref, tail_idx - 1)
      (tail_idx - 1, 2, value_id)
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
  if !remove_unused_brs_tail_is_nonfallthrough(func, then_ref) ||
    !remove_unused_brs_tail_is_nonfallthrough(func, else_ref) {
    return false
  }
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, if_id, 0),
    remove_unused_brs_region_roots(func, then_ref),
    else_body=Some(remove_unused_brs_region_roots(func, else_ref)),
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
  match remove_unused_brs_tail_target(func, region_ref) {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return =>
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
            false
          }
        _ => false
      }
    BranchTarget(target) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == target =>
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
            false
          }
        _ => false
      }
    NoTarget => false
  }
}

///|
fn remove_unused_brs_tail_control_payload_count(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
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
  match remove_unused_brs_tail_target(func, region_ref) {
    ReturnTarget =>
      match tail.op {
        @ir.HotOp::Return if tail.child_count <= 1 => Some(tail.child_count)
        _ => None
      }
    BranchTarget(target) =>
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == target && tail.child_count <= 1 =>
          Some(tail.child_count)
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
) -> Bool {
  let tail_id = @ir.hot_region_get(
    func,
    region_ref,
    @ir.hot_region_root_count(func, region_ref) - 1,
  )
  let tail = @ir.hot_node_get(func, tail_id)
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
    false
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
  let then_payloads = match
    remove_unused_brs_tail_control_payload_count(func, then_ref) {
    Some(count) => count
    None => return false
  }
  let else_payloads = match
    remove_unused_brs_tail_control_payload_count(func, else_ref) {
    Some(count) => count
    None => return false
  }
  if then_payloads != else_payloads ||
    then_payloads != @ir.hot_node_result_arity(func, tail_id) {
    return false
  }
  let mut changed = remove_unused_brs_strip_tail_control(ctx, func, then_ref)
  changed = remove_unused_brs_strip_tail_control(ctx, func, else_ref) || changed
  changed = remove_unused_brs_trim_trailing_nops(ctx, func, then_ref) || changed
  changed = remove_unused_brs_trim_trailing_nops(ctx, func, else_ref) || changed
  changed
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
fn remove_unused_brs_try_rewrite_value_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  if @ir.hot_region_root_count(func, then_ref) != 1 ||
    @ir.hot_region_root_count(func, else_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let else_root = @ir.hot_region_get(func, else_ref, 0)
  let condition = @ir.hot_child_get(func, node_id, 0)
  if !remove_unused_brs_node_is_reorder_safe(
      ctx, func, condition, reorder_cache,
    ) {
    return false
  }
  let (if_true, if_false) = if remove_unused_brs_is_zero_const(func, else_root) &&
    remove_unused_brs_node_is_reorder_safe(ctx, func, then_root, reorder_cache) {
    (then_root, else_root)
  } else if remove_unused_brs_is_zero_const(func, then_root) &&
    remove_unused_brs_node_is_reorder_safe(ctx, func, else_root, reorder_cache) {
    (then_root, else_root)
  } else {
    return false
  }
  let replacement = remove_unused_brs_build_select(
    func,
    @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))[0],
    if_true,
    if_false,
    condition,
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
  if result_arity <= 0 {
    return Some((remove_unused_brs_region_roots(func, region_ref), []))
  }
  let roots = remove_unused_brs_region_roots(func, region_ref)
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
fn remove_unused_brs_try_rewrite_branch_payload_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
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
    for root_idx = 0
        root_idx < @ir.hot_region_root_count(func, body_ref)
        root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
      let stack = [root_id]
      while !stack.is_empty() {
        let current = stack.pop().unwrap()
        if current < 0 || !@ir.hot_node_is_live(func, current) {
          continue
        }
        match @ir.hot_branch_target(func, current) {
          Some(branch_target) if branch_target == if_label => return false
          _ => ()
        }
        for child_id in remove_unused_brs_live_children(func, current) {
          stack.push(child_id)
        }
      }
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
    for root_idx = 0
        root_idx < @ir.hot_region_root_count(func, body_ref)
        root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
      let stack = [root_id]
      while !stack.is_empty() {
        let current = stack.pop().unwrap()
        if current < 0 || !@ir.hot_node_is_live(func, current) {
          continue
        }
        match @ir.hot_branch_target(func, current) {
          Some(branch_target) if branch_target == if_label => return false
          _ => ()
        }
        for child_id in remove_unused_brs_live_children(func, current) {
          stack.push(child_id)
        }
      }
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
fn remove_unused_brs_try_flatten_block_if_chain(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
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
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  let target = @ir.hot_control_node_label(func, holder)
  let condition = @ir.hot_child_get(func, if_id, 0)
  match then_node.op {
    @ir.HotOp::Br if then_node.imm0 == target && then_node.child_count == 0 => {
      for root_idx = 0
          root_idx < @ir.hot_region_root_count(func, else_ref)
          root_idx = root_idx + 1 {
        let else_root = @ir.hot_region_get(func, else_ref, root_idx)
        let stack = [else_root]
        while !stack.is_empty() {
          let current = stack.pop().unwrap()
          if current < 0 || !@ir.hot_node_is_live(func, current) {
            continue
          }
          match @ir.hot_branch_target(func, current) {
            Some(branch_target) if branch_target == if_label => return false
            _ => ()
          }
          for child_id in remove_unused_brs_live_children(func, current) {
            stack.push(child_id)
          }
        }
      }
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
      for root_idx = 0
          root_idx < @ir.hot_region_root_count(func, then_ref)
          root_idx = root_idx + 1 {
        let scan_root = @ir.hot_region_get(func, then_ref, root_idx)
        let stack = [scan_root]
        while !stack.is_empty() {
          let current = stack.pop().unwrap()
          if current < 0 || !@ir.hot_node_is_live(func, current) {
            continue
          }
          match @ir.hot_branch_target(func, current) {
            Some(branch_target) if branch_target == if_label => return false
            _ => ()
          }
          for child_id in remove_unused_brs_live_children(func, current) {
            stack.push(child_id)
          }
        }
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
    if remove_unused_brs_try_flatten_block_if_chain(ctx, func, region_ref, idx) {
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
fn remove_unused_brs_mark_seen(seen : Array[Bool], node_id : Int) -> Unit {
  while seen.length() <= node_id {
    seen.push(false)
  }
  seen[node_id] = true
}

///|
fn remove_unused_brs_visit_embedded_subtree(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  seen : Array[Bool],
  reorder_cache : Array[Int],
  payload_context : Bool,
) -> Bool {
  if !@ir.hot_node_is_live(func, node_id) {
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
        ctx, func, node_id, seen, reorder_cache, payload_context,
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
    changed = remove_unused_brs_visit_embedded_subtree(
        ctx, func, child_id, seen, reorder_cache, false,
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
  seen : Array[Bool],
  reorder_cache : Array[Int],
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
        ctx, func, child_id, seen, reorder_cache, false,
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
  seen : Array[Bool],
  reorder_cache : Array[Int],
  payload_context : Bool,
) -> Bool {
  if !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if node_id < seen.length() && seen[node_id] {
    return false
  }
  remove_unused_brs_mark_seen(seen, node_id)
  let mut changed = false
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_flatten_block_if_chains(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_try_strip_tail_if_exits(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_try_voidify_tail_return_if(
          ctx, func, body_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_remove_region_tail(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
        changed
    }
    @ir.HotOp::If => {
      changed = remove_unused_brs_visit_embedded_subtree(
          ctx,
          func,
          @ir.hot_child_get(func, node_id, 0),
          seen,
          reorder_cache,
          false,
        ) ||
        changed
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, then_ref, seen, reorder_cache,
        ) ||
        changed
      if payload_context {
        changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
            ctx, func, then_ref,
          ) ||
          changed
      }
      changed = remove_unused_brs_try_strip_tail_if_exits(ctx, func, then_ref) ||
        changed
      changed = remove_unused_brs_try_voidify_tail_return_if(
          ctx, func, then_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_remove_region_tail(ctx, func, then_ref) ||
        changed
      changed = remove_unused_brs_trim_trailing_nops(ctx, func, then_ref) ||
        changed
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          changed = remove_unused_brs_visit_region(
              ctx, func, else_ref, seen, reorder_cache,
            ) ||
            changed
          if payload_context {
            changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
                ctx, func, else_ref,
              ) ||
              changed
          }
          changed = remove_unused_brs_try_strip_tail_if_exits(
              ctx, func, else_ref,
            ) ||
            changed
          changed = remove_unused_brs_try_voidify_tail_return_if(
              ctx, func, else_ref,
            ) ||
            changed
          changed = remove_unused_brs_try_remove_region_tail(
              ctx, func, else_ref,
            ) ||
            changed
          changed = remove_unused_brs_trim_trailing_nops(ctx, func, else_ref) ||
            changed
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
            ctx, func, child_id, seen, reorder_cache, true,
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
            ctx, func, child_id, seen, reorder_cache, true,
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
        changed = remove_unused_brs_visit_embedded_subtree(
            ctx, func, child_id, seen, reorder_cache, child_payload_context,
          ) ||
          changed
      }
    @ir.HotOp::Try => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_strip_tail_if_exits(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_try_voidify_tail_return_if(
          ctx, func, body_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_remove_region_tail(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
        changed
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) => {
          changed = remove_unused_brs_visit_region(
              ctx, func, catch_ref, seen, reorder_cache,
            ) ||
            changed
          changed = remove_unused_brs_try_strip_tail_if_exits(
              ctx, func, catch_ref,
            ) ||
            changed
          changed = remove_unused_brs_try_voidify_tail_return_if(
              ctx, func, catch_ref,
            ) ||
            changed
          changed = remove_unused_brs_try_remove_region_tail(
              ctx, func, catch_ref,
            ) ||
            changed
          changed = remove_unused_brs_trim_trailing_nops(ctx, func, catch_ref) ||
            changed
        }
        None => ()
      }
    }
    @ir.HotOp::TryTable => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_strip_tail_if_exits(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_try_voidify_tail_return_if(
          ctx, func, body_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_remove_region_tail(ctx, func, body_ref) ||
        changed
      changed = remove_unused_brs_trim_trailing_nops(ctx, func, body_ref) ||
        changed
      let catch_list_ref = @ir.hot_region_catch_list_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, catch_list_ref, seen, reorder_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_strip_tail_if_exits(
          ctx, func, catch_list_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_voidify_tail_return_if(
          ctx, func, catch_list_ref,
        ) ||
        changed
      changed = remove_unused_brs_try_remove_region_tail(
          ctx, func, catch_list_ref,
        ) ||
        changed
      changed = remove_unused_brs_trim_trailing_nops(ctx, func, catch_list_ref) ||
        changed
    }
    _ =>
      changed = remove_unused_brs_visit_generic_children(
          ctx, func, node_id, seen, reorder_cache,
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
  seen : Array[Bool],
  reorder_cache : Array[Int],
) -> Bool {
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  let mut changed = false
  for idx = 0; idx < roots.length(); idx = idx + 1 {
    let node_id = roots[idx]
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if remove_unused_brs_try_rewrite_branch_payload_if(
        ctx, func, region_ref, idx,
      ) {
      changed = true
      continue
    }
    if remove_unused_brs_try_rewrite_two_arm_branch_if(
        ctx, func, region_ref, idx,
      ) {
      changed = true
      continue
    }
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
    changed = remove_unused_brs_visit_node(
        ctx, func, node_id, seen, reorder_cache, false,
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
  let mut any_changed = false
  let mut changed = true
  let mut cycles = 0
  while changed && cycles < 8 {
    cycles += 1
    changed = false
    let seen : Array[Bool] = []
    let reorder_cache : Array[Int] = []
    changed = remove_unused_brs_visit_region(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        seen,
        reorder_cache,
      ) ||
      changed
    changed = remove_unused_brs_flatten_block_if_chains(
        ctx,
        func,
        @ir.HotRegionRef::root(),
      ) ||
      changed
    changed = remove_unused_brs_try_strip_tail_if_exits(
        ctx,
        func,
        @ir.HotRegionRef::root(),
      ) ||
      changed
    changed = remove_unused_brs_try_voidify_tail_return_if(
        ctx,
        func,
        @ir.HotRegionRef::root(),
      ) ||
      changed
    changed = remove_unused_brs_try_remove_region_tail(
        ctx,
        func,
        @ir.HotRegionRef::root(),
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
