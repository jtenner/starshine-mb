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
  "Hoist identical safe code tails out of matching structured control arms."
}

///|
priv struct CodeFoldingExitTail {
  region_ref : @ir.HotRegionRef
  end_idx : Int
}

///|
priv struct CodeFoldingValueExitTail {
  region_ref : @ir.HotRegionRef
  tail_end_idx : Int
  branch_id : Int
  target_label : Int
  payload_roots : Array[Int]
  result_arity : Int
  fallthrough : Bool
  movement_safe : Bool
  suffix_len : Int
  profitability : Int
}

///|
priv struct CodeFoldingRegionRemoval {
  region_ref : @ir.HotRegionRef
  start_idx : Int
  remove_count : Int
}

///|
priv struct CodeFoldingTerminatingTail {
  region_ref : @ir.HotRegionRef
  end_idx : Int
  terminal_kind : Int
  suffix_len : Int
  profitability : Int
}

///|
priv struct CodeFoldingLabelMap {
  left_labels : Array[Int]
  right_labels : Array[Int]
}

///|
fn code_folding_label_map_new() -> CodeFoldingLabelMap {
  { left_labels: [], right_labels: [] }
}

///|
fn code_folding_value_exit_tail_branch(
  region_ref : @ir.HotRegionRef,
  branch_idx : Int,
  branch_id : Int,
  target_label : Int,
  payload_roots : Array[Int],
  result_arity : Int,
) -> CodeFoldingValueExitTail {
  {
    region_ref,
    tail_end_idx: branch_idx,
    branch_id,
    target_label,
    payload_roots,
    result_arity,
    fallthrough: false,
    movement_safe: true,
    suffix_len: 0,
    profitability: 0,
  }
}

///|
fn code_folding_value_exit_tail_fallthrough(
  region_ref : @ir.HotRegionRef,
  end_idx : Int,
  target_label : Int,
  payload_id : Int,
  result_arity : Int,
) -> CodeFoldingValueExitTail {
  {
    region_ref,
    tail_end_idx: end_idx,
    branch_id: -1,
    target_label,
    payload_roots: [payload_id],
    result_arity,
    fallthrough: true,
    movement_safe: true,
    suffix_len: 0,
    profitability: 0,
  }
}

///|
fn code_folding_value_exit_tail_with_plan(
  tail : CodeFoldingValueExitTail,
  suffix_len : Int,
  profitability : Int,
) -> CodeFoldingValueExitTail {
  {
    region_ref: tail.region_ref,
    tail_end_idx: tail.tail_end_idx,
    branch_id: tail.branch_id,
    target_label: tail.target_label,
    payload_roots: tail.payload_roots,
    result_arity: tail.result_arity,
    fallthrough: tail.fallthrough,
    movement_safe: tail.movement_safe,
    suffix_len,
    profitability,
  }
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
fn code_folding_node_contains(
  func : @ir.HotFunc,
  root_id : Int,
  target_id : Int,
) -> Bool {
  if root_id == target_id {
    return true
  }
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, root_id); slot = slot + 1 {
    if code_folding_node_contains(
        func,
        @ir.hot_child_get(func, root_id, slot),
        target_id,
      ) {
      return true
    }
  }
  false
}

///|
fn code_folding_branch_target_survives_hoist(
  func : @ir.HotFunc,
  suffix_root_id : Int,
  out_of_id : Int,
  label_id : Int,
) -> Bool {
  if label_id < 0 || label_id >= func.labels.length() {
    return false
  }
  let owner = @ir.hot_label_owner(func, label_id)
  !code_folding_node_contains(func, out_of_id, owner) ||
  code_folding_node_contains(func, suffix_root_id, owner)
}

///|
fn code_folding_branch_targets_survive_hoist(
  func : @ir.HotFunc,
  suffix_root_id : Int,
  out_of_id : Int,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::Delegate =>
      if !code_folding_branch_target_survives_hoist(
          func,
          suffix_root_id,
          out_of_id,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::BrTable => {
      if !code_folding_branch_target_survives_hoist(
          func,
          suffix_root_id,
          out_of_id,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return false
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !code_folding_branch_target_survives_hoist(
            func, suffix_root_id, out_of_id, label_id,
          ) {
          return false
        }
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if !code_folding_branch_target_survives_hoist(
          func,
          suffix_root_id,
          out_of_id,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::TryTable => return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if !code_folding_branch_targets_survive_hoist(
        func,
        suffix_root_id,
        out_of_id,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_node_is_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => return false
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      if pass_label_is_used(label_id, label_used) {
        return false
      }
    }
    _ => ()
  }
  code_folding_branch_targets_survive_hoist(func, node_id, out_of_id, node_id)
}

///|
fn code_folding_node_is_if_terminal_suffix(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  if node.child_count != 0 {
    return false
  }
  match node.op {
    @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Unreachable => true
    _ => false
  }
}

///|
fn code_folding_terminal_tail_kind_return() -> Int {
  1
}

///|
fn code_folding_terminal_tail_kind_unreachable() -> Int {
  2
}

///|
fn code_folding_terminal_tail_kind_of_node(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef => code_folding_terminal_tail_kind_return()
    @ir.HotOp::Unreachable => code_folding_terminal_tail_kind_unreachable()
    _ => 0
  }
}

///|
fn code_folding_node_children_have_no_control_or_exit(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if code_folding_node_has_control_or_exit(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_node_exits_to_own_block_label(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, node_id)
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  let count = @ir.hot_region_root_count(func, body_ref)
  if label_id < 0 || count == 0 {
    return false
  }
  let last_id = @ir.hot_region_get(func, body_ref, count - 1)
  if last_id < 0 || !@ir.hot_node_is_live(func, last_id) {
    return false
  }
  let last = @ir.hot_node_get(func, last_id)
  match last.op {
    @ir.HotOp::Br => last.imm0 == label_id && last.child_count == 0
    _ => false
  }
}

///|
fn code_folding_terminal_tail_item_allows_following(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  !code_folding_node_prevents_fallthrough(func, node_id) ||
  code_folding_node_exits_to_own_block_label(func, node_id)
}

///|
fn code_folding_terminal_tail_item_is_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Try
    | @ir.HotOp::TryTable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => return false
    @ir.HotOp::Block => ()
    @ir.HotOp::Loop | @ir.HotOp::If => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      if pass_label_is_used(label_id, label_used) {
        return false
      }
    }
    _ => ()
  }
  code_folding_branch_targets_survive_hoist(func, node_id, out_of_id, node_id)
}

///|
fn code_folding_terminal_tail_item_is_movable(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  node_id : Int,
  depth : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if depth == 0 {
    return code_folding_terminal_tail_kind_of_node(func, node_id) != 0 &&
      code_folding_node_children_have_no_control_or_exit(func, node_id)
  }
  @ir.hot_node_result_arity(func, node_id) == 0 &&
  code_folding_terminal_tail_item_allows_following(func, node_id) &&
  code_folding_terminal_tail_item_is_hoistable_suffix(
    func,
    node_id,
    tail.region_ref.holder,
    label_used,
  )
}

///|
fn code_folding_terminal_tail_item_has_external_break_target(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  node_id : Int,
) -> Bool {
  node_id >= 0 &&
  @ir.hot_node_is_live(func, node_id) &&
  !code_folding_branch_targets_survive_hoist(
    func,
    node_id,
    tail.region_ref.holder,
    node_id,
  )
}

///|
fn code_folding_node_is_if_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  if_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  code_folding_node_is_hoistable_suffix(func, node_id, if_id, label_used) ||
  code_folding_node_is_if_terminal_suffix(func, node_id)
}

///|
fn code_folding_label_map_lookup_left(
  label_map : CodeFoldingLabelMap,
  left_label : Int,
) -> Int {
  for idx = 0; idx < label_map.left_labels.length(); idx = idx + 1 {
    if label_map.left_labels[idx] == left_label {
      return idx
    }
  }
  -1
}

///|
fn code_folding_label_map_lookup_right(
  label_map : CodeFoldingLabelMap,
  right_label : Int,
) -> Int {
  for idx = 0; idx < label_map.right_labels.length(); idx = idx + 1 {
    if label_map.right_labels[idx] == right_label {
      return idx
    }
  }
  -1
}

///|
fn code_folding_label_map_add(
  label_map : CodeFoldingLabelMap,
  left_label : Int,
  right_label : Int,
) -> Bool {
  if left_label == right_label {
    return true
  }
  let left_idx = code_folding_label_map_lookup_left(label_map, left_label)
  let right_idx = code_folding_label_map_lookup_right(label_map, right_label)
  if left_idx >= 0 || right_idx >= 0 {
    return left_idx == right_idx && left_idx >= 0
  }
  label_map.left_labels.push(left_label)
  label_map.right_labels.push(right_label)
  true
}

///|
fn code_folding_labels_equal_with_map(
  left_label : Int,
  right_label : Int,
  label_map : CodeFoldingLabelMap,
) -> Bool {
  if left_label == right_label {
    return true
  }
  let left_idx = code_folding_label_map_lookup_left(label_map, left_label)
  left_idx >= 0 && label_map.right_labels[left_idx] == right_label
}

