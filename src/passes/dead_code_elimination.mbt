///|
pub fn dead_code_elimination_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new("dead-code-elimination", requires=[], invalidates=[
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
pub fn dead_code_elimination_summary() -> String {
  "Prune unreachable tails, dead dropped values, and dead-result structured control in hot IR regions."
}

///|
priv struct DeadCodeEliminationNodeUseCache {
  mut revision : Int
  mut use_def : @ir.HotUseDef?
}

///|
priv struct DeadCodeEliminationFallthroughCache {
  revision : Array[Int]
  result : Array[Bool]
}

///|
priv struct DeadCodeEliminationBranchUserCache {
  mut has_any_branch : Bool?
  mut by_label : Array[Array[Int]]?
}

///|
priv struct DeadCodeEliminationPurityCache {
  revision : Array[Int]
  result : Array[Bool]
}

///|
fn DeadCodeEliminationNodeUseCache::new() -> DeadCodeEliminationNodeUseCache {
  { revision: -1, use_def: None }
}

///|
fn DeadCodeEliminationBranchUserCache::new() -> DeadCodeEliminationBranchUserCache {
  { has_any_branch: None, by_label: None }
}

///|
fn dead_code_elimination_new_fallthrough_cache(
  func : @ir.HotFunc,
) -> DeadCodeEliminationFallthroughCache {
  let revision : Array[Int] = []
  let result : Array[Bool] = []
  for _ in 0..<@ir.hot_node_count(func) {
    revision.push(-1)
    result.push(false)
  }
  { revision, result }
}

///|
fn dead_code_elimination_ensure_fallthrough_cache_capacity(
  cache : DeadCodeEliminationFallthroughCache,
  node_id : Int,
) -> Unit {
  while cache.revision.length() <= node_id {
    cache.revision.push(-1)
    cache.result.push(false)
  }
}

///|
fn dead_code_elimination_new_purity_cache(
  func : @ir.HotFunc,
) -> DeadCodeEliminationPurityCache {
  let revision : Array[Int] = []
  let result : Array[Bool] = []
  for _ in 0..<@ir.hot_node_count(func) {
    revision.push(-1)
    result.push(false)
  }
  { revision, result }
}

///|
fn dead_code_elimination_ensure_purity_cache_capacity(
  cache : DeadCodeEliminationPurityCache,
  node_id : Int,
) -> Unit {
  while cache.revision.length() <= node_id {
    cache.revision.push(-1)
    cache.result.push(false)
  }
}

///|
fn dead_code_elimination_flags_force_impure(flags : UInt) -> Bool {
  (flags & @ir.HOT_FLAG_CONTROL) != 0U ||
  (flags & @ir.HOT_FLAG_BRANCH) != 0U ||
  (flags & @ir.HOT_FLAG_TERMINATOR) != 0U ||
  (flags & @ir.HOT_FLAG_CALL) != 0U ||
  (flags & @ir.HOT_FLAG_THROWS) != 0U ||
  (flags & @ir.HOT_FLAG_HAS_EXCEPTIONAL_SUCC) != 0U ||
  (flags & @ir.HOT_FLAG_MAY_TRAP) != 0U
}

///|
fn dead_code_elimination_node_is_intrinsically_impure(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if dead_code_elimination_flags_force_impure(@ir.hot_node_flags(func, node_id)) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalGet
    | @ir.HotOp::LocalSet
    | @ir.HotOp::LocalTee
    | @ir.HotOp::GlobalGet
    | @ir.HotOp::GlobalSet
    | @ir.HotOp::Load
    | @ir.HotOp::Store
    | @ir.HotOp::MemorySize
    | @ir.HotOp::MemoryGrow
    | @ir.HotOp::MemoryCopy
    | @ir.HotOp::MemoryInit
    | @ir.HotOp::MemoryFill
    | @ir.HotOp::DataDrop
    | @ir.HotOp::TableGet
    | @ir.HotOp::TableSize
    | @ir.HotOp::TableSet
    | @ir.HotOp::TableGrow
    | @ir.HotOp::TableFill
    | @ir.HotOp::TableCopy
    | @ir.HotOp::TableInit
    | @ir.HotOp::ElemDrop
    | @ir.HotOp::Atomic
    | @ir.HotOp::Heap => true
    _ => false
  }
}

///|
fn dead_code_elimination_require_node_uses(
  cache : DeadCodeEliminationNodeUseCache,
  func : @ir.HotFunc,
) -> @ir.HotUseDef {
  let revision = @ir.hot_revision_current(func)
  match cache.use_def {
    Some(existing) if cache.revision == revision => existing
    _ => {
      let rebuilt = @ir.use_def_build_node_uses(func)
      cache.revision = revision
      cache.use_def = Some(rebuilt)
      rebuilt
    }
  }
}

///|
fn dead_code_elimination_node_use_count(
  cache : DeadCodeEliminationNodeUseCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  let use_def = dead_code_elimination_require_node_uses(cache, func)
  @ir.node_use_count(use_def, node_id)
}

///|
fn dead_code_elimination_collect_detached_nodes(
  func : @ir.HotFunc,
  node_id : Int,
  out : Array[Int],
  limit : Int,
) -> Unit {
  if out.length() > limit || node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return
  }
  out.push(node_id)
  if out.length() > limit {
    return
  }
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
      continue
    }
    dead_code_elimination_collect_detached_nodes(func, child_id, out, limit)
    if out.length() > limit {
      return
    }
  }
}

