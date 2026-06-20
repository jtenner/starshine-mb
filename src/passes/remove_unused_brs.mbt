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
priv struct RemoveUnusedBrsRootSite {
  region_ref : @ir.HotRegionRef
  idx : Int
}

///|
priv struct RemoveUnusedBrsCycleScan {
  label_refs : Array[Int]
  branch_payload_children : @bitset.BitSet
  has_br_table : Bool
}

///|
priv enum RemoveUnusedBrsCaughtThrowMatch {
  NoCaughtThrowMatch
  CaughtThrowExact(Int)
  CaughtThrowAll(Int)
  CaughtThrowRef
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
  mut br_table_count : Int
  mut drop_count : Int
  mut result_block_non_block_prefix_count : Int
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
      @ir.HotOp::Block => {
        shape.block_count = shape.block_count + 1
        if @ir.hot_node_result_arity(func, node_id) > 0 {
          let body_ref = @ir.hot_region_body_ref(func, node_id)
          if @ir.hot_region_root_count(func, body_ref) >= 2 {
            let prefix_id = @ir.hot_region_get(func, body_ref, 0)
            if prefix_id >= 0 && @ir.hot_node_is_live(func, prefix_id) {
              match @ir.hot_node_get(func, prefix_id).op {
                @ir.HotOp::Block => ()
                _ =>
                  shape.result_block_non_block_prefix_count = shape.result_block_non_block_prefix_count +
                    1
              }
            }
          }
        }
      }
      @ir.HotOp::Loop => shape.loop_count = shape.loop_count + 1
      @ir.HotOp::Br => shape.br_count = shape.br_count + 1
      @ir.HotOp::BrTable => shape.br_table_count = shape.br_table_count + 1
      @ir.HotOp::Drop => shape.drop_count = shape.drop_count + 1
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
priv struct RemoveUnusedBrsHotVoidReturnLadderSummary {
  local_count : Int
  root_count : Int
  node_count : Int
  shape : RemoveUnusedBrsHotVoidReturnLadderShape
}

///|
fn remove_unused_brs_new_hot_void_return_ladder_shape() -> RemoveUnusedBrsHotVoidReturnLadderShape {
  {
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
    br_table_count: 0,
    drop_count: 0,
    result_block_non_block_prefix_count: 0,
  }
}

///|
fn remove_unused_brs_collect_hot_void_return_ladder_summary(
  func : @ir.HotFunc,
) -> RemoveUnusedBrsHotVoidReturnLadderSummary {
  let shape = remove_unused_brs_new_hot_void_return_ladder_shape()
  remove_unused_brs_scan_hot_void_return_ladder_shape(func, shape)
  {
    local_count: @ir.hot_local_count(func),
    root_count: @ir.hot_root_count(func),
    node_count: @ir.hot_node_count(func),
    shape,
  }
}

///|
fn remove_unused_brs_can_skip_large_tagged_result_prefix_ladder(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let root_count = summary.root_count
  let node_count = summary.node_count
  let shape = summary.shape
  if local_count < 450 || local_count > 700 {
    return false
  }
  if root_count < 1 || root_count > 2 {
    return false
  }
  if node_count < 800 || node_count > 4500 {
    return false
  }
  let total_if_count = shape.void_if_count + shape.value_if_count
  let non_block_prefix_count = shape.result_block_non_block_prefix_count
  let matches_reduced_lock = local_count >= 450 &&
    local_count <= 700 &&
    root_count >= 1 &&
    root_count <= 2 &&
    node_count >= 800 &&
    shape.call_count >= 180 &&
    shape.call_count <= 500 &&
    shape.local_set_count >= 120 &&
    shape.local_set_count <= 360 &&
    shape.local_tee_count >= 120 &&
    shape.local_tee_count <= 360 &&
    total_if_count >= 180 &&
    total_if_count <= 400 &&
    shape.void_if_count >= 100 &&
    shape.void_if_count <= 260 &&
    shape.value_if_count >= 60 &&
    shape.value_if_count <= 160 &&
    shape.select_count <= 32 &&
    shape.br_if_count == 0 &&
    shape.block_count >= 60 &&
    shape.block_count <= 400 &&
    shape.loop_count == 0 &&
    shape.br_table_count == 0 &&
    non_block_prefix_count >= 16
  let matches_artifact_dispatch = local_count >= 560 &&
    local_count <= 620 &&
    root_count == 2 &&
    node_count >= 3000 &&
    node_count <= 4000 &&
    shape.call_count >= 280 &&
    shape.call_count <= 360 &&
    shape.local_set_count >= 250 &&
    shape.local_set_count <= 340 &&
    shape.local_tee_count >= 250 &&
    shape.local_tee_count <= 340 &&
    shape.void_if_count >= 140 &&
    shape.void_if_count <= 200 &&
    shape.value_if_count >= 60 &&
    shape.value_if_count <= 100 &&
    shape.return_count >= 60 &&
    shape.return_count <= 100 &&
    shape.select_count >= 8 &&
    shape.select_count <= 24 &&
    shape.br_if_count == 0 &&
    shape.block_count >= 420 &&
    shape.block_count <= 560 &&
    shape.loop_count == 0 &&
    shape.br_count >= 100 &&
    shape.br_count <= 160 &&
    shape.br_table_count == 0 &&
    shape.drop_count <= 8 &&
    non_block_prefix_count >= 16 &&
    non_block_prefix_count <= 24
  matches_reduced_lock || matches_artifact_dispatch
}

///|
fn remove_unused_brs_can_skip_medium_branchy_block_ladder(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let node_count = summary.node_count
  let shape = summary.shape
  if local_count < 200 || local_count > 500 {
    return false
  }
  if node_count < 1300 || node_count > 2300 {
    return false
  }
  shape.call_count >= 130 &&
  shape.call_count <= 380 &&
  shape.local_set_count >= 90 &&
  shape.local_set_count <= 220 &&
  shape.local_tee_count >= 120 &&
  shape.local_tee_count <= 280 &&
  shape.void_if_count >= 50 &&
  shape.void_if_count <= 160 &&
  shape.value_if_count <= 12 &&
  shape.return_count <= 24 &&
  shape.select_count <= 4 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 100 &&
  shape.block_count <= 240 &&
  shape.loop_count <= 16 &&
  shape.br_count >= 30 &&
  shape.br_count <= 60 &&
  shape.br_table_count == 0 &&
  shape.drop_count <= 80 &&
  shape.result_block_non_block_prefix_count <= 4
}

///|
fn remove_unused_brs_can_skip_call_heavy_mixed_if_mesh(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let root_count = summary.root_count
  let node_count = summary.node_count
  let shape = summary.shape
  let total_if_count = shape.void_if_count + shape.value_if_count
  local_count >= 190 &&
  local_count <= 650 &&
  root_count >= 2 &&
  root_count <= 60 &&
  node_count >= 1100 &&
  node_count <= 3200 &&
  shape.call_count >= 100 &&
  shape.call_count <= 650 &&
  shape.local_set_count >= 90 &&
  shape.local_set_count <= 350 &&
  shape.local_tee_count >= 75 &&
  shape.local_tee_count <= 300 &&
  total_if_count >= 50 &&
  total_if_count <= 140 &&
  shape.void_if_count <= 90 &&
  shape.return_count <= 20 &&
  shape.select_count <= 1 &&
  shape.br_if_count <= 1 &&
  shape.block_count >= 90 &&
  shape.block_count <= 230 &&
  shape.loop_count <= 5 &&
  shape.br_count >= 13 &&
  shape.br_count <= 50 &&
  shape.br_table_count == 0 &&
  shape.drop_count <= 90
}

///|
fn remove_unused_brs_can_skip_localset_heavy_value_if_mesh(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let root_count = summary.root_count
  let node_count = summary.node_count
  let shape = summary.shape
  local_count >= 220 &&
  local_count <= 700 &&
  root_count >= 5 &&
  root_count <= 50 &&
  node_count >= 1050 &&
  node_count <= 3200 &&
  shape.call_count >= 45 &&
  shape.call_count <= 110 &&
  shape.local_set_count >= 130 &&
  shape.local_set_count <= 650 &&
  shape.local_tee_count >= 79 &&
  shape.local_tee_count <= 320 &&
  shape.void_if_count <= 24 &&
  shape.value_if_count >= 14 &&
  shape.value_if_count <= 100 &&
  shape.return_count <= 21 &&
  shape.select_count <= 13 &&
  shape.br_if_count <= 5 &&
  shape.block_count >= 70 &&
  shape.block_count <= 231 &&
  shape.loop_count <= 2 &&
  shape.br_count >= 12 &&
  shape.br_count <= 83 &&
  shape.br_table_count == 0 &&
  shape.drop_count <= 25
}

///|
fn remove_unused_brs_can_skip_large_void_return_ladder(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let root_count = summary.root_count
  let node_count = summary.node_count
  let shape = summary.shape
  let matches_wide_void_ladder = local_count >= 700 &&
    root_count >= 64 &&
    shape.call_count >= 900 &&
    shape.local_set_count >= 350 &&
    shape.local_tee_count >= 350 &&
    shape.void_if_count >= 150 &&
    shape.value_if_count == 0 &&
    shape.return_count >= 90 &&
    shape.return_count * 5 >= shape.void_if_count &&
    shape.select_count <= 4 &&
    shape.br_if_count <= 2
  let matches_compact_decision_ladder = local_count >= 700 &&
    root_count <= 8 &&
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
  let matches_single_root_value_if_ladder = local_count >= 700 &&
    root_count == 1 &&
    node_count >= 1500 &&
    shape.call_count >= 300 &&
    shape.local_set_count >= 150 &&
    shape.local_tee_count >= 150 &&
    shape.void_if_count == 0 &&
    shape.value_if_count >= 150 &&
    shape.return_count == 0 &&
    shape.select_count == 0 &&
    shape.br_if_count == 0 &&
    shape.block_count >= 600 &&
    shape.loop_count == 0 &&
    shape.br_count == 0
  let matches_nested_constructor_return_ladder = local_count >= 20 &&
    local_count <= 40 &&
    shape.call_count >= 6 &&
    shape.call_count <= 16 &&
    shape.local_set_count >= 4 &&
    shape.local_set_count <= 20 &&
    shape.local_tee_count >= 4 &&
    shape.local_tee_count <= 16 &&
    shape.void_if_count >= 3 &&
    shape.void_if_count <= 8 &&
    shape.value_if_count == 0 &&
    shape.return_count == 0 &&
    shape.select_count == 0 &&
    shape.br_if_count == 0 &&
    shape.block_count >= 6 &&
    shape.block_count <= 12 &&
    shape.loop_count == 0 &&
    shape.br_count == 2
  let matches_mixed_branch_value_ladder = local_count >= 450 &&
    local_count <= 900 &&
    node_count >= 4000 &&
    shape.call_count >= 350 &&
    shape.local_set_count >= 250 &&
    shape.local_tee_count >= 250 &&
    shape.void_if_count >= 120 &&
    shape.value_if_count >= 20 &&
    shape.value_if_count <= 120 &&
    shape.return_count >= 15 &&
    shape.return_count <= 100 &&
    shape.select_count <= 12 &&
    shape.br_if_count <= 12 &&
    shape.block_count >= 400 &&
    shape.loop_count <= 4 &&
    shape.br_count >= 70 &&
    shape.br_count <= 150
  matches_wide_void_ladder ||
  matches_compact_decision_ladder ||
  matches_single_root_value_if_ladder ||
  matches_nested_constructor_return_ladder ||
  matches_mixed_branch_value_ladder
}

///|
fn remove_unused_brs_can_skip_large_br_table_return_ladder(
  summary : RemoveUnusedBrsHotVoidReturnLadderSummary,
) -> Bool {
  let local_count = summary.local_count
  let node_count = summary.node_count
  let shape = summary.shape
  let total_if_count = shape.void_if_count + shape.value_if_count
  local_count >= 80 &&
  node_count >= 500 &&
  shape.call_count >= 100 &&
  shape.local_set_count >= 50 &&
  shape.local_tee_count >= 20 &&
  total_if_count >= 60 &&
  total_if_count <= 400 &&
  shape.return_count >= 20 &&
  shape.return_count <= 80 &&
  shape.select_count <= 8 &&
  shape.br_if_count == 0 &&
  shape.block_count >= 20 &&
  shape.block_count <= 800 &&
  shape.loop_count <= 32 &&
  shape.br_count >= 5 &&
  shape.br_count <= 300 &&
  shape.br_table_count >= 1 &&
  shape.br_table_count <= 4 &&
  shape.drop_count <= 200
}

///|
fn remove_unused_brs_node_has_stack_effect_hazard(
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
    | @ir.HotOp::MemoryCopy
    | @ir.HotOp::MemoryFill => return true
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if remove_unused_brs_is_region_child_slot(node.op, slot) {
      continue
    }
    if remove_unused_brs_node_has_stack_effect_hazard(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn remove_unused_brs_region_has_result_local_set_stack_hazard(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let result_arity = if region_ref == @ir.HotRegionRef::root() {
    @ir.hot_type_result_arity(func, @ir.hot_body_result_type(func))
  } else if region_ref.holder >= 0 &&
    @ir.hot_node_is_live(func, region_ref.holder) {
    @ir.hot_node_result_arity(func, region_ref.holder)
  } else {
    @ir.hot_region_result_arity(func, region_ref)
  }
  if (region_ref == @ir.HotRegionRef::root() || result_arity > 0) &&
    @ir.hot_region_root_count(func, region_ref) > 1 {
    let mut has_local_set = false
    let mut has_stack_effect = false
    for idx = 0
        idx < @ir.hot_region_root_count(func, region_ref)
        idx = idx + 1 {
      let root_id = @ir.hot_region_get(func, region_ref, idx)
      if root_id >= 0 && @ir.hot_node_is_live(func, root_id) {
        match @ir.hot_node_get(func, root_id).op {
          @ir.HotOp::LocalSet => has_local_set = true
          _ => ()
        }
        if remove_unused_brs_node_has_stack_effect_hazard(func, root_id) {
          has_stack_effect = true
        }
      }
    }
    if has_local_set && has_stack_effect {
      return true
    }
  }
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    let node = @ir.hot_node_get(func, root_id)
    for info in @ir.hot_control_region_slot_info(node.op) {
      let child_ref = match info.role {
        @ir.HotControlRegionRole::BodyRegion =>
          Some(@ir.hot_region_body_ref(func, root_id))
        @ir.HotControlRegionRole::ThenRegion =>
          Some(@ir.hot_region_then_ref(func, root_id))
        @ir.HotControlRegionRole::ElseRegion =>
          @ir.hot_region_else_ref(func, root_id)
        @ir.HotControlRegionRole::CatchRegion =>
          @ir.hot_region_catch_ref(func, root_id)
        @ir.HotControlRegionRole::CatchListRegion =>
          Some(@ir.hot_region_catch_list_ref(func, root_id))
      }
      match child_ref {
        Some(child_ref) =>
          if remove_unused_brs_region_has_result_local_set_stack_hazard(
              func, child_ref,
            ) {
            return true
          }
        None => ()
      }
    }
  }
  false
}

///|
fn remove_unused_brs_tail_target(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> RemoveUnusedBrsTailTarget {
  if region_ref == @ir.HotRegionRef::root() {
    return ReturnTarget
  }
  match @ir.hot_region_holder_block_label(func, region_ref) {
    Some(target) => BranchTarget(target)
    None => NoTarget
  }
}

///|
fn remove_unused_brs_region_enclosing_branch_target(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  if region_ref == @ir.HotRegionRef::root() {
    return None
  }
  let holder = region_ref.holder
  if holder < 0 ||
    !@ir.hot_node_is_live(func, holder) ||
    !@ir.hot_is_control_node(func, holder) {
    return None
  }
  Some(@ir.hot_control_node_label(func, holder))
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
fn remove_unused_brs_compute_cycle_scan(
  func : @ir.HotFunc,
) -> RemoveUnusedBrsCycleScan {
  let label_refs = Array::make(func.labels.length(), 0)
  let payload_children = @bitset.BitSet::new(@ir.hot_node_count(func))
  let mut has_br_table = false
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
      @ir.HotOp::BrTable => {
        has_br_table = true
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          if label_id >= 0 && label_id < label_refs.length() {
            label_refs[label_id] = label_refs[label_id] + 1
          }
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
    let payload_slots = match node.op {
      @ir.HotOp::Br | @ir.HotOp::Return => node.child_count
      @ir.HotOp::BrIf | @ir.HotOp::BrTable =>
        if node.child_count > 0 {
          node.child_count - 1
        } else {
          0
        }
      _ => 0
    }
    for slot = 0; slot < payload_slots; slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
        payload_children[child_id] = true
      }
    }
  }
  { label_refs, branch_payload_children: payload_children, has_br_table }
}

///|
fn remove_unused_brs_cleanup_detached_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  detached : Array[Int],
) -> Unit {
  // Large detached subgraphs do not affect lowered output once roots/child
  // edges are gone; eagerly collecting them here is disproportionately
  // expensive on real RUB artifact functions.
  if detached.length() > 32 {
    return
  }
  let node_count = @ir.hot_node_count(func)
  let candidates : Array[Int] = []
  let in_candidate = @bitset.BitSet::new(node_count)
  for node_id in detached {
    if node_id < 0 ||
      node_id >= node_count ||
      !@ir.hot_node_is_live(func, node_id) ||
      @ir.hot_is_control_node(func, node_id) ||
      in_candidate[node_id] {
      continue
    }
    in_candidate[node_id] = true
    candidates.push(node_id)
  }
  if candidates.is_empty() {
    return
  }
  let is_unreferenced = fn(node_id : Int) -> Bool {
    for root in func.roots {
      if root == node_id {
        return false
      }
    }
    for owner = 0; owner < node_count; owner = owner + 1 {
      if !@ir.hot_node_is_live(func, owner) || owner == node_id {
        continue
      }
      let node = @ir.hot_node_get(func, owner)
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if @ir.hot_child_get(func, owner, slot) == node_id {
          return false
        }
      }
    }
    true
  }
  let mut changed = false
  let mut progress = true
  while progress {
    progress = false
    for node_id in candidates {
      if node_id < 0 ||
        node_id >= node_count ||
        !in_candidate[node_id] ||
        !@ir.hot_node_is_live(func, node_id) {
        continue
      }
      if !is_unreferenced(node_id) {
        continue
      }
      @ir.hot_delete_node(func, node_id)
      changed = true
      progress = true
      in_candidate[node_id] = false
    }
  }
  if changed {
    remove_unused_brs_mark_mutated(ctx, func, "cleanup-detached-nodes")
  }
}

///|
fn remove_unused_brs_delete_unused_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_ids : Array[Int],
) -> Unit {
  remove_unused_brs_cleanup_detached_nodes(ctx, func, node_ids)
}

///|
fn remove_unused_brs_tag_idx_raw(tag_idx : @lib.TagIdx) -> Int {
  let @lib.TagIdx(raw) = tag_idx
  raw.reinterpret_as_int()
}

///|
fn remove_unused_brs_single_ref_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.RefType? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  match @ir.hot_type_results(func, @ir.hot_node_type(func, node_id)) {
    [@lib.RefTypeValType(rt)] => Some(rt)
    _ => None
  }
}

///|
fn remove_unused_brs_node_is_ref_null(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::RefNull => true
    _ => false
  }
}

///|
fn remove_unused_brs_ref_matches(
  actual : @lib.RefType,
  expected : @lib.RefType,
) -> Bool {
  @validate.Match::matches(
    @lib.ValType::ref_type(actual),
    @lib.ValType::ref_type(expected),
    @validate.Env::new(),
  )
}

///|
fn remove_unused_brs_try_rewrite_gc_br_on_root(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let root_id = @ir.hot_region_get(func, region_ref, idx)
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return false
  }
  let mut br_id = root_id
  let mut dropped_context = false
  match @ir.hot_node_get(func, root_id).op {
    @ir.HotOp::Drop => {
      if @ir.hot_child_count(func, root_id) != 1 {
        return false
      }
      br_id = @ir.hot_child_get(func, root_id, 0)
      dropped_context = true
    }
    _ => ()
  }
  if br_id < 0 || !@ir.hot_node_is_live(func, br_id) {
    return false
  }
  let br_node = @ir.hot_node_get(func, br_id)
  match br_node.op {
    @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail => ()
    _ => return false
  }
  if @ir.hot_child_count(func, br_id) != 1 {
    return false
  }
  let ref_id = @ir.hot_child_get(func, br_id, 0)
  let ref_type = match remove_unused_brs_single_ref_type(func, ref_id) {
    Some(rt) => rt
    None => return false
  }
  let target = br_node.imm0
  let replacement : Array[Int] = []
  let mut changed = false
  match br_node.op {
    @ir.HotOp::BrOnNull =>
      if remove_unused_brs_node_is_ref_null(func, ref_id) {
        replacement.push(@ir.hot_build_drop(func, ref_id))
        replacement.push(@ir.hot_build_br(func, target))
        changed = true
      } else if ref_type.is_non_nullable() && dropped_context {
        replacement.push(@ir.hot_build_drop(func, ref_id))
        changed = true
      } else if ref_type.is_non_nullable() && !dropped_context {
        replacement.push(ref_id)
        changed = true
      }
    @ir.HotOp::BrOnNonNull =>
      if ref_type.is_non_nullable() {
        replacement.push(@ir.hot_build_br(func, target, values=[ref_id]))
        changed = true
      } else if remove_unused_brs_node_is_ref_null(func, ref_id) {
        replacement.push(@ir.hot_build_drop(func, ref_id))
        changed = true
      }
    @ir.HotOp::BrOnCast | @ir.HotOp::BrOnCastFail => {
      let target_ref = match @ir.hot_node_exact_instr(func, br_id) {
        Some(@lib.BrOnCast(_, @lib.CastOp(_, target_nullable), _, target_heap))
        | Some(
          @lib.BrOnCastFail(_, @lib.CastOp(_, target_nullable), _, target_heap)
        ) => @lib.RefType::new(target_nullable, target_heap)
        _ => return false
      }
      if remove_unused_brs_ref_matches(ref_type, target_ref) {
        match br_node.op {
          @ir.HotOp::BrOnCast => {
            replacement.push(@ir.hot_build_br(func, target, values=[ref_id]))
            changed = true
          }
          @ir.HotOp::BrOnCastFail if dropped_context => {
            replacement.push(@ir.hot_build_drop(func, ref_id))
            changed = true
          }
          @ir.HotOp::BrOnCastFail => {
            replacement.push(ref_id)
            changed = true
          }
          _ => ()
        }
      } else {
        match br_node.op {
          @ir.HotOp::BrOnCast =>
            if remove_unused_brs_node_is_ref_null(func, ref_id) &&
              target_ref.is_non_nullable() {
              if dropped_context {
                replacement.push(@ir.hot_build_drop(func, ref_id))
              } else {
                replacement.push(ref_id)
              }
              changed = true
            }
          _ => ()
        }
      }
    }
    _ => ()
  }
  if !changed {
    return false
  }
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, replacement)
  removed.push(br_id)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  remove_unused_brs_mark_mutated(ctx, func, "gc-br-on-cleanup")
  true
}

