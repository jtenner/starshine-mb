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
fn merge_blocks_region_contains_loop(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
      continue
    }
    let node = @ir.hot_node_get(func, root_id)
    match node.op {
      @ir.HotOp::Loop => return true
      @ir.HotOp::Block =>
        if merge_blocks_region_contains_loop(
            func,
            @ir.hot_region_body_ref(func, root_id),
          ) {
          return true
        }
      @ir.HotOp::If => {
        if merge_blocks_region_contains_loop(
            func,
            @ir.hot_region_then_ref(func, root_id),
          ) {
          return true
        }
        match @ir.hot_region_else_ref(func, root_id) {
          Some(else_ref) =>
            if merge_blocks_region_contains_loop(func, else_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::Try => {
        if merge_blocks_region_contains_loop(
            func,
            @ir.hot_region_body_ref(func, root_id),
          ) {
          return true
        }
        match @ir.hot_region_catch_ref(func, root_id) {
          Some(catch_ref) =>
            if merge_blocks_region_contains_loop(func, catch_ref) {
              return true
            }
          None => ()
        }
      }
      @ir.HotOp::TryTable =>
        if merge_blocks_region_contains_loop(
            func,
            @ir.hot_region_body_ref(func, root_id),
          ) ||
          merge_blocks_region_contains_loop(
            func,
            @ir.hot_region_catch_list_ref(func, root_id),
          ) {
          return true
        }
      _ => ()
    }
  }
  false
}

///|
fn merge_blocks_rewrite_dead_unreachable_suffix_roots(
  func : @ir.HotFunc,
  roots : Array[Int],
) -> Bool {
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
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = merge_blocks_visit_region(
              func, else_region, label_used, flattened_roots, module_ctx, false,
              false,
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
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = merge_blocks_visit_region(
              func, catch_region, label_used, flattened_roots, module_ctx, control_has_params,
              false,
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
      )
      merge_blocks_visit_region(
        func,
        @ir.hot_region_catch_list_ref(func, node_id),
        label_used,
        flattened_roots,
        module_ctx,
        control_has_params,
        false,
      ) ||
      changed
    }
    _ => false
  }
}

///|
fn merge_blocks_can_lift_block_child(
  func : @ir.HotFunc,
  block_id : Int,
  label_used : @bitset.BitSet,
  module_ctx : @ir.HotModuleContext?,
) -> Bool {
  if block_id < 0 || !@ir.hot_node_is_live(func, block_id) {
    return false
  }
  match @ir.hot_node_get(func, block_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if pass_label_is_used(@ir.hot_control_node_label(func, block_id), label_used) {
    return false
  }
  if merge_blocks_block_has_params(func, block_id, module_ctx) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if merge_blocks_region_contains_loop(func, body_ref) {
    return false
  }
  let root_count = @ir.hot_region_root_count(func, body_ref)
  if root_count < 2 {
    return false
  }
  let tail_id = @ir.hot_region_get(func, body_ref, root_count - 1)
  if @ir.hot_node_result_arity(func, tail_id) != 1 {
    return false
  }
  let block_results = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, block_id),
  )
  let tail_results = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, tail_id),
  )
  block_results == tail_results && block_results.length() == 1
}