///|
fn dead_code_elimination_region_result_arity(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Int {
  if region_ref == @ir.HotRegionRef::root() {
    return -1
  }
  let holder = region_ref.holder
  match @ir.hot_node_get(func, holder).op {
    // Loop bodies fall through with the loop's result type, but their label
    // branch arity stays separate for continue-style branches.
    @ir.HotOp::Loop => @ir.hot_node_result_arity(func, holder)
    _ => @ir.hot_region_result_arity(func, region_ref)
  }
}

///|
fn dead_code_elimination_delete_unused_nodes(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  node_ids : Array[Int],
) -> Unit {
  // Large detached subgraphs do not affect lowered output once roots/child
  // edges are gone; eagerly collecting them here is disproportionately
  // expensive on real modules.
  if node_ids.length() > 32 {
    return
  }
  let node_count = @ir.hot_node_count(func)
  let candidates : Array[Int] = []
  let in_candidate : Array[Bool] = []
  let internal_refs : Array[Int] = []
  let external_refs : Array[Int] = []
  for idx = 0; idx < node_count; idx = idx + 1 {
    in_candidate.push(false)
    internal_refs.push(0)
    external_refs.push(0)
  }
  for node_id in node_ids {
    if node_id < 0 ||
      node_id >= node_count ||
      !@ir.hot_node_is_live(func, node_id) ||
      in_candidate[node_id] {
      continue
    }
    in_candidate[node_id] = true
    candidates.push(node_id)
  }
  if candidates.is_empty() {
    return
  }
  let node_uses = dead_code_elimination_require_node_uses(node_use_cache, func)
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    let owner = @ir.hot_label_owner(func, label_id)
    if owner >= 0 && owner < node_count && in_candidate[owner] {
      external_refs[owner] += 1
    }
  }
  for node_id in candidates {
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id >= 0 && child_id < node_count && in_candidate[child_id] {
        internal_refs[child_id] += 1
      }
    }
  }
  for node_id in candidates {
    for site in @ir.node_use_sites(node_uses, node_id) {
      let user_id = site.user
      if user_id < 0 || user_id >= node_count || !in_candidate[user_id] {
        external_refs[node_id] += 1
      }
    }
  }
  let ready = candidates.copy()
  let mut changed = false
  while !ready.is_empty() {
    let node_id = ready.pop().unwrap()
    if node_id < 0 ||
      node_id >= node_count ||
      !in_candidate[node_id] ||
      !@ir.hot_node_is_live(func, node_id) ||
      external_refs[node_id] != 0 ||
      internal_refs[node_id] != 0 {
      continue
    }
    let children : Array[Int] = []
    for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, node_id, slot)
      if child_id < 0 || child_id >= node_count || !in_candidate[child_id] {
        continue
      }
      children.push(child_id)
    }
    @ir.hot_delete_node(func, node_id)
    changed = true
    in_candidate[node_id] = false
    for child_id in children {
      internal_refs[child_id] -= 1
      if external_refs[child_id] == 0 && internal_refs[child_id] == 0 {
        ready.push(child_id)
      }
    }
  }
  if changed {
    pass_mark_mutated(ctx, func)
  }
}