///|
fn remove_unused_brs_match_caught_throw(
  func : @ir.HotFunc,
  throw_tag : Int,
  catchers : Array[Int],
) -> RemoveUnusedBrsCaughtThrowMatch {
  for i = catchers.length() - 1; i >= 0; i = i - 1 {
    let catcher_id = catchers[i]
    if catcher_id < 0 || !@ir.hot_node_is_live(func, catcher_id) {
      continue
    }
    let catcher = @ir.hot_node_get(func, catcher_id)
    match catcher.op {
      @ir.HotOp::Try => return CaughtThrowRef
      @ir.HotOp::TryTable => {
        let info = @ir.hot_catch_info_get(func, catcher.imm1)
        for catch_ in info.catches {
          match catch_ {
            @ir.HotCatchArm::CatchArm(tag_idx, label_id) =>
              if remove_unused_brs_tag_idx_raw(tag_idx) == throw_tag {
                return CaughtThrowExact(label_id)
              }
            @ir.HotCatchArm::CatchRefArm(tag_idx, _) =>
              if remove_unused_brs_tag_idx_raw(tag_idx) == throw_tag {
                return CaughtThrowRef
              }
            @ir.HotCatchArm::CatchAllArm(label_id) =>
              return CaughtThrowAll(label_id)
            @ir.HotCatchArm::CatchAllRefArm(_) => return CaughtThrowRef
          }
        }
      }
      _ => return CaughtThrowRef
    }
  }
  NoCaughtThrowMatch
}

///|
fn remove_unused_brs_try_rewrite_caught_throw_root(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  throw_id : Int,
  catchers : Array[Int],
) -> Bool {
  if !@ir.hot_node_is_live(func, throw_id) {
    return false
  }
  let node = @ir.hot_node_get(func, throw_id)
  match node.op {
    @ir.HotOp::Throw => ()
    _ => return false
  }
  match remove_unused_brs_match_caught_throw(func, node.imm0, catchers) {
    NoCaughtThrowMatch | CaughtThrowRef => false
    CaughtThrowExact(label_id) => {
      let payloads : Array[Int] = []
      for child_idx = 0; child_idx < node.child_count; child_idx = child_idx + 1 {
        payloads.push(@ir.hot_child_get(func, throw_id, child_idx))
      }
      let br = @ir.hot_build_br(func, label_id, values=payloads)
      let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [br])
      remove_unused_brs_delete_unused_nodes(ctx, func, removed)
      true
    }
    CaughtThrowAll(label_id) => {
      let replacement : Array[Int] = []
      for child_idx = 0; child_idx < node.child_count; child_idx = child_idx + 1 {
        let child = @ir.hot_child_get(func, throw_id, child_idx)
        if child >= 0 && @ir.hot_node_is_live(func, child) {
          replacement.push(@ir.hot_build_drop(func, child))
        }
      }
      replacement.push(@ir.hot_build_br(func, label_id))
      let removed = pass_splice_region(
        ctx, func, region_ref, idx, 1, replacement,
      )
      remove_unused_brs_delete_unused_nodes(ctx, func, removed)
      true
    }
  }
}

///|
fn remove_unused_brs_try_rewrite_caught_throws_in_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  catchers : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      remove_unused_brs_try_rewrite_caught_throws_in_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        catchers,
      )
    @ir.HotOp::If => {
      if remove_unused_brs_try_rewrite_caught_throws_in_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, node_id),
          catchers,
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          remove_unused_brs_try_rewrite_caught_throws_in_region(
            ctx, func, else_ref, catchers,
          )
        None => false
      }
    }
    @ir.HotOp::Try => {
      let nested = catchers.copy()
      nested.push(node_id)
      if remove_unused_brs_try_rewrite_caught_throws_in_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, node_id),
          nested,
        ) {
        return true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_ref) =>
          remove_unused_brs_try_rewrite_caught_throws_in_region(
            ctx, func, catch_ref, nested,
          )
        None => false
      }
    }
    @ir.HotOp::TryTable => {
      let nested = catchers.copy()
      nested.push(node_id)
      remove_unused_brs_try_rewrite_caught_throws_in_region(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        nested,
      )
    }
    _ => {
      for child_idx = 0
          child_idx < @ir.hot_child_count(func, node_id)
          child_idx = child_idx + 1 {
        let child = @ir.hot_child_get(func, node_id, child_idx)
        if remove_unused_brs_try_rewrite_caught_throws_in_node(
            ctx, func, child, catchers,
          ) {
          return true
        }
      }
      false
    }
  }
}

///|
fn remove_unused_brs_try_rewrite_caught_throws_in_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  catchers : Array[Int],
) -> Bool {
  let roots : Array[Int] = []
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
  for idx = 0; idx < roots.length(); idx = idx + 1 {
    let node_id = roots[idx]
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let current_idx = remove_unused_brs_find_region_root_index(
      func, region_ref, node_id,
    )
    if current_idx < 0 {
      continue
    }
    if remove_unused_brs_try_rewrite_caught_throw_root(
        ctx, func, region_ref, current_idx, node_id, catchers,
      ) {
      return true
    }
    if remove_unused_brs_try_rewrite_caught_throws_in_node(
        ctx, func, node_id, catchers,
      ) {
      return true
    }
  }
  false
}

///|
fn remove_unused_brs_simplify_dead_local_tees(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Bool {
  let local_reads = @bitset.BitSet::new(@ir.hot_local_count(func))
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalGet =>
        if node.imm0 >= 0 && node.imm0 < local_reads.length() {
          local_reads[node.imm0] = true
        }
      _ => ()
    }
  }

  let candidates : Array[Int] = []
  for root_idx = 0; root_idx < @ir.hot_root_count(func); root_idx = root_idx + 1 {
    let root_id = @ir.hot_root_get(func, root_idx)
    if !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    candidates.push(root_id)
    let root = @ir.hot_node_get(func, root_id)
    match root.op {
      @ir.HotOp::Drop =>
        if root.child_count == 1 {
          candidates.push(@ir.hot_child_get(func, root_id, 0))
        }
      _ => ()
    }
  }

  let detached : Array[Int] = []
  let mut changed = false
  for node_id in candidates {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::LocalTee => {
        let local_id = node.imm0
        if local_id < 0 ||
          local_id >= local_reads.length() ||
          local_reads[local_id] ||
          node.child_count != 1 {
          continue
        }
        let child_id = @ir.hot_child_get(func, node_id, 0)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        @ir.hot_replace_node(func, node_id, @ir.hot_node_get(func, child_id))
        detached.push(child_id)
        changed = true
      }
      _ => ()
    }
  }
  if changed {
    remove_unused_brs_mark_mutated(ctx, func, "simplify-dead-local-tees")
    remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  }
  changed
}

///|
fn remove_unused_brs_mark_mutated(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  reason : String,
) -> Unit {
  ignore(reason)
  pass_mark_mutated(ctx, func)
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
  remove_unused_brs_mark_mutated(ctx, func, "replace-with-nop")
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
  remove_unused_brs_mark_mutated(ctx, func, "replace-with-child")
  remove_unused_brs_delete_unused_nodes(ctx, func, detached)
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
fn remove_unused_brs_selectify_binary_base_cost(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) =>
      if instr == @lib.Instruction::i32_div_s() ||
        instr == @lib.Instruction::i32_div_u() ||
        instr == @lib.Instruction::i32_rem_s() ||
        instr == @lib.Instruction::i32_rem_u() ||
        instr == @lib.Instruction::i64_div_s() ||
        instr == @lib.Instruction::i64_div_u() ||
        instr == @lib.Instruction::i64_rem_s() ||
        instr == @lib.Instruction::i64_rem_u() {
        5
      } else {
        1
      }
    None => 1
  }
}

///|
fn remove_unused_brs_selectify_convert_base_cost(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  match @ir.hot_node_exact_instr(func, node_id) {
    Some(instr) =>
      if instr == @lib.Instruction::i32_trunc_f32s() ||
        instr == @lib.Instruction::i32_trunc_f32u() ||
        instr == @lib.Instruction::i32_trunc_f64s() ||
        instr == @lib.Instruction::i32_trunc_f64u() ||
        instr == @lib.Instruction::i64_trunc_f32s() ||
        instr == @lib.Instruction::i64_trunc_f32u() ||
        instr == @lib.Instruction::i64_trunc_f64s() ||
        instr == @lib.Instruction::i64_trunc_f64u() {
        5
      } else {
        1
      }
    None => 1
  }
}

///|
fn remove_unused_brs_selectify_cost(func : @ir.HotFunc, node_id : Int) -> Int {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return 0
  }
  let node = @ir.hot_node_get(func, node_id)
  let mut cost = match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::Nop => 0
    @ir.HotOp::Binary =>
      remove_unused_brs_selectify_binary_base_cost(func, node_id)
    @ir.HotOp::Convert =>
      remove_unused_brs_selectify_convert_base_cost(func, node_id)
    @ir.HotOp::RefTest | @ir.HotOp::RefTestDesc => 5
    @ir.HotOp::RefCast
    | @ir.HotOp::RefCastDescEq
    | @ir.HotOp::Heap
    | @ir.HotOp::Atomic
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef => 8
    @ir.HotOp::Block => 1
    _ => 1
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    cost += remove_unused_brs_selectify_cost(
      func,
      @ir.hot_child_get(func, node_id, slot),
    )
  }
  match node.op {
    @ir.HotOp::Block => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, body_ref)
          idx = idx + 1 {
        cost += remove_unused_brs_selectify_cost(
          func,
          @ir.hot_region_get(func, body_ref, idx),
        )
      }
    }
    _ => ()
  }
  cost
}

///|
fn remove_unused_brs_selectify_too_costly(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  then_root : Int,
  else_root : Int,
) -> Bool {
  if ctx.shrink_level >= 2 {
    return false
  }
  let then_cost = remove_unused_brs_selectify_cost(func, then_root)
  let else_cost = remove_unused_brs_selectify_cost(func, else_root)
  let max_cost = if then_cost > else_cost { then_cost } else { else_cost }
  if ctx.shrink_level <= 0 {
    max_cost > 4
  } else {
    max_cost >= 8
  }
}

///|
fn remove_unused_brs_build_i32_eqz(func : @ir.HotFunc, operand : Int) -> Int {
  let temp = @ir.hot_build_unary(func, @lib.ValType::i32(), operand)
  @ir.hot_node_exact_instr_set(func, temp, @lib.Instruction::i32_eqz())
  temp
}

///|
fn remove_unused_brs_build_i32_sub(
  func : @ir.HotFunc,
  lhs : Int,
  rhs : Int,
) -> Int {
  let temp = @ir.hot_build_binary(func, @lib.ValType::i32(), lhs, rhs)
  @ir.hot_node_exact_instr_set(func, temp, @lib.Instruction::i32_sub())
  temp
}

///|
fn remove_unused_brs_build_i32_eq(
  func : @ir.HotFunc,
  lhs : Int,
  rhs : Int,
) -> Int {
  let temp = @ir.hot_build_compare(func, lhs, rhs)
  @ir.hot_node_exact_instr_set(func, temp, @lib.Instruction::i32_eq())
  temp
}

///|
fn remove_unused_brs_local_read_mask_resize(
  reads : @bitset.BitSet,
  local_id : Int,
) -> Unit {
  if local_id >= reads.length() {
    reads.grow(local_id + 1)
  }
}

///|
fn remove_unused_brs_mark_local_reads_in_value_expr(
  func : @ir.HotFunc,
  node_id : Int,
  reads : @bitset.BitSet,
) -> Unit {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => {
      let local_id = node.imm0
      if local_id >= 0 {
        remove_unused_brs_local_read_mask_resize(reads, local_id)
        reads[local_id] = true
      }
    }
    @ir.HotOp::If => {
      remove_unused_brs_mark_local_reads_in_value_expr(
        func,
        @ir.hot_child_get(func, node_id, 0),
        reads,
      )
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        remove_unused_brs_mark_local_reads_in_value_expr(
          func,
          @ir.hot_region_get(func, then_ref, idx),
          reads,
        )
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          for idx = 0
              idx < @ir.hot_region_root_count(func, else_ref)
              idx = idx + 1 {
            remove_unused_brs_mark_local_reads_in_value_expr(
              func,
              @ir.hot_region_get(func, else_ref, idx),
              reads,
            )
          }
        None => ()
      }
    }
    _ =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        remove_unused_brs_mark_local_reads_in_value_expr(
          func,
          @ir.hot_child_get(func, node_id, slot),
          reads,
        )
      }
  }
}

///|
fn remove_unused_brs_condition_is_select_safe_over_value_arms(
  func : @ir.HotFunc,
  node_id : Int,
  arm_reads : @bitset.BitSet,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc
    | @ir.HotOp::TableSize
    | @ir.HotOp::Nop
    | @ir.HotOp::Drop
    | @ir.HotOp::Unary
    | @ir.HotOp::Binary
    | @ir.HotOp::Compare
    | @ir.HotOp::Convert
    | @ir.HotOp::Select
    | @ir.HotOp::TupleMake
    | @ir.HotOp::TupleExtract => {
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        if !remove_unused_brs_condition_is_select_safe_over_value_arms(
            func,
            @ir.hot_child_get(func, node_id, slot),
            arm_reads,
          ) {
          return false
        }
      }
      true
    }
    @ir.HotOp::LocalTee => {
      let local_id = node.imm0
      if local_id >= 0 && local_id < arm_reads.length() && arm_reads[local_id] {
        return false
      }
      remove_unused_brs_condition_is_select_safe_over_value_arms(
        func,
        @ir.hot_child_get(func, node_id, 0),
        arm_reads,
      )
    }
    @ir.HotOp::If => {
      if @ir.hot_node_result_arity(func, node_id) != 1 {
        return false
      }
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => else_ref
        None => return false
      }
      if !remove_unused_brs_condition_is_select_safe_over_value_arms(
          func,
          @ir.hot_child_get(func, node_id, 0),
          arm_reads,
        ) {
        return false
      }
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      for idx = 0
          idx < @ir.hot_region_root_count(func, then_ref)
          idx = idx + 1 {
        if !remove_unused_brs_condition_is_select_safe_over_value_arms(
            func,
            @ir.hot_region_get(func, then_ref, idx),
            arm_reads,
          ) {
          return false
        }
      }
      for idx = 0
          idx < @ir.hot_region_root_count(func, else_ref)
          idx = idx + 1 {
        if !remove_unused_brs_condition_is_select_safe_over_value_arms(
            func,
            @ir.hot_region_get(func, else_ref, idx),
            arm_reads,
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
fn remove_unused_brs_match_i32_const_value(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const =>
      match @ir.hot_const_get(func, node.imm0) {
        @ir.HotConstPayload::I32Const(value) => Some(value.0)
        _ => None
      }
    _ => None
  }
}

///|
fn remove_unused_brs_match_br_if_ladder_selector(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => Some((node_id, node.imm0))
    @ir.HotOp::LocalTee =>
      if node.child_count == 1 {
        Some((node_id, node.imm0))
      } else {
        None
      }
    _ => None
  }
}

///|
fn remove_unused_brs_match_br_if_ladder_eq_const(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int)? {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return None
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Unary => {
      if node.child_count != 1 ||
        @ir.hot_node_exact_instr(func, node_id) !=
        Some(@lib.Instruction::i32_eqz()) {
        return None
      }
      return Some((@ir.hot_child_get(func, node_id, 0), 0))
    }
    @ir.HotOp::Compare =>
      if node.child_count != 2 ||
        @ir.hot_node_exact_instr(func, node_id) !=
        Some(@lib.Instruction::i32_eq()) {
        return None
      }
    _ => return None
  }
  let lhs = @ir.hot_child_get(func, node_id, 0)
  let rhs = @ir.hot_child_get(func, node_id, 1)
  match remove_unused_brs_match_i32_const_value(func, rhs) {
    Some(value) => Some((lhs, value))
    None =>
      match remove_unused_brs_match_i32_const_value(func, lhs) {
        Some(value) => Some((rhs, value))
        None => None
      }
  }
}

///|
fn remove_unused_brs_int_array_contains(
  values : Array[Int],
  needle : Int,
) -> Bool {
  for value in values {
    if value == needle {
      return true
    }
  }
  false
}

///|
fn remove_unused_brs_ladder_selector_matches(
  func : @ir.HotFunc,
  selector_id : Int,
  selector_local : Int,
) -> Bool {
  if selector_id < 0 || !@ir.hot_node_is_live(func, selector_id) {
    return false
  }
  let selector = @ir.hot_node_get(func, selector_id)
  match selector.op {
    @ir.HotOp::LocalGet if selector.imm0 == selector_local => true
    _ => false
  }
}

///|
fn remove_unused_brs_try_drop_void_self_branch_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  block_id : Int,
) -> Bool {
  let block_node = @ir.hot_node_get(func, block_id)
  match block_node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if @ir.hot_type_result_arity(func, block_node.ty) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let branch_id = @ir.hot_region_get(func, body_ref, 0)
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::Br => ()
    _ => return false
  }
  if branch_node.child_count != 0 ||
    branch_node.imm0 != @ir.hot_control_node_label(func, block_id) {
    return false
  }
  @ir.hot_region_replace_body(func, body_ref, [])
  remove_unused_brs_delete_unused_nodes(ctx, func, [branch_id])
  remove_unused_brs_mark_mutated(ctx, func, "drop-void-self-branch-block")
  true
}

///|
fn remove_unused_brs_try_fold_constant_br_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let branch_id = @ir.hot_region_get(func, region_ref, idx)
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if branch_node.child_count < 1 {
    return false
  }
  let condition_slot = branch_node.child_count - 1
  let condition = @ir.hot_child_get(func, branch_id, condition_slot)
  let value = match remove_unused_brs_match_i32_const_value(func, condition) {
    Some(value) => value
    None => return false
  }
  let payloads : Array[Int] = []
  for child_idx = 0; child_idx < condition_slot; child_idx = child_idx + 1 {
    let payload = @ir.hot_child_get(func, branch_id, child_idx)
    if payload < 0 || !@ir.hot_node_is_live(func, payload) {
      return false
    }
    payloads.push(payload)
  }
  let replacement = if value == 0 {
    payloads
  } else {
    [@ir.hot_build_br(func, branch_node.imm0, values=payloads)]
  }
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, replacement)
  removed.push(condition)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  remove_unused_brs_mark_mutated(ctx, func, "fold-constant-br-if")
  true
}

