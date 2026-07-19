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
priv struct CodeFoldingExitIndex {
  tails : @hashmap.HashMap[Int, Array[CodeFoldingExitTail]]?
  embedded_visited : Array[Bool]
  structured_visited : Array[Bool]
  visited_control_bodies : Array[Bool]
  fallthrough_epochs : Array[Int]
  fallthrough_values : Array[Bool]
  mut movement_suffix_marks : Array[Int]
  mut movement_out_of_marks : Array[Int]
  mut movement_visited_marks : Array[Int]
  mut movement_epoch : Int
  mut facts_epoch : Int
  mut invalidated : Bool
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
priv struct CodeFoldingTerminatingFacts {
  fallthrough_state : Array[Int]
  measure_values : Array[Int]
  may_throw_state : Array[Int]
  has_eh_state : Array[Int]
  external_break_state : Array[Int]
  mut shallow_hash_ready : Array[Bool]
  mut shallow_hash_values : Array[Int]
  has_any_branch_target : Bool
  suffix_marks : Array[Int]
  visited_marks : Array[Int]
  mut mark_epoch : Int
  mut root_has_eh_ready : Bool
  mut root_has_eh_value : Bool
}

///|
fn CodeFoldingTerminatingFacts::new(
  func : @ir.HotFunc,
  label_used : @bitset.BitSet,
) -> CodeFoldingTerminatingFacts {
  let node_count = @ir.hot_node_count(func)
  let mut has_any_branch_target = false
  for label_id = 0; label_id < label_used.length(); label_id = label_id + 1 {
    if pass_label_is_used(label_id, label_used) {
      has_any_branch_target = true
      break
    }
  }
  let branch_fact_count = if has_any_branch_target { node_count } else { 0 }
  {
    fallthrough_state: Array::make(node_count, 0),
    measure_values: Array::make(node_count, 0),
    may_throw_state: Array::make(node_count, 0),
    has_eh_state: Array::make(node_count, 0),
    external_break_state: Array::make(branch_fact_count, 0),
    shallow_hash_ready: [],
    shallow_hash_values: [],
    has_any_branch_target,
    suffix_marks: Array::make(branch_fact_count, 0),
    visited_marks: Array::make(branch_fact_count, 0),
    mark_epoch: 0,
    root_has_eh_ready: false,
    root_has_eh_value: false,
  }
}

///|
fn CodeFoldingTerminatingFacts::next_mark_epoch(
  self : CodeFoldingTerminatingFacts,
) -> Int {
  self.mark_epoch += 1
  self.mark_epoch
}

///|
fn code_folding_label_map_new() -> CodeFoldingLabelMap {
  { left_labels: [], right_labels: [] }
}

///|
fn code_folding_worth_adding_block_threshold() -> Int {
  3
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
fn CodeFoldingExitIndex::begin_movement_query(
  self : CodeFoldingExitIndex,
  node_count : Int,
) -> Int {
  if self.movement_suffix_marks.length() != node_count {
    self.movement_suffix_marks = Array::make(node_count, 0)
    self.movement_out_of_marks = Array::make(node_count, 0)
    self.movement_visited_marks = Array::make(node_count, 0)
  }
  self.movement_epoch += 1
  self.movement_epoch
}

///|
fn code_folding_mark_contained_nodes(
  func : @ir.HotFunc,
  node_id : Int,
  marks : Array[Int],
  epoch : Int,
) -> Unit {
  if node_id < 0 ||
    node_id >= marks.length() ||
    marks[node_id] == epoch ||
    !@ir.hot_node_is_live(func, node_id) {
    return
  }
  marks[node_id] = epoch
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    code_folding_mark_contained_nodes(
      func,
      @ir.hot_child_get(func, node_id, slot),
      marks,
      epoch,
    )
  }
}

///|
fn code_folding_branch_target_survives_hoist_in_marks(
  func : @ir.HotFunc,
  index : CodeFoldingExitIndex,
  epoch : Int,
  label_id : Int,
) -> Bool {
  if label_id < 0 || label_id >= func.labels.length() {
    return false
  }
  let owner = @ir.hot_label_owner(func, label_id)
  owner >= 0 &&
  owner < index.movement_out_of_marks.length() &&
  (
    index.movement_out_of_marks[owner] != epoch ||
    index.movement_suffix_marks[owner] == epoch
  )
}

///|
fn code_folding_branch_targets_survive_hoist_in_marks(
  func : @ir.HotFunc,
  index : CodeFoldingExitIndex,
  epoch : Int,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    node_id >= index.movement_visited_marks.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if index.movement_visited_marks[node_id] == epoch {
    return true
  }
  index.movement_visited_marks[node_id] = epoch
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::Delegate =>
      if !code_folding_branch_target_survives_hoist_in_marks(
          func,
          index,
          epoch,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::BrTable => {
      if !code_folding_branch_target_survives_hoist_in_marks(
          func,
          index,
          epoch,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return false
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !code_folding_branch_target_survives_hoist_in_marks(
            func, index, epoch, label_id,
          ) {
          return false
        }
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if !code_folding_branch_target_survives_hoist_in_marks(
          func,
          index,
          epoch,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::TryTable => return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if !code_folding_branch_targets_survive_hoist_in_marks(
        func,
        index,
        epoch,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_branch_targets_survive_hoist(
  func : @ir.HotFunc,
  suffix_root_id : Int,
  out_of_id : Int,
  node_id : Int,
  index : CodeFoldingExitIndex,
) -> Bool {
  let epoch = index.begin_movement_query(@ir.hot_node_count(func))
  code_folding_mark_contained_nodes(
    func,
    suffix_root_id,
    index.movement_suffix_marks,
    epoch,
  )
  code_folding_mark_contained_nodes(
    func,
    out_of_id,
    index.movement_out_of_marks,
    epoch,
  )
  code_folding_branch_targets_survive_hoist_in_marks(
    func, index, epoch, node_id,
  )
}

///|
fn code_folding_node_is_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
  label_used : @bitset.BitSet,
  exit_index : CodeFoldingExitIndex,
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
  code_folding_can_move_eh_effects(func, node_id, out_of_id) &&
  code_folding_branch_targets_survive_hoist(
    func, node_id, out_of_id, node_id, exit_index,
  )
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
    | @ir.HotOp::Unreachable
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => true
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
    @ir.HotOp::BrTable => {
      if last.child_count != 1 ||
        @ir.hot_branch_table_default_target(func, last.imm0) != label_id {
        return false
      }
      for target_id in @ir.hot_branch_table_targets(func, last.imm0) {
        if target_id != label_id {
          return false
        }
      }
      true
    }
    _ => false
  }
}

///|
fn code_folding_terminating_node_prevents_fallthrough(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if node_id < 0 ||
    node_id >= facts.fallthrough_state.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match facts.fallthrough_state[node_id] {
    3 => return true
    2 | 1 => return false
    _ => ()
  }
  facts.fallthrough_state[node_id] = 1
  let mut result = false
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
    | @ir.HotOp::Delegate => result = true
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) == 1 {
        result = code_folding_terminating_node_prevents_fallthrough(
          func,
          @ir.hot_child_get(func, node_id, 0),
          facts,
        )
      }
    @ir.HotOp::Try | @ir.HotOp::TryTable => ()
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let count = @ir.hot_region_root_count(func, body_ref)
      if count > 0 {
        result = code_folding_terminating_node_prevents_fallthrough(
          func,
          @ir.hot_region_get(func, body_ref, count - 1),
          facts,
        )
      }
    }
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let then_ref = @ir.hot_region_then_ref(func, node_id)
          let then_count = @ir.hot_region_root_count(func, then_ref)
          let else_count = @ir.hot_region_root_count(func, else_ref)
          if then_count > 0 && else_count > 0 {
            result = code_folding_terminating_node_prevents_fallthrough(
                func,
                @ir.hot_region_get(func, then_ref, then_count - 1),
                facts,
              ) &&
              code_folding_terminating_node_prevents_fallthrough(
                func,
                @ir.hot_region_get(func, else_ref, else_count - 1),
                facts,
              )
          }
        }
        None => ()
      }
    _ => ()
  }
  facts.fallthrough_state[node_id] = if result { 3 } else { 2 }
  result
}