///|
fn code_folding_nodes_equal_with_label_map(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  label_used : @bitset.BitSet,
  label_map : CodeFoldingLabelMap,
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
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::If =>
      if (
          pass_label_is_used(left.imm0, label_used) ||
          pass_label_is_used(right.imm0, label_used)
        ) &&
        !code_folding_label_map_add(label_map, left.imm0, right.imm0) {
        return false
      }
    @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate =>
      if !code_folding_labels_equal_with_map(left.imm0, right.imm0, label_map) {
        return false
      }
    @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef =>
      if @ir.hot_call_sig_get(func, left.imm0) !=
        @ir.hot_call_sig_get(func, right.imm0) {
        return false
      }
    _ => if left.imm0 != right.imm0 { return false }
  }
  for slot = 0; slot < left.child_count; slot = slot + 1 {
    if !code_folding_nodes_equal_with_label_map(
        func,
        @ir.hot_child_get(func, left_id, slot),
        @ir.hot_child_get(func, right_id, slot),
        label_used,
        label_map,
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_nodes_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  code_folding_nodes_equal_with_label_map(
    func,
    left_id,
    right_id,
    label_used,
    code_folding_label_map_new(),
  )
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
fn code_folding_common_suffix_len(
  func : @ir.HotFunc,
  if_id : Int,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
) -> Int {
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  let limit = if then_count < else_count { then_count } else { else_count }
  let mut count = 0
  while count < limit {
    let then_id = @ir.hot_region_get(func, then_ref, then_count - 1 - count)
    let else_id = @ir.hot_region_get(func, else_ref, else_count - 1 - count)
    if @ir.hot_node_result_arity(func, then_id) !=
      @ir.hot_node_result_arity(func, else_id) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, then_id, if_id, label_used,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, else_id, if_id, label_used,
      ) ||
      !code_folding_nodes_equal(func, then_id, else_id, label_used) {
      break
    }
    count += 1
  }
  count
}

///|
fn code_folding_node_measure(func : @ir.HotFunc, node_id : Int) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let mut total = 1
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    total += code_folding_node_measure(
      func,
      @ir.hot_child_get(func, node_id, slot),
    )
  }
  total
}

///|
fn code_folding_suffix_measure(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
  suffix_len : Int,
) -> Int {
  let mut total = 0
  let end_idx = start_idx + suffix_len
  for idx = start_idx; idx < end_idx; idx = idx + 1 {
    total += code_folding_node_measure(
      func,
      @ir.hot_region_get(func, region_ref, idx),
    )
  }
  total
}

///|
fn code_folding_suffix_matches_result_arity(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
  suffix_len : Int,
  result_arity : Int,
) -> Bool {
  if suffix_len <= 0 {
    return false
  }
  let end_idx = start_idx + suffix_len
  for idx = start_idx; idx < end_idx; idx = idx + 1 {
    let arity = @ir.hot_node_result_arity(
      func,
      @ir.hot_region_get(func, region_ref, idx),
    )
    if idx == end_idx - 1 {
      if arity != result_arity {
        return false
      }
    } else if arity != 0 {
      return false
    }
  }
  true
}

///|
fn code_folding_suffix_has_if_terminal(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
  suffix_len : Int,
) -> Bool {
  let end_idx = start_idx + suffix_len
  for idx = start_idx; idx < end_idx; idx = idx + 1 {
    if code_folding_node_is_if_terminal_suffix(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return true
    }
  }
  false
}

///|
fn code_folding_full_value_if_common_suffix_allowed(
  func : @ir.HotFunc,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef,
  then_start : Int,
  else_start : Int,
  suffix_len : Int,
  result_arity : Int,
) -> Bool {
  if result_arity == 0 || then_start != 0 || else_start != 0 {
    return true
  }
  if suffix_len > 1 {
    return true
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let else_root = @ir.hot_region_get(func, else_ref, 0)
  if then_root < 0 || else_root < 0 {
    return false
  }
  match @ir.hot_node_get(func, then_root).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  match @ir.hot_node_get(func, else_root).op {
    @ir.HotOp::Block => true
    _ => false
  }
}

///|
fn code_folding_heap_parent_accepts_embedded_value_wrapper(
  func : @ir.HotFunc,
  parent_id : Int,
) -> Bool {
  match @ir.hot_node_exact_instr(func, parent_id) {
    Some(@lib.Instruction::StructNew(_))
    | Some(@lib.Instruction::ArrayNew(_))
    | Some(@lib.Instruction::StructSet(_, _))
    | Some(@lib.Instruction::ArrayGet(_))
    | Some(@lib.Instruction::ArrayLen)
    | Some(@lib.Instruction::ArraySet(_))
    | Some(@lib.Instruction::ArrayFill(_)) => true
    _ => false
  }
}

///|
fn code_folding_parent_accepts_embedded_value_wrapper(
  func : @ir.HotFunc,
  parent_id : Int,
) -> Bool {
  if parent_id < 0 || !@ir.hot_node_is_live(func, parent_id) {
    return false
  }
  match @ir.hot_node_get(func, parent_id).op {
    @ir.HotOp::Select
    | @ir.HotOp::Drop
    | @ir.HotOp::Call
    | @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefTest
    | @ir.HotOp::RefCast
    | @ir.HotOp::TableGet
    | @ir.HotOp::TableSet
    | @ir.HotOp::TableGrow
    | @ir.HotOp::TableFill
    | @ir.HotOp::TableCopy
    | @ir.HotOp::TableInit
    | @ir.HotOp::MemoryGrow
    | @ir.HotOp::MemoryCopy
    | @ir.HotOp::MemoryFill
    | @ir.HotOp::MemoryInit
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Load
    | @ir.HotOp::LocalSet
    | @ir.HotOp::LocalTee
    | @ir.HotOp::GlobalSet
    | @ir.HotOp::Store
    | @ir.HotOp::Br
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCallRef => true
    @ir.HotOp::Heap =>
      code_folding_heap_parent_accepts_embedded_value_wrapper(func, parent_id)
    _ => false
  }
}

///|
fn code_folding_try_fold_embedded_value_if_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  parent_id : Int,
  child_slot : Int,
  if_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if parent_id < 0 ||
    if_id < 0 ||
    !@ir.hot_node_is_live(func, parent_id) ||
    !@ir.hot_node_is_live(func, if_id) ||
    !code_folding_parent_accepts_embedded_value_wrapper(func, parent_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  if code_folding_node_always_exits(func, condition) {
    return false
  }
  let result_types = @ir.hot_type_results(func, if_node.ty)
  if result_types.length() != 1 {
    return false
  }
  let result_arity = 1
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(ref_) => ref_
    None => return false
  }
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, then_ref, else_ref, label_used,
  )
  if suffix_len <= 0 {
    return false
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  let then_start = then_count - suffix_len
  let else_start = else_count - suffix_len
  if code_folding_region_prefix_has_exit(func, then_ref, then_start) ||
    code_folding_region_prefix_has_exit(func, else_ref, else_start) ||
    !code_folding_suffix_matches_result_arity(
      func, then_ref, then_start, suffix_len, result_arity,
    ) ||
    !code_folding_suffix_matches_result_arity(
      func, else_ref, else_start, suffix_len, result_arity,
    ) ||
    code_folding_suffix_has_if_terminal(func, then_ref, then_start, suffix_len) {
    return false
  }
  if then_start == 0 && else_start == 0 && suffix_len <= 1 {
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
  let replacement = if then_start == 0 && else_start == 0 {
    let drop_condition = @ir.hot_build_drop(func, condition)
    let nodes = [drop_condition]
    for node_id in hoisted {
      nodes.push(node_id)
    }
    nodes
  } else {
    @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
    let nodes = [if_id]
    for node_id in hoisted {
      nodes.push(node_id)
    }
    nodes
  }
  let wrapper = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(result_types[0]),
    replacement,
  )
  @ir.hot_child_set(func, parent_id, child_slot, wrapper)
  pass_mark_mutated(ctx, func)
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="embedded-value-if-common-suffix",
  )
  true
}