///|
fn remove_unused_brs_try_rewrite_br_if_eq_ladder_to_br_table(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let first_branch = @ir.hot_region_get(func, region_ref, idx)
  if first_branch < 0 || !@ir.hot_node_is_live(func, first_branch) {
    return false
  }
  let first_branch_node = @ir.hot_node_get(func, first_branch)
  match first_branch_node.op {
    @ir.HotOp::BrIf => if first_branch_node.child_count != 1 { return false }
    _ => return false
  }
  let first_target = match @ir.hot_branch_target(func, first_branch) {
    Some(label_id) => label_id
    None => return false
  }
  let first_condition = @ir.hot_child_get(func, first_branch, 0)
  let (first_selector, first_const) = match
    remove_unused_brs_match_br_if_ladder_eq_const(func, first_condition) {
    Some(matched) => matched
    None => return false
  }
  let (selector_node, selector_local) = match
    remove_unused_brs_match_br_if_ladder_selector(func, first_selector) {
    Some(matched) => matched
    None => return false
  }
  if first_const < 0 || first_const >= 2147483647 {
    return false
  }

  let branch_ids : Array[Int] = [first_branch]
  let constants : Array[Int] = [first_const]
  let target_labels : Array[Int] = [first_target]
  let mut scan_idx = idx + 1
  while scan_idx < @ir.hot_region_root_count(func, region_ref) {
    let branch_id = @ir.hot_region_get(func, region_ref, scan_idx)
    if branch_id < 0 || !@ir.hot_node_is_live(func, branch_id) {
      break
    }
    let branch_node = @ir.hot_node_get(func, branch_id)
    match branch_node.op {
      @ir.HotOp::BrIf => if branch_node.child_count != 1 { break }
      _ => break
    }
    let target_label = match @ir.hot_branch_target(func, branch_id) {
      Some(label_id) => label_id
      None => break
    }
    let condition = @ir.hot_child_get(func, branch_id, 0)
    let (selector_id, const_value) = match
      remove_unused_brs_match_br_if_ladder_eq_const(func, condition) {
      Some(matched) => matched
      None => break
    }
    if !remove_unused_brs_ladder_selector_matches(
        func, selector_id, selector_local,
      ) {
      break
    }
    if const_value < 0 || const_value >= 2147483647 {
      break
    }
    if remove_unused_brs_int_array_contains(constants, const_value) {
      break
    }
    branch_ids.push(branch_id)
    constants.push(const_value)
    target_labels.push(target_label)
    scan_idx = scan_idx + 1
  }
  if branch_ids.length() < 3 {
    return false
  }

  let mut min_const = constants[0]
  let mut max_const = constants[0]
  for const_value in constants {
    if const_value < min_const {
      min_const = const_value
    }
    if const_value > max_const {
      max_const = const_value
    }
  }
  let range = max_const - min_const
  if range > 1024 || range > branch_ids.length() * 3 {
    return false
  }

  let inner_block = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let inner_label = @ir.hot_control_node_label(func, inner_block)
  let table_targets = Array::make(range + 1, inner_label)
  for i = 0; i < constants.length(); i = i + 1 {
    table_targets[constants[i] - min_const] = target_labels[i]
  }
  let selector = if min_const == 0 {
    selector_node
  } else {
    remove_unused_brs_build_i32_sub(
      func,
      selector_node,
      @ir.hot_build_const_i32(func, @lib.I32(min_const)),
    )
  }
  let br_table = @ir.hot_build_br_table(
    func, table_targets, inner_label, selector,
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, inner_block),
    [br_table],
  )

  let replacement : Array[Int] = []
  let mut nop_count = 0
  while nop_count < branch_ids.length() - 1 {
    replacement.push(@ir.hot_build_nop(func))
    nop_count = nop_count + 1
  }
  replacement.push(inner_block)
  let removed = pass_splice_region(
    ctx,
    func,
    region_ref,
    idx,
    branch_ids.length(),
    replacement,
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_trim_trailing_nops(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  preserve_single_if_arm_nop? : Bool = false,
) -> Bool {
  let mut changed = false
  let initial_root_count = @ir.hot_region_root_count(func, region_ref)
  let preserve_single_root_nop = region_ref == @ir.HotRegionRef::root() &&
    initial_root_count == 1
  let preserve_single_if_arm_nop = preserve_single_if_arm_nop &&
    initial_root_count == 1
  while @ir.hot_region_root_count(func, region_ref) > 0 {
    if preserve_single_root_nop &&
      @ir.hot_region_root_count(func, region_ref) == 1 {
      break
    }
    if preserve_single_if_arm_nop &&
      @ir.hot_region_root_count(func, region_ref) == 1 {
      break
    }
    let idx = @ir.hot_region_root_count(func, region_ref) - 1
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      _ => break
    }
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [])
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
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
fn remove_unused_brs_node_is_nonfallthrough_root(
  func : @ir.HotFunc,
  node_id : Int,
  label_refs : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::If => {
      let else_ref = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) => else_ref
        None => return false
      }
      remove_unused_brs_tail_is_nonfallthrough(
        func,
        @ir.hot_region_then_ref(func, node_id),
      ) &&
      remove_unused_brs_tail_is_nonfallthrough(func, else_ref)
    }
    @ir.HotOp::Block => {
      let label_id = @ir.hot_control_node_label(func, node_id)
      if label_id >= 0 &&
        label_id < label_refs.length() &&
        label_refs[label_id] > 0 {
        return false
      }
      remove_unused_brs_tail_is_nonfallthrough(
        func,
        @ir.hot_region_body_ref(func, node_id),
      )
    }
    _ => {
      let edge_kinds = @ir.cfg_terminator_edge_kinds(node.op)
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
fn remove_unused_brs_root_suffix_required_after_void_structured_terminal(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if @ir.hot_type_result_arity(func, @ir.hot_body_result_type(func)) == 0 {
    return false
  }
  if @ir.hot_node_result_arity(func, node_id) != 0 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => true
    _ => false
  }
}

///|
fn remove_unused_brs_prune_dead_suffix_after_nonfallthrough(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  if region_ref != @ir.HotRegionRef::root() {
    return false
  }
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count <= 1 {
    return false
  }
  for idx = 0; idx < root_count - 1; idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if !remove_unused_brs_node_is_nonfallthrough_root(func, node_id, label_refs) {
      continue
    }
    if remove_unused_brs_root_suffix_required_after_void_structured_terminal(
        func, node_id,
      ) {
      continue
    }
    let replacement = match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => {
        let body_ref = @ir.hot_region_body_ref(func, node_id)
        if @ir.hot_region_root_count(func, body_ref) == 1 {
          let body_root = @ir.hot_region_get(func, body_ref, 0)
          if @ir.hot_node_is_live(func, body_root) {
            match @ir.hot_node_get(func, body_root).op {
              @ir.HotOp::Unreachable => [body_root]
              _ => [node_id]
            }
          } else {
            [node_id]
          }
        } else {
          [node_id]
        }
      }
      _ => [node_id]
    }
    let removed = pass_splice_region(
      ctx,
      func,
      region_ref,
      idx,
      root_count - idx,
      replacement,
    )
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
    return true
  }
  false
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
fn remove_unused_brs_region_roots_are_void_context_safe(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if root_id >= 0 &&
      @ir.hot_node_is_live(func, root_id) &&
      @ir.hot_node_result_arity(func, root_id) != 0 {
      return false
    }
  }
  true
}

///|
fn remove_unused_brs_build_tail_return_if_arm_body(
  func : @ir.HotFunc,
  arm_ref : @ir.HotRegionRef,
  return_arity : Int,
) -> Array[Int]? {
  if remove_unused_brs_tail_is_nonfallthrough(func, arm_ref) {
    if !remove_unused_brs_region_roots_are_void_context_safe(func, arm_ref) {
      return None
    }
    return Some(remove_unused_brs_region_roots(func, arm_ref))
  }
  let (prefix, payload) = match
    @ir.hot_region_split_trailing_payload_roots(func, arm_ref, return_arity) {
    Some(split) => split
    None => return None
  }
  let return_values = match
    remove_unused_brs_expand_payload_children(func, payload, return_arity) {
    Some(values) => values
    None => return None
  }
  let body = prefix.copy()
  body.push(@ir.hot_build_return(func, return_values))
  Some(body)
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
  removed.push(if_id)
  removed.push(then_ref.holder)
  removed.push(else_ref.holder)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
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
  let arm_is_carried_result_wrapper = fn(root_id : Int) -> Bool {
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      return false
    }
    if @ir.hot_node_result_arity(func, root_id) <= 0 {
      return false
    }
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop => true
      _ => false
    }
  }
  if arm_is_carried_result_wrapper(then_root) ||
    arm_is_carried_result_wrapper(else_root) {
    return false
  }
  if @ir.hot_region_single_exit_root(func, then_ref) == None {
    return false
  }
  if @ir.hot_region_single_exit_root(func, else_ref) == None {
    return false
  }
  if !remove_unused_brs_has_safe_exit_only_value_if_use_chain(
      ctx, func, node_id,
    ) {
    return false
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
  @ir.hot_control_demote_if_to_block(func, node_id, [
    void_if,
    @ir.hot_child_get(func, replacement, 1),
  ])
  remove_unused_brs_mark_mutated(
    ctx, func, "rewrite-value-if-single-exit-use-chain",
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    replacement,
    then_ref.holder,
    else_ref.holder,
  ])
  true
}

///|
fn remove_unused_brs_root_use_region_ref(
  func : @ir.HotFunc,
  node_id : Int,
  holder_id : Int,
  slot : Int,
) -> @ir.HotRegionRef? {
  let user = @ir.hot_node_get(func, holder_id)
  for info in @ir.hot_control_region_slot_info(user.op) {
    let region_ref = match info.role {
      @ir.HotControlRegionRole::BodyRegion =>
        Some(@ir.hot_region_body_ref(func, holder_id))
      @ir.HotControlRegionRole::ThenRegion =>
        Some(@ir.hot_region_then_ref(func, holder_id))
      @ir.HotControlRegionRole::ElseRegion =>
        @ir.hot_region_else_ref(func, holder_id)
      @ir.HotControlRegionRole::CatchRegion =>
        @ir.hot_region_catch_ref(func, holder_id)
      @ir.HotControlRegionRole::CatchListRegion =>
        Some(@ir.hot_region_catch_list_ref(func, holder_id))
    }
    match region_ref {
      Some(region_ref) =>
        if slot < @ir.hot_region_root_count(func, region_ref) &&
          @ir.hot_region_get(func, region_ref, slot) == node_id {
          return Some(region_ref)
        }
      None => ()
    }
  }
  None
}

///|
fn remove_unused_brs_has_safe_exit_only_value_if_use_chain(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let use_def = pass_require_use_def(ctx, func)
  let mut current = node_id
  for hops = 0; hops < 64; hops = hops + 1 {
    if @ir.node_use_count(use_def, current) != 1 {
      return false
    }
    let sites = @ir.node_use_sites_borrowed(use_def, current)
    if sites.length() != 1 {
      return false
    }
    let site = sites[0]
    if site.user == -1 {
      return false
    }
    let user = @ir.hot_node_get(func, site.user)
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot =>
        match user.op {
          @ir.HotOp::LocalTee => {
            if site.slot != 0 {
              return false
            }
            current = site.user
          }
          @ir.HotOp::Drop | @ir.HotOp::LocalSet => return site.slot == 0
          @ir.HotOp::Br | @ir.HotOp::Return => return true
          @ir.HotOp::BrIf | @ir.HotOp::BrTable =>
            return site.slot < @ir.hot_child_count(func, site.user) - 1
          _ => return false
        }
      @ir.HotUseSlotKind::RootUseSlot => {
        let region_ref = match
          remove_unused_brs_root_use_region_ref(
            func,
            current,
            site.user,
            site.slot,
          ) {
          Some(region_ref) => region_ref
          None => return false
        }
        if @ir.hot_node_result_arity(func, site.user) != 1 ||
          site.slot != @ir.hot_region_root_count(func, region_ref) - 1 {
          return false
        }
        current = site.user
      }
    }
  }
  false
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
        @ir.HotOp::Return => {
          let result_arity = if region_ref == @ir.HotRegionRef::root() {
            @ir.hot_type_result_arity(func, @ir.hot_body_result_type(func))
          } else {
            @ir.hot_region_result_arity(func, region_ref)
          }
          if result_arity > 0 &&
            region_ref == @ir.HotRegionRef::root() &&
            @ir.hot_region_root_count(func, region_ref) > 1 {
            return false
          }
          if tail.child_count == 0 {
            if result_arity > 0 &&
              @ir.hot_region_root_count(func, region_ref) > result_arity + 1 {
              return false
            }
            let changed = remove_unused_brs_splice_tail_roots(
              ctx,
              func,
              region_ref,
              tail_id,
              [],
            )
            changed
          } else if tail.child_count == 1 {
            rewrite_tail_child(@ir.hot_child_get(func, tail_id, 0))
          } else {
            let changed = remove_unused_brs_splice_tail_with_children(
              ctx, func, region_ref, tail_id,
            )
            changed
          }
        }
        _ => false
      }
    BranchTarget(target) => {
      if tail.child_count > 0 &&
        @ir.hot_region_result_arity(func, region_ref) == 0 {
        return false
      }
      match tail.op {
        @ir.HotOp::Br if tail.imm0 == target => {
          let result_arity = @ir.hot_region_result_arity(func, region_ref)
          if result_arity > 0 && @ir.hot_region_root_count(func, region_ref) > 1 {
            return false
          }
          if tail.child_count == 0 {
            if result_arity == 0 {
              return false
            }
            let changed = remove_unused_brs_splice_tail_roots(
              ctx,
              func,
              region_ref,
              tail_id,
              [],
            )
            changed
          } else if tail.child_count == 1 {
            rewrite_tail_child(@ir.hot_child_get(func, tail_id, 0))
          } else {
            let changed = remove_unused_brs_splice_tail_with_children(
              ctx, func, region_ref, tail_id,
            )
            changed
          }
        }
        _ => false
      }
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
      @ir.hot_split_trailing_payload_roots(
        func, payload_roots, expected_payloads,
      ) {
      Some(_) => Some(expected_payloads)
      None => None
    }
  }
  let child_payloads = fn() -> Int? {
    if tail.child_count > 1 {
      match @ir.hot_node_repeated_live_child(func, tail_id) {
        Some(first_id) =>
          if @ir.hot_node_result_arity(func, first_id) == expected_payloads {
            return Some(expected_payloads)
          }
        None => ()
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
  changed = remove_unused_brs_trim_trailing_nops(
      ctx,
      func,
      then_ref,
      preserve_single_if_arm_nop=true,
    ) ||
    changed
  changed = remove_unused_brs_trim_trailing_nops(
      ctx,
      func,
      else_ref,
      preserve_single_if_arm_nop=true,
    ) ||
    changed
  changed
}

///|
fn remove_unused_brs_region_result_arity(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int? {
  if region_ref == @ir.HotRegionRef::root() {
    return Some(@ir.hot_type_result_arity(func, @ir.hot_body_result_type(func)))
  }
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
  let tail_id = remove_unused_brs_region_tail_id(func, region_ref)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return false
  }
  let tail = @ir.hot_node_get(func, tail_id)
  if expected_payloads > 0 &&
    region_ref == @ir.HotRegionRef::root() &&
    @ir.hot_region_root_count(func, region_ref) > 1 {
    return false
  }
  if expected_payloads > 0 &&
    tail.child_count == 0 &&
    region_ref == @ir.HotRegionRef::root() {
    return false
  }
  if expected_payloads > 0 &&
    tail.child_count == 0 &&
    @ir.hot_region_root_count(func, region_ref) > expected_payloads + 1 {
    return false
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
  let changed = remove_unused_brs_strip_tail_control(
    ctx,
    func,
    region_ref,
    ReturnTarget,
  )
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
      if @ir.hot_node_count(func) >= 256 &&
        !remove_unused_brs_node_is_reorder_safe(
          ctx, func, condition, reorder_cache,
        ) {
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
  @ir.hot_control_demote_if_to_block(func, node_id, [replacement])
  remove_unused_brs_mark_mutated(
    ctx, func, "rewrite-return-child-br_if-to-combined-guard",
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    then_region.holder,
    then_root,
  ])
  true
}

///|
fn remove_unused_brs_try_inline_single_br_if_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if remove_unused_brs_label_is_used(label_refs, block_label) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let body_root = @ir.hot_region_get(func, body_ref, 0)
  match @ir.hot_node_get(func, body_root).op {
    @ir.HotOp::Br | @ir.HotOp::BrIf => ()
    _ => return false
  }
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, [body_root]))
  remove_unused_brs_mark_mutated(ctx, func, "inline-single-br-if-block")
  true
}

///|
fn remove_unused_brs_collect_simple_branches_to_label(
  func : @ir.HotFunc,
  node_id : Int,
  target_label : Int,
  seen : Array[Bool],
  out : Array[Int],
) -> Unit {
  if node_id < 0 || node_id >= seen.length() || seen[node_id] {
    return
  }
  if !@ir.hot_node_is_live(func, node_id) {
    return
  }
  seen[node_id] = true
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => {
      if node.imm0 == target_label && node.child_count == 0 {
        out.push(node_id)
      }
      return
    }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if remove_unused_brs_is_region_child_slot(node.op, slot) {
      continue
    }
    remove_unused_brs_collect_simple_branches_to_label(
      func,
      @ir.hot_child_get(func, node_id, slot),
      target_label,
      seen,
      out,
    )
  }
  let scan_region = fn(region_ref : @ir.HotRegionRef) -> Unit {
    for idx = 0
        idx < @ir.hot_region_root_count(func, region_ref)
        idx = idx + 1 {
      remove_unused_brs_collect_simple_branches_to_label(
        func,
        @ir.hot_region_get(func, region_ref, idx),
        target_label,
        seen,
        out,
      )
    }
  }
  for info in @ir.hot_control_region_slot_info(node.op) {
    match info.role {
      @ir.HotControlRegionRole::BodyRegion =>
        scan_region(@ir.hot_region_body_ref(func, node_id))
      @ir.HotControlRegionRole::ThenRegion =>
        scan_region(@ir.hot_region_then_ref(func, node_id))
      @ir.HotControlRegionRole::ElseRegion =>
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) => scan_region(else_ref)
          None => ()
        }
      @ir.HotControlRegionRole::CatchRegion =>
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) => scan_region(catch_ref)
          None => ()
        }
      @ir.HotControlRegionRole::CatchListRegion =>
        scan_region(@ir.hot_region_catch_list_ref(func, node_id))
    }
  }
}

///|
fn remove_unused_brs_collect_retargetable_branches_to_label(
  func : @ir.HotFunc,
  node_id : Int,
  target_label : Int,
  seen : Array[Bool],
  out : Array[Int],
) -> Unit {
  if node_id < 0 || node_id >= seen.length() || seen[node_id] {
    return
  }
  if !@ir.hot_node_is_live(func, node_id) {
    return
  }
  seen[node_id] = true
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br => return
    @ir.HotOp::BrIf =>
      if node.imm0 == target_label && node.child_count == 1 {
        out.push(node_id)
      }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if remove_unused_brs_is_region_child_slot(node.op, slot) {
      continue
    }
    remove_unused_brs_collect_retargetable_branches_to_label(
      func,
      @ir.hot_child_get(func, node_id, slot),
      target_label,
      seen,
      out,
    )
  }
  let scan_region = fn(region_ref : @ir.HotRegionRef) -> Unit {
    for idx = 0
        idx < @ir.hot_region_root_count(func, region_ref)
        idx = idx + 1 {
      remove_unused_brs_collect_retargetable_branches_to_label(
        func,
        @ir.hot_region_get(func, region_ref, idx),
        target_label,
        seen,
        out,
      )
    }
  }
  for info in @ir.hot_control_region_slot_info(node.op) {
    match info.role {
      @ir.HotControlRegionRole::BodyRegion =>
        scan_region(@ir.hot_region_body_ref(func, node_id))
      @ir.HotControlRegionRole::ThenRegion =>
        scan_region(@ir.hot_region_then_ref(func, node_id))
      @ir.HotControlRegionRole::ElseRegion =>
        match @ir.hot_region_else_ref(func, node_id) {
          Some(else_ref) => scan_region(else_ref)
          None => ()
        }
      @ir.HotControlRegionRole::CatchRegion =>
        match @ir.hot_region_catch_ref(func, node_id) {
          Some(catch_ref) => scan_region(catch_ref)
          None => ()
        }
      @ir.HotControlRegionRole::CatchListRegion =>
        scan_region(@ir.hot_region_catch_list_ref(func, node_id))
    }
  }
}

///|
fn remove_unused_brs_retarget_retargetable_branches(
  func : @ir.HotFunc,
  from_label : Int,
  to_label : Int,
) -> Int {
  if from_label < 0 ||
    to_label < 0 ||
    from_label == to_label ||
    @ir.hot_label_branch_arity(func, from_label) != 0 ||
    @ir.hot_label_branch_arity(func, to_label) != 0 {
    return 0
  }
  let targets : Array[Int] = []
  let seen = Array::make(@ir.hot_node_count(func), false)
  for idx = 0
      idx < @ir.hot_region_root_count(func, @ir.HotRegionRef::root())
      idx = idx + 1 {
    remove_unused_brs_collect_retargetable_branches_to_label(
      func,
      @ir.hot_region_get(func, @ir.HotRegionRef::root(), idx),
      from_label,
      seen,
      targets,
    )
  }
  for target in targets {
    @ir.hot_branch_target_set(func, target, to_label)
  }
  targets.length()
}

///|
fn remove_unused_brs_try_thread_jump_through_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    @ir.hot_label_branch_arity(func, block_label) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count == 1 {
    let child_id = @ir.hot_region_get(func, body_ref, 0)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      return false
    }
    match @ir.hot_node_get(func, child_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, child_id) != 0 {
          return false
        }
      _ => return false
    }
    let child_label = @ir.hot_control_node_label(func, child_id)
    if child_label < 0 ||
      child_label >= label_refs.length() ||
      label_refs[child_label] <= 0 {
      return false
    }
    if remove_unused_brs_retarget_retargetable_branches(
        func, child_label, block_label,
      ) >
      0 {
      remove_unused_brs_mark_mutated(ctx, func, "jump-thread-one-child-block")
      return true
    }
  } else if body_count == 2 {
    let child_id = @ir.hot_region_get(func, body_ref, 0)
    let jump_id = @ir.hot_region_get(func, body_ref, 1)
    if child_id < 0 ||
      jump_id < 0 ||
      !@ir.hot_node_is_live(func, child_id) ||
      !@ir.hot_node_is_live(func, jump_id) {
      return false
    }
    match @ir.hot_node_get(func, child_id).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, child_id) != 0 {
          return false
        }
      _ => return false
    }
    let jump_node = @ir.hot_node_get(func, jump_id)
    match jump_node.op {
      @ir.HotOp::Br if jump_node.child_count == 0 => ()
      _ => return false
    }
    let child_label = @ir.hot_control_node_label(func, child_id)
    let jump_target = match @ir.hot_branch_target(func, jump_id) {
      Some(label_id) => label_id
      None => return false
    }
    if child_label < 0 ||
      child_label >= label_refs.length() ||
      label_refs[child_label] <= 0 {
      return false
    }
    if remove_unused_brs_retarget_retargetable_branches(
        func, child_label, jump_target,
      ) >
      0 {
      remove_unused_brs_mark_mutated(ctx, func, "jump-thread-child-to-jump")
      return true
    }
  }
  false
}