///|
fn code_folding_terminating_collect_child_nodes(
  func : @ir.HotFunc,
  node_id : Int,
  marks : Array[Int],
  epoch : Int,
) -> Unit {
  if node_id < 0 ||
    node_id >= marks.length() ||
    marks[node_id] == epoch ||
    !@ir.hot_node_is_live(func, node_id) {
    return
  }
  marks[node_id] = epoch
  let node = @ir.hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    code_folding_terminating_collect_child_nodes(
      func,
      @ir.hot_child_get(func, node_id, slot),
      marks,
      epoch,
    )
  }
}

///|
fn code_folding_terminating_node_may_throw(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if node_id < 0 ||
    node_id >= facts.may_throw_state.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match facts.may_throw_state[node_id] {
    3 => return true
    2 | 1 => return false
    _ => ()
  }
  facts.may_throw_state[node_id] = 1
  let node = @ir.hot_node_get(func, node_id)
  let mut result = match node.op {
    @ir.HotOp::Call
    | @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => true
    _ => false
  }
  if !result {
    for slot = 0; slot < node.child_count; slot = slot + 1 {
      if code_folding_terminating_node_may_throw(
          func,
          @ir.hot_child_get(func, node_id, slot),
          facts,
        ) {
        result = true
        break
      }
    }
  }
  facts.may_throw_state[node_id] = if result { 3 } else { 2 }
  result
}

///|
fn code_folding_terminating_node_has_eh_control(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if node_id < 0 ||
    node_id >= facts.has_eh_state.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match facts.has_eh_state[node_id] {
    3 => return true
    2 | 1 => return false
    _ => ()
  }
  facts.has_eh_state[node_id] = 1
  let node = @ir.hot_node_get(func, node_id)
  let mut result = match node.op {
    @ir.HotOp::Try | @ir.HotOp::TryTable => true
    _ => false
  }
  if !result {
    match node.op {
      @ir.HotOp::Block | @ir.HotOp::Loop => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        for idx = 0
            idx < @ir.hot_region_root_count(func, body_ref)
            idx = idx + 1 {
          if code_folding_terminating_node_has_eh_control(
              func,
              @ir.hot_region_get(func, body_ref, idx),
              facts,
            ) {
            result = true
            break
          }
        }
      }
      @ir.HotOp::If => {
        let then_ref = @ir.hot_region_then_ref(func, node_id)
        for idx = 0
            idx < @ir.hot_region_root_count(func, then_ref)
            idx = idx + 1 {
          if code_folding_terminating_node_has_eh_control(
              func,
              @ir.hot_region_get(func, then_ref, idx),
              facts,
            ) {
            result = true
            break
          }
        }
        if !result {
          match @ir.hot_region_else_ref(func, node_id) {
            Some(else_ref) =>
              for idx = 0
                  idx < @ir.hot_region_root_count(func, else_ref)
                  idx = idx + 1 {
                if code_folding_terminating_node_has_eh_control(
                    func,
                    @ir.hot_region_get(func, else_ref, idx),
                    facts,
                  ) {
                  result = true
                  break
                }
              }
            None => ()
          }
        }
      }
      _ =>
        for slot = 0; slot < node.child_count; slot = slot + 1 {
          if code_folding_terminating_node_has_eh_control(
              func,
              @ir.hot_child_get(func, node_id, slot),
              facts,
            ) {
            result = true
            break
          }
        }
    }
  }
  facts.has_eh_state[node_id] = if result { 3 } else { 2 }
  result
}

///|
fn code_folding_terminating_out_of_has_eh_control(
  func : @ir.HotFunc,
  out_of_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if out_of_id >= 0 {
    return code_folding_terminating_node_has_eh_control(func, out_of_id, facts)
  }
  if facts.root_has_eh_ready {
    return facts.root_has_eh_value
  }
  let root_ref = @ir.HotRegionRef::root()
  let mut result = false
  for idx = 0; idx < @ir.hot_region_root_count(func, root_ref); idx = idx + 1 {
    if code_folding_terminating_node_has_eh_control(
        func,
        @ir.hot_region_get(func, root_ref, idx),
        facts,
      ) {
      result = true
      break
    }
  }
  facts.root_has_eh_value = result
  facts.root_has_eh_ready = true
  result
}

///|
fn code_folding_terminating_can_move_eh_effects(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  !code_folding_terminating_node_may_throw(func, node_id, facts) ||
  !code_folding_terminating_out_of_has_eh_control(func, out_of_id, facts)
}

///|
fn code_folding_terminal_tail_item_allows_following(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  !code_folding_terminating_node_prevents_fallthrough(func, node_id, facts) ||
  code_folding_node_exits_to_own_block_label(func, node_id)
}

///|
fn code_folding_terminal_tail_item_is_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
  label_used : @bitset.BitSet,
  facts : CodeFoldingTerminatingFacts,
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
  // Group selection has already rejected every item with a branch target
  // outside this suffix. An internal target necessarily survives the hoist,
  // so repeating the descendant-set proof here would only rescan the item.
  code_folding_terminating_can_move_eh_effects(func, node_id, out_of_id, facts)
}

///|
fn code_folding_terminal_tail_item_is_movable(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  node_id : Int,
  depth : Int,
  label_used : @bitset.BitSet,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if depth == 0 {
    return code_folding_terminal_tail_kind_of_node(func, node_id) != 0 &&
      code_folding_terminating_can_move_eh_effects(func, node_id, -1, facts)
  }
  @ir.hot_node_result_arity(func, node_id) == 0 &&
  code_folding_terminal_tail_item_allows_following(func, node_id, facts) &&
  code_folding_terminal_tail_item_is_hoistable_suffix(
    func,
    node_id,
    tail.region_ref.holder,
    label_used,
    facts,
  )
}