///|
fn code_folding_node_always_exits(func : @ir.HotFunc, node_id : Int) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Unreachable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => true
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      code_folding_node_always_exits(func, @ir.hot_child_get(func, node_id, 0))
    @ir.HotOp::Try | @ir.HotOp::TryTable => false
    @ir.HotOp::Block | @ir.HotOp::Loop => {
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
fn code_folding_node_is_noop_before_unreachable(
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Nop => true
    @ir.HotOp::Block => {
      if @ir.hot_node_result_arity(func, node_id) != 0 {
        return false
      }
      let label_id = @ir.hot_control_node_label(func, node_id)
      if pass_label_is_used(label_id, label_used) {
        return false
      }
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let body_count = @ir.hot_region_root_count(func, body_ref)
      for idx = 0; idx < body_count; idx = idx + 1 {
        if !code_folding_node_is_noop_before_unreachable(
            func,
            @ir.hot_region_get(func, body_ref, idx),
            label_used,
          ) {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn code_folding_try_remove_dead_block_before_unreachable_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  // Keep this byte-level cleanup out of large artifact functions until CF-L
  // resolves the current code-folding pass-local timing blocker.
  if @ir.hot_node_count(func) > 4096 {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  if label_id < 0 || @ir.hot_label_branch_arity(func, label_id) <= 1 {
    return false
  }
  let count = @ir.hot_region_root_count(func, region_ref)
  let mut after_unreachable = false
  if idx > 0 {
    let prev_id = @ir.hot_region_get(func, region_ref, idx - 1)
    if prev_id >= 0 {
      match @ir.hot_node_get(func, prev_id).op {
        @ir.HotOp::Unreachable => after_unreachable = true
        _ => ()
      }
    }
  }
  let mut before_unreachable = false
  if idx + 1 < count {
    let next_id = @ir.hot_region_get(func, region_ref, idx + 1)
    if next_id >= 0 {
      match @ir.hot_node_get(func, next_id).op {
        @ir.HotOp::Unreachable => before_unreachable = true
        _ => ()
      }
    }
  }
  if !after_unreachable && !before_unreachable {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if !after_unreachable && pass_label_is_used(label_id, label_used) {
    return false
  }
  let body_count = @ir.hot_region_root_count(func, body_ref)
  let mut unreachable_idx = -1
  for body_idx = 0; body_idx < body_count; body_idx = body_idx + 1 {
    let root_id = @ir.hot_region_get(func, body_ref, body_idx)
    if root_id < 0 {
      return false
    }
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
  if unreachable_idx <= 0 {
    return false
  }
  for body_idx = 0; body_idx < unreachable_idx; body_idx = body_idx + 1 {
    if !code_folding_node_is_noop_before_unreachable(
        func,
        @ir.hot_region_get(func, body_ref, body_idx),
        label_used,
      ) {
      return false
    }
  }
  let nop_id = @ir.hot_build_nop(func)
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, [nop_id]))
  @ir.hot_region_replace_body(func, body_ref, [])
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="remove-dead-block-before-unreachable",
  )
  true
}

///|
fn code_folding_try_flatten_exiting_block_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  if pass_label_is_used(label_id, label_used) {
    return false
  }
  if @ir.hot_node_result_arity(func, block_id) > 1 {
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
  if !code_folding_node_always_exits(func, block_id) {
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
fn code_folding_region_has_trailing_value_root(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let count = @ir.hot_region_root_count(func, region_ref)
  for next_idx = idx + 1; next_idx < count; next_idx = next_idx + 1 {
    let next_id = @ir.hot_region_get(func, region_ref, next_idx)
    if next_id >= 0 &&
      @ir.hot_node_is_live(func, next_id) &&
      @ir.hot_node_result_arity(func, next_id) > 0 {
      return true
    }
  }
  false
}

///|
fn code_folding_try_remove_unreachable_after_exit_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  preserve_bottom_tail : Bool,
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
  if preserve_bottom_tail &&
    (
      idx == @ir.hot_region_root_count(func, region_ref) - 1 ||
      code_folding_region_has_trailing_value_root(func, region_ref, idx)
    ) {
    return false
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
fn code_folding_node_prevents_fallthrough(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Delegate => true
    @ir.HotOp::Drop =>
      @ir.hot_child_count(func, node_id) == 1 &&
      code_folding_node_prevents_fallthrough(
        func,
        @ir.hot_child_get(func, node_id, 0),
      )
    @ir.HotOp::Try | @ir.HotOp::TryTable => false
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let count = @ir.hot_region_root_count(func, body_ref)
      count > 0 &&
      code_folding_node_prevents_fallthrough(
        func,
        @ir.hot_region_get(func, body_ref, count - 1),
      )
    }
    @ir.HotOp::If => {
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(ref_) => ref_
        None => return false
      }
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      let then_count = @ir.hot_region_root_count(func, then_ref)
      let else_count = @ir.hot_region_root_count(func, else_ref)
      then_count > 0 &&
      else_count > 0 &&
      code_folding_node_prevents_fallthrough(
        func,
        @ir.hot_region_get(func, then_ref, then_count - 1),
      ) &&
      code_folding_node_prevents_fallthrough(
        func,
        @ir.hot_region_get(func, else_ref, else_count - 1),
      )
    }
    _ => false
  }
}

///|
fn code_folding_branch_table_has_target(
  func : @ir.HotFunc,
  table_id : Int,
  target_label : Int,
) -> Bool {
  if @ir.hot_branch_table_default_target(func, table_id) == target_label {
    return true
  }
  for label_id in @ir.hot_branch_table_targets(func, table_id) {
    if label_id == target_label {
      return true
    }
  }
  false
}

///|
fn code_folding_node_has_direct_control_child(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
      match @ir.hot_node_get(func, child_id).op {
        @ir.HotOp::Block
        | @ir.HotOp::Loop
        | @ir.HotOp::If
        | @ir.HotOp::Try
        | @ir.HotOp::TryTable => return true
        _ => ()
      }
    }
  }
  false
}

///|
fn code_folding_embedded_control_visit_budget() -> Int {
  512
}

///|
fn code_folding_node_embedded_size_within_budget(
  func : @ir.HotFunc,
  node_id : Int,
  seen : Array[Int],
  budget : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  seen[0] = seen[0] + 1
  if seen[0] > budget {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        if !code_folding_node_embedded_size_within_budget(
            func,
            @ir.hot_region_get(func, body_ref, idx),
            seen,
            budget,
          ) {
          return false
        }
      }
      true
    }
    @ir.HotOp::If => {
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if !code_folding_node_embedded_size_within_budget(
            func,
            @ir.hot_region_get(func, then_ref, idx),
            seen,
            budget,
          ) {
          return false
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if !code_folding_node_embedded_size_within_budget(
                func,
                @ir.hot_region_get(func, else_ref, idx),
                seen,
                budget,
              ) {
              return false
            }
          }
          true
        }
        None => true
      }
    }
    _ => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !code_folding_node_embedded_size_within_budget(
            func,
            @ir.hot_child_get(func, node_id, slot),
            seen,
            budget,
          ) {
          return false
        }
      }
      true
    }
  }
}

///|
fn code_folding_node_has_embedded_branch_control_payload(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => code_folding_node_has_direct_control_child(func, node_id)
    @ir.HotOp::Try | @ir.HotOp::TryTable => false
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        if code_folding_node_has_embedded_branch_control_payload(
            func,
            @ir.hot_region_get(func, body_ref, idx),
          ) {
          return true
        }
      }
      false
    }
    @ir.HotOp::If => {
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if code_folding_node_has_embedded_branch_control_payload(
            func,
            @ir.hot_region_get(func, then_ref, idx),
          ) {
          return true
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if code_folding_node_has_embedded_branch_control_payload(
                func,
                @ir.hot_region_get(func, else_ref, idx),
              ) {
              return true
            }
          }
          false
        }
        None => false
      }
    }
    _ => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if code_folding_node_has_embedded_branch_control_payload(
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
fn code_folding_should_visit_drop_embedded_controls(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let seen = [0]
  code_folding_node_embedded_size_within_budget(
    func,
    node_id,
    seen,
    code_folding_embedded_control_visit_budget(),
  ) &&
  (
    code_folding_node_has_embedded_branch_control_payload(func, node_id) ||
    code_folding_node_has_direct_control_child(func, node_id)
  )
}

///|
fn code_folding_node_has_embedded_eh_control(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Try | @ir.HotOp::TryTable => true
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        if code_folding_node_has_embedded_eh_control(
            func,
            @ir.hot_region_get(func, body_ref, idx),
          ) {
          return true
        }
      }
      false
    }
    @ir.HotOp::If => {
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if code_folding_node_has_embedded_eh_control(
            func,
            @ir.hot_region_get(func, then_ref, idx),
          ) {
          return true
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if code_folding_node_has_embedded_eh_control(
                func,
                @ir.hot_region_get(func, else_ref, idx),
              ) {
              return true
            }
          }
          false
        }
        None => false
      }
    }
    _ => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if code_folding_node_has_embedded_eh_control(
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
fn code_folding_should_visit_drop_embedded_eh_body_if_suffixes(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let seen = [0]
  code_folding_node_embedded_size_within_budget(
    func,
    node_id,
    seen,
    code_folding_embedded_control_visit_budget(),
  ) &&
  code_folding_node_has_embedded_eh_control(func, node_id)
}

///|
fn code_folding_value_exit_tail_payload_count(
  tail : CodeFoldingValueExitTail,
) -> Int {
  tail.payload_roots.length()
}

///|
fn code_folding_value_exit_tail_logical_len(
  tail : CodeFoldingValueExitTail,
) -> Int {
  if tail.fallthrough {
    tail.tail_end_idx
  } else {
    tail.tail_end_idx + code_folding_value_exit_tail_payload_count(tail)
  }
}

///|
fn code_folding_value_exit_tail_item_at_depth(
  func : @ir.HotFunc,
  tail : CodeFoldingValueExitTail,
  depth : Int,
) -> Int {
  if depth < 0 {
    return -1
  }
  let payload_count = code_folding_value_exit_tail_payload_count(tail)
  if !tail.fallthrough && depth < payload_count {
    return tail.payload_roots[payload_count - 1 - depth]
  }
  let root_depth = if tail.fallthrough { depth } else { depth - payload_count }
  let idx = tail.tail_end_idx - 1 - root_depth
  if idx < 0 {
    return -1
  }
  @ir.hot_region_get(func, tail.region_ref, idx)
}

///|
fn code_folding_value_exit_tail_region_roots_to_move(
  tail : CodeFoldingValueExitTail,
  suffix_len : Int,
) -> Int {
  if tail.fallthrough {
    suffix_len
  } else {
    suffix_len - code_folding_value_exit_tail_payload_count(tail)
  }
}

///|
fn code_folding_value_exit_tail_still_at_site(
  func : @ir.HotFunc,
  tail : CodeFoldingValueExitTail,
) -> Bool {
  if tail.tail_end_idx < 0 {
    return false
  }
  if tail.fallthrough {
    return @ir.hot_region_root_count(func, tail.region_ref) == tail.tail_end_idx
  }
  if tail.tail_end_idx >= @ir.hot_region_root_count(func, tail.region_ref) ||
    @ir.hot_region_get(func, tail.region_ref, tail.tail_end_idx) !=
    tail.branch_id {
    return false
  }
  if !@ir.hot_node_is_live(func, tail.branch_id) {
    return false
  }
  let node = @ir.hot_node_get(func, tail.branch_id)
  match node.op {
    @ir.HotOp::Br => ()
    _ => return false
  }
  if node.imm0 != tail.target_label ||
    node.child_count != tail.payload_roots.length() {
    return false
  }
  for slot = 0; slot < tail.payload_roots.length(); slot = slot + 1 {
    if @ir.hot_child_get(func, tail.branch_id, slot) != tail.payload_roots[slot] {
      return false
    }
  }
  true
}

///|
fn code_folding_value_exit_tail_suffix_roots(
  func : @ir.HotFunc,
  tail : CodeFoldingValueExitTail,
  suffix_len : Int,
) -> Array[Int] {
  let roots : Array[Int] = []
  let region_root_count = code_folding_value_exit_tail_region_roots_to_move(
    tail, suffix_len,
  )
  let start_idx = tail.tail_end_idx - region_root_count
  for idx = start_idx; idx < tail.tail_end_idx; idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, tail.region_ref, idx))
  }
  if !tail.fallthrough {
    for payload_id in tail.payload_roots {
      roots.push(payload_id)
    }
  }
  roots
}