///|
fn remove_unused_brs_try_rewrite_branches_to_trap_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  let trap_id = @ir.hot_region_get(func, region_ref, idx + 1)
  if block_id < 0 ||
    trap_id < 0 ||
    !@ir.hot_node_is_live(func, block_id) ||
    !@ir.hot_node_is_live(func, trap_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_node_get(func, trap_id).op {
    @ir.HotOp::Unreachable => ()
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 || @ir.hot_label_branch_arity(func, block_label) != 0 {
    return false
  }
  let targets : Array[Int] = []
  let seen = Array::make(@ir.hot_node_count(func), false)
  remove_unused_brs_collect_simple_branches_to_label(
    func, block_id, block_label, seen, targets,
  )
  if targets.is_empty() {
    return false
  }
  let detached : Array[Int] = []
  for target in targets {
    if target >= 0 && @ir.hot_node_is_live(func, target) {
      let unreachable_id = @ir.hot_build_unreachable(func)
      detached.push(unreachable_id)
      @ir.hot_replace_node(func, target, @ir.hot_node_get(func, unreachable_id))
    }
  }
  remove_unused_brs_mark_mutated(ctx, func, "rewrite-branch-to-trap")
  remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  true
}

///|
fn remove_unused_brs_switch_selector_can_move_before_values(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  selector : Int,
  values : Array[Int],
  reorder_cache : Array[Int],
) -> Bool {
  if !remove_unused_brs_node_is_reorder_safe(ctx, func, selector, reorder_cache) {
    return false
  }
  match @ir.hot_node_get(func, selector).op {
    @ir.HotOp::Const | @ir.HotOp::LocalGet => ()
    _ => return false
  }
  for value in values {
    if !remove_unused_brs_node_is_reorder_safe(ctx, func, value, reorder_cache) {
      return false
    }
  }
  true
}

///|
fn remove_unused_brs_try_optimize_switch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  reorder_cache : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let br_table_id = @ir.hot_region_get(func, region_ref, idx)
  if br_table_id < 0 || !@ir.hot_node_is_live(func, br_table_id) {
    return false
  }
  let node = @ir.hot_node_get(func, br_table_id)
  match node.op {
    @ir.HotOp::BrTable => ()
    _ => return false
  }
  let stack_selector = node.child_count == 0
  if stack_selector && idx == 0 {
    return false
  }

  let default_target = @ir.hot_branch_table_default_target(func, node.imm0)
  let mut targets = @ir.hot_branch_table_targets(func, node.imm0).copy()
  let original_targets_len = targets.length()
  while targets.length() > 0 && targets[targets.length() - 1] == default_target {
    ignore(targets.pop())
  }
  let mut leading_defaults = 0
  while leading_defaults < targets.length() &&
        targets[leading_defaults] == default_target {
    leading_defaults = leading_defaults + 1
  }
  if leading_defaults > 0 {
    let shifted : Array[Int] = []
    for i = leading_defaults; i < targets.length(); i = i + 1 {
      shifted.push(targets[i])
    }
    targets = shifted
  }

  let selector_slot = node.child_count - 1
  let selector = if stack_selector {
    @ir.hot_region_get(func, region_ref, idx - 1)
  } else {
    @ir.hot_child_get(func, br_table_id, selector_slot)
  }
  let values : Array[Int] = []
  if !stack_selector {
    for i = 0; i < selector_slot; i = i + 1 {
      let value = @ir.hot_child_get(func, br_table_id, i)
      if value < 0 || !@ir.hot_node_is_live(func, value) {
        return false
      }
      values.push(value)
    }
  }
  let default_arity = @ir.hot_label_branch_arity(func, default_target)
  let value_carrying = values.length() > 0 || default_arity != 0
  if stack_selector && value_carrying {
    // Child-less value-carrying br_table forms would need stack-payload root
    // surgery around the selector. Keep that uncommon local shape conservative;
    // ordinary lifted value switches carry payloads as br_table children.
    return false
  }
  for target in targets {
    if @ir.hot_label_branch_arity(func, target) != default_arity {
      return false
    }
  }

  let mut condition = selector
  if leading_defaults > 0 {
    condition = remove_unused_brs_build_i32_sub(
      func,
      condition,
      @ir.hot_build_const_i32(func, @lib.I32(leading_defaults)),
    )
  }

  if value_carrying {
    if targets.length() == 0 &&
      remove_unused_brs_switch_selector_can_move_before_values(
        ctx, func, condition, values, reorder_cache,
      ) {
      let drop_selector = @ir.hot_build_drop(func, condition)
      let br = @ir.hot_build_br(func, default_target, values~)
      let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
        drop_selector, br,
      ])
      let detached : Array[Int] = [block]
      @ir.hot_replace_node(func, br_table_id, @ir.hot_node_get(func, block))
      remove_unused_brs_delete_unused_nodes(ctx, func, detached)
      remove_unused_brs_mark_mutated(
        ctx, func, "optimize-switch-one-target-value",
      )
      return true
    }
    if targets.length() != original_targets_len || leading_defaults > 0 {
      let replacement = @ir.hot_build_br_table(
        func,
        targets,
        default_target,
        condition,
        values~,
      )
      let detached : Array[Int] = [replacement]
      @ir.hot_replace_node(
        func,
        br_table_id,
        @ir.hot_node_get(func, replacement),
      )
      remove_unused_brs_delete_unused_nodes(ctx, func, detached)
      remove_unused_brs_mark_mutated(ctx, func, "optimize-switch-value-targets")
      return true
    }
    return false
  }

  if targets.length() == 0 {
    let drop_selector = @ir.hot_build_drop(func, condition)
    let br = @ir.hot_build_br(func, default_target)
    let block = @ir.hot_build_block(func, @lib.BlockType::void_(), [
      drop_selector, br,
    ])
    if stack_selector {
      ignore(@ir.hot_region_splice(func, region_ref, idx - 1, 2, [block]))
    } else {
      let detached : Array[Int] = [block]
      @ir.hot_replace_node(func, br_table_id, @ir.hot_node_get(func, block))
      remove_unused_brs_delete_unused_nodes(ctx, func, detached)
    }
    remove_unused_brs_mark_mutated(ctx, func, "optimize-switch-default-only")
    return true
  }

  if targets.length() == 1 {
    let if_ = @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      condition,
      [@ir.hot_build_br(func, default_target)],
      else_body=Some([@ir.hot_build_br(func, targets[0])]),
    )
    if stack_selector {
      ignore(@ir.hot_region_splice(func, region_ref, idx - 1, 2, [if_]))
    } else {
      let detached : Array[Int] = [if_]
      @ir.hot_replace_node(func, br_table_id, @ir.hot_node_get(func, if_))
      remove_unused_brs_delete_unused_nodes(ctx, func, detached)
    }
    remove_unused_brs_mark_mutated(ctx, func, "optimize-switch-two-options")
    return true
  }

  let min_shrink = 13
  let threshold_met = targets.length() >= min_shrink
  if !threshold_met {
    if targets.length() != original_targets_len || leading_defaults > 0 {
      let replacement = @ir.hot_build_br_table(
        func, targets, default_target, condition,
      )
      if stack_selector {
        ignore(
          @ir.hot_region_splice(func, region_ref, idx - 1, 2, [replacement]),
        )
      } else {
        let detached : Array[Int] = [replacement]
        @ir.hot_replace_node(
          func,
          br_table_id,
          @ir.hot_node_get(func, replacement),
        )
        remove_unused_brs_delete_unused_nodes(ctx, func, detached)
      }
      remove_unused_brs_mark_mutated(ctx, func, "optimize-switch-trim-targets")
      return true
    }
    return false
  }
  for i = 1; i < targets.length() - 1; i = i + 1 {
    if targets[i] != default_target {
      return false
    }
  }

  let temp = @ir.hot_append_body_local(func, @lib.ValType::i32())
  let tee = @ir.hot_build_local_tee(func, temp, condition)
  let last_eq = remove_unused_brs_build_i32_eq(
    func,
    @ir.hot_build_local_get(func, temp),
    @ir.hot_build_const_i32(func, @lib.I32(targets.length() - 1)),
  )
  let inner_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    last_eq,
    [@ir.hot_build_br(func, targets[targets.length() - 1])],
    else_body=Some([@ir.hot_build_br(func, default_target)]),
  )
  let outer_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    tee,
    [inner_if],
    else_body=Some([@ir.hot_build_br(func, targets[0])]),
  )
  if stack_selector {
    ignore(@ir.hot_region_splice(func, region_ref, idx - 1, 2, [outer_if]))
  } else {
    let detached : Array[Int] = [outer_if]
    @ir.hot_replace_node(func, br_table_id, @ir.hot_node_get(func, outer_if))
    remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  }
  remove_unused_brs_mark_mutated(ctx, func, "optimize-switch-large-default-run")
  true
}

///|
fn remove_unused_brs_try_drop_self_targeting_br_table_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    @ir.hot_label_branch_arity(func, block_label) != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let br_table_id = @ir.hot_region_get(func, body_ref, 0)
  if br_table_id < 0 || !@ir.hot_node_is_live(func, br_table_id) {
    return false
  }
  let br_table_node = @ir.hot_node_get(func, br_table_id)
  match br_table_node.op {
    @ir.HotOp::BrTable => if br_table_node.child_count != 1 { return false }
    _ => return false
  }
  let targets = @ir.hot_branch_table_targets(func, br_table_node.imm0)
  for target in targets {
    if target != block_label {
      return false
    }
  }
  if @ir.hot_branch_table_default_target(func, br_table_node.imm0) !=
    block_label {
    return false
  }
  let expected_refs = targets.length() + 1
  if label_refs[block_label] != expected_refs {
    return false
  }

  let selector = @ir.hot_child_get(func, br_table_id, 0)
  if selector < 0 || !@ir.hot_node_is_live(func, selector) {
    return false
  }
  let replacement = @ir.hot_build_drop(func, selector)
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [replacement])
  removed.push(replacement)
  remove_unused_brs_mark_mutated(
    ctx, func, "drop-self-targeting-br-table-block",
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_condition_is_safe_to_speculate(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Const
    | @ir.HotOp::LocalGet
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::MemorySize
    | @ir.HotOp::TableSize
    | @ir.HotOp::RefNull
    | @ir.HotOp::RefIsNull
    | @ir.HotOp::RefFunc => true
    @ir.HotOp::Unary | @ir.HotOp::Compare => {
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !remove_unused_brs_condition_is_safe_to_speculate(
            func,
            @ir.hot_child_get(func, node_id, slot),
          ) {
          return false
        }
      }
      true
    }
    @ir.HotOp::Binary => {
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(
          @lib.Instruction::I32Add
          | @lib.Instruction::I32Sub
          | @lib.Instruction::I32Mul
          | @lib.Instruction::I32And
          | @lib.Instruction::I32Or
          | @lib.Instruction::I32Xor
          | @lib.Instruction::I32Shl
          | @lib.Instruction::I32ShrS
          | @lib.Instruction::I32ShrU
          | @lib.Instruction::I32Rotl
          | @lib.Instruction::I32Rotr
          | @lib.Instruction::I64Add
          | @lib.Instruction::I64Sub
          | @lib.Instruction::I64Mul
          | @lib.Instruction::I64And
          | @lib.Instruction::I64Or
          | @lib.Instruction::I64Xor
          | @lib.Instruction::I64Shl
          | @lib.Instruction::I64ShrS
          | @lib.Instruction::I64ShrU
          | @lib.Instruction::I64Rotl
          | @lib.Instruction::I64Rotr
        ) => ()
        _ => return false
      }
      for slot = 0; slot < node.child_count; slot = slot + 1 {
        if !remove_unused_brs_condition_is_safe_to_speculate(
            func,
            @ir.hot_child_get(func, node_id, slot),
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
fn remove_unused_brs_try_merge_adjacent_br_ifs(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if ctx.shrink_level <= 0 ||
    idx < 0 ||
    idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let br1 = @ir.hot_region_get(func, region_ref, idx)
  let br2 = @ir.hot_region_get(func, region_ref, idx + 1)
  if br1 < 0 ||
    br2 < 0 ||
    !@ir.hot_node_is_live(func, br1) ||
    !@ir.hot_node_is_live(func, br2) {
    return false
  }
  let br1_node = @ir.hot_node_get(func, br1)
  match br1_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }

  if br1_node.child_count == 0 &&
    idx > 0 &&
    idx + 2 < @ir.hot_region_root_count(func, region_ref) {
    let cond1 = @ir.hot_region_get(func, region_ref, idx - 1)
    let cond2 = @ir.hot_region_get(func, region_ref, idx + 1)
    let br2 = @ir.hot_region_get(func, region_ref, idx + 2)
    if cond1 < 0 ||
      cond2 < 0 ||
      br2 < 0 ||
      !@ir.hot_node_is_live(func, cond1) ||
      !@ir.hot_node_is_live(func, cond2) ||
      !@ir.hot_node_is_live(func, br2) {
      return false
    }
    let br2_node = @ir.hot_node_get(func, br2)
    match br2_node.op {
      @ir.HotOp::BrIf => ()
      _ => return false
    }
    if br2_node.child_count != 0 ||
      @ir.hot_branch_target(func, br1) != @ir.hot_branch_target(func, br2) ||
      !remove_unused_brs_condition_is_safe_to_speculate(func, cond2) {
      return false
    }
    let target = match @ir.hot_branch_target(func, br1) {
      Some(label) => label
      None => return false
    }
    let merged = @ir.hot_build_binary(func, @lib.ValType::i32(), cond1, cond2)
    @ir.hot_node_exact_instr_set(func, merged, @lib.Instruction::i32_or())
    let branch = @ir.hot_build_br_if(func, target, merged)
    let removed = pass_splice_region(ctx, func, region_ref, idx - 1, 4, [branch])
    remove_unused_brs_mark_mutated(ctx, func, "merge-adjacent-stack-br-if-or")
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
    return true
  }

  let br2_node = @ir.hot_node_get(func, br2)
  match br2_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if br1_node.child_count != 1 ||
    br2_node.child_count != 1 ||
    @ir.hot_branch_target(func, br1) != @ir.hot_branch_target(func, br2) {
    return false
  }
  let cond1 = @ir.hot_child_get(func, br1, 0)
  let cond2 = @ir.hot_child_get(func, br2, 0)
  if !remove_unused_brs_condition_is_safe_to_speculate(func, cond2) {
    return false
  }

  let merged = @ir.hot_build_binary(func, @lib.ValType::i32(), cond1, cond2)
  @ir.hot_node_exact_instr_set(func, merged, @lib.Instruction::i32_or())
  @ir.hot_child_set(func, br1, 0, merged)
  let removed = pass_splice_region(ctx, func, region_ref, idx + 1, 1, [])
  remove_unused_brs_mark_mutated(ctx, func, "merge-adjacent-br-if-or")
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_try_rewrite_br_table_continuation_wrappers(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let outer_block = @ir.hot_region_get(func, region_ref, idx)
  if outer_block < 0 || !@ir.hot_node_is_live(func, outer_block) {
    return false
  }
  match @ir.hot_node_get(func, outer_block).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, outer_block) != 0 {
        return false
      }
    _ => return false
  }
  let outer_body = @ir.hot_region_body_ref(func, outer_block)
  if @ir.hot_region_root_count(func, outer_body) < 2 {
    return false
  }
  let outer_tail = @ir.hot_region_get(
    func,
    outer_body,
    @ir.hot_region_root_count(func, outer_body) - 1,
  )
  if outer_tail < 0 || !@ir.hot_node_is_live(func, outer_tail) {
    return false
  }
  match @ir.hot_node_get(func, outer_tail).op {
    @ir.HotOp::Br =>
      if @ir.hot_node_get(func, outer_tail).child_count == 0 {
        return false
      }
    _ => return false
  }

  let wrapper_blocks : Array[Int] = []
  let wrapper_tails : Array[Int] = []
  let forwarded_labels : Array[Int] = []
  let forwarded_label_uses : Array[Int] = []
  let mut outer_target : Int? = None
  let mut current = @ir.hot_region_get(func, outer_body, 0)
  while true {
    if current < 0 || !@ir.hot_node_is_live(func, current) {
      return false
    }
    match @ir.hot_node_get(func, current).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, current) != 0 {
          break
        }
      _ => break
    }
    let current_body = @ir.hot_region_body_ref(func, current)
    if @ir.hot_region_root_count(func, current_body) != 2 {
      break
    }
    let child_block = @ir.hot_region_get(func, current_body, 0)
    if child_block < 0 || !@ir.hot_node_is_live(func, child_block) {
      return false
    }
    match @ir.hot_node_get(func, child_block).op {
      @ir.HotOp::Block =>
        if @ir.hot_node_result_arity(func, child_block) != 0 {
          return false
        }
      _ => return false
    }
    let tail_id = @ir.hot_region_get(func, current_body, 1)
    if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
      return false
    }
    let tail_node = @ir.hot_node_get(func, tail_id)
    match tail_node.op {
      @ir.HotOp::Br => if tail_node.child_count != 0 { return false }
      _ => return false
    }
    if @ir.hot_label_branch_arity(func, tail_node.imm0) != 0 {
      return false
    }
    match outer_target {
      Some(saved) => if saved != tail_node.imm0 { return false }
      None => outer_target = Some(tail_node.imm0)
    }
    wrapper_blocks.push(current)
    wrapper_tails.push(tail_id)
    forwarded_labels.push(@ir.hot_control_node_label(func, child_block))
    forwarded_label_uses.push(0)
    current = child_block
  }
  let outer_target = match outer_target {
    Some(target) => target
    None => return false
  }
  if wrapper_blocks.is_empty() ||
    @ir.hot_label_branch_arity(func, outer_target) != 0 {
    return false
  }
  let leaf_block = current
  if leaf_block < 0 || !@ir.hot_node_is_live(func, leaf_block) {
    return false
  }
  match @ir.hot_node_get(func, leaf_block).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, leaf_block) != 0 {
        return false
      }
    _ => return false
  }
  let leaf_body = @ir.hot_region_body_ref(func, leaf_block)
  if @ir.hot_region_root_count(func, leaf_body) != 1 {
    return false
  }
  let br_table_id = @ir.hot_region_get(func, leaf_body, 0)
  if br_table_id < 0 || !@ir.hot_node_is_live(func, br_table_id) {
    return false
  }
  let br_table_node = @ir.hot_node_get(func, br_table_id)
  match br_table_node.op {
    @ir.HotOp::BrTable => if br_table_node.child_count != 1 { return false }
    _ => return false
  }

  let rewritten_targets = @ir.hot_branch_table_targets(func, br_table_node.imm0).copy()
  let mut rewritten_default = @ir.hot_branch_table_default_target(
    func,
    br_table_node.imm0,
  )
  let mut rewrote_any = false
  for idx = 0; idx < rewritten_targets.length(); idx = idx + 1 {
    let target = rewritten_targets[idx]
    for label_idx = 0
        label_idx < forwarded_labels.length()
        label_idx = label_idx + 1 {
      if target == forwarded_labels[label_idx] {
        rewritten_targets[idx] = outer_target
        forwarded_label_uses[label_idx] = forwarded_label_uses[label_idx] + 1
        rewrote_any = true
        break
      }
    }
  }
  for label_idx = 0
      label_idx < forwarded_labels.length()
      label_idx = label_idx + 1 {
    if rewritten_default == forwarded_labels[label_idx] {
      rewritten_default = outer_target
      forwarded_label_uses[label_idx] = forwarded_label_uses[label_idx] + 1
      rewrote_any = true
      break
    }
  }
  if !rewrote_any {
    return false
  }
  for label_idx = 0
      label_idx < forwarded_labels.length()
      label_idx = label_idx + 1 {
    let label = forwarded_labels[label_idx]
    if label < 0 ||
      label >= label_refs.length() ||
      label_refs[label] != forwarded_label_uses[label_idx] {
      return false
    }
  }

  let selector = @ir.hot_child_get(
    func,
    br_table_id,
    br_table_node.child_count - 1,
  )
  let replacement = @ir.hot_build_br_table(
    func, rewritten_targets, rewritten_default, selector,
  )
  let detached : Array[Int] = [replacement]
  @ir.hot_replace_node(func, br_table_id, @ir.hot_node_get(func, replacement))
  for tail_id in wrapper_tails {
    let unreachable_id = @ir.hot_build_unreachable(func)
    detached.push(unreachable_id)
    @ir.hot_replace_node(func, tail_id, @ir.hot_node_get(func, unreachable_id))
  }
  remove_unused_brs_mark_mutated(
    ctx, func, "rewrite-br-table-continuation-wrappers",
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, detached)
  (ctx.trace)(
    "rub-br-table-forward rewrite block=\{outer_block} wrappers=\{wrapper_blocks.length()} target=\{outer_target}",
  )
  true
}