///|
fn dead_code_elimination_node_is_pure(
  purity_cache : DeadCodeEliminationPurityCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let revision = @ir.hot_revision_current(func)
  dead_code_elimination_ensure_purity_cache_capacity(purity_cache, node_id)
  if purity_cache.revision[node_id] == revision {
    return purity_cache.result[node_id]
  }
  if dead_code_elimination_node_is_intrinsically_impure(func, node_id) {
    purity_cache.revision[node_id] = revision
    purity_cache.result[node_id] = false
    return false
  }
  let mut result = true
  for slot = 0; slot < @ir.hot_child_count(func, node_id); slot = slot + 1 {
    let child_id = @ir.hot_child_get(func, node_id, slot)
    if child_id >= 0 &&
      @ir.hot_node_is_live(func, child_id) &&
      !dead_code_elimination_node_is_pure(purity_cache, func, child_id) {
      result = false
      break
    }
  }
  purity_cache.revision[node_id] = revision
  purity_cache.result[node_id] = result
  result
}

///|
fn dead_code_elimination_drop_is_dead(
  purity_cache : DeadCodeEliminationPurityCache,
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Drop =>
      if @ir.hot_child_count(func, node_id) != 1 {
        return false
      }
    _ => return false
  }
  let child_id = @ir.hot_child_get(func, node_id, 0)
  child_id >= 0 &&
  @ir.hot_node_is_live(func, child_id) &&
  dead_code_elimination_node_is_pure(purity_cache, func, child_id)
}

///|
fn dead_code_elimination_record_branch_target(
  branch_users_by_label : Array[Array[Int]],
  last_seen_branch : Array[Int],
  branch_id : Int,
  target : Int,
) -> Unit {
  if target < 0 || target >= branch_users_by_label.length() {
    return
  }
  if last_seen_branch[target] == branch_id {
    return
  }
  last_seen_branch[target] = branch_id
  branch_users_by_label[target].push(branch_id)
}

///|
fn dead_code_elimination_build_branch_users_by_label(
  func : @ir.HotFunc,
) -> Array[Array[Int]] {
  let branch_users_by_label : Array[Array[Int]] = []
  let last_seen_branch : Array[Int] = []
  for label_id = 0; label_id < func.labels.length(); label_id = label_id + 1 {
    branch_users_by_label.push([])
    last_seen_branch.push(-1)
  }
  for branch_id = 0
      branch_id < @ir.hot_node_count(func)
      branch_id = branch_id + 1 {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    match @ir.hot_branch_target(func, branch_id) {
      Some(target) =>
        dead_code_elimination_record_branch_target(
          branch_users_by_label, last_seen_branch, branch_id, target,
        )
      _ => ()
    }
    for target in @ir.hot_branch_table_targets_for_node(func, branch_id) {
      dead_code_elimination_record_branch_target(
        branch_users_by_label, last_seen_branch, branch_id, target,
      )
    }
  }
  branch_users_by_label
}

///|
fn dead_code_elimination_build_empty_branch_users_by_label(
  func : @ir.HotFunc,
) -> Array[Array[Int]] {
  let branch_users_by_label : Array[Array[Int]] = []
  for _ in 0..<func.labels.length() {
    branch_users_by_label.push([])
  }
  branch_users_by_label
}