///|
fn code_folding_collect_value_block_exit_tails_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  target_label : Int,
  result_arity : Int,
  tails : Array[CodeFoldingValueExitTail],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => if node.imm0 == target_label { return false }
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate => if node.imm0 == target_label { return false }
    @ir.HotOp::BrTable =>
      if code_folding_branch_table_has_target(func, node.imm0, target_label) {
        return false
      }
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      if !code_folding_collect_value_block_exit_tails(
          func,
          @ir.hot_region_body_ref(func, node_id),
          target_label,
          result_arity,
          tails,
        ) {
        return false
      }
    @ir.HotOp::If => {
      if !code_folding_collect_value_block_exit_tails(
          func,
          @ir.hot_region_then_ref(func, node_id),
          target_label,
          result_arity,
          tails,
        ) {
        return false
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if !code_folding_collect_value_block_exit_tails(
              func, else_ref, target_label, result_arity, tails,
            ) {
            return false
          }
        None => ()
      }
    }
    @ir.HotOp::Try | @ir.HotOp::TryTable => return false
    _ => ()
  }
  true
}

///|
fn code_folding_collect_value_block_exit_tails(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
  result_arity : Int,
  tails : Array[CodeFoldingValueExitTail],
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      return false
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br =>
        if node.imm0 == target_label {
          if result_arity <= 0 || node.child_count != result_arity {
            return false
          }
          let payload_roots : Array[Int] = []
          for slot = 0; slot < node.child_count; slot = slot + 1 {
            payload_roots.push(@ir.hot_child_get(func, node_id, slot))
          }
          tails.push(
            code_folding_value_exit_tail_branch(
              region_ref, idx, node_id, target_label, payload_roots, result_arity,
            ),
          )
        } else if idx == @ir.hot_region_root_count(func, region_ref) - 1 {
          for slot = 0; slot < node.child_count; slot = slot + 1 {
            let child_id = @ir.hot_child_get(func, node_id, slot)
            if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
              match @ir.hot_node_get(func, child_id).op {
                @ir.HotOp::Block
                | @ir.HotOp::Loop
                | @ir.HotOp::If
                | @ir.HotOp::Try
                | @ir.HotOp::TryTable =>
                  if !code_folding_collect_value_block_exit_tails_in_node(
                      func, child_id, target_label, result_arity, tails,
                    ) {
                    return false
                  }
                _ => ()
              }
            }
          }
        }
      @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => if node.imm0 == target_label { return false }
      @ir.HotOp::BrTable =>
        if code_folding_branch_table_has_target(func, node.imm0, target_label) {
          return false
        }
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if !code_folding_collect_value_block_exit_tails(
            func,
            @ir.hot_region_body_ref(func, node_id),
            target_label,
            result_arity,
            tails,
          ) {
          return false
        }
      @ir.HotOp::If => {
        if !code_folding_collect_value_block_exit_tails(
            func,
            @ir.hot_region_then_ref(func, node_id),
            target_label,
            result_arity,
            tails,
          ) {
          return false
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if !code_folding_collect_value_block_exit_tails(
                func, else_ref, target_label, result_arity, tails,
              ) {
              return false
            }
          None => ()
        }
      }
      @ir.HotOp::Try | @ir.HotOp::TryTable => return false
      _ => ()
    }
  }
  true
}

///|
fn code_folding_value_exit_usable_suffix_len(
  suffix_len : Int,
  result_arity : Int,
) -> Int {
  if suffix_len >= result_arity {
    suffix_len
  } else {
    0
  }
}

///|
fn code_folding_value_exit_expected_item_arity(
  depth : Int,
  result_arity : Int,
) -> Int {
  if depth < result_arity {
    1
  } else {
    0
  }
}

///|
fn code_folding_common_value_block_exit_suffix_len(
  func : @ir.HotFunc,
  block_id : Int,
  target_label : Int,
  result_arity : Int,
  tails : Array[CodeFoldingValueExitTail],
  label_used : @bitset.BitSet,
) -> Int {
  if result_arity <= 0 || tails.length() < 2 {
    return 0
  }
  for tail in tails {
    if tail.target_label != target_label ||
      tail.result_arity != result_arity ||
      !tail.movement_safe ||
      (!tail.fallthrough && tail.payload_roots.length() != result_arity) ||
      !code_folding_value_exit_tail_still_at_site(func, tail) {
      return 0
    }
  }
  let mut count = 0
  while true {
    for tail in tails {
      if code_folding_value_exit_tail_logical_len(tail) <= count {
        return code_folding_value_exit_usable_suffix_len(count, result_arity)
      }
    }
    let first = code_folding_value_exit_tail_item_at_depth(
      func,
      tails[0],
      count,
    )
    let expected_arity = code_folding_value_exit_expected_item_arity(
      count, result_arity,
    )
    if first < 0 ||
      @ir.hot_node_result_arity(func, first) != expected_arity ||
      (
        count >= result_arity &&
        code_folding_node_prevents_fallthrough(func, first)
      ) ||
      !code_folding_node_is_hoistable_suffix(func, first, block_id, label_used) {
      return code_folding_value_exit_usable_suffix_len(count, result_arity)
    }
    for tail_idx = 1; tail_idx < tails.length(); tail_idx = tail_idx + 1 {
      let other = code_folding_value_exit_tail_item_at_depth(
        func,
        tails[tail_idx],
        count,
      )
      if other < 0 ||
        @ir.hot_node_result_arity(func, other) != expected_arity ||
        (
          count >= result_arity &&
          code_folding_node_prevents_fallthrough(func, other)
        ) ||
        !code_folding_node_is_hoistable_suffix(
          func, other, block_id, label_used,
        ) ||
        !code_folding_nodes_equal(func, first, other, label_used) {
        return code_folding_value_exit_usable_suffix_len(count, result_arity)
      }
    }
    count += 1
  }
  0
}

///|
fn code_folding_value_block_exit_suffix_profitability(
  func : @ir.HotFunc,
  tail : CodeFoldingValueExitTail,
  suffix_len : Int,
  duplicate_count : Int,
) -> Int {
  let roots = code_folding_value_exit_tail_suffix_roots(func, tail, suffix_len)
  let mut measure = 0
  for root_id in roots {
    measure += code_folding_node_measure(func, root_id)
  }
  measure * duplicate_count
}

///|
fn code_folding_append_value_exit_tail_removal(
  tail : CodeFoldingValueExitTail,
  removals : Array[CodeFoldingRegionRemoval],
) -> Bool {
  let root_count = code_folding_value_exit_tail_region_roots_to_move(
    tail,
    tail.suffix_len,
  )
  if root_count < 0 || root_count > tail.tail_end_idx {
    return false
  }
  if root_count > 0 {
    removals.push({
      region_ref: tail.region_ref,
      start_idx: tail.tail_end_idx - root_count,
      remove_count: root_count,
    })
  }
  true
}

///|
fn code_folding_region_removal_order(
  lhs : CodeFoldingRegionRemoval,
  rhs : CodeFoldingRegionRemoval,
) -> Int {
  if lhs.region_ref.holder == rhs.region_ref.holder {
    rhs.start_idx - lhs.start_idx
  } else {
    rhs.region_ref.holder - lhs.region_ref.holder
  }
}

///|
fn code_folding_try_fold_value_block_exit_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  let block_node = @ir.hot_node_get(func, block_id)
  match block_node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if idx != @ir.hot_region_root_count(func, region_ref) - 1 {
    return false
  }
  let result_arity = @ir.hot_type_result_arity(func, block_node.ty)
  if result_arity <= 0 {
    return false
  }
  let target_label = @ir.hot_control_node_label(func, block_id)
  if target_label < 0 ||
    @ir.hot_label_branch_arity(func, target_label) != result_arity ||
    !pass_label_is_used(target_label, label_used) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return false
  }
  let tails : Array[CodeFoldingValueExitTail] = []
  if !code_folding_collect_value_block_exit_tails(
      func, body_ref, target_label, result_arity, tails,
    ) {
    return false
  }
  let last_root = @ir.hot_region_get(func, body_ref, body_count - 1)
  if !code_folding_node_prevents_fallthrough(func, last_root) {
    tails.push(
      code_folding_value_exit_tail_fallthrough(
        body_ref, body_count, target_label, last_root, result_arity,
      ),
    )
  }
  let suffix_len = code_folding_common_value_block_exit_suffix_len(
    func, block_id, target_label, result_arity, tails, label_used,
  )
  if suffix_len == 0 {
    return false
  }
  let profitability = code_folding_value_block_exit_suffix_profitability(
    func,
    tails[0],
    suffix_len,
    tails.length() - 1,
  )
  if profitability <= 0 {
    return false
  }
  let planned_tails : Array[CodeFoldingValueExitTail] = []
  for tail in tails {
    planned_tails.push(
      code_folding_value_exit_tail_with_plan(tail, suffix_len, profitability),
    )
  }
  if planned_tails.length() == 0 || planned_tails[0].profitability <= 0 {
    return false
  }
  let hoisted = code_folding_value_exit_tail_suffix_roots(
    func,
    planned_tails[0],
    planned_tails[0].suffix_len,
  )
  if hoisted.length() == 0 {
    return false
  }

  let removals : Array[CodeFoldingRegionRemoval] = []
  let mut removed_branch_payload = false
  for tail in planned_tails {
    if !code_folding_append_value_exit_tail_removal(tail, removals) {
      return false
    }
    if !tail.fallthrough {
      ignore(@ir.hot_replace_child_span(func, tail.branch_id, []))
      removed_branch_payload = true
    }
  }
  if removed_branch_payload {
    pass_mark_mutated(ctx, func)
  }
  removals.sort_by(code_folding_region_removal_order)
  for removal in removals {
    ignore(
      pass_splice_region(
        ctx,
        func,
        removal.region_ref,
        removal.start_idx,
        removal.remove_count,
        [],
      ),
    )
  }
  @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
  pass_mark_mutated(ctx, func)
  ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, hoisted))
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="value-block-exit-common-suffix",
  )
  true
}