///|
fn remove_unused_brs_match_value_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  reorder_cache : Array[Int],
  allow_nonreorder_condition_with_reorder_safe_arms? : Bool = false,
  apply_selectify_cost_model? : Bool = false,
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
  if apply_selectify_cost_model &&
    remove_unused_brs_selectify_too_costly(ctx, func, then_root, else_root) {
    return None
  }
  if !remove_unused_brs_node_is_reorder_safe(
      ctx, func, condition, reorder_cache,
    ) {
    let mut safe_nonreorder_condition = allow_nonreorder_condition_with_reorder_safe_arms
    if !safe_nonreorder_condition {
      let arm_reads = @bitset.BitSet::new(0)
      remove_unused_brs_mark_local_reads_in_value_expr(
        func, then_root, arm_reads,
      )
      remove_unused_brs_mark_local_reads_in_value_expr(
        func, else_root, arm_reads,
      )
      safe_nonreorder_condition = remove_unused_brs_condition_is_select_safe_over_value_arms(
        func, condition, arm_reads,
      )
    }
    if !safe_nonreorder_condition {
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
fn remove_unused_brs_replace_unused_if_with_value_expr(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  if_id : Int,
  replacement_id : Int,
  detached_holders : Array[Int],
) -> Bool {
  if if_id < 0 ||
    !@ir.hot_node_is_live(func, if_id) ||
    replacement_id < 0 ||
    !@ir.hot_node_is_live(func, replacement_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  let block_children : Array[Int] = [replacement_id]
  for holder_id in detached_holders {
    if holder_id < 0 || !@ir.hot_node_is_live(func, holder_id) {
      continue
    }
    ignore(@ir.hot_replace_child_span(func, holder_id, []))
    block_children.push(holder_id)
  }
  @ir.hot_control_demote_if_to_block(func, if_id, block_children)
  remove_unused_brs_mark_mutated(ctx, func, "replace-unused-if-with-value-expr")
  true
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
      ctx,
      func,
      node_id,
      reorder_cache,
      apply_selectify_cost_model=true,
    ) {
    Some(rewrite) =>
      remove_unused_brs_replace_unused_if_with_value_expr(
        ctx,
        func,
        node_id,
        rewrite.replacement,
        [rewrite.then_holder, rewrite.else_holder],
      )
    None => false
  }
}

///|
fn remove_unused_brs_try_rewrite_condition_child_value_if_to_select(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  owner_id : Int,
  reorder_cache : Array[Int],
) -> Bool {
  let owner = @ir.hot_node_get(func, owner_id)
  match owner.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, owner_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, owner_id) {
    Some(_) => return false
    None => ()
  }
  if owner.child_count == 0 {
    return false
  }
  let condition_id = @ir.hot_child_get(func, owner_id, 0)
  if condition_id < 0 || !@ir.hot_node_is_live(func, condition_id) {
    return false
  }
  match @ir.hot_node_get(func, condition_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  match
    remove_unused_brs_match_value_if_to_select(
      ctx,
      func,
      condition_id,
      reorder_cache,
      allow_nonreorder_condition_with_reorder_safe_arms=true,
    ) {
    Some(rewrite) =>
      remove_unused_brs_replace_unused_if_with_value_expr(
        ctx,
        func,
        condition_id,
        rewrite.replacement,
        [rewrite.then_holder, rewrite.else_holder],
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
  @ir.hot_child_set(func, node_id, 0, combined)
  @ir.hot_region_replace_body(func, then_ref, child_then_roots)
  @ir.hot_region_replace_body(func, child_then_ref, [])
  remove_unused_brs_mark_mutated(ctx, func, "merge-nested-if-conditions")
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
  let is_tee = match node.op {
    @ir.HotOp::LocalSet => false
    @ir.HotOp::LocalTee => true
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
  let then_node = @ir.hot_node_get(func, then_root)
  let else_node = @ir.hot_node_get(func, else_root)
  let (set_value, copy_root, condition) = match then_node.op {
    @ir.HotOp::LocalGet if then_node.imm0 == node.imm0 =>
      (
        else_root,
        then_root,
        remove_unused_brs_build_i32_eqz(
          func,
          @ir.hot_child_get(func, value_id, 0),
        ),
      )
    _ =>
      match else_node.op {
        @ir.HotOp::LocalGet if else_node.imm0 == node.imm0 =>
          (then_root, else_root, @ir.hot_child_get(func, value_id, 0))
        _ => return false
      }
  }
  let replacement_set = @ir.hot_build_local_set(func, node.imm0, set_value)
  let replacement_if = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [replacement_set],
  )
  let replacements = if is_tee {
    let results = @ir.hot_type_results(func, @ir.hot_node_type(func, node_id))
    if results.length() != 1 {
      return false
    }
    let replacement_get = @ir.hot_build_local_get(func, node.imm0)
    let block = @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(results[0]),
      [replacement_if, replacement_get],
    )
    [block]
  } else {
    [replacement_if]
  }
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, replacements)
  removed.push(value_id)
  removed.push(then_ref.holder)
  removed.push(else_ref.holder)
  removed.push(copy_root)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
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
  let is_tee = match node.op {
    @ir.HotOp::LocalSet => false
    @ir.HotOp::LocalTee => true
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
  let condition_id = @ir.hot_child_get(func, value_id, 0)
  let (branch_root, branch_target, set_value, condition) = match
    @ir.hot_region_single_plain_br_root(func, then_ref) {
    Some(then_root) => {
      let then_target = match
        @ir.hot_region_single_plain_br_target(func, then_ref) {
        Some(then_target) => then_target
        None => return false
      }
      (
        then_root,
        then_target,
        @ir.hot_region_get(func, else_ref, 0),
        condition_id,
      )
    }
    None => {
      let else_root = match
        @ir.hot_region_single_plain_br_root(func, else_ref) {
        Some(else_root) => else_root
        None => return false
      }
      let else_target = match
        @ir.hot_region_single_plain_br_target(func, else_ref) {
        Some(else_target) => else_target
        None => return false
      }
      (
        else_root,
        else_target,
        @ir.hot_region_get(func, then_ref, 0),
        remove_unused_brs_build_i32_eqz(func, condition_id),
      )
    }
  }
  let branch = @ir.hot_build_br_if(func, branch_target, condition)
  let replacement_store = if is_tee {
    @ir.hot_build_local_tee(func, node.imm0, set_value)
  } else {
    @ir.hot_build_local_set(func, node.imm0, set_value)
  }
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
    branch, replacement_store,
  ])
  removed.push(value_id)
  removed.push(then_ref.holder)
  removed.push(else_ref.holder)
  removed.push(branch_root)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
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
  let then_root = match @ir.hot_region_single_plain_br_root(func, then_ref) {
    Some(then_root) => then_root
    None => return false
  }
  let else_root = match @ir.hot_region_single_plain_br_root(func, else_ref) {
    Some(else_root) => else_root
    None => return false
  }
  let then_target = match
    @ir.hot_region_single_plain_br_target(func, then_ref) {
    Some(then_target) => then_target
    None => return false
  }
  let else_target = match
    @ir.hot_region_single_plain_br_target(func, else_ref) {
    Some(else_target) => else_target
    None => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if then_target == if_label || else_target == if_label {
    return false
  }
  if then_target == else_target {
    let replacement = @ir.hot_build_br(func, then_target)
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
      replacement,
    ])
    removed.push(if_id)
    removed.push(then_ref.holder)
    removed.push(then_root)
    removed.push(else_ref.holder)
    removed.push(else_root)
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
    return true
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  let branch_if = @ir.hot_build_br_if(func, then_target, condition)
  let branch = @ir.hot_build_br(func, else_target)
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
    branch_if, branch,
  ])
  remove_unused_brs_delete_unused_nodes(
    ctx,
    func,
    removed + [if_id, then_ref.holder, then_root, else_ref.holder, else_root],
  )
  true
}

///|
fn remove_unused_brs_try_rewrite_one_arm_payload_branch_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
  func_has_br_table : Bool,
) -> Bool {
  if func_has_br_table {
    return false
  }
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let try_build = fn(
    branch_ref : @ir.HotRegionRef,
    body_ref : @ir.HotRegionRef,
    negate_condition : Bool,
  ) -> Bool {
    let branch_root = match @ir.hot_region_single_live_root(func, branch_ref) {
      Some(branch_root) => branch_root
      None => return false
    }
    let branch_node = @ir.hot_node_get(func, branch_root)
    match branch_node.op {
      @ir.HotOp::Br => if branch_node.child_count == 0 { return false }
      _ => return false
    }
    let target = match @ir.hot_branch_target(func, branch_root) {
      Some(target) => target
      None => return false
    }
    if target == if_label {
      return false
    }
    match @ir.hot_region_holder_block_root(func, region_ref) {
      Some(holder) =>
        if idx == 0 &&
          @ir.hot_node_result_arity(func, holder) == 1 &&
          @ir.hot_region_root_count(func, body_ref) == 0 &&
          @ir.hot_region_root_count(func, region_ref) >= 2 &&
          target == @ir.hot_control_node_label(func, holder) {
          return false
        }
      None => ()
    }
    if @ir.hot_label_branch_arity(func, target) != 1 {
      return false
    }
    let payloads : Array[Int] = []
    for child_idx = 0
        child_idx < @ir.hot_child_count(func, branch_root)
        child_idx = child_idx + 1 {
      let child_id = @ir.hot_child_get(func, branch_root, child_idx)
      if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
        return false
      }
      payloads.push(child_id)
    }
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, condition)
    } else {
      condition
    }
    let guard_branch = @ir.hot_build_br_if(
      func,
      target,
      guard_condition,
      values=payloads,
    )
    let dropped_guard = @ir.hot_build_drop(func, guard_branch)
    let replacement = [dropped_guard]
    for root_idx = 0
        root_idx < @ir.hot_region_root_count(func, body_ref)
        root_idx = root_idx + 1 {
      replacement.push(@ir.hot_region_get(func, body_ref, root_idx))
    }
    ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
    remove_unused_brs_delete_unused_nodes(ctx, func, [
      if_id,
      then_ref.holder,
      else_ref.holder,
      branch_root,
    ])
    true
  }
  if try_build(then_ref, else_ref, false) {
    return true
  }
  try_build(else_ref, then_ref, true)
}

///|
fn remove_unused_brs_try_rewrite_prefixed_one_arm_payload_branch_if_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
  reorder_cache : Array[Int],
) -> Bool {
  if @ir.hot_region_result_arity(func, region_ref) != 1 {
    return false
  }
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if idx <= 0 || idx >= root_count - 1 {
    return false
  }
  let holder = match @ir.hot_region_holder_block_root(func, region_ref) {
    Some(holder) => holder
    None => return false
  }
  if @ir.hot_node_result_arity(func, holder) != 1 {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(_) => return false
    None => ()
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let target = @ir.hot_control_node_label(func, holder)
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let result_type = @ir.hot_type_results(func, @ir.hot_node_type(func, holder))[0]
  let payload_value = match
    remove_unused_brs_build_stack_exit_region_value_expr(
      ctx,
      func,
      then_ref,
      BranchTarget(target),
      result_type,
      reorder_cache,
    ) {
    Some(payload_value) => payload_value
    None => return false
  }
  let guard_branch = @ir.hot_build_br_if(
    func,
    target,
    @ir.hot_child_get(func, if_id, 0),
    values=[payload_value],
  )
  let dropped_guard = @ir.hot_build_drop(func, guard_branch)
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, [dropped_guard]))
  remove_unused_brs_delete_unused_nodes(ctx, func, [if_id, then_ref.holder])
  true
}

///|
fn remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
  branch_payload_children : @bitset.BitSet,
) -> Bool {
  let holder = match @ir.hot_region_holder_block_root(func, region_ref) {
    Some(holder) => holder
    None => return false
  }
  if @ir.hot_node_result_arity(func, holder) <= 0 ||
    @ir.hot_region_root_count(func, region_ref) <= 1 {
    return false
  }
  let inner_id = @ir.hot_region_get(func, region_ref, 0)
  if inner_id < 0 || !@ir.hot_node_is_live(func, inner_id) {
    return false
  }
  match @ir.hot_node_get(func, inner_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, inner_id) != 0 {
        (ctx.trace)(
          "rub-result-prefix reject=inner-result block=\{inner_id} holder=\{holder}",
        )
        return false
      }
    _ => {
      (ctx.trace)(
        "rub-result-prefix reject=inner-op block=\{inner_id} op=\{@ir.hot_node_get(func, inner_id).op}",
      )
      return false
    }
  }
  let inner_body_ref = @ir.hot_region_body_ref(func, inner_id)
  let inner_root_count = @ir.hot_region_root_count(func, inner_body_ref)
  if inner_root_count < 2 {
    return false
  }
  let guard_id = @ir.hot_region_get(func, inner_body_ref, 0)
  let branch_id = @ir.hot_region_get(func, inner_body_ref, inner_root_count - 1)
  if guard_id < 0 ||
    branch_id < 0 ||
    !@ir.hot_node_is_live(func, guard_id) ||
    !@ir.hot_node_is_live(func, branch_id) {
    return false
  }
  let guard_node = @ir.hot_node_get(func, guard_id)
  match guard_node.op {
    @ir.HotOp::BrIf => if guard_node.child_count != 1 { return false }
    _ => return false
  }
  let inner_label = @ir.hot_control_node_label(func, inner_id)
  if inner_label < 0 || inner_label >= label_refs.length() {
    return false
  }
  if @ir.hot_branch_target(func, guard_id) != Some(inner_label) {
    (ctx.trace)(
      "rub-result-prefix reject=guard-target inner=\{inner_id} guard=\{guard_id}",
    )
    return false
  }
  let outer_label = @ir.hot_control_node_label(func, holder)
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::Br =>
      if branch_node.child_count !=
        @ir.hot_label_branch_arity(func, outer_label) {
        (ctx.trace)(
          "rub-result-prefix reject=branch-arity holder=\{holder} inner=\{inner_id} child_count=\{branch_node.child_count} outer_arity=\{@ir.hot_label_branch_arity(func, outer_label)}",
        )
        return false
      }
    _ => {
      (ctx.trace)(
        "rub-result-prefix reject=branch-op holder=\{holder} inner=\{inner_id} op=\{branch_node.op}",
      )
      return false
    }
  }
  if @ir.hot_branch_target(func, branch_id) != Some(outer_label) {
    (ctx.trace)(
      "rub-result-prefix reject=branch-target holder=\{holder} inner=\{inner_id} branch=\{branch_id}",
    )
    return false
  }
  if holder >= 0 &&
    holder < branch_payload_children.length() &&
    branch_payload_children[holder] &&
    inner_root_count == 2 {
    (ctx.trace)(
      "rub-result-prefix reject=payload-holder holder=\{holder} inner=\{inner_id}",
    )
    return false
  }
  if label_refs[inner_label] != 1 {
    (ctx.trace)(
      "rub-result-prefix reject=label-refs inner=\{inner_id} refs=\{label_refs[inner_label]}",
    )
    return false
  }
  let nop_id = @ir.hot_build_nop(func)
  let replacement_body = [nop_id]
  for root_idx = 1; root_idx < inner_root_count - 1; root_idx = root_idx + 1 {
    replacement_body.push(@ir.hot_region_get(func, inner_body_ref, root_idx))
  }
  replacement_body.push(branch_id)
  @ir.hot_region_replace_body(func, inner_body_ref, replacement_body)
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, guard_id, 0)),
    [inner_id],
  )
  ignore(pass_splice_region(ctx, func, region_ref, 0, 1, [if_id]))
  remove_unused_brs_delete_unused_nodes(ctx, func, [guard_id])
  (ctx.trace)(
    "rub-result-prefix rewrite holder=\{holder} inner=\{inner_id} roots=\{inner_root_count}",
  )
  true
}

///|
fn remove_unused_brs_try_rewrite_drop_result_block_if_tail_branch(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let drop_id = @ir.hot_region_get(func, region_ref, idx)
  if drop_id < 0 || !@ir.hot_node_is_live(func, drop_id) {
    return false
  }
  let drop_node = @ir.hot_node_get(func, drop_id)
  match drop_node.op {
    @ir.HotOp::Drop => if drop_node.child_count != 1 { return false }
    _ => return false
  }
  let holder = @ir.hot_child_get(func, drop_id, 0)
  if holder < 0 || !@ir.hot_node_is_live(func, holder) {
    return false
  }
  match @ir.hot_node_get(func, holder).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, holder) != 1 {
        return false
      }
    _ => return false
  }
  let holder_label = @ir.hot_control_node_label(func, holder)
  if holder_label < 0 ||
    holder_label >= label_refs.length() ||
    label_refs[holder_label] != 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, holder)
  if @ir.hot_region_root_count(func, body_ref) != 2 {
    return false
  }
  let if_id = @ir.hot_region_get(func, body_ref, 0)
  let branch_id = @ir.hot_region_get(func, body_ref, 1)
  if if_id < 0 ||
    branch_id < 0 ||
    !@ir.hot_node_is_live(func, if_id) ||
    !@ir.hot_node_is_live(func, branch_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(_) => return false
    None => ()
  }
  let branch_node = @ir.hot_node_get(func, branch_id)
  match branch_node.op {
    @ir.HotOp::Br =>
      if branch_node.child_count != @ir.hot_node_result_arity(func, holder) {
        return false
      }
    _ => return false
  }
  let branch_target = match @ir.hot_branch_target(func, branch_id) {
    Some(target) => target
    None => return false
  }
  if branch_target == holder_label {
    return false
  }
  let dropped_branch = @ir.hot_build_drop(func, branch_id)
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
    if_id, dropped_branch,
  ])
  removed.push(holder)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_root_branch_tail(
  func : @ir.HotFunc,
  root_id : Int,
) -> (Int, Int)? {
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return None
  }
  let root = @ir.hot_node_get(func, root_id)
  match root.op {
    @ir.HotOp::Br =>
      match @ir.hot_branch_target(func, root_id) {
        Some(target) => Some((root_id, target))
        None => None
      }
    @ir.HotOp::Drop => {
      if root.child_count != 1 {
        return None
      }
      let child_id = @ir.hot_child_get(func, root_id, 0)
      if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
        return None
      }
      match @ir.hot_node_get(func, child_id).op {
        @ir.HotOp::Br =>
          match @ir.hot_branch_target(func, child_id) {
            Some(target) => Some((child_id, target))
            None => None
          }
        _ => None
      }
    }
    _ => None
  }
}

///|
fn remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 || block_label >= label_refs.length() {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 2 {
    return false
  }
  let guard_id = @ir.hot_region_get(func, body_ref, 0)
  if guard_id < 0 || !@ir.hot_node_is_live(func, guard_id) {
    return false
  }
  let guard_node = @ir.hot_node_get(func, guard_id)
  match guard_node.op {
    @ir.HotOp::BrIf => if guard_node.child_count != 1 { return false }
    _ => return false
  }
  let label_ref_count = label_refs[block_label]
  if label_ref_count != 1 {
    if label_ref_count != 2 {
      (ctx.trace)(
        "rub-prefix-root reject=label-refs block=\{block_id} refs=\{label_ref_count}",
      )
      return false
    }
    let body_tail = @ir.hot_region_get(func, body_ref, root_count - 1)
    match remove_unused_brs_root_branch_tail(func, body_tail) {
      Some((tail_branch, target)) =>
        if target != block_label ||
          @ir.hot_node_get(func, tail_branch).child_count != 0 {
          (ctx.trace)(
            "rub-prefix-root reject=self-tail block=\{block_id} refs=\{label_ref_count} target=\{target}",
          )
          return false
        }
      None => {
        (ctx.trace)(
          "rub-prefix-root reject=missing-self-tail block=\{block_id} refs=\{label_ref_count}",
        )
        return false
      }
    }
  }
  if @ir.hot_branch_target(func, guard_id) != Some(block_label) {
    (ctx.trace)(
      "rub-prefix-root reject=guard-target block=\{block_id} guard=\{guard_id}",
    )
    return false
  }
  let mut matched_payload_tail = false
  let tail_root = @ir.hot_region_get(func, body_ref, root_count - 1)
  match remove_unused_brs_root_branch_tail(func, tail_root) {
    Some((branch_id, target)) =>
      if target != block_label {
        let target_arity = @ir.hot_label_branch_arity(func, target)
        let branch_child_count = @ir.hot_node_get(func, branch_id).child_count
        if (target_arity > 0 && branch_child_count == target_arity) ||
          branch_child_count == 0 {
          matched_payload_tail = true
        }
      }
    None => ()
  }
  if !matched_payload_tail &&
    idx + 1 < @ir.hot_region_root_count(func, region_ref) {
    let sibling_root = @ir.hot_region_get(func, region_ref, idx + 1)
    match remove_unused_brs_root_branch_tail(func, sibling_root) {
      Some((branch_id, target)) =>
        if target != block_label {
          let target_arity = @ir.hot_label_branch_arity(func, target)
          let branch_child_count = @ir.hot_node_get(func, branch_id).child_count
          if (target_arity > 0 && branch_child_count == target_arity) ||
            branch_child_count == 0 {
            matched_payload_tail = true
          }
        }
      None => ()
    }
  }
  if !matched_payload_tail &&
    idx + 1 < @ir.hot_region_root_count(func, region_ref) {
    let suffix_tail_root = @ir.hot_region_get(
      func,
      region_ref,
      @ir.hot_region_root_count(func, region_ref) - 1,
    )
    match remove_unused_brs_root_branch_tail(func, suffix_tail_root) {
      Some((branch_id, target)) =>
        if target != block_label {
          let target_arity = @ir.hot_label_branch_arity(func, target)
          let branch_child_count = @ir.hot_node_get(func, branch_id).child_count
          if (target_arity > 0 && branch_child_count == target_arity) ||
            branch_child_count == 0 {
            matched_payload_tail = true
          }
        }
      None => ()
    }
  }
  if !matched_payload_tail {
    (ctx.trace)(
      "rub-prefix-root reject=payload-tail block=\{block_id} roots=\{root_count}",
    )
    return false
  }
  let condition = remove_unused_brs_build_i32_eqz(
    func,
    @ir.hot_child_get(func, guard_id, 0),
  )
  let nop_id = @ir.hot_build_nop(func)
  let replacement_body = [nop_id]
  for root_idx = 1; root_idx < root_count; root_idx = root_idx + 1 {
    replacement_body.push(@ir.hot_region_get(func, body_ref, root_idx))
  }
  @ir.hot_region_replace_body(func, body_ref, replacement_body)
  let replacement = @ir.hot_build_if(func, @lib.BlockType::void_(), condition, [
    block_id,
  ])
  ignore(pass_splice_region(ctx, func, region_ref, idx, 1, [replacement]))
  remove_unused_brs_delete_unused_nodes(ctx, func, [guard_id])
  (ctx.trace)(
    "rub-prefix-root rewrite block=\{block_id} roots=\{root_count} refs=\{label_ref_count}",
  )
  true
}