///|
fn merge_blocks_lift_expression_block_children(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  label_used : @bitset.BitSet,
  module_ctx : @ir.HotModuleContext?,
) -> Int {
  let root_id = @ir.hot_region_get(func, region_ref, idx)
  if root_id < 0 || !@ir.hot_node_is_live(func, root_id) {
    return 0
  }
  let root_node = @ir.hot_node_get(func, root_id)
  match root_node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      return 0
    _ => ()
  }
  let child_count = @ir.hot_child_count(func, root_id)
  if child_count == 0 {
    return 0
  }
  let mut previous_effects = 0U
  let lifted_prefixes : Array[Int] = []
  let next_children : Array[Int] = []
  let mut changed = false
  for slot = 0; slot < child_count; slot = slot + 1 {
    match root_node.op {
      @ir.HotOp::If if slot != 0 => {
        next_children.push(@ir.hot_child_get(func, root_id, slot))
        continue
      }
      _ => ()
    }
    let child_id = @ir.hot_child_get(func, root_id, slot)
    if merge_blocks_can_lift_block_child(func, child_id, label_used, module_ctx) {
      let body_ref = @ir.hot_region_body_ref(func, child_id)
      let root_count = @ir.hot_region_root_count(func, body_ref)
      let tail_id = @ir.hot_region_get(func, body_ref, root_count - 1)
      let prefix : Array[Int] = []
      let mut prefix_effects = 0U
      let mut prefix_has_branch = false
      for prefix_idx = 0
          prefix_idx < root_count - 1
          prefix_idx = prefix_idx + 1 {
        let prefix_id = @ir.hot_region_get(func, body_ref, prefix_idx)
        prefix.push(prefix_id)
        prefix_effects = prefix_effects | @ir.effects_for_node(func, prefix_id)
        if merge_blocks_node_has_branch(func, prefix_id) {
          prefix_has_branch = true
        }
      }
      if !prefix_has_branch &&
        (
          @ir.effects_is_pure(prefix_effects) ||
          @ir.effects_is_pure(previous_effects)
        ) {
        for prefix_id in prefix {
          lifted_prefixes.push(prefix_id)
        }
        next_children.push(tail_id)
        @ir.hot_region_replace_body(func, body_ref, [])
        previous_effects = previous_effects |
          @ir.effects_for_node(func, tail_id)
        changed = true
        continue
      }
    }
    next_children.push(child_id)
    previous_effects = previous_effects | @ir.effects_for_node(func, child_id)
  }
  if !changed || lifted_prefixes.length() == 0 {
    return 0
  }
  ignore(@ir.hot_replace_child_span(func, root_id, next_children))
  ignore(@ir.hot_region_splice(func, region_ref, idx, 0, lifted_prefixes))
  lifted_prefixes.length()
}

///|
fn merge_blocks_node_has_branch(func : @ir.HotFunc, node_id : Int) -> Bool {
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
    | @ir.HotOp::Delegate => return true
    @ir.HotOp::Block | @ir.HotOp::Loop | @ir.HotOp::Try =>
      if merge_blocks_region_has_branch(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
    @ir.HotOp::If => {
      if merge_blocks_region_has_branch(
          func,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_ref) =>
          if merge_blocks_region_has_branch(func, else_ref) {
            return true
          }
        None => ()
      }
    }
    @ir.HotOp::TryTable =>
      if merge_blocks_region_has_branch(
          func,
          @ir.hot_region_body_ref(func, node_id),
        ) ||
        merge_blocks_region_has_branch(
          func,
          @ir.hot_region_catch_list_ref(func, node_id),
        ) {
        return true
      }
    _ => ()
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    if merge_blocks_node_has_branch(
        func,
        @ir.hot_child_get(func, node_id, slot),
      ) {
      return true
    }
  }
  false
}

///|
fn merge_blocks_region_has_branch(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    if merge_blocks_node_has_branch(
        func,
        @ir.hot_region_get(func, region_ref, idx),
      ) {
      return true
    }
  }
  false
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
  let result_count = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, block_id),
  ).length()
  if pass_label_is_used(label_id, label_used) {
    // Keep live-label blocks intact. Pulling prefixes out of a block that is
    // still a branch target can change the active label stack seen by branches
    // nested in later roots and make lowering emit branches with the wrong
    // result arity.
    return false
  }
  let param_count = merge_blocks_block_param_count(func, block_id, module_ctx)
  if param_count > 0 &&
    (
      !enclosing_control_has_params ||
      (param_count != 1 && !(enclosing_control_is_loop && result_count == 0))
    ) {
    return false
  }
  let body_ref = @ir.hot_region_body_ref(func, block_id)
  if merge_blocks_region_contains_loop(func, body_ref) {
    return false
  }
  merge_blocks_collect_region_roots(func, body_ref, flattened_roots)
  if !merge_blocks_rewrite_dead_unreachable_suffix_roots(func, flattened_roots) {
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
) -> Bool {
  let mut changed = false
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      changed = merge_blocks_visit_control_node(
          func, node_id, label_used, flattened_roots, module_ctx,
        ) ||
        changed
    }
    let lifted_count = merge_blocks_lift_expression_block_children(
      func, region_ref, idx, label_used, module_ctx,
    )
    if lifted_count > 0 {
      changed = true
      idx += lifted_count
    }
    if merge_blocks_flatten_region_root_block(
        func, region_ref, idx, label_used, flattened_roots, module_ctx, enclosing_control_has_params,
        enclosing_control_is_loop,
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
  let label_used = pass_compute_label_used(func)
  let flattened_roots : Array[Int] = []
  if !merge_blocks_visit_region(
      func,
      @ir.HotRegionRef::root(),
      label_used,
      flattened_roots,
      ctx.module_ctx,
      false,
      false,
    ) {
    return HotPassResult::unchanged()
  }
  pass_mark_mutated(ctx, func)
  HotPassResult::changed()
}