///|
fn code_folding_collect_block_exit_tails_in_node(
  func : @ir.HotFunc,
  node_id : Int,
  target_label : Int,
  tails : Array[CodeFoldingExitTail],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br =>
      if node.imm0 == target_label {
        return false
      } else {
        for slot = 0; slot < node.child_count; slot = slot + 1 {
          let child_id = @ir.hot_child_get(func, node_id, slot)
          if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
            match @ir.hot_node_get(func, child_id).op {
              @ir.HotOp::Block
              | @ir.HotOp::Loop
              | @ir.HotOp::If
              | @ir.HotOp::Try
              | @ir.HotOp::TryTable =>
                if !code_folding_collect_block_exit_tails_in_node(
                    func, child_id, target_label, tails,
                  ) {
                  return false
                }
              _ => ()
            }
          }
        }
      }
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate => if node.imm0 == target_label { return false }
    @ir.HotOp::BrTable =>
      if code_folding_branch_table_has_target(func, node.imm0, target_label) {
        return false
      }
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      if !code_folding_collect_block_exit_tails(
          func,
          @ir.hot_region_body_ref(func, node_id),
          target_label,
          tails,
        ) {
        return false
      }
    @ir.HotOp::If => {
      if !code_folding_collect_block_exit_tails(
          func,
          @ir.hot_region_then_ref(func, node_id),
          target_label,
          tails,
        ) {
        return false
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if !code_folding_collect_block_exit_tails(
              func, else_ref, target_label, tails,
            ) {
            return false
          }
        None => ()
      }
    }
    @ir.HotOp::Try | @ir.HotOp::TryTable => return false
    _ => ()
  }
  true
}

///|
fn code_folding_collect_block_exit_tails(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
  tails : Array[CodeFoldingExitTail],
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      return false
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br =>
        if node.imm0 == target_label {
          if node.child_count != 0 || idx == 0 {
            return false
          }
          tails.push({ region_ref, end_idx: idx })
        } else if idx == @ir.hot_region_root_count(func, region_ref) - 1 {
          for slot = 0; slot < node.child_count; slot = slot + 1 {
            let child_id = @ir.hot_child_get(func, node_id, slot)
            if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
              match @ir.hot_node_get(func, child_id).op {
                @ir.HotOp::Block
                | @ir.HotOp::Loop
                | @ir.HotOp::If
                | @ir.HotOp::Try
                | @ir.HotOp::TryTable =>
                  if !code_folding_collect_block_exit_tails_in_node(
                      func, child_id, target_label, tails,
                    ) {
                    return false
                  }
                _ => ()
              }
            }
          }
        }
      @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => if node.imm0 == target_label { return false }
      @ir.HotOp::BrTable =>
        if code_folding_branch_table_has_target(func, node.imm0, target_label) {
          return false
        }
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if !code_folding_collect_block_exit_tails(
            func,
            @ir.hot_region_body_ref(func, node_id),
            target_label,
            tails,
          ) {
          return false
        }
      @ir.HotOp::If => {
        if !code_folding_collect_block_exit_tails(
            func,
            @ir.hot_region_then_ref(func, node_id),
            target_label,
            tails,
          ) {
          return false
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if !code_folding_collect_block_exit_tails(
                func, else_ref, target_label, tails,
              ) {
              return false
            }
          None => ()
        }
      }
      @ir.HotOp::Try | @ir.HotOp::TryTable => return false
      _ => ()
    }
  }
  true
}

///|
fn code_folding_exit_tail_regions_are_unique(
  tails : Array[CodeFoldingExitTail],
) -> Bool {
  for i = 0; i < tails.length(); i = i + 1 {
    for j = i + 1; j < tails.length(); j = j + 1 {
      if tails[i].region_ref.holder == tails[j].region_ref.holder {
        return false
      }
    }
  }
  true
}

///|
fn code_folding_common_block_exit_suffix_len(
  func : @ir.HotFunc,
  block_id : Int,
  tails : Array[CodeFoldingExitTail],
  label_used : @bitset.BitSet,
) -> Int {
  if tails.length() < 2 {
    return 0
  }
  let mut limit = tails[0].end_idx
  for tail in tails {
    if tail.end_idx < limit {
      limit = tail.end_idx
    }
  }
  let mut count = 0
  while count < limit {
    let first = @ir.hot_region_get(
      func,
      tails[0].region_ref,
      tails[0].end_idx - 1 - count,
    )
    if @ir.hot_node_result_arity(func, first) != 0 ||
      !code_folding_node_is_hoistable_suffix(func, first, block_id, label_used) {
      break
    }
    let mut all_match = true
    for tail_idx = 1; tail_idx < tails.length(); tail_idx = tail_idx + 1 {
      let other = @ir.hot_region_get(
        func,
        tails[tail_idx].region_ref,
        tails[tail_idx].end_idx - 1 - count,
      )
      if @ir.hot_node_result_arity(func, other) != 0 ||
        !code_folding_node_is_hoistable_suffix(
          func, other, block_id, label_used,
        ) ||
        !code_folding_nodes_equal(func, first, other, label_used) {
        all_match = false
      }
    }
    if !all_match {
      break
    }
    count += 1
  }
  count
}

///|
fn code_folding_try_fold_block_exit_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let target_label = @ir.hot_control_node_label(func, block_id)
  if target_label < 0 ||
    @ir.hot_label_branch_arity(func, target_label) != 0 ||
    !pass_label_is_used(target_label, label_used) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 0 {
    return false
  }
  let tails : Array[CodeFoldingExitTail] = []
  if !code_folding_collect_block_exit_tails(func, body_ref, target_label, tails) {
    return false
  }
  let last_root = @ir.hot_region_get(func, body_ref, body_count - 1)
  if !code_folding_node_prevents_fallthrough(func, last_root) {
    tails.push({ region_ref: body_ref, end_idx: body_count })
  }
  if tails.length() < 2 || !code_folding_exit_tail_regions_are_unique(tails) {
    return false
  }
  let suffix_len = code_folding_common_block_exit_suffix_len(
    func, block_id, tails, label_used,
  )
  if suffix_len == 0 {
    return false
  }
  let hoisted = pass_splice_region(
    ctx,
    func,
    tails[0].region_ref,
    tails[0].end_idx - suffix_len,
    suffix_len,
    [],
  )
  for tail_idx = 1; tail_idx < tails.length(); tail_idx = tail_idx + 1 {
    ignore(
      pass_splice_region(
        ctx,
        func,
        tails[tail_idx].region_ref,
        tails[tail_idx].end_idx - suffix_len,
        suffix_len,
        [],
      ),
    )
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, hoisted))
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="block-exit-common-suffix",
  )
  true
}

///|
fn code_folding_region_single_unused_block(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
) -> Int {
  if @ir.hot_region_root_count(func, region_ref) != 1 {
    return -1
  }
  let block_id = @ir.hot_region_get(func, region_ref, 0)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return -1
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return -1
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  if pass_label_is_used(label_id, label_used) {
    return -1
  }
  block_id
}

///|
fn code_folding_block_suffix_matches_region(
  func : @ir.HotFunc,
  if_id : Int,
  block_body_ref : @ir.HotRegionRef,
  block_start : Int,
  other_ref : @ir.HotRegionRef,
  other_start : Int,
  suffix_len : Int,
  result_arity : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if suffix_len <= 0 ||
    block_start < 0 ||
    other_start < 0 ||
    code_folding_region_prefix_has_exit(func, block_body_ref, block_start) ||
    code_folding_region_prefix_has_exit(func, other_ref, other_start) ||
    !code_folding_suffix_matches_result_arity(
      func, block_body_ref, block_start, suffix_len, result_arity,
    ) ||
    !code_folding_suffix_matches_result_arity(
      func, other_ref, other_start, suffix_len, result_arity,
    ) ||
    code_folding_suffix_has_if_terminal(
      func, block_body_ref, block_start, suffix_len,
    ) {
    return false
  }
  for offset = 0; offset < suffix_len; offset = offset + 1 {
    let block_root = @ir.hot_region_get(
      func,
      block_body_ref,
      block_start + offset,
    )
    let other_root = @ir.hot_region_get(func, other_ref, other_start + offset)
    if !code_folding_node_is_if_hoistable_suffix(
        func, block_root, if_id, label_used,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, other_root, if_id, label_used,
      ) ||
      !code_folding_nodes_equal(func, block_root, other_root, label_used) {
      return false
    }
  }
  true
}

///|
fn code_folding_try_fold_one_block_if_arm(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  if_id : Int,
  block_region_ref : @ir.HotRegionRef,
  other_ref : @ir.HotRegionRef,
  result_arity : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  let block_id = code_folding_region_single_unused_block(
    func, block_region_ref, label_used,
  )
  if block_id < 0 {
    return false
  }
  if @ir.hot_type_result_arity(func, @ir.hot_node_get(func, block_id).ty) !=
    result_arity {
    return false
  }
  let block_body_ref = @ir.hot_region_body_ref(func, block_id)
  let block_count = @ir.hot_region_root_count(func, block_body_ref)
  let other_count = @ir.hot_region_root_count(func, other_ref)
  if other_count == 0 || block_count == 0 {
    return false
  }
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, block_body_ref, other_ref, label_used,
  )
  if suffix_len == 0 {
    return false
  }
  let block_start = block_count - suffix_len
  let other_start = other_count - suffix_len
  if !code_folding_block_suffix_matches_region(
      func, if_id, block_body_ref, block_start, other_ref, other_start, suffix_len,
      result_arity, label_used,
    ) {
    return false
  }

  let hoisted = pass_splice_region(
    ctx,
    func,
    block_body_ref,
    block_start,
    suffix_len,
    [],
  )
  ignore(pass_splice_region(ctx, func, other_ref, other_start, suffix_len, []))
  if block_start == 0 && other_start == 0 {
    let condition = @ir.hot_child_get(func, if_id, 0)
    let drop_condition = @ir.hot_build_drop(func, condition)
    let replacement = [drop_condition]
    for node_id in hoisted {
      replacement.push(node_id)
    }
    ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
  } else {
    if result_arity != 0 {
      @ir.hot_control_result_type_set(func, block_id, @ir.hot_type_void(func))
      @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
      pass_mark_mutated(ctx, func)
    }
    ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, hoisted))
  }
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="if-one-block-common-suffix",
  )
  true
}