///|
fn remove_unused_brs_try_rewrite_result_block_one_arm_payload_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  current_site : RemoveUnusedBrsRootSite?,
  block_id : Int,
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  branch_payload_children : @bitset.BitSet,
) -> Bool {
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 1 {
        return false
      }
    _ => return false
  }
  if block_id >= 0 &&
    block_id < branch_payload_children.length() &&
    branch_payload_children[block_id] {
    return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    label_refs[block_label] != 1 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) < 2 {
    return false
  }
  let result_arity = @ir.hot_node_result_arity(func, block_id)
  if result_arity != 1 {
    return false
  }
  let result_type = @ir.hot_type_results(
      func,
      @ir.hot_node_type(func, block_id),
    )[0]
  let fallthrough_roots : Array[Int] = []
  for root_idx = 1
      root_idx < @ir.hot_region_root_count(func, body_ref)
      root_idx = root_idx + 1 {
    fallthrough_roots.push(@ir.hot_region_get(func, body_ref, root_idx))
  }
  match
    @ir.hot_split_trailing_payload_roots(func, fallthrough_roots, result_arity) {
    Some(_) => ()
    None => return false
  }
  let direct_if_id = @ir.hot_region_get(func, body_ref, 0)
  if direct_if_id >= 0 && @ir.hot_node_is_live(func, direct_if_id) {
    match @ir.hot_node_get(func, direct_if_id).op {
      @ir.HotOp::If =>
        if @ir.hot_node_result_arity(func, direct_if_id) == 0 {
          let then_ref = @ir.hot_region_then_ref(func, direct_if_id)
          match @ir.hot_region_else_ref(func, direct_if_id) {
            Some(_) => ()
            None => {
              let branch_value = match
                remove_unused_brs_build_stack_exit_region_value_expr(
                  ctx,
                  func,
                  then_ref,
                  BranchTarget(block_label),
                  result_type,
                  reorder_cache,
                ) {
                Some(branch_value) => branch_value
                None =>
                  match
                    remove_unused_brs_build_stack_exit_region_value_body(
                      func,
                      then_ref,
                      BranchTarget(block_label),
                      result_arity,
                    ) {
                    Some(branch_body) =>
                      if branch_body.length() > 1 &&
                        remove_unused_brs_roots_have_embedded_control(
                          func, branch_body,
                        ) {
                        return false
                      } else {
                        @ir.hot_build_block(
                          func,
                          @lib.BlockType::val_type(result_type),
                          branch_body,
                        )
                      }
                    None => return false
                  }
              }
              let replacement = @ir.hot_build_if(
                func,
                @lib.BlockType::val_type(result_type),
                @ir.hot_child_get(func, direct_if_id, 0),
                [branch_value],
                else_body=Some(fallthrough_roots),
              )
              let site = match current_site {
                Some(site) => site
                None => return false
              }
              let removed = pass_splice_region(
                ctx,
                func,
                site.region_ref,
                site.idx,
                1,
                [replacement],
              )
              removed.push(direct_if_id)
              removed.push(then_ref.holder)
              remove_unused_brs_delete_unused_nodes(ctx, func, removed)
              return true
            }
          }
        }
      _ => ()
    }
  }
  // Binaryen keeps carried wrapper blocks for the remaining one-arm payload
  // families here, so RUB leaves them intact for parity.
  return false
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
fn remove_unused_brs_roots_have_embedded_control(
  func : @ir.HotFunc,
  roots : Array[Int],
) -> Bool {
  let control_cache : Array[Int] = []
  for root_id in roots {
    if remove_unused_brs_subtree_has_embedded_control(
        func, root_id, control_cache,
      ) {
      return true
    }
  }
  false
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
    @ir.hot_split_trailing_payload_roots(func, roots, 1) {
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
fn remove_unused_brs_build_stack_exit_region_value_body(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target : RemoveUnusedBrsTailTarget,
  result_arity : Int,
) -> Array[Int]? {
  if result_arity <= 0 {
    return None
  }
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
  if roots.length() > 1 {
    return None
  }
  let body_roots : Array[Int] = []
  for idx = 0; idx < roots.length() - 1; idx = idx + 1 {
    body_roots.push(roots[idx])
  }
  for child_idx = 0; child_idx < tail.child_count; child_idx = child_idx + 1 {
    let child_id = @ir.hot_child_get(func, tail_id, child_idx)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      return None
    }
    body_roots.push(child_id)
  }
  match @ir.hot_split_trailing_payload_roots(func, body_roots, result_arity) {
    Some(_) => Some(body_roots)
    None => None
  }
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
  if roots.length() > 1 {
    return None
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
  if payload_roots.length() > 1 &&
    remove_unused_brs_roots_have_embedded_control(func, payload_roots) {
    return None
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
    remove_unused_brs_replace_unused_if_with_value_expr(
      ctx,
      func,
      if_id,
      replacement,
      [then_ref.holder, else_ref.holder],
    )
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
    @ir.HotOp::Br =>
      match @ir.hot_node_repeated_live_child(func, br_id) {
        Some(candidate) => candidate
        None => return false
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
  if br_node.child_count != result_arity {
    return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let try_build = fn(
    branch_ref : @ir.HotRegionRef,
    body_ref : @ir.HotRegionRef,
    negate_condition : Bool,
  ) -> Bool {
    ignore(
      match @ir.hot_region_single_plain_br_root(func, branch_ref) {
        Some(branch_root) => branch_root
        None => return false
      },
    )
    let branch_target = match
      @ir.hot_region_single_plain_br_target(func, branch_ref) {
      Some(branch_target) => branch_target
      None => return false
    }
    if branch_target == if_label {
      return false
    }
    let (body_prefix, body_payload) = match
      @ir.hot_region_split_trailing_payload_roots(func, body_ref, result_arity) {
      Some(split) => split
      None => return false
    }
    if body_payload.length() != br_node.child_count {
      return false
    }
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, if_id, 0))
    } else {
      @ir.hot_child_get(func, if_id, 0)
    }
    let guard_branch = @ir.hot_build_br_if(func, branch_target, guard_condition)
    let exit_branch = @ir.hot_build_br(func, br_node.imm0, values=body_payload)
    let replacement = [guard_branch]
    for root_id in body_prefix {
      replacement.push(root_id)
    }
    replacement.push(exit_branch)
    let removed = pass_splice_region(ctx, func, region_ref, idx, 1, replacement)
    removed.push(br_id)
    removed.push(if_id)
    removed.push(then_ref.holder)
    removed.push(else_ref.holder)
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
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
    let branch_target = match
      @ir.hot_region_single_plain_br_target(func, branch_ref) {
      Some(branch_target) => branch_target
      None => return false
    }
    if branch_target == if_label {
      return false
    }
    let (body_prefix, body_payload) = match
      @ir.hot_region_split_trailing_payload_roots(func, body_ref, result_arity) {
      Some(split) => split
      None => return false
    }
    let guard_condition = if negate_condition {
      remove_unused_brs_build_i32_eqz(func, @ir.hot_child_get(func, if_id, 0))
    } else {
      @ir.hot_child_get(func, if_id, 0)
    }
    let guard_branch = @ir.hot_build_br_if(func, branch_target, guard_condition)
    let replacement = [guard_branch]
    for root_id in body_prefix {
      replacement.push(root_id)
    }
    for payload_id in body_payload {
      replacement.push(payload_id)
    }
    let removed = pass_splice_region(
      ctx, func, region_ref, tail_idx, 1, replacement,
    )
    remove_unused_brs_delete_unused_nodes(
      ctx,
      func,
      removed + [if_id, then_ref.holder, else_ref.holder],
    )
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
  ignore(ctx)
  ignore(func)
  ignore(region_ref)
  ignore(label_refs)
  // Generated ordered -O4z slot40 still corrupts stack state after this rewrite
  // composes with later lowering/restructuring steps. Keep it retired until the
  // valid-context contract is reduced and re-landed under focused oracle-backed
  // coverage.
  false
}

///|
fn remove_unused_brs_try_rewrite_return_child_if_branch_exit(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  if_id : Int,
  label_refs : Array[Int],
) -> Bool {
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
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let mut changed = false
  if remove_unused_brs_region_maybe_has_tail_value_if_branch_exit(
      func, then_ref,
    ) {
    changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
      ctx, func, then_ref, label_refs,
    )
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) =>
      if remove_unused_brs_region_maybe_has_tail_value_if_branch_exit(
          func, else_ref,
        ) {
        changed = remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
            ctx, func, else_ref, label_refs,
          ) ||
          changed
      }
    None => ()
  }
  changed
}

///|
fn remove_unused_brs_region_maybe_has_tail_value_if_branch_exit(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if @ir.hot_region_root_count(func, region_ref) <= 1 {
    return false
  }
  let tail_id = remove_unused_brs_region_tail_id(func, region_ref)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return false
  }
  let tail_node = @ir.hot_node_get(func, tail_id)
  match tail_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, tail_id) != 1 {
        return false
      }
    _ => return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, tail_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, tail_id)
  let has_plain_branch_arm = fn(arm_ref : @ir.HotRegionRef) -> Bool {
    match @ir.hot_region_single_plain_br_root(func, arm_ref) {
      Some(_) => true
      None => false
    }
  }
  has_plain_branch_arm(then_ref) || has_plain_branch_arm(else_ref)
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
  let holder = match @ir.hot_region_holder_block_root(func, region_ref) {
    Some(holder) => holder
    None => return false
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
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let target = @ir.hot_control_node_label(func, holder)
  let condition = @ir.hot_child_get(func, if_id, 0)
  match @ir.hot_region_single_plain_br_root(func, then_ref) {
    Some(then_root) =>
      if @ir.hot_region_single_plain_br_target(func, then_ref) == Some(target) {
        let branch = @ir.hot_build_br_if(func, target, condition)
        let replacement = [branch]
        for root_idx = 0
            root_idx < @ir.hot_region_root_count(func, else_ref)
            root_idx = root_idx + 1 {
          replacement.push(@ir.hot_region_get(func, else_ref, root_idx))
        }
        ignore(pass_splice_region(ctx, func, region_ref, idx, 1, replacement))
        remove_unused_brs_delete_unused_nodes(ctx, func, [
          if_id,
          then_ref.holder,
          then_root,
          else_ref.holder,
        ])
        return true
      }
    None => ()
  }
  match @ir.hot_region_single_plain_br_root(func, else_ref) {
    Some(else_root) =>
      if @ir.hot_region_single_plain_br_target(func, else_ref) == Some(target) {
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
        remove_unused_brs_delete_unused_nodes(ctx, func, [
          if_id,
          then_ref.holder,
          else_ref.holder,
          else_root,
        ])
        return true
      }
    None => ()
  }
  false
}

///|
fn remove_unused_brs_flatten_block_if_chains(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  match @ir.hot_region_holder_block_root(func, region_ref) {
    Some(_) => ()
    None => return false
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
fn remove_unused_brs_tail_fallthrough_last_live_root_idx(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int {
  let mut idx = @ir.hot_region_root_count(func, region_ref) - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Unreachable => idx = idx - 1
        _ => return idx
      }
    } else {
      idx = idx - 1
    }
  }
  -1
}

///|
fn remove_unused_brs_strip_region_suffix_after(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if idx < 0 || idx + 1 >= root_count {
    return false
  }
  for suffix_idx = idx + 1; suffix_idx < root_count; suffix_idx = suffix_idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, suffix_idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Unreachable => ()
      _ => return false
    }
  }
  let removed = pass_splice_region(
    ctx,
    func,
    region_ref,
    idx + 1,
    root_count - idx - 1,
    [],
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_try_void_tail_if_return_to_fallthrough(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  if_id : Int,
  label_refs : Array[Int],
) -> Bool {
  if @ir.hot_type_result_arity(func, @ir.hot_body_result_type(func)) != 0 {
    return false
  }
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let try_arm = fn(
    return_ref : @ir.HotRegionRef,
    exit_ref : @ir.HotRegionRef,
  ) -> Bool {
    if @ir.hot_region_root_count(func, return_ref) != 1 {
      return false
    }
    let return_id = @ir.hot_region_get(func, return_ref, 0)
    if return_id < 0 || !@ir.hot_node_is_live(func, return_id) {
      return false
    }
    let return_node = @ir.hot_node_get(func, return_id)
    match return_node.op {
      @ir.HotOp::Return => if return_node.child_count != 0 { return false }
      _ => return false
    }
    if !remove_unused_brs_tail_is_nonfallthrough(func, exit_ref) {
      return false
    }
    let nop_id = @ir.hot_build_nop(func)
    let removed = pass_splice_region(ctx, func, return_ref, 0, 1, [nop_id])
    removed.push(return_id)
    remove_unused_brs_delete_unused_nodes(ctx, func, removed)
    true
  }
  try_arm(then_ref, else_ref) || try_arm(else_ref, then_ref)
}

///|
fn remove_unused_brs_try_tail_loop_return_to_fallthrough(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  let idx = remove_unused_brs_tail_fallthrough_last_live_root_idx(
    func, region_ref,
  )
  if idx < 0 {
    return false
  }
  let node_id = @ir.hot_region_get(func, region_ref, idx)
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  let mut changed = false
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Loop => {
      if @ir.hot_node_result_arity(func, node_id) != 0 {
        return false
      }
      changed = remove_unused_brs_try_tail_loop_return_to_fallthrough(
        ctx,
        func,
        @ir.hot_region_body_ref(func, node_id),
        label_refs,
      )
    }
    @ir.HotOp::If =>
      changed = remove_unused_brs_try_void_tail_if_return_to_fallthrough(
        ctx, func, node_id, label_refs,
      )
    _ => return false
  }
  if changed {
    ignore(
      remove_unused_brs_strip_region_suffix_after(ctx, func, region_ref, idx),
    )
  }
  changed
}

///|
fn remove_unused_brs_try_invert_empty_then_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_id : Int,
  label_refs : Array[Int],
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, node_id) != 0 {
        return false
      }
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, node_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, node_id)
  if @ir.hot_region_root_count(func, then_ref) != 0 {
    return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, node_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let else_roots = remove_unused_brs_region_roots(func, else_ref)
  if else_roots.is_empty() {
    return false
  }
  let inverted = remove_unused_brs_build_i32_eqz(
    func,
    @ir.hot_child_get(func, node_id, 0),
  )
  @ir.hot_region_replace_body(func, then_ref, else_roots)
  @ir.hot_region_replace_body(func, else_ref, [])
  @ir.hot_child_set(func, node_id, 0, inverted)
  @ir.hot_child_set(func, node_id, 2, -1)
  remove_unused_brs_mark_mutated(ctx, func, "invert-empty-then-if")
  true
}

///|
fn remove_unused_brs_trim_plain_block_exit_arm(
  func : @ir.HotFunc,
  arm_ref : @ir.HotRegionRef,
  target_label : Int,
) -> Array[Int]? {
  let root_count = @ir.hot_region_root_count(func, arm_ref)
  if root_count == 0 {
    return None
  }
  let tail_id = @ir.hot_region_get(func, arm_ref, root_count - 1)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return None
  }
  let tail = @ir.hot_node_get(func, tail_id)
  match tail.op {
    @ir.HotOp::Br if @ir.hot_branch_target(func, tail_id) == Some(target_label) &&
      tail.child_count == 0 => ()
    _ => return None
  }
  let body : Array[Int] = []
  for idx = 0; idx < root_count - 1; idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, arm_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    body.push(root_id)
  }
  Some(body)
}

///|
fn remove_unused_brs_return_arm_roots_are_void_safe(
  func : @ir.HotFunc,
  arm_ref : @ir.HotRegionRef,
  return_tail : Int,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, arm_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, arm_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    if root_id == return_tail {
      continue
    }
    if @ir.hot_node_result_arity(func, root_id) != 0 {
      return false
    }
  }
  true
}

///|
fn remove_unused_brs_region_suffix_is_unreachable_only(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  start_idx : Int,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if start_idx < 0 || start_idx >= root_count {
    return false
  }
  let mut saw_unreachable = false
  for idx = start_idx; idx < root_count; idx = idx + 1 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Nop => ()
      @ir.HotOp::Unreachable => saw_unreachable = true
      _ => return false
    }
  }
  saw_unreachable
}

///|
fn remove_unused_brs_try_voidify_if_block_exit_unreachable_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if idx < 0 || idx >= root_count - 1 {
    return false
  }
  if !remove_unused_brs_region_suffix_is_unreachable_only(
      func,
      region_ref,
      idx + 1,
    ) {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let target_label = match remove_unused_brs_tail_target(func, region_ref) {
    BranchTarget(label_id) => label_id
    _ => return false
  }
  let _ = label_refs
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let arm_keep_body = fn(arm_ref : @ir.HotRegionRef) -> Array[Int]? {
    if !remove_unused_brs_tail_is_nonfallthrough(func, arm_ref) {
      return None
    }
    let tail_id = remove_unused_brs_region_tail_id(func, arm_ref)
    if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
      return None
    }
    let tail = @ir.hot_node_get(func, tail_id)
    match tail.op {
      @ir.HotOp::Return if tail.child_count > 0 => ()
      _ => return None
    }
    if !remove_unused_brs_return_arm_roots_are_void_safe(func, arm_ref, tail_id) {
      return None
    }
    Some(remove_unused_brs_region_roots(func, arm_ref))
  }
  let try_build = fn(
    keep_ref : @ir.HotRegionRef,
    exit_ref : @ir.HotRegionRef,
    keep_is_then : Bool,
  ) -> Bool {
    let keep_body = match arm_keep_body(keep_ref) {
      Some(body) => body
      None => return false
    }
    let exit_body = match
      remove_unused_brs_trim_plain_block_exit_arm(func, exit_ref, target_label) {
      Some(body) => body
      None => return false
    }
    let replacement = if keep_is_then {
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        @ir.hot_child_get(func, if_id, 0),
        keep_body,
        else_body=Some(exit_body),
      )
    } else {
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        @ir.hot_child_get(func, if_id, 0),
        exit_body,
        else_body=Some(keep_body),
      )
    }
    let removed = pass_splice_region(
      ctx,
      func,
      region_ref,
      idx,
      root_count - idx,
      [replacement],
    )
    remove_unused_brs_delete_unused_nodes(
      ctx,
      func,
      [if_id, then_ref.holder, else_ref.holder] + removed,
    )
    true
  }
  try_build(then_ref, else_ref, true) || try_build(else_ref, then_ref, false)
}