///|
fn code_folding_terminating_branch_target_is_internal(
  func : @ir.HotFunc,
  facts : CodeFoldingTerminatingFacts,
  epoch : Int,
  label_id : Int,
) -> Bool {
  if label_id < 0 || label_id >= func.labels.length() {
    return false
  }
  let owner = @ir.hot_label_owner(func, label_id)
  owner >= 0 &&
  owner < facts.suffix_marks.length() &&
  facts.suffix_marks[owner] == epoch
}

///|
fn code_folding_terminating_branch_targets_are_internal(
  func : @ir.HotFunc,
  facts : CodeFoldingTerminatingFacts,
  epoch : Int,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    node_id >= facts.visited_marks.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if facts.visited_marks[node_id] == epoch {
    return true
  }
  facts.visited_marks[node_id] = epoch
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::Delegate =>
      if !code_folding_terminating_branch_target_is_internal(
          func,
          facts,
          epoch,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::BrTable => {
      if !code_folding_terminating_branch_target_is_internal(
          func,
          facts,
          epoch,
          @ir.hot_branch_table_default_target(func, node.imm0),
        ) {
        return false
      }
      for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
        if !code_folding_terminating_branch_target_is_internal(
            func, facts, epoch, label_id,
          ) {
          return false
        }
      }
    }
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if !code_folding_terminating_branch_target_is_internal(
          func,
          facts,
          epoch,
          node.imm0,
        ) {
        return false
      }
    @ir.HotOp::TryTable => return false
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if !code_folding_terminating_branch_targets_are_internal(
        func,
        facts,
        epoch,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn code_folding_terminal_tail_item_has_external_break_target(
  func : @ir.HotFunc,
  _tail : CodeFoldingTerminatingTail,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Bool {
  if !facts.has_any_branch_target {
    return false
  }
  if node_id < 0 ||
    node_id >= facts.external_break_state.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match facts.external_break_state[node_id] {
    3 => return true
    2 | 1 => return false
    _ => ()
  }
  facts.external_break_state[node_id] = 1
  let epoch = facts.next_mark_epoch()
  code_folding_terminating_collect_child_nodes(
    func,
    node_id,
    facts.suffix_marks,
    epoch,
  )
  let result = !code_folding_terminating_branch_targets_are_internal(
    func, facts, epoch, node_id,
  )
  facts.external_break_state[node_id] = if result { 3 } else { 2 }
  result
}

///|
fn code_folding_node_is_if_hoistable_suffix(
  func : @ir.HotFunc,
  node_id : Int,
  if_id : Int,
  label_used : @bitset.BitSet,
  exit_index : CodeFoldingExitIndex,
) -> Bool {
  (
    code_folding_node_is_hoistable_suffix(
      func, node_id, if_id, label_used, exit_index,
    ) ||
    code_folding_node_is_if_terminal_suffix(func, node_id)
  ) &&
  code_folding_can_move_eh_effects(func, node_id, if_id)
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
    @ir.HotOp::BrTable => {
      if !code_folding_labels_equal_with_map(
          @ir.hot_branch_table_default_target(func, left.imm0),
          @ir.hot_branch_table_default_target(func, right.imm0),
          label_map,
        ) {
        return false
      }
      let left_targets = @ir.hot_branch_table_targets(func, left.imm0)
      let right_targets = @ir.hot_branch_table_targets(func, right.imm0)
      if left_targets.length() != right_targets.length() {
        return false
      }
      for idx = 0; idx < left_targets.length(); idx = idx + 1 {
        if !code_folding_labels_equal_with_map(
            left_targets[idx],
            right_targets[idx],
            label_map,
          ) {
          return false
        }
      }
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
fn code_folding_nodes_equal_exact_labels(
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
    @ir.HotOp::BrTable => {
      if @ir.hot_branch_table_default_target(func, left.imm0) !=
        @ir.hot_branch_table_default_target(func, right.imm0) {
        return false
      }
      let left_targets = @ir.hot_branch_table_targets(func, left.imm0)
      let right_targets = @ir.hot_branch_table_targets(func, right.imm0)
      if left_targets.length() != right_targets.length() {
        return false
      }
      for idx = 0; idx < left_targets.length(); idx = idx + 1 {
        if left_targets[idx] != right_targets[idx] {
          return false
        }
      }
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
    if !code_folding_nodes_equal_exact_labels(
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
fn code_folding_nodes_equal(
  func : @ir.HotFunc,
  left_id : Int,
  right_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  code_folding_nodes_equal_exact_labels(func, left_id, right_id) ||
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
  exit_index : CodeFoldingExitIndex,
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
      !code_folding_nodes_equal(func, then_id, else_id, label_used) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, then_id, if_id, label_used, exit_index,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, else_id, if_id, label_used, exit_index,
      ) {
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
    | Some(@lib.Instruction::StructGet(_, _))
    | Some(@lib.Instruction::StructGetS(_, _))
    | Some(@lib.Instruction::StructGetU(_, _))
    | Some(@lib.Instruction::ArrayNew(_))
    | Some(@lib.Instruction::ArrayNewDefault(_))
    | Some(@lib.Instruction::ArrayNewFixed(_, _))
    | Some(@lib.Instruction::ArrayNewData(_, _))
    | Some(@lib.Instruction::ArrayNewElem(_, _))
    | Some(@lib.Instruction::StructSet(_, _))
    | Some(@lib.Instruction::ArrayGet(_))
    | Some(@lib.Instruction::ArrayGetS(_))
    | Some(@lib.Instruction::ArrayGetU(_))
    | Some(@lib.Instruction::ArrayLen)
    | Some(@lib.Instruction::ArraySet(_))
    | Some(@lib.Instruction::ArrayFill(_))
    | Some(@lib.Instruction::ArrayCopy(_, _))
    | Some(@lib.Instruction::ArrayInitData(_, _))
    | Some(@lib.Instruction::ArrayInitElem(_, _))
    | Some(@lib.Instruction::RefEq)
    | Some(@lib.Instruction::RefAsNonNull)
    | Some(@lib.Instruction::AnyConvertExtern)
    | Some(@lib.Instruction::ExternConvertAny)
    | Some(@lib.Instruction::RefI31) => true
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
    | @ir.HotOp::BrIf
    | @ir.HotOp::Return
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
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
  exit_index : CodeFoldingExitIndex,
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
    func, if_id, then_ref, else_ref, label_used, exit_index,
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
fn CodeFoldingExitIndex::invalidate_facts(self : CodeFoldingExitIndex) -> Unit {
  self.facts_epoch += 1
}

///|
fn code_folding_node_prevents_fallthrough_with_index(
  func : @ir.HotFunc,
  node_id : Int,
  index : CodeFoldingExitIndex,
) -> Bool {
  if node_id < 0 ||
    node_id >= index.fallthrough_epochs.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if index.fallthrough_epochs[node_id] == index.facts_epoch {
    return index.fallthrough_values[node_id]
  }
  index.fallthrough_epochs[node_id] = index.facts_epoch
  index.fallthrough_values[node_id] = false
  let mut result = false
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
    | @ir.HotOp::Delegate => result = true
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) == 1 {
        result = code_folding_node_prevents_fallthrough_with_index(
          func,
          @ir.hot_child_get(func, node_id, 0),
          index,
        )
      }
    @ir.HotOp::Try | @ir.HotOp::TryTable => ()
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      let count = @ir.hot_region_root_count(func, body_ref)
      if count > 0 {
        result = code_folding_node_prevents_fallthrough_with_index(
          func,
          @ir.hot_region_get(func, body_ref, count - 1),
          index,
        )
      }
    }
    @ir.HotOp::If =>
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => {
          let then_ref = @ir.hot_region_then_ref(func, node_id)
          let then_count = @ir.hot_region_root_count(func, then_ref)
          let else_count = @ir.hot_region_root_count(func, else_ref)
          if then_count > 0 && else_count > 0 {
            result = code_folding_node_prevents_fallthrough_with_index(
                func,
                @ir.hot_region_get(func, then_ref, then_count - 1),
                index,
              ) &&
              code_folding_node_prevents_fallthrough_with_index(
                func,
                @ir.hot_region_get(func, else_ref, else_count - 1),
                index,
              )
          }
        }
        None => ()
      }
    _ => ()
  }
  index.fallthrough_values[node_id] = result
  result
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
fn code_folding_region_has_embedded_eh_control(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if code_folding_node_has_embedded_eh_control(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return true
    }
  }
  false
}

///|
fn code_folding_out_of_has_eh_control(
  func : @ir.HotFunc,
  out_of_id : Int,
) -> Bool {
  if out_of_id < 0 {
    code_folding_region_has_embedded_eh_control(func, @ir.HotRegionRef::root())
  } else {
    code_folding_node_has_embedded_eh_control(func, out_of_id)
  }
}

///|
fn code_folding_node_may_throw_for_eh_move(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Call
    | @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::ReturnCall
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef
    | @ir.HotOp::Throw
    | @ir.HotOp::Rethrow
    | @ir.HotOp::ThrowRef => return true
    _ => ()
  }
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if code_folding_node_may_throw_for_eh_move(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn code_folding_can_move_eh_effects(
  func : @ir.HotFunc,
  node_id : Int,
  out_of_id : Int,
) -> Bool {
  !code_folding_node_may_throw_for_eh_move(func, node_id) ||
  !code_folding_out_of_has_eh_control(func, out_of_id)
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
  exit_index : CodeFoldingExitIndex,
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
        code_folding_node_prevents_fallthrough_with_index(
          func, first, exit_index,
        )
      ) ||
      !code_folding_node_is_hoistable_suffix(
        func, first, block_id, label_used, exit_index,
      ) {
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
          code_folding_node_prevents_fallthrough_with_index(
            func, other, exit_index,
          )
        ) ||
        !code_folding_node_is_hoistable_suffix(
          func, other, block_id, label_used, exit_index,
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
  exit_index : CodeFoldingExitIndex,
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
  if !code_folding_node_prevents_fallthrough_with_index(
      func, last_root, exit_index,
    ) {
    tails.push(
      code_folding_value_exit_tail_fallthrough(
        body_ref, body_count, target_label, last_root, result_arity,
      ),
    )
  }
  let suffix_len = code_folding_common_value_block_exit_suffix_len(
    func, block_id, target_label, result_arity, tails, label_used, exit_index,
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
fn CodeFoldingExitIndex::new(
  node_count : Int,
  build_block_exit_index : Bool,
  visit_control_bodies : Bool,
) -> CodeFoldingExitIndex {
  let index_node_count = if build_block_exit_index { node_count } else { 0 }
  {
    tails: if build_block_exit_index {
      Some(@hashmap.new())
    } else {
      None
    },
    embedded_visited: Array::make(index_node_count, false),
    structured_visited: Array::make(index_node_count, false),
    visited_control_bodies: Array::make(
      if visit_control_bodies {
        node_count
      } else {
        0
      },
      false,
    ),
    fallthrough_epochs: Array::make(index_node_count, 0),
    fallthrough_values: Array::make(index_node_count, false),
    movement_suffix_marks: [],
    movement_out_of_marks: [],
    movement_visited_marks: [],
    movement_epoch: 0,
    facts_epoch: 1,
    invalidated: false,
  }
}

///|
fn CodeFoldingExitIndex::mark_unoptimizable(
  self : CodeFoldingExitIndex,
  label : Int,
) -> Unit {
  if label >= 0 {
    match self.tails {
      Some(tails_by_label) => tails_by_label.set(label, [])
      None => ()
    }
  }
}

///|
fn CodeFoldingExitIndex::add_tail(
  self : CodeFoldingExitIndex,
  label : Int,
  tail : CodeFoldingExitTail,
) -> Unit {
  match self.tails {
    Some(tails_by_label) =>
      match tails_by_label.get(label) {
        Some(tails) => if tails.length() > 0 { tails.push(tail) }
        None => tails_by_label.set(label, [tail])
      }
    None => ()
  }
}

///|
fn CodeFoldingExitIndex::mark_active_unoptimizable(
  self : CodeFoldingExitIndex,
  active_block_labels : Array[Int],
) -> Unit {
  for label in active_block_labels {
    self.mark_unoptimizable(label)
  }
}

///|
fn code_folding_index_block_exit_embedded_controls(
  func : @ir.HotFunc,
  node_id : Int,
  active_block_labels : Array[Int],
  index : CodeFoldingExitIndex,
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  if node_id < index.embedded_visited.length() &&
    index.embedded_visited[node_id] {
    return
  }
  if node_id < index.embedded_visited.length() {
    index.embedded_visited[node_id] = true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable =>
      code_folding_index_block_exit_node(
        func,
        node_id,
        None,
        -1,
        false,
        active_block_labels,
        index,
      )
    _ =>
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, slot),
          active_block_labels,
          index,
        )
      }
  }
}

///|
fn code_folding_index_block_exit_node(
  func : @ir.HotFunc,
  node_id : Int,
  region_ref : @ir.HotRegionRef?,
  region_idx : Int,
  final_region_root : Bool,
  active_block_labels : Array[Int],
  index : CodeFoldingExitIndex,
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    index.mark_active_unoptimizable(active_block_labels)
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => {
      if node_id < index.structured_visited.length() &&
        index.structured_visited[node_id] {
        return
      }
      if node_id < index.structured_visited.length() {
        index.structured_visited[node_id] = true
      }
    }
    _ => ()
  }
  match node.op {
    @ir.HotOp::Br => {
      if final_region_root && node.child_count == 0 && region_idx > 0 {
        match region_ref {
          Some(ref_) =>
            index.add_tail(node.imm0, { region_ref: ref_, end_idx: region_idx })
          None => index.mark_unoptimizable(node.imm0)
        }
      } else {
        index.mark_unoptimizable(node.imm0)
      }
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, slot),
          active_block_labels,
          index,
        )
      }
    }
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate => {
      index.mark_unoptimizable(node.imm0)
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, slot),
          active_block_labels,
          index,
        )
      }
    }
    @ir.HotOp::BrTable => {
      index.mark_unoptimizable(
        @ir.hot_branch_table_default_target(func, node.imm0),
      )
      for target in @ir.hot_branch_table_targets(func, node.imm0) {
        index.mark_unoptimizable(target)
      }
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, slot),
          active_block_labels,
          index,
        )
      }
    }
    @ir.HotOp::Block => {
      let label = @ir.hot_control_node_label(func, node_id)
      active_block_labels.push(label)
      code_folding_index_block_exit_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        active_block_labels,
        index,
      )
      ignore(active_block_labels.pop())
    }
    @ir.HotOp::Loop =>
      code_folding_index_block_exit_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        active_block_labels,
        index,
      )
    @ir.HotOp::If => {
      if node.child_count > 0 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, 0),
          active_block_labels,
          index,
        )
      }
      code_folding_index_block_exit_region(
        func,
        @ir.hot_region_then_ref(func, node_id),
        active_block_labels,
        index,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          code_folding_index_block_exit_region(
            func, else_ref, active_block_labels, index,
          )
        None => ()
      }
    }
    @ir.HotOp::Try | @ir.HotOp::TryTable =>
      index.mark_active_unoptimizable(active_block_labels)
    _ =>
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        code_folding_index_block_exit_embedded_controls(
          func,
          @ir.hot_child_get(func, node_id, slot),
          active_block_labels,
          index,
        )
      }
  }
}