///|
fn code_folding_try_fold_two_block_if_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  if_id : Int,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef,
  result_arity : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  let then_block = code_folding_region_single_unused_block(
    func, then_ref, label_used,
  )
  let else_block = code_folding_region_single_unused_block(
    func, else_ref, label_used,
  )
  if then_block < 0 || else_block < 0 {
    return false
  }
  let then_type = @ir.hot_node_get(func, then_block).ty
  let else_type = @ir.hot_node_get(func, else_block).ty
  if then_type != else_type ||
    @ir.hot_type_result_arity(func, then_type) != result_arity {
    return false
  }
  let then_body_ref = @ir.hot_region_body_ref(func, then_block)
  let else_body_ref = @ir.hot_region_body_ref(func, else_block)
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, then_body_ref, else_body_ref, label_used,
  )
  if suffix_len == 0 {
    return false
  }
  let then_count = @ir.hot_region_root_count(func, then_body_ref)
  let else_count = @ir.hot_region_root_count(func, else_body_ref)
  let then_start = then_count - suffix_len
  let else_start = else_count - suffix_len
  if then_start == 0 && else_start == 0 {
    return false
  }
  if code_folding_region_prefix_has_exit(func, then_body_ref, then_start) ||
    code_folding_region_prefix_has_exit(func, else_body_ref, else_start) ||
    !code_folding_suffix_matches_result_arity(
      func, then_body_ref, then_start, suffix_len, result_arity,
    ) ||
    !code_folding_suffix_matches_result_arity(
      func, else_body_ref, else_start, suffix_len, result_arity,
    ) ||
    code_folding_suffix_has_if_terminal(
      func, then_body_ref, then_start, suffix_len,
    ) {
    return false
  }

  let hoisted = pass_splice_region(
    ctx,
    func,
    then_body_ref,
    then_start,
    suffix_len,
    [],
  )
  ignore(
    pass_splice_region(ctx, func, else_body_ref, else_start, suffix_len, []),
  )
  if result_arity != 0 {
    @ir.hot_control_result_type_set(func, then_block, @ir.hot_type_void(func))
    @ir.hot_control_result_type_set(func, else_block, @ir.hot_type_void(func))
    @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
    pass_mark_mutated(ctx, func)
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx + 1, 0, hoisted))
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="if-two-block-common-suffix",
  )
  true
}

///|
fn code_folding_try_fold_one_block_if_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  if_id : Int,
  then_ref : @ir.HotRegionRef,
  else_ref : @ir.HotRegionRef,
  result_arity : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  code_folding_try_fold_one_block_if_arm(
    ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
  ) ||
  code_folding_try_fold_one_block_if_arm(
    ctx, func, region_ref, idx, if_id, else_ref, then_ref, result_arity, label_used,
  )
}

///|
fn code_folding_terminating_tail(
  region_ref : @ir.HotRegionRef,
  end_idx : Int,
  terminal_kind : Int,
) -> CodeFoldingTerminatingTail {
  { region_ref, end_idx, terminal_kind, suffix_len: 0, profitability: 0 }
}

///|
fn code_folding_terminating_tail_with_plan(
  tail : CodeFoldingTerminatingTail,
  suffix_len : Int,
  profitability : Int,
) -> CodeFoldingTerminatingTail {
  {
    region_ref: tail.region_ref,
    end_idx: tail.end_idx,
    terminal_kind: tail.terminal_kind,
    suffix_len,
    profitability,
  }
}

///|
fn code_folding_terminating_tail_item_at_depth(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  depth : Int,
) -> Int {
  if depth < 0 || tail.end_idx <= depth {
    return -1
  }
  @ir.hot_region_get(func, tail.region_ref, tail.end_idx - 1 - depth)
}

///|
fn code_folding_terminating_tail_still_at_site(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
) -> Bool {
  if tail.end_idx <= 0 ||
    tail.end_idx > @ir.hot_region_root_count(func, tail.region_ref) {
    return false
  }
  code_folding_terminal_tail_kind_of_node(
    func,
    @ir.hot_region_get(func, tail.region_ref, tail.end_idx - 1),
  ) ==
  tail.terminal_kind
}

///|
fn code_folding_terminating_tail_is_root_end(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
) -> Bool {
  tail.region_ref == @ir.HotRegionRef::root() &&
  tail.end_idx == @ir.hot_region_root_count(func, @ir.HotRegionRef::root())
}

///|
fn code_folding_collect_terminating_tails(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  tails : Array[CodeFoldingTerminatingTail],
) -> Bool {
  let count = @ir.hot_region_root_count(func, region_ref)
  if count > 0 {
    let last_id = @ir.hot_region_get(func, region_ref, count - 1)
    let kind = code_folding_terminal_tail_kind_of_node(func, last_id)
    if kind != 0 {
      tails.push(code_folding_terminating_tail(region_ref, count, kind))
    }
  }
  for idx = 0; idx < count; idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      return false
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        if !code_folding_collect_terminating_tails(
            func,
            @ir.hot_region_body_ref(func, node_id),
            tails,
          ) {
          return false
        }
      @ir.HotOp::If => {
        if !code_folding_collect_terminating_tails(
            func,
            @ir.hot_region_then_ref(func, node_id),
            tails,
          ) {
          return false
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if !code_folding_collect_terminating_tails(func, else_ref, tails) {
              return false
            }
          None => ()
        }
      }
      @ir.HotOp::Try | @ir.HotOp::TryTable => return false
      _ => ()
    }
  }
  true
}

///|
fn code_folding_terminating_suffix_measure(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  suffix_len : Int,
) -> Int {
  if suffix_len <= 0 || tail.end_idx < suffix_len {
    return 0
  }
  let mut total = 0
  let start_idx = tail.end_idx - suffix_len
  for idx = start_idx; idx < tail.end_idx; idx = idx + 1 {
    total += code_folding_node_measure(
      func,
      @ir.hot_region_get(func, tail.region_ref, idx),
    )
  }
  total
}

///|
fn code_folding_terminating_tail_group_has_root_end(
  func : @ir.HotFunc,
  tails : Array[CodeFoldingTerminatingTail],
) -> Bool {
  for tail in tails {
    if code_folding_terminating_tail_is_root_end(func, tail) {
      return true
    }
  }
  false
}

///|
fn code_folding_node_is_simple_tail_call_operand(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::Const
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc => true
    _ => false
  }
}

