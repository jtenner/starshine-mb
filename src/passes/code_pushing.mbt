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
fn code_pushing_nonnull_struct_get_source_local(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return -1
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Heap => ()
    _ => return -1
  }
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(@lib.Instruction::StructGet(_, _))
    | Some(@lib.Instruction::StructGetS(_, _))
    | Some(@lib.Instruction::StructGetU(_, _)) => ()
    _ => return -1
  }
  if @ir.hot_child_count(func, node_id) != 1 {
    return -1
  }
  let source_id = @ir.hot_child_get(func, node_id, 0)
  if !code_pushing_node_is_local_get(func, source_id) {
    return -1
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, source_id)) {
    [@lib.RefTypeValType(rt)] if rt.is_non_nullable() =>
      @ir.hot_node_get(func, source_id).imm0
    _ => -1
  }
}

///|
fn code_pushing_node_is_nontrapping_struct_get_from_local_get(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  code_pushing_nonnull_struct_get_source_local(func, node_id) >= 0
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
    @ir.HotOp::Heap =>
      code_pushing_node_is_nontrapping_struct_get_from_local_get(func, node_id)
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
fn code_pushing_node_has_any_local_get(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_pushing_node_has_any_local_get(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
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
fn code_pushing_effects_safe_to_cross_for_heap_read(mask : UInt) -> Bool {
  (
    mask &
    (
      @ir.EFFECT_MASK_CALL |
      @ir.EFFECT_MASK_THROW |
      @ir.EFFECT_MASK_GLOBAL_STATE |
      @ir.EFFECT_MASK_MEMORY_WRITE |
      @ir.EFFECT_MASK_TABLE_WRITE
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
    let source_local = code_pushing_nonnull_struct_get_source_local(
      func, value_id,
    )
    if source_local >= 0 {
      let (_, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
        func, node_id, source_local, 0, 0,
      )
      writes == 0 &&
      code_pushing_effects_safe_to_cross_for_heap_read(
        @ir.effects_for_node(func, node_id),
      )
    } else {
      true
    }
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
fn code_pushing_count_local_gets_writes_in_region_suffix_bounded(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
  start_idx : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  let mut gets = 0
  let mut writes = 0
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut idx = if start_idx > 0 { start_idx } else { 0 }
  while idx < root_count {
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
    idx += 1
  }
  (gets, writes)
}

///|
fn code_pushing_region_writes_local_deep_limited(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  local_id : Int,
  depth : Int,
) -> Bool {
  if depth <= 0 {
    return false
  }
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if code_pushing_node_writes_local_deep_limited(
        func,
        @ir.hot_region_get(func, region_ref, idx),
        local_id,
        depth,
      ) {
      return true
    }
  }
  false
}

///|
fn code_pushing_if_arms_write_local_deep_limited(
  func : @ir.HotFunc,
  if_id : Int,
  local_id : Int,
  depth : Int,
) -> Bool {
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  if code_pushing_region_writes_local_deep_limited(
      func,
      @ir.hot_region_then_ref(func, if_id),
      local_id,
      depth,
    ) {
    return true
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) =>
      code_pushing_region_writes_local_deep_limited(
        func, else_ref, local_id, depth,
      )
    None => false
  }
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
fn code_pushing_count_unique_local_gets_writes_in_node_bounded(
  func : @ir.HotFunc,
  node_id : Int,
  local_id : Int,
  max_gets : Int,
  max_writes : Int,
  visited : Array[Int],
) -> (Int, Int) {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return (0, 0)
  }
  if visited.any(fn(existing) { existing == node_id }) {
    return (0, 0)
  }
  visited.push(node_id)
  let node = @ir.hot_node_get(func, node_id)
  let mut gets = 0
  let mut writes = 0
  match node.op {
    @ir.HotOp::LocalGet if node.imm0 == local_id => gets += 1
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee if node.imm0 == local_id =>
      writes += 1
    _ => ()
  }
  if gets > max_gets || writes > max_writes {
    return (gets, writes)
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let (child_gets, child_writes) = code_pushing_count_unique_local_gets_writes_in_node_bounded(
      func,
      @ir.hot_child_get(func, node_id, slot),
      local_id,
      max_gets - gets,
      max_writes - writes,
      visited,
    )
    gets += child_gets
    writes += child_writes
    if gets > max_gets || writes > max_writes {
      return (gets, writes)
    }
  }
  (gets, writes)
}

///|
fn code_pushing_count_unique_total_local_gets_writes_bounded(
  func : @ir.HotFunc,
  local_id : Int,
  max_gets : Int,
  max_writes : Int,
) -> (Int, Int) {
  let visited : Array[Int] = []
  let mut gets = 0
  let mut writes = 0
  for idx = 0; idx < @ir.hot_root_count(func); idx = idx + 1 {
    let (root_gets, root_writes) = code_pushing_count_unique_local_gets_writes_in_node_bounded(
      func,
      @ir.hot_root_get(func, idx),
      local_id,
      max_gets - gets,
      max_writes - writes,
      visited,
    )
    gets += root_gets
    writes += root_writes
    if gets > max_gets || writes > max_writes {
      return (gets, writes)
    }
  }
  (gets, writes)
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
fn code_pushing_region_cannot_fall_through_simple(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count == 0 {
    return false
  }
  let last_id = @ir.hot_region_get(func, region_ref, root_count - 1)
  if last_id < 0 || !@ir.hot_node_is_live(func, last_id) {
    return false
  }
  match @ir.hot_node_get(func, last_id).op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef => true
    _ => false
  }
}

///|
fn code_pushing_push_point_kind(func : @ir.HotFunc, node_id : Int) -> String {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return "none"
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => "if"
    @ir.HotOp::BrTable => "switch"
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => "conditional-branch"
    @ir.HotOp::Drop => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return "none"
      }
      let child_kind = code_pushing_push_point_kind(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
      if child_kind == "none" {
        "none"
      } else {
        "dropped-" + child_kind
      }
    }
    _ => "none"
  }
}

///|
fn code_pushing_segment_window_diagnostic(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> String {
  if set_idx < 0 || set_idx >= @ir.hot_region_root_count(func, region_ref) {
    return "reject:no-local-set"
  }
  let set_id = @ir.hot_region_get(func, region_ref, set_idx)
  if set_id < 0 || !@ir.hot_node_is_live(func, set_id) {
    return "reject:no-local-set"
  }
  let set_node = @ir.hot_node_get(func, set_id)
  match set_node.op {
    @ir.HotOp::LocalSet => ()
    _ => return "reject:no-local-set"
  }
  if @ir.hot_node_result_arity(func, set_id) != 0 {
    return "reject:no-local-set"
  }
  let local_id = set_node.imm0
  let (prefix_gets, _) = code_pushing_count_local_gets_writes_in_region_prefix_bounded(
    func, region_ref, local_id, set_idx, 0, 1_000_000,
  )
  if prefix_gets != 0 {
    return "reject:prefix-local-read"
  }
  let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
    func, local_id, 1_000_000, 2,
  )
  if total_writes != 1 {
    return "reject:multiple-local-writes"
  }
  if total_gets == 0 {
    return "reject:no-local-use"
  }
  let value_id = @ir.hot_child_get(func, set_id, 0)
  if !code_pushing_node_is_movable_value(func, value_id) {
    return "reject:not-pushable-value"
  }
  let mut idx = set_idx + 1
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let candidate_id = @ir.hot_region_get(func, region_ref, idx)
    let kind = code_pushing_push_point_kind(func, candidate_id)
    if kind != "none" {
      if !code_pushing_node_safe_to_cross_for_value(
          func, candidate_id, value_id,
        ) {
        return "reject:ordered-before-barrier"
      }
      return "candidate:" + kind
    }
    let (gets, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
      func, candidate_id, local_id, 1, 0,
    )
    if writes != 0 {
      return "reject:multiple-local-writes"
    }
    if gets != 0 {
      return "reject:use-before-push-point"
    }
    if !code_pushing_node_safe_to_cross_for_value(func, candidate_id, value_id) {
      return "reject:ordered-before-barrier"
    }
    idx += 1
  }
  "reject:no-push-point"
}

///|
fn code_pushing_direct_br_if_push_point_supported(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if node.imm0 < 0 {
    return false
  }
  let branch_arity = @ir.hot_label_branch_arity(func, node.imm0)
  match @ir.hot_label_kind(func, node.imm0) {
    @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::LoopLabel =>
      branch_arity == 0 && @ir.hot_child_count(func, node_id) == 1
    _ => false
  }
}

///|
fn code_pushing_single_set_conditional_branch_push_point_supported(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut branch_id = node_id
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Drop => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
      branch_id = @ir.hot_child_get(func, node_id, 0)
    }
    _ => ()
  }
  if branch_id < 0 || !@ir.hot_node_is_live(func, branch_id) {
    return false
  }
  let branch = @ir.hot_node_get(func, branch_id)
  if branch.imm0 < 0 {
    return false
  }
  let branch_arity = @ir.hot_label_branch_arity(func, branch.imm0)
  let child_count = @ir.hot_child_count(func, branch_id)
  match branch.op {
    @ir.HotOp::BrIf =>
      match @ir.hot_label_kind(func, branch.imm0) {
        @ir.HotLabelKind::BlockLabel =>
          (branch_arity == 0 && child_count == 1) ||
          (branch_arity == 1 && child_count == 2)
        @ir.HotLabelKind::LoopLabel => branch_arity == 0 && child_count == 1
        _ => false
      }
    @ir.HotOp::BrOnNull =>
      match @ir.hot_label_kind(func, branch.imm0) {
        @ir.HotLabelKind::BlockLabel | @ir.HotLabelKind::LoopLabel =>
          branch_arity == 0 && child_count == 1
        _ => false
      }
    @ir.HotOp::BrOnNonNull =>
      match @ir.hot_label_kind(func, branch.imm0) {
        @ir.HotLabelKind::BlockLabel =>
          branch_arity >= 1 && child_count >= 1 && child_count <= branch_arity
        _ => false
      }
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail =>
      match @ir.hot_label_kind(func, branch.imm0) {
        @ir.HotLabelKind::BlockLabel => branch_arity == 1 && child_count == 1
        _ => false
      }
    _ => false
  }
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
fn code_pushing_value_is_ordered_set_movable(
  func : @ir.HotFunc,
  value_id : Int,
) -> Bool {
  code_pushing_node_is_movable_value(func, value_id) ||
  code_pushing_node_is_local_get(func, value_id)
}