///|
fn dead_code_elimination_require_has_any_branch(
  cache : DeadCodeEliminationBranchUserCache,
  func : @ir.HotFunc,
) -> Bool {
  match cache.has_any_branch {
    Some(existing) => existing
    None => {
      let mut has_any_branch = false
      for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
        if @ir.hot_node_is_live(func, node_id) &&
          @ir.hot_node_has_flag(func, node_id, @ir.HOT_FLAG_BRANCH) {
          has_any_branch = true
          break
        }
      }
      cache.has_any_branch = Some(has_any_branch)
      has_any_branch
    }
  }
}

///|
fn dead_code_elimination_require_branch_users_by_label(
  cache : DeadCodeEliminationBranchUserCache,
  func : @ir.HotFunc,
) -> Array[Array[Int]] {
  match cache.by_label {
    Some(existing) => existing
    None => {
      let built = if dead_code_elimination_require_has_any_branch(cache, func) {
        dead_code_elimination_build_branch_users_by_label(func)
      } else {
        dead_code_elimination_build_empty_branch_users_by_label(func)
      }
      cache.by_label = Some(built)
      built
    }
  }
}

///|
fn dead_code_elimination_can_voidify_control(
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  node_id : Int,
) -> Bool {
  if @ir.hot_node_result_arity(func, node_id) == 0 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block =>
      dead_code_elimination_has_incoming_branches(
        dead_code_elimination_require_branch_users_by_label(
          branch_user_cache, func,
        ),
        @ir.hot_control_node_label(func, node_id),
      ) ||
      !dead_code_elimination_region_may_fallthrough(
        func,
        branch_user_cache,
        fallthrough_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::Loop =>
      @ir.hot_label_branch_arity(
        func,
        @ir.hot_control_node_label(func, node_id),
      ) ==
      0
    @ir.HotOp::If | @ir.HotOp::Try | @ir.HotOp::TryTable =>
      !dead_code_elimination_has_incoming_internal_region_branches(
        func,
        dead_code_elimination_require_branch_users_by_label(
          branch_user_cache, func,
        ),
        node_id,
      )
    _ => false
  }
}

///|
fn dead_code_elimination_has_incoming_branches(
  branch_users_by_label : Array[Array[Int]],
  label_id : Int,
) -> Bool {
  label_id >= 0 &&
  label_id < branch_users_by_label.length() &&
  !branch_users_by_label[label_id].is_empty()
}

///|
fn dead_code_elimination_region_has_incoming_branches(
  func : @ir.HotFunc,
  branch_users_by_label : Array[Array[Int]],
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() {
    return false
  }
  dead_code_elimination_has_incoming_branches(
    branch_users_by_label,
    @ir.hot_control_node_label(func, region_ref.holder),
  )
}

///|
fn dead_code_elimination_has_incoming_internal_region_branches(
  func : @ir.HotFunc,
  branch_users_by_label : Array[Array[Int]],
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => {
      let then_has_branches = dead_code_elimination_region_has_incoming_branches(
        func,
        branch_users_by_label,
        @ir.hot_region_then_ref(func, node_id),
      )
      let else_has_branches = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          dead_code_elimination_region_has_incoming_branches(
            func, branch_users_by_label, else_region,
          )
        None => false
      }
      then_has_branches || else_has_branches
    }
    @ir.HotOp::Try => {
      let body_has_branches = dead_code_elimination_region_has_incoming_branches(
        func,
        branch_users_by_label,
        @ir.hot_region_body_ref(func, node_id),
      )
      let catch_has_branches = match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          dead_code_elimination_region_has_incoming_branches(
            func, branch_users_by_label, catch_region,
          )
        None => false
      }
      body_has_branches || catch_has_branches
    }
    @ir.HotOp::TryTable =>
      dead_code_elimination_region_has_incoming_branches(
        func,
        branch_users_by_label,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      dead_code_elimination_region_has_incoming_branches(
        func,
        branch_users_by_label,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    _ => false
  }
}