///|
fn code_folding_terminating_suffix_is_tail_call_operands_only(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  suffix_len : Int,
) -> Bool {
  let terminal_id = code_folding_terminating_tail_item_at_depth(func, tail, 0)
  if terminal_id < 0 || !@ir.hot_node_is_live(func, terminal_id) {
    return false
  }
  match @ir.hot_node_get(func, terminal_id).op {
    @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef => ()
    _ => return false
  }
  if suffix_len <= 1 {
    return true
  }
  for depth = 1; depth < suffix_len; depth = depth + 1 {
    if !code_folding_node_is_simple_tail_call_operand(
        func,
        code_folding_terminating_tail_item_at_depth(func, tail, depth),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_pick_terminating_tail_group_from_anchor(
  func : @ir.HotFunc,
  anchor_tail : CodeFoldingTerminatingTail,
  candidates : Array[CodeFoldingTerminatingTail],
  label_used : @bitset.BitSet,
) -> Array[CodeFoldingTerminatingTail] {
  let mut current = candidates
  let mut best : Array[CodeFoldingTerminatingTail] = []
  let mut best_len = 0
  let mut depth = 0
  while true {
    let anchor = code_folding_terminating_tail_item_at_depth(
      func, anchor_tail, depth,
    )
    if anchor < 0 {
      break
    }
    if !code_folding_terminal_tail_item_is_movable(
        func, anchor_tail, anchor, depth, label_used,
      ) {
      if code_folding_terminal_tail_item_has_external_break_target(
          func, anchor_tail, anchor,
        ) {
        return []
      }
      break
    }
    let next : Array[CodeFoldingTerminatingTail] = []
    let mut blocked_by_external_target = false
    for tail in current {
      let item = code_folding_terminating_tail_item_at_depth(func, tail, depth)
      if code_folding_terminal_tail_item_has_external_break_target(
          func, tail, item,
        ) {
        blocked_by_external_target = true
      }
      if item >= 0 &&
        code_folding_terminal_tail_item_is_movable(
          func, tail, item, depth, label_used,
        ) &&
        code_folding_nodes_equal(func, anchor, item, label_used) {
        next.push(tail)
      }
    }
    if blocked_by_external_target {
      return []
    }
    if next.length() < 2 {
      break
    }
    best = next
    best_len = depth + 1
    current = best
    depth += 1
  }
  if best_len == 0 || best.length() < 2 {
    return []
  }
  let profitability = code_folding_terminating_suffix_measure(
      func, anchor_tail, best_len,
    ) *
    (best.length() - 1)
  if profitability < 3 ||
    code_folding_terminating_suffix_is_tail_call_operands_only(
      func, anchor_tail, best_len,
    ) {
    return []
  }
  let planned : Array[CodeFoldingTerminatingTail] = []
  for tail in best {
    planned.push(
      code_folding_terminating_tail_with_plan(tail, best_len, profitability),
    )
  }
  planned
}

///|
fn code_folding_pick_terminating_tail_group(
  func : @ir.HotFunc,
  desired_kind : Int,
  all_tails : Array[CodeFoldingTerminatingTail],
  label_used : @bitset.BitSet,
) -> Array[CodeFoldingTerminatingTail] {
  let candidates : Array[CodeFoldingTerminatingTail] = []
  for tail in all_tails {
    if tail.terminal_kind == desired_kind &&
      code_folding_terminating_tail_still_at_site(func, tail) {
      candidates.push(tail)
    }
  }
  if candidates.length() < 2 {
    return []
  }
  let mut best : Array[CodeFoldingTerminatingTail] = []
  let mut best_len = 0
  let mut best_profitability = 0
  let mut best_has_root = false
  for anchor_tail in candidates {
    let planned = code_folding_pick_terminating_tail_group_from_anchor(
      func, anchor_tail, candidates, label_used,
    )
    if planned.length() > 0 {
      let planned_len = planned[0].suffix_len
      let planned_profitability = planned[0].profitability
      let planned_has_root = code_folding_terminating_tail_group_has_root_end(
        func, planned,
      )
      if planned_len > best_len ||
        (planned_len == best_len && planned_profitability > best_profitability) ||
        (
          planned_len == best_len &&
          planned_profitability == best_profitability &&
          planned_has_root &&
          !best_has_root
        ) {
        best = planned
        best_len = planned_len
        best_profitability = planned_profitability
        best_has_root = planned_has_root
      }
    }
  }
  best
}

///|
fn code_folding_try_rewrite_terminating_tail_group(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  tails : Array[CodeFoldingTerminatingTail],
) -> Bool {
  if tails.length() < 2 || tails[0].suffix_len <= 0 {
    return false
  }
  let root_ref = @ir.HotRegionRef::root()
  let root_tails : Array[CodeFoldingTerminatingTail] = []
  for tail in tails {
    if tail.suffix_len != tails[0].suffix_len ||
      tail.profitability != tails[0].profitability ||
      !code_folding_terminating_tail_still_at_site(func, tail) {
      return false
    }
    if code_folding_terminating_tail_is_root_end(func, tail) {
      root_tails.push(tail)
    }
  }
  if root_tails.length() > 1 {
    return false
  }
  let has_root_tail = root_tails.length() == 1
  let root_count_before_rewrite = @ir.hot_region_root_count(func, root_ref)
  let root_prevents_fallthrough = root_count_before_rewrite > 0 &&
    code_folding_node_prevents_fallthrough(
      func,
      @ir.hot_region_get(func, root_ref, root_count_before_rewrite - 1),
    )
  let needs_fallthrough_skip = !has_root_tail && !root_prevents_fallthrough
  if needs_fallthrough_skip && @ir.hot_region_result_arity(func, root_ref) != 0 {
    return false
  }
  let anchor_tail = if has_root_tail { root_tails[0] } else { tails[0] }
  let suffix_len = anchor_tail.suffix_len
  let anchor_start = anchor_tail.end_idx - suffix_len
  if anchor_start < 0 {
    return false
  }
  let hoisted = pass_splice_region(
    ctx,
    func,
    anchor_tail.region_ref,
    anchor_start,
    suffix_len,
    [],
  )
  let wrapper = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let wrapper_label = @ir.hot_control_node_label(func, wrapper)
  let skip_wrapper = if needs_fallthrough_skip {
    @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  } else {
    -1
  }
  let skip_label = if needs_fallthrough_skip {
    @ir.hot_control_node_label(func, skip_wrapper)
  } else {
    -1
  }
  for tail in tails {
    let start_idx = tail.end_idx - suffix_len
    if start_idx < 0 {
      return false
    }
    let is_anchor = tail.region_ref == anchor_tail.region_ref &&
      tail.end_idx == anchor_tail.end_idx
    if has_root_tail && is_anchor {
      continue
    }
    let branch = @ir.hot_build_br(func, wrapper_label)
    let remove_count = if is_anchor { 0 } else { suffix_len }
    ignore(
      pass_splice_region(ctx, func, tail.region_ref, start_idx, remove_count, [
        branch,
      ]),
    )
  }
  let prefix_count = @ir.hot_region_root_count(func, root_ref)
  let prefix_roots = pass_splice_region(ctx, func, root_ref, 0, prefix_count, [])
  if needs_fallthrough_skip {
    prefix_roots.push(@ir.hot_build_br(func, skip_label))
  }
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, wrapper),
    prefix_roots,
  )
  if needs_fallthrough_skip {
    let skip_roots = [wrapper]
    for node_id in hoisted {
      skip_roots.push(node_id)
    }
    @ir.hot_region_replace_body(
      func,
      @ir.hot_region_body_ref(func, skip_wrapper),
      skip_roots,
    )
    ignore(pass_splice_region(ctx, func, root_ref, 0, 0, [skip_wrapper]))
  } else {
    let replacement = [wrapper]
    for node_id in hoisted {
      replacement.push(node_id)
    }
    ignore(pass_splice_region(ctx, func, root_ref, 0, 0, replacement))
  }
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="terminating-tail-common-suffix",
  )
  true
}

///|
fn code_folding_try_fold_terminating_tails(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  label_used : @bitset.BitSet,
) -> Bool {
  let tails : Array[CodeFoldingTerminatingTail] = []
  if !code_folding_collect_terminating_tails(
      func,
      @ir.HotRegionRef::root(),
      tails,
    ) {
    return false
  }
  let unreachable_group = code_folding_pick_terminating_tail_group(
    func,
    code_folding_terminal_tail_kind_unreachable(),
    tails,
    label_used,
  )
  if code_folding_try_rewrite_terminating_tail_group(
      ctx, func, unreachable_group,
    ) {
    return true
  }
  let return_group = code_folding_pick_terminating_tail_group(
    func,
    code_folding_terminal_tail_kind_return(),
    tails,
    label_used,
  )
  code_folding_try_rewrite_terminating_tail_group(ctx, func, return_group)
}

///|
fn code_folding_terminal_suffix_matches_following(
  func : @ir.HotFunc,
  if_id : Int,
  then_ref : @ir.HotRegionRef,
  then_start : Int,
  region_ref : @ir.HotRegionRef,
  following_start : Int,
  suffix_len : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if suffix_len <= 0 ||
    then_start < 0 ||
    code_folding_region_prefix_has_exit(func, then_ref, then_start) ||
    !code_folding_suffix_has_if_terminal(func, then_ref, then_start, suffix_len) ||
    !code_folding_suffix_has_if_terminal(
      func, region_ref, following_start, suffix_len,
    ) {
    return false
  }
  for offset = 0; offset < suffix_len; offset = offset + 1 {
    let then_root = @ir.hot_region_get(func, then_ref, then_start + offset)
    let following_root = @ir.hot_region_get(
      func,
      region_ref,
      following_start + offset,
    )
    if offset + 1 < suffix_len &&
      (
        code_folding_node_prevents_fallthrough(func, then_root) ||
        code_folding_node_prevents_fallthrough(func, following_root)
      ) {
      return false
    }
    if @ir.hot_node_result_arity(func, then_root) != 0 ||
      @ir.hot_node_result_arity(func, following_root) != 0 ||
      !code_folding_node_is_if_hoistable_suffix(
        func, then_root, if_id, label_used,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, following_root, if_id, label_used,
      ) ||
      !code_folding_nodes_equal(func, then_root, following_root, label_used) {
      return false
    }
  }
  true
}

///|
fn code_folding_try_fold_if_then_fallthrough_terminal_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  if_id : Int,
  then_ref : @ir.HotRegionRef,
  result_arity : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if result_arity != 0 {
    return false
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let following_start = idx + 1
  let region_count = @ir.hot_region_root_count(func, region_ref)
  let suffix_len = region_count - following_start
  if then_count == 0 || suffix_len <= 0 || then_count < suffix_len {
    return false
  }
  let then_start = then_count - suffix_len
  if !code_folding_terminal_suffix_matches_following(
      func, if_id, then_ref, then_start, region_ref, following_start, suffix_len,
      label_used,
    ) {
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
  let wrapper = @ir.hot_build_block(func, @lib.BlockType::void_(), [if_id])
  let wrapper_label = @ir.hot_control_node_label(func, wrapper)
  let branch = @ir.hot_build_br(func, wrapper_label)
  ignore(pass_splice_region(ctx, func, then_ref, then_start, 0, [branch]))
  let replacement = [wrapper]
  for node_id in hoisted {
    replacement.push(node_id)
  }
  ignore(
    pass_splice_region(ctx, func, region_ref, idx, suffix_len + 1, replacement),
  )
  pipeline_trace_hook(
    ctx.trace,
    ctx.descriptor.name,
    "mutated",
    payload="if-then-fallthrough-terminal-suffix",
  )
  true
}

///|
fn code_folding_try_fold_if_at_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
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
  let condition = @ir.hot_child_get(func, if_id, 0)
  if code_folding_node_always_exits(func, condition) {
    return false
  }
  let result_arity = @ir.hot_type_result_arity(func, if_node.ty)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(ref_) => ref_
    None =>
      return code_folding_try_fold_if_then_fallthrough_terminal_at_region(
        ctx, func, region_ref, idx, if_id, then_ref, result_arity, label_used,
      )
  }
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, then_ref, else_ref, label_used,
  )
  if suffix_len == 0 {
    return code_folding_try_fold_two_block_if_at_region(
        ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
      ) ||
      code_folding_try_fold_one_block_if_at_region(
        ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
      )
  }
  let then_count = @ir.hot_region_root_count(func, then_ref)
  let else_count = @ir.hot_region_root_count(func, else_ref)
  let then_start = then_count - suffix_len
  let else_start = else_count - suffix_len
  let suffix_has_terminal = code_folding_suffix_has_if_terminal(
    func, then_ref, then_start, suffix_len,
  )
  if code_folding_region_prefix_has_exit(func, then_ref, then_start) ||
    code_folding_region_prefix_has_exit(func, else_ref, else_start) ||
    !code_folding_suffix_matches_result_arity(
      func, then_ref, then_start, suffix_len, result_arity,
    ) ||
    !code_folding_suffix_matches_result_arity(
      func, else_ref, else_start, suffix_len, result_arity,
    ) ||
    (suffix_has_terminal && (then_start != 0 || else_start != 0)) ||
    !code_folding_full_value_if_common_suffix_allowed(
      func, then_ref, else_ref, then_start, else_start, suffix_len, result_arity,
    ) {
    return false
  }
  if result_arity == 0 &&
    then_start == 0 &&
    else_start == 0 &&
    code_folding_suffix_measure(func, then_ref, then_start, suffix_len) < 3 {
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
    if result_arity != 0 {
      @ir.hot_control_result_type_set(func, if_id, @ir.hot_type_void(func))
      pass_mark_mutated(ctx, func)
    }
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
fn code_folding_try_fold_if_at_eh_body_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
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
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(ref_) => ref_
    None => return false
  }
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, then_ref, else_ref, label_used,
  )
  if suffix_len > 0 {
    let then_count = @ir.hot_region_root_count(func, then_ref)
    let then_start = then_count - suffix_len
    if code_folding_suffix_has_if_terminal(
        func, then_ref, then_start, suffix_len,
      ) {
      return false
    }
  }
  code_folding_try_fold_if_at_region(ctx, func, region_ref, idx, label_used)
}

