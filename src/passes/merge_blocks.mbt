///|
pub fn merge_blocks_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("merge-blocks", invalidates=[
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
pub fn merge_blocks_summary() -> String {
  "Flatten branch-free block roots into their parent regions to expose later branch cleanup."
}

///|
fn merge_blocks_has_candidate(func : @ir.HotFunc) -> Bool {
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::Block => return true
      _ => ()
    }
  }
  false
}

///|
fn merge_blocks_compute_label_used(func : @ir.HotFunc) -> @bitset.BitSet {
  let label_used = @bitset.BitSet::new(func.labels.length())
  let mark_label = fn(label_id : Int) {
    if label_id >= 0 && label_id < label_used.length() {
      label_used[label_id] = true
    }
  }
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Br
      | @ir.HotOp::BrIf
      | @ir.HotOp::BrOnNull
      | @ir.HotOp::BrOnNonNull
      | @ir.HotOp::BrOnCast
      | @ir.HotOp::BrOnCastFail
      | @ir.HotOp::Delegate => mark_label(node.imm0)
      @ir.HotOp::BrTable => {
        mark_label(@ir.hot_branch_table_default_target(func, node.imm0))
        for label_id in @ir.hot_branch_table_targets(func, node.imm0) {
          mark_label(label_id)
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
          mark_label(label_id)
        }
      }
      _ => ()
    }
  }
  label_used
}

///|
fn merge_blocks_label_is_used(
  label_id : Int,
  label_used : @bitset.BitSet,
) -> Bool {
  label_id >= 0 && label_id < label_used.length() && label_used[label_id]
}

///|
fn merge_blocks_collect_region_roots(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  roots : Array[Int],
) -> Unit {
  roots.clear()
  let root_count = @ir.hot_region_root_count(func, region_ref)
  for idx = 0; idx < root_count; idx = idx + 1 {
    roots.push(@ir.hot_region_get(func, region_ref, idx))
  }
}

///|
fn merge_blocks_control_block_type(
  func : @ir.HotFunc,
  node_id : Int,
) -> @lib.BlockType? {
  match @ir.hot_type_get(func, @ir.hot_node_get(func, node_id).ty) {
    @ir.HotTypeInfo::BlockResult(block_type)
    | @ir.HotTypeInfo::BlockResultResolved(block_type, _, _) => Some(block_type)
    _ => None
  }
}

///|
fn merge_blocks_block_param_count(
  func : @ir.HotFunc,
  node_id : Int,
  module_ctx : @ir.HotModuleContext?,
) -> Int {
  match merge_blocks_control_block_type(func, node_id) {
    Some(@lib.TypeIdxBlockType(type_idx)) =>
      match module_ctx {
        Some(ctx) =>
          match @ir.hot_module_resolve_type_func_type(ctx, type_idx) {
            Some(@lib.FuncType(params, _)) => params.length()
            None => 1
          }
        None => 1
      }
    _ => 0
  }
}

///|
fn merge_blocks_block_has_params(
  func : @ir.HotFunc,
  node_id : Int,
  module_ctx : @ir.HotModuleContext?,
) -> Bool {
  merge_blocks_block_param_count(func, node_id, module_ctx) > 0
}

///|
fn merge_blocks_rewrite_dead_unreachable_suffix_roots(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  roots : Array[Int],
) -> Bool {
  ignore(use_def)
  if roots.length() == 0 {
    return true
  }
  let rewrite_dead_values_before = fn(unreachable_idx : Int) -> Bool {
    if unreachable_idx < 0 || unreachable_idx >= roots.length() {
      return true
    }
    let rewritten : Array[Int] = []
    for idx = 0; idx < unreachable_idx; idx = idx + 1 {
      rewritten.push(roots[idx])
    }
    for idx = unreachable_idx + 1; idx < roots.length(); idx = idx + 1 {
      let root_id = roots[idx]
      if @ir.hot_node_result_arity(func, root_id) != 1 {
        return false
      }
      rewritten.push(@ir.hot_build_drop(func, root_id))
    }
    rewritten.push(roots[unreachable_idx])
    roots.clear()
    for root_id in rewritten {
      roots.push(root_id)
    }
    true
  }
  match @ir.hot_node_get(func, roots[roots.length() - 1]).op {
    @ir.HotOp::Unreachable =>
      return rewrite_dead_values_before(roots.length() - 1)
    _ => ()
  }
  for idx = 0; idx < roots.length(); idx = idx + 1 {
    match @ir.hot_node_get(func, roots[idx]).op {
      @ir.HotOp::Unreachable => return rewrite_dead_values_before(idx)
      _ => ()
    }
  }
  true
}