///|
fn code_pushing_node_is_drop_const_window_separator(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 ||
    @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
    return false
  }
  match @ir.hot_node_get(func, child_id).op {
    @ir.HotOp::Const =>
      @ir.effects_is_pure(@ir.effects_for_node(func, child_id))
    _ => false
  }
}

///|
fn code_pushing_node_is_drop_local_get_window_separator(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 ||
    @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  code_pushing_node_is_local_get(func, child_id)
}

///|
fn code_pushing_node_is_drop_global_get_window_separator(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 ||
    @ir.hot_child_count(func, node_id) != 1 {
    return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  code_pushing_node_is_global_get(func, child_id)
}

///|
fn code_pushing_node_is_safe_drop_window_separator(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  code_pushing_node_is_drop_const_window_separator(func, node_id) ||
  code_pushing_node_is_drop_local_get_window_separator(func, node_id) ||
  code_pushing_node_is_drop_global_get_window_separator(func, node_id)
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
          ) ||
          code_pushing_if_arms_write_local_deep_limited(
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
fn code_pushing_try_sink_generated_prefix_sets_after_br_on_non_null(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 2 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let first_id = @ir.hot_region_get(func, region_ref, set_idx)
  if first_id < 0 || !@ir.hot_node_is_live(func, first_id) {
    return false
  }
  match @ir.hot_node_get(func, first_id).op {
    @ir.HotOp::LocalSet => ()
    _ => return false
  }
  let mut branch_idx = -1
  let mut idx = set_idx + 1
  let max_idx = set_idx + 16
  while idx < @ir.hot_region_root_count(func, region_ref) && idx <= max_idx {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      return false
    }
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::BrOnNonNull => {
        branch_idx = idx
        break
      }
      _ => ()
    }
    idx += 1
  }
  if branch_idx < 0 {
    return false
  }
  let branch_id = @ir.hot_region_get(func, region_ref, branch_idx)
  let branch = @ir.hot_node_get(func, branch_id)
  if branch.imm0 < 0 || @ir.hot_child_count(func, branch_id) < 1 {
    return false
  }
  let set_ids : Array[Int] = []
  let local_ids : Array[Int] = []
  let value_ids : Array[Int] = []
  for scan_idx = set_idx; scan_idx < branch_idx; scan_idx = scan_idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, scan_idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      return false
    }
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::LocalSet => {
        if @ir.hot_node_result_arity(func, root_id) != 0 {
          return false
        }
        let local_id = root.imm0
        if local_ids.any(fn(existing) { existing == local_id }) {
          return false
        }
        let value_id = @ir.hot_child_get(func, root_id, 0)
        if !code_pushing_node_is_movable_value(func, value_id) ||
          code_pushing_node_has_any_local_get(func, value_id) {
          continue
        }
        let (prefix_gets, _) = code_pushing_count_local_gets_writes_in_region_prefix_bounded(
          func, region_ref, local_id, set_idx, 0, 1_000_000,
        )
        if prefix_gets != 0 {
          return false
        }
        let mut safe_to_branch = true
        for cross_idx = scan_idx + 1
            cross_idx <= branch_idx
            cross_idx = cross_idx + 1 {
          let cross_id = @ir.hot_region_get(func, region_ref, cross_idx)
          let (gets, writes) = code_pushing_count_local_gets_writes_in_node_bounded(
            func, cross_id, local_id, 1, 0,
          )
          if gets != 0 ||
            writes != 0 ||
            !code_pushing_node_safe_to_cross_for_value(func, cross_id, value_id) {
            safe_to_branch = false
          }
        }
        if !safe_to_branch {
          continue
        }
        let (total_gets, total_writes) = code_pushing_count_unique_total_local_gets_writes_bounded(
          func, local_id, 1_000_000, 1,
        )
        if total_writes != 1 || total_gets == 0 {
          continue
        }
        let (suffix_gets, suffix_writes) = code_pushing_count_local_gets_writes_in_region_suffix_bounded(
          func,
          region_ref,
          local_id,
          branch_idx + 1,
          total_gets,
          0,
        )
        if suffix_writes == 0 && suffix_gets == total_gets {
          set_ids.push(root_id)
          local_ids.push(local_id)
          value_ids.push(value_id)
        }
      }
      _ =>
        if code_pushing_push_point_kind(func, root_id) != "none" {
          return false
        }
    }
  }
  if set_ids.length() == 0 {
    return false
  }
  let pushed_sets : Array[Int] = []
  for move_idx = 0; move_idx < set_ids.length(); move_idx = move_idx + 1 {
    pushed_sets.push(
      code_pushing_make_local_set_clone(
        func,
        local_ids[move_idx],
        value_ids[move_idx],
      ),
    )
  }
  ignore(
    pass_splice_region(ctx, func, region_ref, branch_idx + 1, 0, pushed_sets),
  )
  for move_idx = 0; move_idx < set_ids.length(); move_idx = move_idx + 1 {
    let nop = @ir.hot_build_nop(func)
    pass_replace_node(ctx, func, set_ids[move_idx], @ir.hot_node_get(func, nop))
  }
  true
}