///|
fn code_folding_index_block_exit_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  active_block_labels : Array[Int],
  index : CodeFoldingExitIndex,
) -> Unit {
  let count = @ir.hot_region_root_count(func, region_ref)
  for idx = 0; idx < count; idx = idx + 1 {
    code_folding_index_block_exit_node(
      func,
      @ir.hot_region_get(func, region_ref, idx),
      Some(region_ref),
      idx,
      idx + 1 == count,
      active_block_labels,
      index,
    )
  }
}

///|
fn code_folding_build_block_exit_index(
  func : @ir.HotFunc,
  label_used : @bitset.BitSet,
) -> CodeFoldingExitIndex {
  let node_count = @ir.hot_node_count(func)
  let mut has_used_block_label = false
  let mut has_control_body = false
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Block => {
          has_control_body = true
          if pass_label_is_used(
              @ir.hot_control_node_label(func, node_id),
              label_used,
            ) {
            has_used_block_label = true
            break
          }
        }
        @ir.HotOp::Loop
        | @ir.HotOp::If
        | @ir.HotOp::Try
        | @ir.HotOp::TryTable => has_control_body = true
        _ => ()
      }
    }
  }
  let index = CodeFoldingExitIndex::new(
    node_count, has_used_block_label, has_control_body,
  )
  if has_used_block_label {
    code_folding_index_block_exit_region(
      func,
      @ir.HotRegionRef::root(),
      [],
      index,
    )
  }
  index
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
  let seen : @hashmap.HashMap[Int, Bool] = @hashmap.new(
    capacity=tails.length() * 2 + 1,
  )
  for tail in tails {
    let holder = tail.region_ref.holder
    if seen.contains(holder) {
      return false
    }
    seen.set(holder, true)
  }
  true
}