///|
fn remove_unused_brs_try_voidify_tail_value_if_block_exit(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if root_count < 2 {
    return false
  }
  let if_idx = root_count - 1
  let if_id = @ir.hot_region_get(func, region_ref, if_idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, if_id) != 1 {
    return false
  }
  let payload_idx = if_idx - 1
  let payload_id = @ir.hot_region_get(func, region_ref, payload_idx)
  if payload_id < 0 || !@ir.hot_node_is_live(func, payload_id) {
    return false
  }
  match @ir.hot_node_get(func, payload_id).op {
    @ir.HotOp::Unreachable => ()
    _ => return false
  }
  let target_label = match remove_unused_brs_tail_target(func, region_ref) {
    BranchTarget(label_id) => label_id
    _ => return false
  }
  let _ = label_refs
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let arm_keep_body = fn(arm_ref : @ir.HotRegionRef) -> Array[Int]? {
    if !remove_unused_brs_tail_is_nonfallthrough(func, arm_ref) {
      return None
    }
    let tail_id = remove_unused_brs_region_tail_id(func, arm_ref)
    if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
      return None
    }
    let tail = @ir.hot_node_get(func, tail_id)
    match tail.op {
      @ir.HotOp::Return if tail.child_count > 0 => ()
      _ => return None
    }
    if !remove_unused_brs_return_arm_roots_are_void_safe(func, arm_ref, tail_id) {
      return None
    }
    Some(remove_unused_brs_region_roots(func, arm_ref))
  }
  let try_build = fn(
    keep_ref : @ir.HotRegionRef,
    exit_ref : @ir.HotRegionRef,
    keep_is_then : Bool,
  ) -> Bool {
    let keep_body = match arm_keep_body(keep_ref) {
      Some(body) => body
      None => return false
    }
    let exit_body = match
      remove_unused_brs_trim_plain_block_exit_arm(func, exit_ref, target_label) {
      Some(body) => body
      None => return false
    }
    let replacement = if keep_is_then {
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        @ir.hot_child_get(func, if_id, 0),
        keep_body,
        else_body=Some(exit_body),
      )
    } else {
      @ir.hot_build_if(
        func,
        @lib.BlockType::void_(),
        @ir.hot_child_get(func, if_id, 0),
        exit_body,
        else_body=Some(keep_body),
      )
    }
    let removed = pass_splice_region(ctx, func, region_ref, payload_idx, 2, [
      replacement,
    ])
    remove_unused_brs_delete_unused_nodes(
      ctx,
      func,
      [payload_id, if_id, then_ref.holder, else_ref.holder] + removed,
    )
    true
  }
  try_build(then_ref, else_ref, true) || try_build(else_ref, then_ref, false)
}

///|
fn remove_unused_brs_try_restructure_one_arm_return_if_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if idx < 0 || idx >= root_count - 1 {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(_) => return false
    None => ()
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  if @ir.hot_region_root_count(func, then_ref) != 1 {
    return false
  }
  let then_root = @ir.hot_region_get(func, then_ref, 0)
  let then_node = @ir.hot_node_get(func, then_root)
  match then_node.op {
    @ir.HotOp::Return => if then_node.child_count != 0 { return false }
    _ => return false
  }
  let suffix_roots : Array[Int] = []
  for root_idx = idx + 1; root_idx < root_count; root_idx = root_idx + 1 {
    suffix_roots.push(@ir.hot_region_get(func, region_ref, root_idx))
  }
  let suffix_target = match
    remove_unused_brs_region_enclosing_branch_target(func, region_ref) {
    Some(label_id) => label_id
    None => return false
  }
  if suffix_roots.is_empty() {
    return false
  }
  for root_idx = 0
      root_idx < suffix_roots.length() - 1
      root_idx = root_idx + 1 {
    if @ir.cfg_terminator_edge_kinds(
        @ir.hot_node_get(func, suffix_roots[root_idx]).op,
      ).length() >
      0 {
      return false
    }
  }
  let suffix_tail = @ir.hot_node_get(
    func,
    suffix_roots[suffix_roots.length() - 1],
  )
  match suffix_tail.op {
    @ir.HotOp::Br if suffix_tail.imm0 == suffix_target &&
      suffix_tail.child_count == 0 => ()
    _ => return false
  }
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, if_id, 0),
    [then_root],
    else_body=Some(suffix_roots),
  )
  let unreachable_id = @ir.hot_build_unreachable(func)
  ignore(
    pass_splice_region(ctx, func, region_ref, idx, root_count - idx, [
      replacement, unreachable_id,
    ]),
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, [if_id, then_ref.holder])
  true
}

///|
fn remove_unused_brs_try_restructure_one_exit_arm_if_suffix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  if idx < 0 || idx >= root_count - 1 {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
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
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let then_nonfallthrough = remove_unused_brs_tail_is_nonfallthrough(
    func, then_ref,
  )
  let else_nonfallthrough = remove_unused_brs_tail_is_nonfallthrough(
    func, else_ref,
  )
  if then_nonfallthrough == else_nonfallthrough {
    return false
  }
  let suffix_target = match
    remove_unused_brs_region_enclosing_branch_target(func, region_ref) {
    Some(label_id) => label_id
    None => return false
  }
  let suffix_roots : Array[Int] = []
  for root_idx = idx + 1; root_idx < root_count; root_idx = root_idx + 1 {
    suffix_roots.push(@ir.hot_region_get(func, region_ref, root_idx))
  }
  if suffix_roots.is_empty() {
    return false
  }
  for root_idx = 0
      root_idx < suffix_roots.length() - 1
      root_idx = root_idx + 1 {
    if @ir.cfg_terminator_edge_kinds(
        @ir.hot_node_get(func, suffix_roots[root_idx]).op,
      ).length() >
      0 {
      return false
    }
  }
  let suffix_tail = @ir.hot_node_get(
    func,
    suffix_roots[suffix_roots.length() - 1],
  )
  match suffix_tail.op {
    @ir.HotOp::Br if suffix_tail.imm0 == suffix_target &&
      suffix_tail.child_count == 0 => ()
    _ => return false
  }
  let then_body = remove_unused_brs_region_roots(func, then_ref)
  let else_body = remove_unused_brs_region_roots(func, else_ref)
  let moved_suffix : Array[Int] = []
  for root_id in suffix_roots {
    moved_suffix.push(root_id)
  }
  let replacement = if then_nonfallthrough {
    @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      @ir.hot_child_get(func, if_id, 0),
      then_body,
      else_body=Some(else_body + moved_suffix),
    )
  } else {
    @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      @ir.hot_child_get(func, if_id, 0),
      then_body + moved_suffix,
      else_body=Some(else_body),
    )
  }
  let unreachable_id = @ir.hot_build_unreachable(func)
  ignore(
    pass_splice_region(ctx, func, region_ref, idx, root_count - idx, [
      replacement, unreachable_id,
    ]),
  )
  remove_unused_brs_delete_unused_nodes(ctx, func, [
    if_id,
    then_ref.holder,
    else_ref.holder,
  ])
  true
}

///|
fn remove_unused_brs_count_label_uses_in_roots(
  func : @ir.HotFunc,
  roots : Array[Int],
  target_label : Int,
) -> Int {
  if target_label < 0 || target_label >= func.labels.length() {
    return 0
  }
  let seen = @bitset.BitSet::new(@ir.hot_node_count(func))
  let work : Array[Int] = []
  for root in roots {
    work.push(root)
  }
  let mut count = 0
  while !work.is_empty() {
    let node_id = work.pop().unwrap()
    if node_id < 0 ||
      node_id >= @ir.hot_node_count(func) ||
      !@ir.hot_node_is_live(func, node_id) ||
      seen[node_id] {
      continue
    }
    seen[node_id] = true
    match @ir.hot_branch_target(func, node_id) {
      Some(label_id) if label_id == target_label => count += 1
      _ => ()
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::BrTable => {
        if @ir.hot_branch_table_default_target(func, node.imm0) == target_label {
          count += 1
        }
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          if label_id == target_label {
            count += 1
          }
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
          if label_id == target_label {
            count += 1
          }
        }
      }
      _ => ()
    }
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      work.push(@ir.hot_child_get(func, node_id, slot))
    }
  }
  count
}

///|
fn remove_unused_brs_count_label_uses_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_label : Int,
) -> Int {
  remove_unused_brs_count_label_uses_in_roots(
    func,
    remove_unused_brs_region_roots(func, region_ref),
    target_label,
  )
}

///|
fn remove_unused_brs_region_roots_are_pure_select_arm(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  roots : Array[Int],
  reorder_cache : Array[Int],
) -> Bool {
  remove_unused_brs_region_roots_are_reorder_safe(
    ctx, func, roots, reorder_cache,
  )
}

///|
fn remove_unused_brs_try_restructure_self_branch_block_prefix(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
  reorder_cache : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
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
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 || block_label >= label_refs.length() {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let body_count = @ir.hot_region_root_count(func, body_ref)
  if body_count < 2 {
    return false
  }
  if remove_unused_brs_count_label_uses_in_region(func, body_ref, block_label) !=
    1 {
    return false
  }
  let first_id = @ir.hot_region_get(func, body_ref, 0)
  if first_id < 0 || !@ir.hot_node_is_live(func, first_id) {
    return false
  }
  let first_node = @ir.hot_node_get(func, first_id)
  let mut drop_id = -1
  let mut consumed_end = 0
  let mut stack_value = -1
  let mut stack_condition = -1
  let br_if_id = match first_node.op {
    @ir.HotOp::Drop => {
      if first_node.child_count != 1 {
        return false
      }
      let candidate = @ir.hot_child_get(func, first_id, 0)
      if candidate < 0 || !@ir.hot_node_is_live(func, candidate) {
        return false
      }
      drop_id = first_id
      candidate
    }
    @ir.HotOp::BrIf => {
      if first_node.child_count == 2 && body_count >= 2 {
        let maybe_drop = @ir.hot_region_get(func, body_ref, 1)
        if maybe_drop >= 0 && @ir.hot_node_is_live(func, maybe_drop) {
          match @ir.hot_node_get(func, maybe_drop).op {
            @ir.HotOp::Drop => {
              drop_id = maybe_drop
              consumed_end = 1
            }
            _ => ()
          }
        }
      }
      first_id
    }
    _ => {
      if body_count < 2 {
        return false
      }
      let second_id = @ir.hot_region_get(func, body_ref, 1)
      if second_id < 0 || !@ir.hot_node_is_live(func, second_id) {
        return false
      }
      match @ir.hot_node_get(func, second_id).op {
        @ir.HotOp::BrIf => {
          stack_condition = first_id
          consumed_end = 1
          second_id
        }
        _ => {
          if body_count < 4 {
            return false
          }
          let third_id = @ir.hot_region_get(func, body_ref, 2)
          let fourth_id = @ir.hot_region_get(func, body_ref, 3)
          if third_id < 0 ||
            fourth_id < 0 ||
            !@ir.hot_node_is_live(func, third_id) ||
            !@ir.hot_node_is_live(func, fourth_id) {
            return false
          }
          match
            (
              @ir.hot_node_get(func, third_id).op,
              @ir.hot_node_get(func, fourth_id).op,
            ) {
            (@ir.HotOp::BrIf, @ir.HotOp::Drop) => {
              stack_value = first_id
              stack_condition = second_id
              drop_id = fourth_id
              consumed_end = 3
              third_id
            }
            _ => return false
          }
        }
      }
    }
  }
  let br_if_node = @ir.hot_node_get(func, br_if_id)
  match br_if_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if @ir.hot_branch_target(func, br_if_id) != Some(block_label) {
    return false
  }
  let condition = if stack_condition >= 0 {
    stack_condition
  } else {
    if br_if_node.child_count <= 0 {
      return false
    }
    @ir.hot_child_get(func, br_if_id, br_if_node.child_count - 1)
  }
  if condition < 0 || !@ir.hot_node_is_live(func, condition) {
    return false
  }
  if !remove_unused_brs_node_is_reorder_safe(
      ctx, func, condition, reorder_cache,
    ) {
    return false
  }
  let result_types = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, block_id),
  )
  if drop_id < 0 {
    if !result_types.is_empty() {
      return false
    }
    if stack_condition < 0 && br_if_node.child_count != 1 {
      return false
    }
    if stack_condition >= 0 &&
      br_if_node.child_count != 0 &&
      br_if_node.child_count != 1 {
      return false
    }
    for root_idx = 0; root_idx <= consumed_end; root_idx = root_idx + 1 {
      ignore(
        @ir.hot_region_set(func, body_ref, root_idx, @ir.hot_build_nop(func)),
      )
    }
    let replacement = @ir.hot_build_if(
      func,
      @lib.BlockType::void_(),
      remove_unused_brs_build_i32_eqz(func, condition),
      [block_id],
    )
    ignore(@ir.hot_region_set(func, region_ref, idx, replacement))
    remove_unused_brs_mark_mutated(
      ctx, func, "restructure-self-branch-block-prefix",
    )
    return true
  }
  if result_types.length() != 1 {
    return false
  }
  if stack_value < 0 && br_if_node.child_count != 2 {
    return false
  }
  if stack_value >= 0 && br_if_node.child_count > 2 {
    return false
  }
  let value = if stack_value >= 0 {
    stack_value
  } else {
    @ir.hot_child_get(func, br_if_id, 0)
  }
  if value < 0 || !@ir.hot_node_is_live(func, value) {
    return false
  }
  let result_type = result_types[0]
  if @ir.hot_node_result_arity(func, value) != 1 {
    return false
  }
  let value_types = @ir.hot_type_results(func, @ir.hot_node_type(func, value))
  if value_types.length() != 1 || value_types[0] != result_type {
    return false
  }
  let suffix_roots : Array[Int] = []
  for root_idx = consumed_end + 1
      root_idx < body_count
      root_idx = root_idx + 1 {
    suffix_roots.push(@ir.hot_region_get(func, body_ref, root_idx))
  }
  if remove_unused_brs_node_is_reorder_safe(ctx, func, value, reorder_cache) {
    for root_idx = 0; root_idx <= consumed_end; root_idx = root_idx + 1 {
      ignore(
        @ir.hot_region_set(func, body_ref, root_idx, @ir.hot_build_nop(func)),
      )
    }
    let replacement = @ir.hot_build_if(
      func,
      @lib.BlockType::val_type(result_type),
      condition,
      [value],
      else_body=Some([block_id]),
    )
    ignore(@ir.hot_region_set(func, region_ref, idx, replacement))
    remove_unused_brs_mark_mutated(
      ctx, func, "restructure-self-branch-block-prefix-value-if",
    )
    return true
  }
  if !remove_unused_brs_region_roots_are_pure_select_arm(
      ctx, func, suffix_roots, reorder_cache,
    ) {
    return false
  }
  for root_idx = 0; root_idx <= consumed_end; root_idx = root_idx + 1 {
    ignore(
      @ir.hot_region_set(func, body_ref, root_idx, @ir.hot_build_nop(func)),
    )
  }
  let replacement = remove_unused_brs_build_select(
    func, result_type, value, block_id, condition,
  )
  ignore(@ir.hot_region_set(func, region_ref, idx, replacement))
  remove_unused_brs_mark_mutated(
    ctx, func, "restructure-self-branch-block-prefix-select",
  )
  true
}

///|
fn remove_unused_brs_try_sink_single_if_exit_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    label_refs[block_label] <= 0 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let if_id = @ir.hot_region_get(func, body_ref, 0)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  if condition < 0 || !@ir.hot_node_is_live(func, condition) {
    return false
  }
  match @ir.hot_node_get(func, condition).op {
    @ir.HotOp::Unreachable => return false
    _ => ()
  }
  if remove_unused_brs_count_label_uses_in_roots(func, [condition], block_label) !=
    0 {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let else_ref = @ir.hot_region_else_ref(func, if_id)
  let then_uses = remove_unused_brs_count_label_uses_in_region(
    func, then_ref, block_label,
  )
  let else_uses = match else_ref {
    Some(ref_) =>
      remove_unused_brs_count_label_uses_in_region(func, ref_, block_label)
    None => 0
  }
  let target_ref = if else_uses == 0 && then_uses > 0 {
    then_ref
  } else if then_uses == 0 && else_uses > 0 {
    match else_ref {
      Some(ref_) => ref_
      None => return false
    }
  } else {
    return false
  }
  let moved_roots = remove_unused_brs_region_roots(func, target_ref)
  if moved_roots.length() < 2 {
    return false
  }
  if !moved_roots.is_empty() {
    let tail_id = moved_roots[moved_roots.length() - 1]
    if tail_id >= 0 && @ir.hot_node_is_live(func, tail_id) {
      let tail_node = @ir.hot_node_get(func, tail_id)
      match tail_node.op {
        @ir.HotOp::Br if @ir.hot_branch_target(func, tail_id) ==
          Some(block_label) &&
          tail_node.child_count == 0 => return false
        @ir.HotOp::BrIf if @ir.hot_branch_target(func, tail_id) ==
          Some(block_label) => return false
        _ => ()
      }
    }
  }
  @ir.hot_region_replace_body(func, body_ref, moved_roots)
  @ir.hot_region_replace_body(func, target_ref, [block_id])
  ignore(@ir.hot_region_set(func, region_ref, idx, if_id))
  remove_unused_brs_mark_mutated(ctx, func, "sink-single-if-exit-block")
  true
}

///|
fn remove_unused_brs_try_sink_if_arm_self_branch_block(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    label_refs[block_label] != 1 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, body_ref) != 1 {
    return false
  }
  let if_id = @ir.hot_region_get(func, body_ref, 0)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  let if_node = @ir.hot_node_get(func, if_id)
  match if_node.op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let else_ref = match @ir.hot_region_else_ref(func, if_id) {
    Some(else_ref) => else_ref
    None => return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let arm_without_self_branch = fn(arm_ref : @ir.HotRegionRef) -> Array[Int]? {
    let arm_root_count = @ir.hot_region_root_count(func, arm_ref)
    if arm_root_count == 0 {
      return None
    }
    let tail_id = @ir.hot_region_get(func, arm_ref, arm_root_count - 1)
    let tail_node = @ir.hot_node_get(func, tail_id)
    match tail_node.op {
      @ir.HotOp::Br if tail_node.imm0 == block_label &&
        tail_node.child_count == 0 => {
        let roots : Array[Int] = []
        for root_idx = 0; root_idx < arm_root_count - 1; root_idx = root_idx + 1 {
          roots.push(@ir.hot_region_get(func, arm_ref, root_idx))
        }
        if roots.is_empty() {
          return None
        }
        Some(roots)
      }
      _ => None
    }
  }
  let wrapped_arm = fn(roots : Array[Int]) -> Array[Int] {
    let inner = @ir.hot_build_block(func, @lib.BlockType::void_(), roots)
    [@ir.hot_build_block(func, @lib.BlockType::void_(), [inner])]
  }
  let then_self = arm_without_self_branch(then_ref)
  let else_self = arm_without_self_branch(else_ref)
  if then_self == None && else_self == None {
    return false
  }
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, if_id, 0),
    match then_self {
      Some(roots) => wrapped_arm(roots)
      None => remove_unused_brs_region_roots(func, then_ref)
    },
    else_body=Some(
      match else_self {
        Some(roots) => wrapped_arm(roots)
        None => remove_unused_brs_region_roots(func, else_ref)
      },
    ),
  )
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [replacement])
  removed.push(block_id)
  removed.push(if_id)
  removed.push(then_ref.holder)
  removed.push(else_ref.holder)
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_try_flip_loop_eqz_backedge_if_to_else(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  let loop_label = match
    remove_unused_brs_region_enclosing_branch_target(func, region_ref) {
    Some(label_id) => label_id
    None => return false
  }
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let if_id = @ir.hot_region_get(func, region_ref, idx)
  if if_id < 0 || !@ir.hot_node_is_live(func, if_id) {
    return false
  }
  match @ir.hot_node_get(func, if_id).op {
    @ir.HotOp::If =>
      if @ir.hot_node_result_arity(func, if_id) != 0 {
        return false
      }
    _ => return false
  }
  match @ir.hot_region_else_ref(func, if_id) {
    Some(_) => return false
    None => ()
  }
  let if_label = @ir.hot_control_node_label(func, if_id)
  if remove_unused_brs_label_is_used(label_refs, if_label) {
    return false
  }
  let condition = @ir.hot_child_get(func, if_id, 0)
  match @ir.hot_node_get(func, condition).op {
    @ir.HotOp::Unary =>
      if @ir.hot_node_exact_instr(func, condition) !=
        Some(@lib.Instruction::i32_eqz()) {
        return false
      }
    _ => return false
  }
  if @ir.hot_child_count(func, condition) != 1 {
    return false
  }
  let then_ref = @ir.hot_region_then_ref(func, if_id)
  let then_count = @ir.hot_region_root_count(func, then_ref)
  if then_count == 0 {
    return false
  }
  let moved_delete : Array[Int] = []
  let mut moved_ref = then_ref
  if then_count == 1 {
    let wrapper_id = @ir.hot_region_get(func, then_ref, 0)
    if wrapper_id >= 0 && @ir.hot_node_is_live(func, wrapper_id) {
      match @ir.hot_node_get(func, wrapper_id).op {
        @ir.HotOp::Block =>
          if @ir.hot_node_result_arity(func, wrapper_id) == 0 {
            let wrapper_label = @ir.hot_control_node_label(func, wrapper_id)
            if !remove_unused_brs_label_is_used(label_refs, wrapper_label) {
              moved_ref = @ir.hot_region_body_ref(func, wrapper_id)
              moved_delete.push(wrapper_id)
            }
          }
        _ => ()
      }
    }
  }
  let moved_count = @ir.hot_region_root_count(func, moved_ref)
  if moved_count == 0 {
    return false
  }
  for root_idx = 0; root_idx < moved_count; root_idx = root_idx + 1 {
    let root_id = @ir.hot_region_get(func, moved_ref, root_idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      return false
    }
    if @ir.hot_node_result_arity(func, root_id) != 0 {
      return false
    }
  }
  let moved_tail = @ir.hot_region_get(func, moved_ref, moved_count - 1)
  match @ir.hot_node_get(func, moved_tail).op {
    @ir.HotOp::Br if @ir.hot_branch_target(func, moved_tail) == Some(loop_label) &&
      @ir.hot_child_count(func, moved_tail) == 0 => ()
    _ => return false
  }
  let moved_roots = remove_unused_brs_region_roots(func, moved_ref)
  let empty_exit = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
  let replacement = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_child_get(func, condition, 0),
    [empty_exit],
    else_body=Some(moved_roots),
  )
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [replacement])
  removed.push(if_id)
  removed.push(then_ref.holder)
  removed.push(condition)
  for node_id in moved_delete {
    removed.push(node_id)
  }
  remove_unused_brs_delete_unused_nodes(ctx, func, removed)
  true
}