///|
fn merge_blocks_visit_control_node(
  func : @ir.HotFunc,
  node_id : Int,
  label_used : @bitset.BitSet,
  flattened_roots : Array[Int],
  module_ctx : @ir.HotModuleContext?,
  use_def : @ir.HotUseDef,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  let control_has_params = merge_blocks_block_has_params(
    func, node_id, module_ctx,
  )
  let control_is_loop = match node.op {
    @ir.HotOp::Loop => true
    _ => false
  }
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      merge_blocks_visit_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        control_has_params,
        control_is_loop,
        use_def,
      )
    @ir.HotOp::If => {
      let mut changed = merge_blocks_visit_region(
        func,
        @ir.hot_region_then_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        false,
        false,
        use_def,
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = merge_blocks_visit_region(
              func, else_region, label_used, flattened_roots, module_ctx, false,
              false, use_def,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::Try => {
      let mut changed = merge_blocks_visit_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        control_has_params,
        false,
        use_def,
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = merge_blocks_visit_region(
              func, catch_region, label_used, flattened_roots, module_ctx, control_has_params,
              false, use_def,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::TryTable => {
      let changed = merge_blocks_visit_region(
        func,
        @ir.hot_region_body_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        control_has_params,
        false,
        use_def,
      )
      merge_blocks_visit_region(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        control_has_params,
        false,
        use_def,
      ) ||
      changed
    }
    _ => false
  }
}

///|
fn merge_blocks_flatten_region_root_block(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
  flattened_roots : Array[Int],
  module_ctx : @ir.HotModuleContext?,
  enclosing_control_has_params : Bool,
  enclosing_control_is_loop : Bool,
  use_def : @ir.HotUseDef,
) -> Bool {
  let block_id = @ir.hot_region_get(func, region_ref, idx)
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  let node = @ir.hot_node_get(func, block_id)
  match node.op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let label_id = @ir.hot_control_node_label(func, block_id)
  if merge_blocks_label_is_used(label_id, label_used) {
    return false
  }
  let param_count = merge_blocks_block_param_count(func, block_id, module_ctx)
  let result_count = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, block_id),
  ).length()
  if param_count > 0 &&
    (
      !enclosing_control_has_params ||
      (param_count != 1 && !(enclosing_control_is_loop && result_count == 0))
    ) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  merge_blocks_collect_region_roots(func, body_ref, flattened_roots)
  if !merge_blocks_rewrite_dead_unreachable_suffix_roots(
      func, use_def, flattened_roots,
    ) {
    return false
  }
  ignore(@ir.hot_region_splice(func, region_ref, idx, 1, flattened_roots))
  @ir.hot_region_replace_body(func, body_ref, [])
  true
}

///|
fn merge_blocks_visit_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  label_used : @bitset.BitSet,
  flattened_roots : Array[Int],
  module_ctx : @ir.HotModuleContext?,
  enclosing_control_has_params : Bool,
  enclosing_control_is_loop : Bool,
  use_def : @ir.HotUseDef,
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      changed = merge_blocks_visit_control_node(
          func, node_id, label_used, flattened_roots, module_ctx, use_def,
        ) ||
        changed
    }
    if merge_blocks_flatten_region_root_block(
        func, region_ref, idx, label_used, flattened_roots, module_ctx, enclosing_control_has_params,
        enclosing_control_is_loop, use_def,
      ) {
      changed = true
    } else {
      idx += 1
    }
  }
  changed
}

///|
fn merge_blocks_run(ctx : HotPassContext, func : @ir.HotFunc) -> HotPassResult {
  if !merge_blocks_has_candidate(func) {
    return HotPassResult::unchanged()
  }
  let label_used = merge_blocks_compute_label_used(func)
  let use_def = @ir.use_def_build_node_uses(func)
  let flattened_roots : Array[Int] = []
  if !merge_blocks_visit_region(
      func,
      @ir.HotRegionRef::root(),
      label_used,
      flattened_roots,
      ctx.module_ctx,
      false,
      false,
      use_def,
    ) {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