///|
fn code_pushing_try_sink_ordered_sets_after_push_point(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  if set_idx + 2 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let set_ids : Array[Int] = []
  let local_ids : Array[Int] = []
  let value_ids : Array[Int] = []
  let source_local_ids : Array[Int] = []
  let mut saw_drop_global_get_separator = false
  let mut idx = set_idx
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    let kind = code_pushing_push_point_kind(func, root_id)
    if kind != "none" {
      break
    }
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      return false
    }
    let root_node = @ir.hot_node_get(func, root_id)
    match root_node.op {
      @ir.HotOp::LocalSet => {
        if @ir.hot_node_result_arity(func, root_id) != 0 {
          return false
        }
        let local_id = root_node.imm0
        if local_ids.any(fn(existing) { existing == local_id }) {
          return false
        }
        let value_id = @ir.hot_child_get(func, root_id, 0)
        if !code_pushing_value_is_ordered_set_movable(func, value_id) {
          return false
        }
        let source_local = if code_pushing_node_is_local_get(func, value_id) {
          @ir.hot_node_get(func, value_id).imm0
        } else {
          if code_pushing_node_has_any_local_get(func, value_id) {
            return false
          }
          -1
        }
        if source_local == local_id ||
          local_ids.any(fn(existing) { existing == source_local }) {
          return false
        }
        let (prefix_gets, _) = code_pushing_count_local_gets_writes_in_region_prefix_bounded(
          func, region_ref, local_id, set_idx, 0, 1_000_000,
        )
        if prefix_gets != 0 {
          return false
        }
        let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
          func, local_id, 1_000_000, 1,
        )
        if total_writes != 1 || total_gets == 0 {
          return false
        }
        set_ids.push(root_id)
        local_ids.push(local_id)
        value_ids.push(value_id)
        source_local_ids.push(source_local)
      }
      @ir.HotOp::Nop =>
        // Binaryen's segment optimizer can carry harmless roots such as nops
        // in the window while preserving the moved local.set order.
        if set_ids.length() == 0 ||
          @ir.hot_node_result_arity(func, root_id) != 0 {
          return false
        }
      @ir.HotOp::Drop if code_pushing_node_is_safe_drop_window_separator(
          func, root_id,
        ) => {
        // Source-backed non-adjacent slices admit only dead drop(const),
        // drop(local.get), and ordinary/dropped-if drop(global.get) roots as
        // bounded separators. Binaryen v130 probes did not move the same
        // global-get separator window across br_if, so that push point is
        // rejected after we discover the destination below.
        if set_ids.length() == 0 {
          return false
        }
        if code_pushing_node_is_drop_global_get_window_separator(func, root_id) {
          saw_drop_global_get_separator = true
        }
      }
      _ => return false
    }
    idx += 1
  }
  if set_ids.length() < 2 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let push_id = @ir.hot_region_get(func, region_ref, idx)
  let push_kind = code_pushing_push_point_kind(func, push_id)
  let mut if_id = -1
  let mut branch_id = -1
  if push_kind == "if" {
    if_id = push_id
  } else if push_kind == "dropped-if" && @ir.hot_child_count(func, push_id) == 1 {
    if_id = @ir.hot_child_get(func, push_id, 0)
  } else if push_kind == "conditional-branch" &&
    (
      code_pushing_direct_br_if_push_point_supported(func, push_id) ||
      code_pushing_single_set_conditional_branch_push_point_supported(
        func, push_id,
      )
    ) {
    // Value-carrying br_if may lower as a direct HOT BrIf with branch payload
    // children even though the source WAT is `drop (br_if ...)`. Use the same
    // shape gate as the single-set conditional-branch slice, then let whole-root
    // local accounting below reject payloads/conditions/guards that read moved
    // locals.
    if saw_drop_global_get_separator {
      return false
    }
    branch_id = push_id
  } else if push_kind == "dropped-conditional-branch" &&
    code_pushing_single_set_conditional_branch_push_point_supported(
      func, push_id,
    ) {
    if saw_drop_global_get_separator {
      return false
    }
    branch_id = push_id
  } else {
    return false
  }
  if if_id >= 0 {
    if !@ir.hot_node_is_live(func, if_id) {
      return false
    }
    if push_kind == "if" && @ir.hot_node_result_arity(func, if_id) != 0 {
      return false
    }
    if push_kind == "dropped-if" &&
      @ir.hot_node_result_arity(func, push_id) != 0 {
      return false
    }
  } else if branch_id < 0 || !@ir.hot_node_is_live(func, branch_id) {
    return false
  }
  for move_idx = 0; move_idx < set_ids.length(); move_idx = move_idx + 1 {
    let local_id = local_ids[move_idx]
    let value_id = value_ids[move_idx]
    let source_local = source_local_ids[move_idx]
    if !code_pushing_node_safe_to_cross_for_value(func, push_id, value_id) {
      return false
    }
    if source_local >= 0 {
      if local_ids.any(fn(moved_local) { moved_local == source_local }) {
        return false
      }
      if if_id >= 0 {
        if code_pushing_if_arms_write_local_deep_limited(
            func, if_id, source_local, 8,
          ) {
          return false
        }
      } else {
        let (_, source_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
          func, branch_id, source_local, 0, 0,
        )
        if source_writes != 0 {
          return false
        }
      }
    }
    if if_id >= 0 {
      let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
        func, if_id, local_id,
      )
      if then_gets + else_gets != 0 {
        return false
      }
    } else {
      let (branch_gets, branch_writes) = code_pushing_count_local_gets_writes_in_node_bounded(
        func, branch_id, local_id, 0, 0,
      )
      if branch_gets != 0 || branch_writes != 0 {
        return false
      }
    }
    let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
      func, local_id, 1_000_000, 1,
    )
    if total_writes != 1 || total_gets == 0 {
      return false
    }
    let (suffix_gets, suffix_writes) = code_pushing_count_local_gets_writes_in_region_suffix_bounded(
      func,
      region_ref,
      local_id,
      idx + 1,
      total_gets,
      0,
    )
    if suffix_writes != 0 || suffix_gets != total_gets {
      return false
    }
  }
  let pushed_sets : Array[Int] = []
  for move_idx = 0; move_idx < set_ids.length(); move_idx = move_idx + 1 {
    pushed_sets.push(
      code_pushing_make_local_set_clone(
        func,
        local_ids[move_idx],
        value_ids[move_idx],
      ),
    )
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, pushed_sets))
  for move_idx = 0; move_idx < set_ids.length(); move_idx = move_idx + 1 {
    let nop = @ir.hot_build_nop(func)
    pass_replace_node(ctx, func, set_ids[move_idx], @ir.hot_node_get(func, nop))
  }
  true
}