///|
fn dead_code_elimination_op_has_fallthrough_edge(op : @ir.HotOp) -> Bool {
  match op {
    @ir.HotOp::Br
    | @ir.HotOp::BrTable
    | @ir.HotOp::Return
    | @ir.HotOp::Throw
    | @ir.HotOp::ThrowRef
    | @ir.HotOp::Rethrow
    | @ir.HotOp::Delegate
    | @ir.HotOp::Unreachable => false
    @ir.HotOp::BrIf
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail
    | @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => true
  }
}

///|
fn dead_code_elimination_region_may_fallthrough(
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let root_count = @ir.hot_region_root_count(func, region_ref)
  let mut idx = 0
  while idx < root_count {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 &&
      @ir.hot_node_is_live(func, node_id) &&
      !dead_code_elimination_node_may_fallthrough(
        func, branch_user_cache, fallthrough_cache, node_id,
      ) {
      return false
    }
    idx += 1
  }
  true
}

///|
fn dead_code_elimination_node_may_fallthrough(
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let revision = @ir.hot_revision_current(func)
  dead_code_elimination_ensure_fallthrough_cache_capacity(
    fallthrough_cache, node_id,
  )
  if fallthrough_cache.revision[node_id] == revision {
    return fallthrough_cache.result[node_id]
  }
  let result = dead_code_elimination_node_may_fallthrough_uncached(
    func, branch_user_cache, fallthrough_cache, node_id,
  )
  fallthrough_cache.revision[node_id] = revision
  fallthrough_cache.result[node_id] = result
  result
}

///|
fn dead_code_elimination_node_may_fallthrough_uncached(
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return true
  }
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block =>
      dead_code_elimination_has_incoming_branches(
        dead_code_elimination_require_branch_users_by_label(
          branch_user_cache, func,
        ),
        @ir.hot_control_node_label(func, node_id),
      ) ||
      dead_code_elimination_region_may_fallthrough(
        func,
        branch_user_cache,
        fallthrough_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::Loop =>
      dead_code_elimination_region_may_fallthrough(
        func,
        branch_user_cache,
        fallthrough_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
        branch_user_cache, func,
      )
      if dead_code_elimination_has_incoming_branches(
          branch_users_by_label,
          @ir.hot_control_node_label(func, node_id),
        ) {
        return true
      }
      if dead_code_elimination_region_may_fallthrough(
          func,
          branch_user_cache,
          fallthrough_cache,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          dead_code_elimination_region_may_fallthrough(
            func, branch_user_cache, fallthrough_cache, else_region,
          )
        None => true
      }
    }
    @ir.HotOp::Try => {
      let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
        branch_user_cache, func,
      )
      if dead_code_elimination_has_incoming_branches(
          branch_users_by_label,
          @ir.hot_control_node_label(func, node_id),
        ) {
        return true
      }
      if dead_code_elimination_region_may_fallthrough(
          func,
          branch_user_cache,
          fallthrough_cache,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          dead_code_elimination_region_may_fallthrough(
            func, branch_user_cache, fallthrough_cache, catch_region,
          )
        None => false
      }
    }
    @ir.HotOp::TryTable => {
      let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
        branch_user_cache, func,
      )
      dead_code_elimination_has_incoming_branches(
        branch_users_by_label,
        @ir.hot_control_node_label(func, node_id),
      ) ||
      dead_code_elimination_region_may_fallthrough(
        func,
        branch_user_cache,
        fallthrough_cache,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      dead_code_elimination_region_may_fallthrough(
        func,
        branch_user_cache,
        fallthrough_cache,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    }
    _ => dead_code_elimination_op_has_fallthrough_edge(node.op)
  }
}