///|
fn remove_unused_brs_try_move_loop_backedge_suffix_into_block_exit_br_if(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_refs : Array[Int],
) -> Bool {
  let loop_label = match
    remove_unused_brs_region_enclosing_branch_target(func, region_ref) {
    Some(label_id) => label_id
    None => return false
  }
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_label = @ir.hot_control_node_label(func, block_id)
  if block_label < 0 ||
    block_label >= label_refs.length() ||
    label_refs[block_label] != 1 {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count <= 1 {
    return false
  }
  let tail_id = @ir.hot_region_get(func, body_ref, root_count - 1)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return false
  }
  match @ir.hot_node_get(func, tail_id).op {
    @ir.HotOp::Br if @ir.hot_branch_target(func, tail_id) == Some(loop_label) &&
      @ir.hot_child_count(func, tail_id) == 0 => ()
    _ => return false
  }
  let mut scan_idx = root_count - 2
  while scan_idx >= 0 {
    let candidate_id = @ir.hot_region_get(func, body_ref, scan_idx)
    if candidate_id < 0 || !@ir.hot_node_is_live(func, candidate_id) {
      return false
    }
    match @ir.hot_node_get(func, candidate_id).op {
      @ir.HotOp::BrIf if @ir.hot_branch_target(func, candidate_id) ==
        Some(block_label) &&
        @ir.hot_child_count(func, candidate_id) == 1 => {
        let suffix_roots : Array[Int] = []
        for suffix_idx = scan_idx + 1
            suffix_idx < root_count
            suffix_idx = suffix_idx + 1 {
          let suffix_id = @ir.hot_region_get(func, body_ref, suffix_idx)
          if suffix_id < 0 || !@ir.hot_node_is_live(func, suffix_id) {
            return false
          }
          if suffix_idx < root_count - 1 {
            if @ir.hot_node_result_arity(func, suffix_id) != 0 {
              return false
            }
            if @ir.cfg_terminator_edge_kinds(
                @ir.hot_node_get(func, suffix_id).op,
              ).length() >
              0 {
              return false
            }
          }
          suffix_roots.push(suffix_id)
        }
        if suffix_roots.is_empty() {
          return false
        }
        let empty_exit = @ir.hot_build_block(func, @lib.BlockType::void_(), [])
        let replacement = @ir.hot_build_if(
          func,
          @lib.BlockType::void_(),
          @ir.hot_child_get(func, candidate_id, 0),
          [empty_exit],
          else_body=Some(suffix_roots),
        )
        let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [
          replacement,
        ])
        removed.push(block_id)
        removed.push(candidate_id)
        remove_unused_brs_delete_unused_nodes(ctx, func, removed)
        return true
      }
      _ => {
        if @ir.cfg_terminator_edge_kinds(
            @ir.hot_node_get(func, candidate_id).op,
          ).length() >
          0 {
          return false
        }
        if scan_idx == 0 {
          return false
        }
        scan_idx = scan_idx - 1
        continue
      }
    }
  }
  false
}

///|
fn remove_unused_brs_try_flip_single_loop_adjacent_br_if_backedge(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, block_body_ref) != 1 {
    return false
  }
  let loop_id = @ir.hot_region_get(func, block_body_ref, 0)
  if loop_id < 0 || !@ir.hot_node_is_live(func, loop_id) {
    return false
  }
  match @ir.hot_node_get(func, loop_id).op {
    @ir.HotOp::Loop =>
      if @ir.hot_node_result_arity(func, loop_id) != 0 {
        return false
      }
    _ => return false
  }
  let loop_label = @ir.hot_control_node_label(func, loop_id)
  let loop_body_ref = @ir.hot_region_body_ref(func, loop_id)
  if @ir.hot_region_root_count(func, loop_body_ref) != 2 {
    return false
  }
  let br_if_id = @ir.hot_region_get(func, loop_body_ref, 0)
  let backedge_id = @ir.hot_region_get(func, loop_body_ref, 1)
  if br_if_id < 0 ||
    backedge_id < 0 ||
    !@ir.hot_node_is_live(func, br_if_id) ||
    !@ir.hot_node_is_live(func, backedge_id) {
    return false
  }
  let br_if_node = @ir.hot_node_get(func, br_if_id)
  match br_if_node.op {
    @ir.HotOp::BrIf => ()
    _ => return false
  }
  if @ir.hot_child_count(func, br_if_id) != 1 {
    return false
  }
  let exit_label = match @ir.hot_branch_target(func, br_if_id) {
    Some(label_id) => label_id
    None => return false
  }
  if exit_label == loop_label {
    return false
  }
  let backedge_node = @ir.hot_node_get(func, backedge_id)
  match backedge_node.op {
    @ir.HotOp::Br if @ir.hot_branch_target(func, backedge_id) ==
      Some(loop_label) &&
      @ir.hot_child_count(func, backedge_id) == 0 => ()
    _ => return false
  }
  let inverted = remove_unused_brs_build_i32_eqz(
    func,
    @ir.hot_child_get(func, br_if_id, 0),
  )
  @ir.hot_child_set(func, br_if_id, 0, inverted)
  @ir.hot_branch_target_set(func, br_if_id, loop_label)
  @ir.hot_branch_target_set(func, backedge_id, exit_label)
  remove_unused_brs_mark_mutated(ctx, func, "flip-loop-adjacent-br-if")
  true
}

///|
fn remove_unused_brs_try_rotate_void_block_single_loop(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if idx < 0 || idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block =>
      if @ir.hot_node_result_arity(func, block_id) != 0 {
        return false
      }
    _ => return false
  }
  let block_body_ref = @ir.hot_region_body_ref(func, block_id)
  if @ir.hot_region_root_count(func, block_body_ref) != 1 {
    return false
  }
  let loop_id = @ir.hot_region_get(func, block_body_ref, 0)
  if loop_id < 0 || !@ir.hot_node_is_live(func, loop_id) {
    return false
  }
  match @ir.hot_node_get(func, loop_id).op {
    @ir.HotOp::Loop =>
      if @ir.hot_node_result_arity(func, loop_id) != 0 {
        return false
      }
    _ => return false
  }
  let loop_body_ref = @ir.hot_region_body_ref(func, loop_id)
  if !remove_unused_brs_tail_is_nonfallthrough(func, loop_body_ref) {
    return false
  }
  let loop_body_roots : Array[Int] = []
  for root_idx = 0
      root_idx < @ir.hot_region_root_count(func, loop_body_ref)
      root_idx = root_idx + 1 {
    loop_body_roots.push(@ir.hot_region_get(func, loop_body_ref, root_idx))
  }
  let work : Array[Int] = []
  for root in loop_body_roots {
    work.push(root)
  }
  while !work.is_empty() {
    let node_id = work.pop().unwrap()
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if @ir.hot_is_control_node(func, node_id) &&
      @ir.hot_node_result_arity(func, node_id) > 0 {
      return false
    }
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      work.push(@ir.hot_child_get(func, node_id, slot))
    }
  }
  let wrapped_body = @ir.hot_build_block(
    func,
    @lib.BlockType::void_(),
    loop_body_roots,
  )
  let unreachable_id = @ir.hot_build_unreachable(func)
  @ir.hot_region_replace_body(func, block_body_ref, [
    wrapped_body, unreachable_id,
  ])
  @ir.hot_region_replace_body(func, loop_body_ref, [block_id])
  ignore(@ir.hot_region_set(func, region_ref, idx, loop_id))
  remove_unused_brs_mark_mutated(ctx, func, "rewrite-loop-leading-break")
  true
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
fn remove_unused_brs_prepare_int_cache(
  cache : Array[Int],
  size : Int,
  fill : Int,
) -> Unit {
  while cache.length() < size {
    cache.push(fill)
  }
  for idx = 0; idx < size; idx = idx + 1 {
    cache[idx] = fill
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
  branch_payload_children : @bitset.BitSet,
  func_has_br_table : Bool,
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
        None,
        node_id,
        seen,
        reorder_cache,
        label_refs,
        branch_payload_children,
        func_has_br_table,
        payload_context,
        return_context &&
        (
          @ir.hot_node_result_arity(func, node_id) > 0 ||
          remove_unused_brs_subtree_has_return(func, node_id, return_cache)
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
        ctx, func, child_id, seen, reorder_cache, label_refs, branch_payload_children,
        func_has_br_table, child_payload_context, false, control_cache, return_cache,
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
  branch_payload_children : @bitset.BitSet,
  func_has_br_table : Bool,
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
        ctx, func, child_id, seen, reorder_cache, label_refs, branch_payload_children,
        func_has_br_table, false, false, control_cache, return_cache,
      ) ||
      changed
  }
  changed
}

///|
fn remove_unused_brs_visit_node(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  current_site : RemoveUnusedBrsRootSite?,
  node_id : Int,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  branch_payload_children : @bitset.BitSet,
  func_has_br_table : Bool,
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
          ctx, func, body_ref, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, return_context, control_cache, return_cache,
        ) ||
        changed
      if remove_unused_brs_try_rewrite_result_block_one_arm_payload_if(
          ctx, func, current_site, node_id, reorder_cache, label_refs, branch_payload_children,
        ) {
        return true
      }
      if remove_unused_brs_try_rewrite_result_block_prefix_payload_branch(
          ctx, func, body_ref, label_refs, branch_payload_children,
        ) {
        return true
      }
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
            changed = remove_unused_brs_try_voidify_tail_value_if_block_exit(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
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
          branch_payload_children,
          func_has_br_table,
          false,
          false,
          control_cache,
          return_cache,
        ) ||
        changed
      changed = remove_unused_brs_try_rewrite_condition_child_value_if_to_select(
          ctx, func, node_id, reorder_cache,
        ) ||
        changed
      let then_ref = @ir.hot_region_then_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, then_ref, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, return_context, control_cache, return_cache,
        ) ||
        changed
      let then_tail_id_for_return = remove_unused_brs_region_tail_id(
        func, then_ref,
      )
      if return_context && then_tail_id_for_return >= 0 {
        let then_tail_op = @ir.hot_node_get(func, then_tail_id_for_return).op
        match then_tail_op {
          @ir.HotOp::Return =>
            if remove_unused_brs_try_strip_return_context_tail(
                ctx, func, then_ref,
              ) {
              changed = true
            }
          _ => ()
        }
      }
      if payload_context && !return_context {
        if remove_unused_brs_try_rewrite_tail_value_if_branch_exit(
            ctx, func, then_ref, label_refs,
          ) {
          changed = true
        }
        if remove_unused_brs_try_rewrite_tail_value_if_simple_payload_arm(
            ctx, func, then_ref, label_refs,
          ) {
          changed = true
        }
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
            changed = remove_unused_brs_trim_trailing_nops(
                ctx,
                func,
                then_ref,
                preserve_single_if_arm_nop=true,
              ) ||
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
              ctx, func, else_ref, seen, reorder_cache, label_refs, branch_payload_children,
              func_has_br_table, return_context, control_cache, return_cache,
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
                if remove_unused_brs_try_strip_tail_if_exits(
                    ctx, func, else_ref,
                  ) {
                  changed = true
                }
                if remove_unused_brs_try_rewrite_one_sided_stack_tail_if_to_select(
                    ctx, func, else_ref, reorder_cache, label_refs,
                  ) {
                  changed = true
                }
              }
              @ir.HotOp::Return =>
                if remove_unused_brs_try_voidify_tail_return_if(
                    ctx, func, else_ref, label_refs,
                  ) {
                  changed = true
                }
              @ir.HotOp::Nop =>
                if remove_unused_brs_trim_trailing_nops(
                    ctx,
                    func,
                    else_ref,
                    preserve_single_if_arm_nop=true,
                  ) {
                  changed = true
                }
              _ => ()
            }
          }
          if else_tail_id >= 0 &&
            remove_unused_brs_region_has_removable_tail_target(func, else_ref) {
            if remove_unused_brs_try_remove_region_tail(
                ctx, func, else_ref, reorder_cache,
              ) {
              changed = true
            }
          }
        }
        None => ()
      }
      if payload_context &&
        remove_unused_brs_try_voidify_exit_only_value_if(ctx, func, node_id) {
        return true
      }
      if remove_unused_brs_try_rewrite_value_if_to_select(
          ctx, func, node_id, reorder_cache,
        ) {
        changed = true
      }
      if remove_unused_brs_try_merge_nested_if_conditions(
          ctx, func, node_id, reorder_cache,
        ) {
        changed = true
      }
      if remove_unused_brs_try_rewrite_if_br(ctx, func, node_id, reorder_cache) {
        changed = true
      }
    }
    @ir.HotOp::LocalSet =>
      for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, node_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        changed = remove_unused_brs_visit_embedded_subtree(
            ctx, func, child_id, seen, reorder_cache, label_refs, branch_payload_children,
            func_has_br_table, true, false, control_cache, return_cache,
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
            ctx, func, child_id, seen, reorder_cache, label_refs, branch_payload_children,
            func_has_br_table, true, false, control_cache, return_cache,
          ) ||
          changed
      }
    @ir.HotOp::Br | @ir.HotOp::BrIf | @ir.HotOp::BrTable | @ir.HotOp::Return => {
      let branch_like_op = @ir.hot_node_get(func, node_id).op
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
            ctx, func, child_id, seen, reorder_cache, label_refs, branch_payload_children,
            func_has_br_table, child_payload_context, child_return_context, control_cache,
            return_cache,
          ) ||
          changed
        match branch_like_op {
          @ir.HotOp::Return =>
            if slot == 0 && child_return_context {
              changed = remove_unused_brs_try_rewrite_return_child_if_branch_exit(
                  ctx, func, child_id, label_refs,
                ) ||
                changed
            }
          _ => ()
        }
      }
    }
    @ir.HotOp::Try => {
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, return_context, control_cache, return_cache,
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
            changed = remove_unused_brs_try_voidify_tail_value_if_block_exit(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
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
              ctx, func, catch_ref, seen, reorder_cache, label_refs, branch_payload_children,
              func_has_br_table, return_context, control_cache, return_cache,
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
      if remove_unused_brs_try_rewrite_caught_throws_in_node(
          ctx,
          func,
          node_id,
          [],
        ) {
        return true
      }
      let body_ref = @ir.hot_region_body_ref(func, node_id)
      changed = remove_unused_brs_visit_region(
          ctx, func, body_ref, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, return_context, control_cache, return_cache,
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
            changed = remove_unused_brs_try_voidify_tail_value_if_block_exit(
                ctx, func, body_ref, label_refs,
              ) ||
              changed
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
          ctx, func, catch_list_ref, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, return_context, control_cache, return_cache,
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
          ctx, func, node_id, seen, reorder_cache, label_refs, branch_payload_children,
          func_has_br_table, control_cache, return_cache,
        ) ||
        changed
  }
  changed
}

///|
fn remove_unused_brs_find_region_root_index(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  node_id : Int,
) -> Int {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if @ir.hot_region_get(func, region_ref, idx) == node_id {
      return idx
    }
  }
  -1
}

///|
fn remove_unused_brs_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  seen : Array[Int],
  reorder_cache : Array[Int],
  label_refs : Array[Int],
  branch_payload_children : @bitset.BitSet,
  func_has_br_table : Bool,
  return_context : Bool,
  control_cache : Array[Int],
  return_cache : Array[Int],
) -> Bool {
  if remove_unused_brs_prune_dead_suffix_after_nonfallthrough(
      ctx, func, region_ref, label_refs,
    ) {
    return true
  }
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
    let current_idx = remove_unused_brs_find_region_root_index(
      func, region_ref, node_id,
    )
    if current_idx < 0 {
      continue
    }
    if remove_unused_brs_try_rewrite_gc_br_on_root(
        ctx, func, region_ref, current_idx,
      ) {
      changed = true
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::BrIf => {
        if remove_unused_brs_try_fold_constant_br_if(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_merge_adjacent_br_ifs(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_br_if_eq_ladder_to_br_table(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
      }
      @ir.HotOp::BrTable =>
        if remove_unused_brs_try_optimize_switch(
            ctx, func, region_ref, current_idx, reorder_cache,
          ) {
          changed = true
          continue
        }
      _ => ()
    }
    if !remove_unused_brs_subtree_has_embedded_control(
        func, node_id, control_cache,
      ) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => {
        if remove_unused_brs_try_drop_void_self_branch_block(ctx, func, node_id) {
          changed = true
          continue
        }
        if remove_unused_brs_try_thread_jump_through_block(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_branches_to_trap_block(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_sink_single_if_exit_block(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_sink_if_arm_self_branch_block(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_inline_single_br_if_block(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_drop_self_targeting_br_table_block(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_br_table_continuation_wrappers(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          return true
        }
        if remove_unused_brs_try_rewrite_block_prefix_payload_branch_root(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_move_loop_backedge_suffix_into_block_exit_br_if(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_flip_single_loop_adjacent_br_if_backedge(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rotate_void_block_single_loop(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_restructure_self_branch_block_prefix(
            ctx, func, region_ref, current_idx, label_refs, reorder_cache,
          ) {
          changed = true
          continue
        }
      }
      @ir.HotOp::Drop =>
        if remove_unused_brs_try_rewrite_drop_result_block_if_tail_branch(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
      @ir.HotOp::Br =>
        if remove_unused_brs_try_rewrite_branch_payload_if(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
      @ir.HotOp::If => {
        if remove_unused_brs_try_flip_loop_eqz_backedge_if_to_else(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_invert_empty_then_if(
            ctx, func, node_id, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_voidify_if_block_exit_unreachable_suffix(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_restructure_one_exit_arm_if_suffix(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_restructure_one_arm_return_if_suffix(
            ctx, func, region_ref, current_idx, label_refs,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_prefixed_one_arm_payload_branch_if_suffix(
            ctx, func, region_ref, current_idx, label_refs, reorder_cache,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_one_arm_payload_branch_if(
            ctx, func, region_ref, current_idx, label_refs, func_has_br_table,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_two_arm_branch_if(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
      }
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
        if remove_unused_brs_try_rewrite_region_local_set_br_arm(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
        if remove_unused_brs_try_rewrite_region_local_set_copy_arm(
            ctx, func, region_ref, current_idx,
          ) {
          changed = true
          continue
        }
      }
      _ => ()
    }
    let node_return_context = return_context && idx == roots.length() - 1
    changed = remove_unused_brs_visit_node(
        ctx,
        func,
        Some({ region_ref, idx: current_idx }),
        node_id,
        seen,
        reorder_cache,
        label_refs,
        branch_payload_children,
        func_has_br_table,
        false,
        node_return_context,
        control_cache,
        return_cache,
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
  let skip_summary = remove_unused_brs_collect_hot_void_return_ladder_summary(
    func,
  )
  if remove_unused_brs_can_skip_large_br_table_return_ladder(skip_summary) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=large-br-table-return-ladder-noop",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_can_skip_large_tagged_result_prefix_ladder(skip_summary) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=large-tagged-result-prefix-ladder-noop",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_can_skip_medium_branchy_block_ladder(skip_summary) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=medium-branchy-block-ladder-noop",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_can_skip_call_heavy_mixed_if_mesh(skip_summary) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=call-heavy-mixed-if-mesh-noop",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_can_skip_localset_heavy_value_if_mesh(skip_summary) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=localset-heavy-value-if-mesh-noop",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_can_skip_large_void_return_ladder(skip_summary) {
    let reason = if @ir.hot_local_count(func) >= 20 &&
      @ir.hot_local_count(func) <= 40 {
      "nested-constructor-return-ladder-noop"
    } else {
      "large-void-if-return-ladder-noop"
    }
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=\{reason}",
    )
    return HotPassResult::unchanged()
  }
  if remove_unused_brs_region_has_result_local_set_stack_hazard(
      func,
      @ir.HotRegionRef::root(),
    ) {
    pipeline_trace_hook(
      ctx.trace,
      ctx.descriptor.name,
      "skip-hot",
      payload="reason=result-local-set-stack-hazard-noop",
    )
    return HotPassResult::unchanged()
  }
  let mut any_changed = false
  let mut changed = true
  let mut cycles = 0
  let seen : Array[Int] = []
  let reorder_cache : Array[Int] = []
  let control_cache : Array[Int] = []
  let return_cache : Array[Int] = []
  while changed && cycles < 8 {
    cycles += 1
    changed = false
    let node_count = @ir.hot_node_count(func)
    remove_unused_brs_prepare_int_cache(seen, node_count, 0)
    remove_unused_brs_prepare_int_cache(reorder_cache, node_count, -1)
    remove_unused_brs_prepare_int_cache(control_cache, node_count, -1)
    remove_unused_brs_prepare_int_cache(return_cache, node_count, -1)
    let cycle_scan = remove_unused_brs_compute_cycle_scan(func)
    let label_refs = cycle_scan.label_refs
    changed = remove_unused_brs_visit_region(
        ctx,
        func,
        @ir.HotRegionRef::root(),
        seen,
        reorder_cache,
        label_refs,
        cycle_scan.branch_payload_children,
        cycle_scan.has_br_table,
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
    changed = remove_unused_brs_try_tail_loop_return_to_fallthrough(
        ctx,
        func,
        @ir.HotRegionRef::root(),
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
    changed = remove_unused_brs_simplify_dead_local_tees(ctx, func) || changed
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