///|
fn code_folding_common_block_exit_suffix_len(
  func : @ir.HotFunc,
  block_id : Int,
  tails : Array[CodeFoldingExitTail],
  label_used : @bitset.BitSet,
  exit_index : CodeFoldingExitIndex,
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
      !code_folding_node_is_hoistable_suffix(
        func, first, block_id, label_used, exit_index,
      ) {
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
        !code_folding_nodes_equal(func, first, other, label_used) ||
        !code_folding_node_is_hoistable_suffix(
          func, other, block_id, label_used, exit_index,
        ) {
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
  exit_index : CodeFoldingExitIndex,
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
  match exit_index.tails {
    Some(tails_by_label) =>
      match tails_by_label.get(target_label) {
        Some(indexed) => {
          if indexed.length() == 0 {
            return false
          }
          for tail in indexed {
            tails.push(tail)
          }
        }
        None =>
          if !code_folding_collect_block_exit_tails(
              func, body_ref, target_label, tails,
            ) {
            return false
          }
      }
    None =>
      if !code_folding_collect_block_exit_tails(
          func, body_ref, target_label, tails,
        ) {
        return false
      }
  }
  let mut indexed_tails_valid = true
  for tail in tails {
    if tail.end_idx < 0 ||
      tail.end_idx > @ir.hot_region_root_count(func, tail.region_ref) {
      indexed_tails_valid = false
    }
  }
  if !indexed_tails_valid {
    while tails.length() > 0 {
      ignore(tails.pop())
    }
    if !code_folding_collect_block_exit_tails(
        func, body_ref, target_label, tails,
      ) {
      return false
    }
  }
  let last_root = @ir.hot_region_get(func, body_ref, body_count - 1)
  if !code_folding_node_prevents_fallthrough_with_index(
      func, last_root, exit_index,
    ) {
    tails.push({ region_ref: body_ref, end_idx: body_count })
  }
  if tails.length() < 2 || !code_folding_exit_tail_regions_are_unique(tails) {
    return false
  }
  for tail in tails {
    if @ir.hot_region_result_arity(func, tail.region_ref) > 0 {
      return false
    }
  }
  let suffix_len = code_folding_common_block_exit_suffix_len(
    func, block_id, tails, label_used, exit_index,
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
  exit_index.invalidated = true
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
  exit_index : CodeFoldingExitIndex,
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
        func, block_root, if_id, label_used, exit_index,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, other_root, if_id, label_used, exit_index,
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
  exit_index : CodeFoldingExitIndex,
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
    func, if_id, block_body_ref, other_ref, label_used, exit_index,
  )
  if suffix_len == 0 {
    return false
  }
  let block_start = block_count - suffix_len
  let other_start = other_count - suffix_len
  if !code_folding_block_suffix_matches_region(
      func, if_id, block_body_ref, block_start, other_ref, other_start, suffix_len,
      result_arity, label_used, exit_index,
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
  exit_index : CodeFoldingExitIndex,
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
    func, if_id, then_body_ref, else_body_ref, label_used, exit_index,
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
  exit_index : CodeFoldingExitIndex,
) -> Bool {
  code_folding_try_fold_one_block_if_arm(
    ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
    exit_index,
  ) ||
  code_folding_try_fold_one_block_if_arm(
    ctx, func, region_ref, idx, if_id, else_ref, then_ref, result_arity, label_used,
    exit_index,
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
      @ir.HotOp::Try => return false
      @ir.HotOp::TryTable =>
        if !code_folding_collect_terminating_tails(
            func,
            @ir.hot_region_body_ref(func, node_id),
            tails,
          ) {
          return false
        }
      _ => ()
    }
  }
  true
}

///|
fn code_folding_terminating_node_measure(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Int {
  if node_id < 0 ||
    node_id >= facts.measure_values.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let measured = facts.measure_values[node_id]
  if measured > 0 {
    return measured
  }
  if measured < 0 {
    return 0
  }
  facts.measure_values[node_id] = -1
  let node = @ir.hot_node_get(func, node_id)
  let mut total = 1
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    total += code_folding_terminating_node_measure(
      func,
      @ir.hot_child_get(func, node_id, slot),
      facts,
    )
  }
  facts.measure_values[node_id] = total
  total
}

///|
fn code_folding_terminating_suffix_measure(
  func : @ir.HotFunc,
  tail : CodeFoldingTerminatingTail,
  suffix_len : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Int {
  if suffix_len <= 0 || tail.end_idx < suffix_len {
    return 0
  }
  let mut total = 0
  let start_idx = tail.end_idx - suffix_len
  for idx = start_idx; idx < tail.end_idx; idx = idx + 1 {
    total += code_folding_terminating_node_measure(
      func,
      @ir.hot_region_get(func, tail.region_ref, idx),
      facts,
    )
  }
  total
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
fn code_folding_terminating_node_imm0_hash(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const | @ir.HotOp::RefNull =>
      @debug.to_string(@ir.hot_const_get(func, node.imm0)).hash()
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Br
    | @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Delegate => 1
    @ir.HotOp::BrTable =>
      @ir.hot_branch_table_targets(func, node.imm0).length().hash()
    @ir.HotOp::CallIndirect
    | @ir.HotOp::CallRef
    | @ir.HotOp::ReturnCallIndirect
    | @ir.HotOp::ReturnCallRef =>
      @debug.to_string(@ir.hot_call_sig_get(func, node.imm0)).hash()
    _ => node.imm0.hash()
  }
}

///|
fn code_folding_terminating_node_shallow_hash(
  func : @ir.HotFunc,
  node_id : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  if facts.shallow_hash_ready.length() == 0 {
    let node_count = @ir.hot_node_count(func)
    facts.shallow_hash_ready = Array::make(node_count, false)
    facts.shallow_hash_values = Array::make(node_count, 0)
  }
  if node_id >= facts.shallow_hash_ready.length() {
    return 0
  }
  if facts.shallow_hash_ready[node_id] {
    return facts.shallow_hash_values[node_id]
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut hash = node.op.to_string().hash()
  hash = hash * 31 + node.ty.hash()
  hash = hash * 31 + node.flags.hash()
  hash = hash * 31 + code_folding_terminating_node_imm0_hash(func, node_id)
  hash = hash * 31 + node.imm1.hash()
  hash = hash * 31 + node.child_count.hash()
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      hash *= 31
    } else {
      let child = @ir.hot_node_get(func, child_id)
      hash = hash * 31 + child.op.to_string().hash()
      hash = hash * 31 + child.ty.hash()
      hash = hash * 31 + child.flags.hash()
      hash = hash * 31 + code_folding_terminating_node_imm0_hash(func, child_id)
      hash = hash * 31 + child.imm1.hash()
      hash = hash * 31 + child.child_count.hash()
    }
  }
  facts.shallow_hash_values[node_id] = hash
  facts.shallow_hash_ready[node_id] = true
  hash
}

///|
fn code_folding_plan_terminating_tail_group(
  func : @ir.HotFunc,
  tails : Array[CodeFoldingTerminatingTail],
  suffix_len : Int,
  facts : CodeFoldingTerminatingFacts,
) -> Array[CodeFoldingTerminatingTail] {
  if suffix_len <= 0 || tails.length() < 2 {
    return []
  }
  let anchor_tail = tails[0]
  let profitability = code_folding_terminating_suffix_measure(
      func, anchor_tail, suffix_len, facts,
    ) *
    (tails.length() - 1)
  let helper_cost = tails.length() + code_folding_worth_adding_block_threshold()
  if profitability <= helper_cost ||
    code_folding_terminating_suffix_is_tail_call_operands_only(
      func, anchor_tail, suffix_len,
    ) {
    return []
  }
  let planned : Array[CodeFoldingTerminatingTail] = []
  for tail in tails {
    planned.push(
      code_folding_terminating_tail_with_plan(tail, suffix_len, profitability),
    )
  }
  planned
}

///|
fn code_folding_pick_terminating_tail_group_from_anchor(
  func : @ir.HotFunc,
  anchor_tail : CodeFoldingTerminatingTail,
  candidates : Array[CodeFoldingTerminatingTail],
  label_used : @bitset.BitSet,
  facts : CodeFoldingTerminatingFacts,
) -> Array[CodeFoldingTerminatingTail] {
  let mut current = candidates
  let mut best : Array[CodeFoldingTerminatingTail] = []
  let mut best_len = 0
  let mut depth = 0
  while true {
    let anchor = code_folding_terminating_tail_item_at_depth(
      func, anchor_tail, depth,
    )
    if anchor < 0 ||
      code_folding_terminal_tail_item_has_external_break_target(
        func, anchor_tail, anchor, facts,
      ) ||
      !code_folding_terminal_tail_item_is_movable(
        func, anchor_tail, anchor, depth, label_used, facts,
      ) {
      break
    }
    let exact_equality_proves_movable = depth == 0 ||
      !code_folding_terminating_node_may_throw(func, anchor, facts)
    let next : Array[CodeFoldingTerminatingTail] = []
    for tail in current {
      let item = code_folding_terminating_tail_item_at_depth(func, tail, depth)
      if item < 0 {
        continue
      }
      let exact_equal = code_folding_nodes_equal_exact_labels(
        func, anchor, item,
      )
      if exact_equal && exact_equality_proves_movable {
        next.push(tail)
        continue
      }
      if !code_folding_terminal_tail_item_has_external_break_target(
          func, tail, item, facts,
        ) &&
        code_folding_terminal_tail_item_is_movable(
          func, tail, item, depth, label_used, facts,
        ) &&
        (
          exact_equal ||
          code_folding_nodes_equal_with_label_map(
            func,
            anchor,
            item,
            label_used,
            code_folding_label_map_new(),
          )
        ) {
        next.push(tail)
      }
    }
    if next.length() < 2 {
      break
    }
    best = next
    best_len = depth + 1
    current = best
    depth += 1
  }
  code_folding_plan_terminating_tail_group(func, best, best_len, facts)
}

///|
fn code_folding_pick_terminating_tail_group_at_depth(
  func : @ir.HotFunc,
  tails : Array[CodeFoldingTerminatingTail],
  depth : Int,
  label_used : @bitset.BitSet,
  facts : CodeFoldingTerminatingFacts,
) -> Array[CodeFoldingTerminatingTail] {
  if tails.length() < 2 {
    return []
  }
  let bucket_lookup : @hashmap.HashMap[Int, Int] = @hashmap.new(
    capacity=tails.length() * 2 + 1,
  )
  let buckets : Array[Array[CodeFoldingTerminatingTail]] = []
  for tail in tails {
    let item = code_folding_terminating_tail_item_at_depth(func, tail, depth)
    if item < 0 ||
      code_folding_terminal_tail_item_has_external_break_target(
        func, tail, item, facts,
      ) ||
      !code_folding_terminal_tail_item_is_movable(
        func, tail, item, depth, label_used, facts,
      ) {
      continue
    }
    let key = code_folding_terminating_node_shallow_hash(func, item, facts)
    match bucket_lookup.get(key) {
      Some(bucket_idx) => buckets[bucket_idx].push(tail)
      None => {
        bucket_lookup.set(key, buckets.length())
        buckets.push([tail])
      }
    }
  }
  for bucket in buckets {
    if bucket.length() < 2 {
      continue
    }
    let mut remaining = bucket
    while remaining.length() >= 2 {
      let representative = code_folding_terminating_tail_item_at_depth(
        func,
        remaining[0],
        depth,
      )
      let equal : Array[CodeFoldingTerminatingTail] = []
      let others : Array[CodeFoldingTerminatingTail] = []
      for tail in remaining {
        let item = code_folding_terminating_tail_item_at_depth(
          func, tail, depth,
        )
        if code_folding_nodes_equal(func, representative, item, label_used) {
          equal.push(tail)
        } else {
          others.push(tail)
        }
      }
      if equal.length() >= 2 {
        let deeper = code_folding_pick_terminating_tail_group_at_depth(
          func,
          equal,
          depth + 1,
          label_used,
          facts,
        )
        if deeper.length() > 0 {
          return deeper
        }
      }
      remaining = others
    }
  }
  if depth == 0 {
    []
  } else {
    code_folding_plan_terminating_tail_group(func, tails, depth, facts)
  }
}

///|
fn code_folding_pick_terminating_tail_group(
  func : @ir.HotFunc,
  desired_kind : Int,
  all_tails : Array[CodeFoldingTerminatingTail],
  label_used : @bitset.BitSet,
  facts : CodeFoldingTerminatingFacts,
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
  let first_anchor = code_folding_pick_terminating_tail_group_from_anchor(
    func,
    candidates[0],
    candidates,
    label_used,
    facts,
  )
  if first_anchor.length() > 0 {
    return first_anchor
  }
  code_folding_pick_terminating_tail_group_at_depth(
    func, candidates, 0, label_used, facts,
  )
}

///|
fn code_folding_splice_terminating_region_unmarked(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
  node_ids : Array[Int],
) -> Array[Int] {
  let removed = @ir.hot_region_splice(
    func, region_ref, idx, remove_count, node_ids,
  )
  if remove_count != 0 || !node_ids.is_empty() {
    match ctx.perf {
      Some(perf) => perf_count_region_splice(perf)
      None => ()
    }
  }
  removed
}

///|
fn code_folding_try_rewrite_terminating_tail_group(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  tails : Array[CodeFoldingTerminatingTail],
  facts : CodeFoldingTerminatingFacts,
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
    code_folding_terminating_node_prevents_fallthrough(
      func,
      @ir.hot_region_get(func, root_ref, root_count_before_rewrite - 1),
      facts,
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
  let hoisted = code_folding_splice_terminating_region_unmarked(
    ctx,
    func,
    anchor_tail.region_ref,
    anchor_start,
    suffix_len,
    [],
  )
  let wrapper = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let wrapper_label = @ir.hot_control_node_label(func, wrapper)
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
      code_folding_splice_terminating_region_unmarked(
        ctx,
        func,
        tail.region_ref,
        start_idx,
        remove_count,
        [branch],
      ),
    )
  }
  let prefix_count = @ir.hot_region_root_count(func, root_ref)
  let prefix_roots = code_folding_splice_terminating_region_unmarked(
    ctx,
    func,
    root_ref,
    0,
    prefix_count,
    [],
  )
  if needs_fallthrough_skip {
    prefix_roots.push(@ir.hot_build_return(func, []))
  }
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, wrapper),
    prefix_roots,
  )
  let replacement = [wrapper]
  for node_id in hoisted {
    replacement.push(node_id)
  }
  ignore(
    code_folding_splice_terminating_region_unmarked(
      ctx, func, root_ref, 0, 0, replacement,
    ),
  )
  pass_mark_mutated(ctx, func)
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
  let mut unreachable_count = 0
  let mut return_count = 0
  for tail in tails {
    if tail.terminal_kind == code_folding_terminal_tail_kind_unreachable() {
      unreachable_count += 1
    } else if tail.terminal_kind == code_folding_terminal_tail_kind_return() {
      return_count += 1
    }
  }
  if unreachable_count < 2 && return_count < 2 {
    return false
  }
  let facts = CodeFoldingTerminatingFacts::new(func, label_used)
  if unreachable_count >= 2 {
    let unreachable_group = code_folding_pick_terminating_tail_group(
      func,
      code_folding_terminal_tail_kind_unreachable(),
      tails,
      label_used,
      facts,
    )
    if code_folding_try_rewrite_terminating_tail_group(
        ctx, func, unreachable_group, facts,
      ) {
      return true
    }
  }
  if return_count < 2 {
    return false
  }
  let return_group = code_folding_pick_terminating_tail_group(
    func,
    code_folding_terminal_tail_kind_return(),
    tails,
    label_used,
    facts,
  )
  code_folding_try_rewrite_terminating_tail_group(
    ctx, func, return_group, facts,
  )
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
  exit_index : CodeFoldingExitIndex,
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
        code_folding_node_prevents_fallthrough_with_index(
          func, then_root, exit_index,
        ) ||
        code_folding_node_prevents_fallthrough_with_index(
          func, following_root, exit_index,
        )
      ) {
      return false
    }
    if @ir.hot_node_result_arity(func, then_root) != 0 ||
      @ir.hot_node_result_arity(func, following_root) != 0 ||
      !code_folding_nodes_equal(func, then_root, following_root, label_used) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, then_root, if_id, label_used, exit_index,
      ) ||
      !code_folding_node_is_if_hoistable_suffix(
        func, following_root, if_id, label_used, exit_index,
      ) {
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
  exit_index : CodeFoldingExitIndex,
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
      label_used, exit_index,
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
  exit_index : CodeFoldingExitIndex,
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
        ctx, func, region_ref, idx, if_id, then_ref, result_arity, label_used, exit_index,
      )
  }
  let suffix_len = code_folding_common_suffix_len(
    func, if_id, then_ref, else_ref, label_used, exit_index,
  )
  if suffix_len == 0 {
    return code_folding_try_fold_two_block_if_at_region(
        ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
        exit_index,
      ) ||
      code_folding_try_fold_one_block_if_at_region(
        ctx, func, region_ref, idx, if_id, then_ref, else_ref, result_arity, label_used,
        exit_index,
      )
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
    !code_folding_full_value_if_common_suffix_allowed(
      func, then_ref, else_ref, then_start, else_start, suffix_len, result_arity,
    ) {
    return false
  }
  if result_arity == 0 &&
    then_start == 0 &&
    else_start == 0 &&
    code_folding_suffix_measure(func, then_ref, then_start, suffix_len) <
    code_folding_worth_adding_block_threshold() {
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
  exit_index : CodeFoldingExitIndex,
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
  match @ir.hot_region_else_ref(func, if_id) {
    Some(_) => ()
    None => return false
  }
  code_folding_try_fold_if_at_region(
    ctx, func, region_ref, idx, label_used, exit_index,
  )
}

///|
fn code_folding_visit_eh_body_if_suffixes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
  exit_index : CodeFoldingExitIndex,
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
              exit_index,
            ) {
            changed = true
          }
        @ir.HotOp::If => {
          if code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_then_ref(func, node_id),
              label_used,
              exit_index,
            ) {
            changed = true
          }
          match @ir.hot_region_else_ref(func, node_id) {
            Some(else_ref) =>
              if code_folding_visit_eh_body_if_suffixes(
                  ctx, func, else_ref, label_used, exit_index,
                ) {
                changed = true
              }
            None => ()
          }
          if code_folding_try_fold_if_at_eh_body_region(
              ctx, func, region_ref, idx, label_used, exit_index,
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
              exit_index,
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
  exit_index : CodeFoldingExitIndex,
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
          exit_index,
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
            exit_index,
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
            exit_index,
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
                exit_index,
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
            ctx, func, child_id, label_used, exit_index,
          ) {
          changed = true
        }
      }
  }
  changed
}