///|
fn dead_code_elimination_branch_payload_count(
  func : @ir.HotFunc,
  node_id : Int,
) -> Int {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Br | @ir.HotOp::Delegate => node.child_count
    @ir.HotOp::BrIf
    | @ir.HotOp::BrTable
    | @ir.HotOp::BrOnNull
    | @ir.HotOp::BrOnNonNull
    | @ir.HotOp::BrOnCast
    | @ir.HotOp::BrOnCastFail =>
      if node.child_count == 0 {
        0
      } else {
        node.child_count - 1
      }
    _ => 0
  }
}

///|
fn dead_code_elimination_visit_node_regions(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  purity_cache : DeadCodeEliminationPurityCache,
  node_id : Int,
) -> Bool {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      dead_code_elimination_visit_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        fallthrough_cache,
        purity_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      let mut changed = dead_code_elimination_visit_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        fallthrough_cache,
        purity_cache,
        @ir.hot_region_then_ref(func, node_id),
      )
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          changed = dead_code_elimination_visit_region(
              ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
              else_region,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::Try => {
      let mut changed = dead_code_elimination_visit_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        fallthrough_cache,
        purity_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          changed = dead_code_elimination_visit_region(
              ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
              catch_region,
            ) ||
            changed
        None => ()
      }
      changed
    }
    @ir.HotOp::TryTable =>
      dead_code_elimination_visit_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        fallthrough_cache,
        purity_cache,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      dead_code_elimination_visit_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        fallthrough_cache,
        purity_cache,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    _ => false
  }
}

///|
fn dead_code_elimination_voidify_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  purity_cache : DeadCodeEliminationPurityCache,
  node_id : Int,
) -> Bool {
  if !dead_code_elimination_can_voidify_control(
      func, branch_user_cache, fallthrough_cache, node_id,
    ) {
    return false
  }
  let control_op = @ir.hot_node_get(func, node_id).op
  let is_loop = match control_op {
    @ir.HotOp::Loop => true
    _ => false
  }
  let label_id = @ir.hot_control_node_label(func, node_id)
  let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
    branch_user_cache, func,
  )
  if !is_loop &&
    dead_code_elimination_has_incoming_branches(branch_users_by_label, label_id) {
    return false
  }
  let detached : Array[Int] = []
  let branch_rewrites : Array[@ir.HotChildSpanRewrite] = []
  if !is_loop {
    if label_id < 0 || label_id >= branch_users_by_label.length() {
      return false
    }
    for branch_id in branch_users_by_label[label_id] {
      if !@ir.hot_node_is_live(func, branch_id) {
        continue
      }
      let payload_count = dead_code_elimination_branch_payload_count(
        func, branch_id,
      )
      if payload_count == 0 {
        continue
      }
      for slot = 0; slot < payload_count; slot = slot + 1 {
        let child_id = @ir.hot_child_get(func, branch_id, slot)
        if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
          continue
        }
        if !dead_code_elimination_node_is_pure(purity_cache, func, child_id) {
          return false
        }
        dead_code_elimination_collect_detached_nodes(
          func, child_id, detached, 32,
        )
        if detached.length() > 32 {
          break
        }
      }
      let new_children : Array[Int] = []
      if payload_count < @ir.hot_child_count(func, branch_id) {
        new_children.push(
          @ir.hot_child_get(
            func,
            branch_id,
            @ir.hot_child_count(func, branch_id) - 1,
          ),
        )
      }
      branch_rewrites.push(
        @ir.HotChildSpanRewrite::new(branch_id, new_children),
      )
    }
  }
  @ir.hot_replace_child_spans_and_control_result_type(
    func,
    node_id,
    @ir.hot_type_void(func),
    branch_rewrites,
  )
  pass_mark_mutated(ctx, func)
  dead_code_elimination_delete_unused_nodes(ctx, func, node_use_cache, detached)
  ignore(
    dead_code_elimination_visit_node_regions(
      ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
      node_id,
    ),
  )
  true
}