///|
fn code_folding_visit_eh_body_if_suffixes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Block | @ir.HotOp::Loop =>
          if code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_body_ref(func, node_id),
              label_used,
            ) {
            changed = true
          }
        @ir.HotOp::If => {
          if code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_then_ref(func, node_id),
              label_used,
            ) {
            changed = true
          }
          match @ir.hot_region_else_ref(func, node_id) {
            Some(else_ref) =>
              if code_folding_visit_eh_body_if_suffixes(
                  ctx, func, else_ref, label_used,
                ) {
                changed = true
              }
            None => ()
          }
          if code_folding_try_fold_if_at_eh_body_region(
              ctx, func, region_ref, idx, label_used,
            ) {
            changed = true
          }
        }
        @ir.HotOp::Try | @ir.HotOp::TryTable =>
          if code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_body_ref(func, node_id),
              label_used,
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
fn code_folding_visit_embedded_eh_body_if_suffixes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Try | @ir.HotOp::TryTable =>
      if code_folding_visit_eh_body_if_suffixes(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
        ) {
        changed = true
      }
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        if code_folding_visit_embedded_eh_body_if_suffixes(
            ctx,
            func,
            @ir.hot_region_get(func, body_ref, idx),
            label_used,
          ) {
          changed = true
        }
      }
    }
    @ir.HotOp::If => {
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if code_folding_visit_embedded_eh_body_if_suffixes(
            ctx,
            func,
            @ir.hot_region_get(func, then_ref, idx),
            label_used,
          ) {
          changed = true
        }
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            if code_folding_visit_embedded_eh_body_if_suffixes(
                ctx,
                func,
                @ir.hot_region_get(func, else_ref, idx),
                label_used,
              ) {
              changed = true
            }
          }
        None => ()
      }
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if code_folding_visit_embedded_eh_body_if_suffixes(
            ctx, func, child_id, label_used,
          ) {
          changed = true
        }
      }
  }
  changed
}

///|
fn code_folding_visit_embedded_controls(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let control_preserve_bottom_tail = @ir.hot_node_result_arity(func, node_id) >
    0
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block =>
      if code_folding_visit_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          false,
        ) {
        changed = true
      }
    @ir.HotOp::Loop =>
      if code_folding_visit_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          control_preserve_bottom_tail,
        ) {
        changed = true
      }
    @ir.HotOp::If => {
      if code_folding_visit_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          label_used,
          control_preserve_bottom_tail,
        ) {
        changed = true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if code_folding_visit_region(
              ctx, func, else_ref, label_used, control_preserve_bottom_tail,
            ) {
            changed = true
          }
        None => ()
      }
    }
    @ir.HotOp::Try | @ir.HotOp::TryTable =>
      if code_folding_visit_eh_body_if_suffixes(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
        ) {
        changed = true
      }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::Block
            | @ir.HotOp::Loop
            | @ir.HotOp::If
            | @ir.HotOp::Try
            | @ir.HotOp::TryTable => {
              if code_folding_visit_embedded_controls(
                  ctx, func, child_id, label_used,
                ) {
                changed = true
              }
              let next_child_id = @ir.hot_child_get(func, node_id, slot)
              if code_folding_try_fold_embedded_value_if_child(
                  ctx, func, node_id, slot, next_child_id, label_used,
                ) {
                changed = true
              }
            }
            _ => ()
          }
        }
      }
  }
  changed
}

///|
fn code_folding_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
  preserve_bottom_tail : Bool,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      if code_folding_try_remove_drop_unreachable_at_region(
          ctx, func, region_ref, idx,
        ) ||
        code_folding_try_remove_dead_block_before_unreachable_at_region(
          ctx, func, region_ref, idx, label_used,
        ) ||
        code_folding_try_flatten_exiting_block_at_region(
          ctx, func, region_ref, idx, label_used,
        ) ||
        code_folding_try_remove_unreachable_after_exit_at_region(
          ctx, func, region_ref, idx, preserve_bottom_tail,
        ) {
        changed = true
        if idx >= @ir.hot_region_root_count(func, region_ref) {
          continue
        }
        let next_node_id = @ir.hot_region_get(func, region_ref, idx)
        if next_node_id < 0 || !@ir.hot_node_is_live(func, next_node_id) {
          idx += 1
          continue
        }
      }
      let current_id = @ir.hot_region_get(func, region_ref, idx)
      match @ir.hot_node_get(func, current_id).op {
        @ir.HotOp::Block => {
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
              false,
            ) {
            changed = true
          }
          if code_folding_try_fold_value_block_exit_at_region(
              ctx, func, region_ref, idx, label_used,
            ) ||
            code_folding_try_fold_block_exit_at_region(
              ctx, func, region_ref, idx, label_used,
            ) {
            changed = true
          }
        }
        @ir.HotOp::Loop => {
          let control_preserve_bottom_tail = @ir.hot_node_result_arity(
              func, current_id,
            ) >
            0
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
              control_preserve_bottom_tail,
            ) {
            changed = true
          }
        }
        @ir.HotOp::If => {
          let control_preserve_bottom_tail = @ir.hot_node_result_arity(
              func, current_id,
            ) >
            0
          if code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_then_ref(func, current_id),
              label_used,
              control_preserve_bottom_tail,
            ) {
            changed = true
          }
          match @ir.hot_region_else_ref(func, current_id) {
            Some(else_ref) =>
              if code_folding_visit_region(
                  ctx, func, else_ref, label_used, control_preserve_bottom_tail,
                ) {
                changed = true
              }
            None => ()
          }
          if code_folding_try_fold_if_at_region(
              ctx, func, region_ref, idx, label_used,
            ) {
            changed = true
          }
        }
        @ir.HotOp::Try | @ir.HotOp::TryTable =>
          if code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
            ) {
            changed = true
          }
        @ir.HotOp::Select
        | @ir.HotOp::Call
        | @ir.HotOp::CallIndirect
        | @ir.HotOp::CallRef
        | @ir.HotOp::RefIsNull
        | @ir.HotOp::RefTest
        | @ir.HotOp::RefCast
        | @ir.HotOp::TableGet
        | @ir.HotOp::TableSet
        | @ir.HotOp::TableGrow
        | @ir.HotOp::TableFill
        | @ir.HotOp::TableCopy
        | @ir.HotOp::TableInit
        | @ir.HotOp::MemoryGrow
        | @ir.HotOp::MemoryCopy
        | @ir.HotOp::MemoryFill
        | @ir.HotOp::MemoryInit
        | @ir.HotOp::Heap
        | @ir.HotOp::Unary
        | @ir.HotOp::Binary
        | @ir.HotOp::Compare
        | @ir.HotOp::Convert
        | @ir.HotOp::Load
        | @ir.HotOp::LocalSet
        | @ir.HotOp::LocalTee
        | @ir.HotOp::GlobalSet
        | @ir.HotOp::Store
        | @ir.HotOp::Return
        | @ir.HotOp::ReturnCallRef =>
          if code_folding_node_has_direct_control_child(func, current_id) &&
            code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used,
            ) {
            changed = true
          }
        @ir.HotOp::Br => {
          let seen = [0]
          if code_folding_node_has_direct_control_child(func, current_id) &&
            code_folding_node_embedded_size_within_budget(
              func,
              current_id,
              seen,
              code_folding_embedded_control_visit_budget(),
            ) &&
            code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used,
            ) {
            changed = true
          }
        }
        @ir.HotOp::Drop =>
          if code_folding_should_visit_drop_embedded_controls(func, current_id) &&
            code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used,
            ) {
            changed = true
          } else if code_folding_should_visit_drop_embedded_eh_body_if_suffixes(
              func, current_id,
            ) &&
            code_folding_visit_embedded_eh_body_if_suffixes(
              ctx, func, current_id, label_used,
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
  let mut changed = false
  let mut again = true
  while again {
    let label_used = pass_compute_label_used(func)
    let root_ref = @ir.HotRegionRef::root()
    let mut iteration_changed = code_folding_visit_region(
      ctx,
      func,
      root_ref,
      label_used,
      @ir.hot_region_result_arity(func, root_ref) > 0,
    )
    if code_folding_try_fold_terminating_tails(ctx, func, label_used) {
      iteration_changed = true
    }
    if iteration_changed {
      changed = true
    } else {
      again = false
    }
  }
  if changed {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