///|
fn CodeFoldingExitIndex::begin_control_body_visit(
  self : CodeFoldingExitIndex,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    node_id >= self.visited_control_bodies.length() ||
    !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => {
      if self.visited_control_bodies[node_id] {
        return false
      }
      self.visited_control_bodies[node_id] = true
    }
    _ => ()
  }
  true
}

///|
fn code_folding_visit_embedded_controls(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
  exit_index : CodeFoldingExitIndex,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  let control_preserve_bottom_tail = @ir.hot_node_result_arity(func, node_id) >
    0
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block =>
      if exit_index.begin_control_body_visit(func, node_id) &&
        code_folding_visit_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          false,
          exit_index,
        ) {
        changed = true
      }
    @ir.HotOp::Loop =>
      if exit_index.begin_control_body_visit(func, node_id) &&
        code_folding_visit_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          control_preserve_bottom_tail,
          exit_index,
        ) {
        changed = true
      }
    @ir.HotOp::If =>
      if exit_index.begin_control_body_visit(func, node_id) {
        if code_folding_visit_region(
            ctx,
            func,
            @ir.hot_region_then_ref(func, node_id),
            label_used,
            control_preserve_bottom_tail,
            exit_index,
          ) {
          changed = true
        }
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) =>
            if code_folding_visit_region(
                ctx, func, else_ref, label_used, control_preserve_bottom_tail, exit_index,
              ) {
              changed = true
            }
          None => ()
        }
      }
    @ir.HotOp::Try | @ir.HotOp::TryTable =>
      if exit_index.begin_control_body_visit(func, node_id) &&
        code_folding_visit_eh_body_if_suffixes(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          label_used,
          exit_index,
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
                  ctx, func, child_id, label_used, exit_index,
                ) {
                changed = true
              }
              let next_child_id = @ir.hot_child_get(func, node_id, slot)
              if code_folding_try_fold_embedded_value_if_child(
                  ctx, func, node_id, slot, next_child_id, label_used, exit_index,
                ) {
                changed = true
              }
            }
            _ => ()
          }
        }
      }
  }
  if changed {
    exit_index.invalidate_facts()
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
  exit_index : CodeFoldingExitIndex,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      let cleanup_changed = match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Drop =>
          code_folding_try_remove_drop_unreachable_at_region(
            ctx, func, region_ref, idx,
          )
        @ir.HotOp::Block =>
          code_folding_try_remove_dead_block_before_unreachable_at_region(
            ctx, func, region_ref, idx, label_used,
          ) ||
          code_folding_try_flatten_exiting_block_at_region(
            ctx, func, region_ref, idx, label_used,
          )
        @ir.HotOp::Unreachable =>
          code_folding_try_remove_unreachable_after_exit_at_region(
            ctx, func, region_ref, idx, preserve_bottom_tail,
          )
        _ => false
      }
      if cleanup_changed {
        changed = true
        exit_index.invalidate_facts()
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
          if exit_index.begin_control_body_visit(func, current_id) &&
            code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
              false,
              exit_index,
            ) {
            changed = true
          }
          if exit_index.invalidated {
            return true
          }
          if code_folding_try_fold_value_block_exit_at_region(
              ctx, func, region_ref, idx, label_used, exit_index,
            ) {
            exit_index.invalidated = true
            return true
          }
          if code_folding_try_fold_block_exit_at_region(
              ctx, func, region_ref, idx, label_used, exit_index,
            ) {
            return true
          }
        }
        @ir.HotOp::Loop => {
          let control_preserve_bottom_tail = @ir.hot_node_result_arity(
              func, current_id,
            ) >
            0
          if exit_index.begin_control_body_visit(func, current_id) &&
            code_folding_visit_region(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
              control_preserve_bottom_tail,
              exit_index,
            ) {
            changed = true
          }
          if exit_index.invalidated {
            return true
          }
        }
        @ir.HotOp::If => {
          let control_preserve_bottom_tail = @ir.hot_node_result_arity(
              func, current_id,
            ) >
            0
          if exit_index.begin_control_body_visit(func, current_id) {
            if code_folding_visit_region(
                ctx,
                func,
                @ir.hot_region_then_ref(func, current_id),
                label_used,
                control_preserve_bottom_tail,
                exit_index,
              ) {
              changed = true
            }
            if exit_index.invalidated {
              return true
            }
            match @ir.hot_region_else_ref(func, current_id) {
              Some(else_ref) =>
                if code_folding_visit_region(
                    ctx, func, else_ref, label_used, control_preserve_bottom_tail,
                    exit_index,
                  ) {
                  changed = true
                }
              None => ()
            }
          }
          if exit_index.invalidated {
            return true
          }
          if code_folding_try_fold_if_at_region(
              ctx, func, region_ref, idx, label_used, exit_index,
            ) {
            changed = true
            exit_index.invalidate_facts()
          }
        }
        @ir.HotOp::Try | @ir.HotOp::TryTable =>
          if exit_index.begin_control_body_visit(func, current_id) &&
            code_folding_visit_eh_body_if_suffixes(
              ctx,
              func,
              @ir.hot_region_body_ref(func, current_id),
              label_used,
              exit_index,
            ) {
            changed = true
            exit_index.invalidate_facts()
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
        | @ir.HotOp::ReturnCall
        | @ir.HotOp::ReturnCallIndirect
        | @ir.HotOp::ReturnCallRef =>
          if code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used, exit_index,
            ) {
            changed = true
          }
        @ir.HotOp::Br | @ir.HotOp::BrIf =>
          if code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used, exit_index,
            ) {
            changed = true
          }
        @ir.HotOp::Drop =>
          if code_folding_visit_embedded_controls(
              ctx, func, current_id, label_used, exit_index,
            ) {
            changed = true
          } else if code_folding_visit_embedded_eh_body_if_suffixes(
              ctx, func, current_id, label_used, exit_index,
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
    let exit_index = code_folding_build_block_exit_index(func, label_used)
    let root_ref = @ir.HotRegionRef::root()
    let mut iteration_changed = code_folding_visit_region(
      ctx,
      func,
      root_ref,
      label_used,
      @ir.hot_region_result_arity(func, root_ref) > 0,
      exit_index,
    )
    if !exit_index.invalidated &&
      code_folding_try_fold_terminating_tails(ctx, func, label_used) {
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