///|
fn dead_code_elimination_remove_roots(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  remove_count : Int,
) -> Bool {
  if remove_count <= 0 {
    return false
  }
  let removed_roots = pass_splice_region(
    ctx,
    func,
    region_ref,
    idx,
    remove_count,
    [],
  )
  let detached : Array[Int] = []
  for node_id in removed_roots {
    dead_code_elimination_collect_detached_nodes(func, node_id, detached, 32)
    if detached.length() > 32 {
      break
    }
  }
  dead_code_elimination_delete_unused_nodes(ctx, func, node_use_cache, detached)
  true
}

///|
fn dead_code_elimination_replace_root_with_child(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  child_id : Int,
) -> Bool {
  let removed = pass_splice_region(ctx, func, region_ref, idx, 1, [child_id])
  dead_code_elimination_delete_unused_nodes(ctx, func, node_use_cache, removed)
  true
}

///|
fn dead_code_elimination_needs_explicit_unreachable_tail(
  func : @ir.HotFunc,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    @ir.hot_node_result_arity(func, node_id) != 0 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable => true
    _ => false
  }
}

///|
fn dead_code_elimination_has_explicit_unreachable_tail(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  let tail_idx = idx + 1
  if tail_idx < 0 || tail_idx >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let tail_id = @ir.hot_region_get(func, region_ref, tail_idx)
  if tail_id < 0 || !@ir.hot_node_is_live(func, tail_id) {
    return false
  }
  match @ir.hot_node_get(func, tail_id).op {
    @ir.HotOp::Unreachable => true
    _ => false
  }
}

///|
fn dead_code_elimination_ensure_explicit_unreachable_tail(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
) -> Bool {
  if dead_code_elimination_has_explicit_unreachable_tail(func, region_ref, idx) {
    return false
  }
  ignore(
    pass_splice_region(ctx, func, region_ref, idx + 1, 0, [
      @ir.hot_build_unreachable(func),
    ]),
  )
  true
}

///|
fn dead_code_elimination_finish_nonfallthrough_final_root(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  node_id : Int,
) -> Bool {
  idx + 1 == @ir.hot_region_root_count(func, region_ref) &&
  dead_code_elimination_needs_explicit_unreachable_tail(func, node_id) &&
  !dead_code_elimination_node_may_fallthrough(
    func, branch_user_cache, fallthrough_cache, node_id,
  ) &&
  dead_code_elimination_ensure_explicit_unreachable_tail(
    ctx, func, region_ref, idx,
  )
}