///|
fn code_pushing_try_sink_set_after_if_push_point(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  set_idx : Int,
) -> Bool {
  let diagnostic = code_pushing_segment_window_diagnostic(
    func, region_ref, set_idx,
  )
  if diagnostic != "candidate:if" &&
    diagnostic != "candidate:dropped-if" &&
    diagnostic != "candidate:conditional-branch" &&
    diagnostic != "candidate:dropped-conditional-branch" {
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
  let local_id = set_node.imm0
  let mut push_idx = -1
  let mut idx = set_idx + 1
  let mut if_id = -1
  let mut branch_id = -1
  let mut saw_drop_global_get_separator = false
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let candidate_id = @ir.hot_region_get(func, region_ref, idx)
    let kind = code_pushing_push_point_kind(func, candidate_id)
    if kind != "none" {
      if kind == "if" {
        if_id = candidate_id
      } else if kind == "dropped-if" &&
        @ir.hot_child_count(func, candidate_id) == 1 {
        if_id = @ir.hot_child_get(func, candidate_id, 0)
      } else if (
          kind == "conditional-branch" || kind == "dropped-conditional-branch"
        ) &&
        code_pushing_single_set_conditional_branch_push_point_supported(
          func, candidate_id,
        ) {
        if saw_drop_global_get_separator ||
          (
            set_idx > 0 &&
            code_pushing_node_is_drop_global_get_window_separator(
              func,
              @ir.hot_region_get(func, region_ref, set_idx - 1),
            )
          ) {
          return false
        }
        branch_id = candidate_id
      } else {
        return false
      }
      push_idx = idx
      break
    }
    if code_pushing_node_is_drop_global_get_window_separator(func, candidate_id) {
      saw_drop_global_get_separator = true
    }
    idx += 1
  }
  if push_idx < 0 {
    return false
  }
  if branch_id >= 0 {
    // Whole-root accounting below rejects conditions or branch values that read
    // the moved local; this first slice only moves after a local-independent
    // br_if when every use is in the same block suffix.
    ()
  } else {
    if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
      return false
    }
    if diagnostic == "candidate:if" &&
      @ir.hot_node_result_arity(func, if_id) != 0 {
      return false
    }
    let (then_gets, else_gets) = code_pushing_count_local_gets_in_if_arms(
      func, if_id, local_id,
    )
    if then_gets + else_gets != 0 {
      return false
    }
  }
  let (total_gets, total_writes) = code_pushing_count_total_local_gets_writes_bounded(
    func, local_id, 1_000_000, 1,
  )
  if total_writes != 1 || total_gets == 0 {
    return false
  }
  let (suffix_gets, suffix_writes) = code_pushing_count_local_gets_writes_in_region_suffix_bounded(
    func,
    region_ref,
    local_id,
    push_idx + 1,
    total_gets,
    0,
  )
  if suffix_writes != 0 || suffix_gets != total_gets {
    return false
  }
  let pushed_set = code_pushing_make_local_set_clone(func, local_id, value_id)
  ignore(
    pass_splice_region(ctx, func, region_ref, push_idx + 1, 0, [pushed_set]),
  )
  let nop = @ir.hot_build_nop(func)
  pass_replace_node(ctx, func, set_id, @ir.hot_node_get(func, nop))
  true
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
  // Keep the non-mutating segment inventory exercised in normal builds while
  // mutation remains governed by the stricter source-backed checks below.
  ignore(code_pushing_segment_window_diagnostic(func, region_ref, set_idx))
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
    func, local_id, 1_000_000, 1,
  )
  if total_writes != 1 {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id)
  let target_ref = if then_gets > 0 { Some(then_ref) } else { else_ref }
  let mut gets_are_safe = total_gets == arm_gets
  if !gets_are_safe && total_gets > arm_gets {
    let (prefix_gets, prefix_writes) = code_pushing_count_local_gets_writes_in_region_prefix_bounded(
      func, region_ref, local_id, set_idx, 0, 0,
    )
    let (suffix_gets, suffix_writes) = code_pushing_count_local_gets_writes_in_region_suffix_bounded(
      func,
      region_ref,
      local_id,
      if_idx + 1,
      total_gets - arm_gets,
      0,
    )
    let non_consuming_ref = if then_gets > 0 {
      else_ref
    } else {
      Some(then_ref)
    }
    let non_consuming_exits = match non_consuming_ref {
      Some(ref_) => code_pushing_region_cannot_fall_through_simple(func, ref_)
      None => false
    }
    gets_are_safe = prefix_gets == 0 &&
      prefix_writes == 0 &&
      suffix_writes == 0 &&
      suffix_gets > 0 &&
      total_gets == arm_gets + suffix_gets &&
      non_consuming_exits
  }
  if !gets_are_safe {
    return false
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
fn code_pushing_scan_node_children_once(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    match @ir.hot_node_get(func, child_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_body_ref(func, child_id),
          ) {
          return true
        }
      @ir.HotOp::If => {
        if code_pushing_scan_region_once(
            ctx,
            func,
            @ir.hot_region_then_ref(func, child_id),
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, child_id) {
          Some(else_ref) =>
            if code_pushing_scan_region_once(ctx, func, else_ref) {
              return true
            }
          None => ()
        }
      }
      _ => ()
    }
    if code_pushing_scan_node_children_once(ctx, func, child_id) {
      return true
    }
  }
  false
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
    if code_pushing_try_sink_generated_prefix_sets_after_br_on_non_null(
        ctx, func, region_ref, idx,
      ) {
      return true
    }
    if code_pushing_try_sink_ordered_sets_after_push_point(
        ctx, func, region_ref, idx,
      ) {
      return true
    }
    if code_pushing_try_sink_local_get_set_after_if(ctx, func, region_ref, idx) {
      return true
    }
    if code_pushing_try_sink_set_after_if_push_point(ctx, func, region_ref, idx) {
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
      _ =>
        if code_pushing_scan_node_children_once(ctx, func, node_id) {
          return true
        }
    }
  }
  false
}

///|
fn code_pushing_scan_all_control_nodes_once(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
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
    if !changed_round {
      changed_round = code_pushing_scan_all_control_nodes_once(ctx, func)
    }
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