///|
fn dead_code_elimination_visit_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  purity_cache : DeadCodeEliminationPurityCache,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut changed = false
  let result_arity = dead_code_elimination_region_result_arity(func, region_ref)
  let mut idx = 0
  while idx < @ir.hot_region_root_count(func, region_ref) {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
      idx += 1
      continue
    }

    changed = dead_code_elimination_visit_node_regions(
        ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
        node_id,
      ) ||
      changed

    if dead_code_elimination_drop_is_dead(purity_cache, func, node_id) {
      ignore(
        dead_code_elimination_remove_roots(
          ctx, func, node_use_cache, region_ref, idx, 1,
        ),
      )
      changed = true
      continue
    }

    let is_final_root = idx + 1 == @ir.hot_region_root_count(func, region_ref)
    let node_result_arity = @ir.hot_node_result_arity(func, node_id)
    let node_is_control = @ir.hot_is_control_node(func, node_id)
    let needs_unreachable_tail = dead_code_elimination_needs_explicit_unreachable_tail(
      func, node_id,
    )
    let mut node_use_count = -1

    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Drop =>
        if @ir.hot_child_count(func, node_id) == 1 {
          let child_id = @ir.hot_child_get(func, node_id, 0)
          if child_id >= 0 &&
            @ir.hot_node_is_live(func, child_id) &&
            dead_code_elimination_node_use_count(node_use_cache, func, child_id) ==
            1 &&
            dead_code_elimination_voidify_control(
              ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
              child_id,
            ) {
            ignore(
              dead_code_elimination_replace_root_with_child(
                ctx, func, node_use_cache, region_ref, idx, child_id,
              ),
            )
            ignore(
              dead_code_elimination_finish_nonfallthrough_final_root(
                ctx, func, branch_user_cache, fallthrough_cache, region_ref, idx,
                child_id,
              ),
            )
            changed = true
            continue
          }
        }
      _ => ()
    }

    if result_arity == 0 && node_result_arity > 0 {
      if is_final_root &&
        ({
          if node_use_count < 0 {
            node_use_count = dead_code_elimination_node_use_count(
              node_use_cache, func, node_id,
            )
          }
          node_use_count == 1
        }) &&
        dead_code_elimination_node_is_pure(purity_cache, func, node_id) {
        ignore(
          dead_code_elimination_remove_roots(
            ctx, func, node_use_cache, region_ref, idx, 1,
          ),
        )
        changed = true
        continue
      }
      if is_final_root &&
        ({
          if node_use_count < 0 {
            node_use_count = dead_code_elimination_node_use_count(
              node_use_cache, func, node_id,
            )
          }
          node_use_count == 1
        }) &&
        dead_code_elimination_voidify_control(
          ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
          node_id,
        ) {
        ignore(
          dead_code_elimination_finish_nonfallthrough_final_root(
            ctx, func, branch_user_cache, fallthrough_cache, region_ref, idx, node_id,
          ),
        )
        changed = true
        continue
      }
    }

    let node_may_fallthrough = if !is_final_root ||
      (node_is_control && node_result_arity > 0) ||
      needs_unreachable_tail {
      dead_code_elimination_node_may_fallthrough(
        func, branch_user_cache, fallthrough_cache, node_id,
      )
    } else {
      true
    }

    if is_final_root &&
      ({
        if node_use_count < 0 {
          node_use_count = dead_code_elimination_node_use_count(
            node_use_cache, func, node_id,
          )
        }
        node_use_count == 1
      }) &&
      node_result_arity > 0 &&
      !node_may_fallthrough &&
      dead_code_elimination_voidify_control(
        ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
        node_id,
      ) {
      ignore(
        dead_code_elimination_finish_nonfallthrough_final_root(
          ctx, func, branch_user_cache, fallthrough_cache, region_ref, idx, node_id,
        ),
      )
      changed = true
      continue
    }

    if !node_may_fallthrough {
      let keep_unreachable_tail = needs_unreachable_tail &&
        dead_code_elimination_has_explicit_unreachable_tail(
          func, region_ref, idx,
        ) &&
        idx + 2 == @ir.hot_region_root_count(func, region_ref)
      let keep_tail_count = if keep_unreachable_tail { 1 } else { 0 }
      let removable_tail_count = @ir.hot_region_root_count(func, region_ref) -
        (idx + 1) -
        keep_tail_count
      if removable_tail_count > 0 {
        ignore(
          dead_code_elimination_remove_roots(
            ctx,
            func,
            node_use_cache,
            region_ref,
            idx + 1,
            removable_tail_count,
          ),
        )
        changed = true
      }
      if needs_unreachable_tail &&
        idx + 1 == @ir.hot_region_root_count(func, region_ref) &&
        dead_code_elimination_ensure_explicit_unreachable_tail(
          ctx, func, region_ref, idx,
        ) {
        changed = true
        idx += 2
        continue
      }
    }
    idx += 1
  }
  changed
}

///|
fn dead_code_elimination_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  let branch_user_cache = DeadCodeEliminationBranchUserCache::new()
  let node_use_cache = DeadCodeEliminationNodeUseCache::new()
  let fallthrough_cache = dead_code_elimination_new_fallthrough_cache(func)
  let purity_cache = dead_code_elimination_new_purity_cache(func)
  if dead_code_elimination_visit_region(
      ctx,
      func,
      branch_user_cache,
      node_use_cache,
      fallthrough_cache,
      purity_cache,
      @ir.HotRegionRef::root(),
    ) {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
