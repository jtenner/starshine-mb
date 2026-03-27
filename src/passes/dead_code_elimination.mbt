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
  mut has_incoming_by_label : Array[Bool]?
  mut by_label : Array[Array[Int]]?
}

///|
priv struct DeadCodeEliminationPurityCache {
  revision : Array[Int]
  result : Array[Bool]
}

///|
priv struct DeadCodeEliminationStackedForwarderTail {
  payload_if : Int
  rewrite_region : @ir.HotRegionRef
  rewrite_idx : Int
}

///|
fn dead_code_elimination_build_i32_eqz(func : @ir.HotFunc, operand : Int) -> Int {
  @ir.hot_build_select(
    func,
    @lib.ValType::i32(),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    @ir.hot_build_const_i32(func, @lib.I32(1)),
    operand,
  )
}

///|
fn DeadCodeEliminationNodeUseCache::new() -> DeadCodeEliminationNodeUseCache {
  { revision: -1, use_def: None }
}

///|
fn DeadCodeEliminationBranchUserCache::new() -> DeadCodeEliminationBranchUserCache {
  { has_any_branch: None, has_incoming_by_label: None, by_label: None }
}

///|
fn dead_code_elimination_invalidate_branch_user_cache(
  cache : DeadCodeEliminationBranchUserCache,
) -> Unit {
  cache.has_any_branch = None
  cache.has_incoming_by_label = None
  cache.by_label = None
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
fn dead_code_elimination_record_incoming_branch_target(
  has_incoming_by_label : Array[Bool],
  target : Int,
) -> Unit {
  if target < 0 || target >= has_incoming_by_label.length() {
    return
  }
  has_incoming_by_label[target] = true
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
fn dead_code_elimination_build_has_incoming_branches_by_label(
  func : @ir.HotFunc,
) -> Array[Bool] {
  let has_incoming_by_label : Array[Bool] = []
  for _ in 0..<func.labels.length() {
    has_incoming_by_label.push(false)
  }
  for branch_id = 0
      branch_id < @ir.hot_node_count(func)
      branch_id = branch_id + 1 {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    match @ir.hot_branch_target(func, branch_id) {
      Some(target) =>
        dead_code_elimination_record_incoming_branch_target(
          has_incoming_by_label, target,
        )
      _ => ()
    }
    for target in @ir.hot_branch_table_targets_for_node(func, branch_id) {
      dead_code_elimination_record_incoming_branch_target(
        has_incoming_by_label, target,
      )
    }
  }
  has_incoming_by_label
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
fn dead_code_elimination_build_empty_incoming_branches_by_label(
  func : @ir.HotFunc,
) -> Array[Bool] {
  let has_incoming_by_label : Array[Bool] = []
  for _ in 0..<func.labels.length() {
    has_incoming_by_label.push(false)
  }
  has_incoming_by_label
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
fn dead_code_elimination_require_has_incoming_branches_by_label(
  cache : DeadCodeEliminationBranchUserCache,
  func : @ir.HotFunc,
) -> Array[Bool] {
  match cache.has_incoming_by_label {
    Some(existing) => existing
    None => {
      let built = if dead_code_elimination_require_has_any_branch(cache, func) {
        dead_code_elimination_build_has_incoming_branches_by_label(func)
      } else {
        dead_code_elimination_build_empty_incoming_branches_by_label(func)
      }
      cache.has_incoming_by_label = Some(built)
      built
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
      dead_code_elimination_label_has_incoming_branch(
        dead_code_elimination_require_has_incoming_branches_by_label(
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
        dead_code_elimination_require_has_incoming_branches_by_label(
          branch_user_cache, func,
        ),
        node_id,
      )
    _ => false
  }
}

///|
fn dead_code_elimination_label_has_incoming_branch(
  has_incoming_by_label : Array[Bool],
  label_id : Int,
) -> Bool {
  label_id >= 0 &&
  label_id < has_incoming_by_label.length() &&
  has_incoming_by_label[label_id]
}

///|
fn dead_code_elimination_region_has_incoming_branches(
  func : @ir.HotFunc,
  has_incoming_by_label : Array[Bool],
  region_ref : @ir.HotRegionRef,
) -> Bool {
  if region_ref == @ir.HotRegionRef::root() {
    return false
  }
  dead_code_elimination_label_has_incoming_branch(
    has_incoming_by_label,
    @ir.hot_control_node_label(func, region_ref.holder),
  )
}

///|
fn dead_code_elimination_has_incoming_internal_region_branches(
  func : @ir.HotFunc,
  has_incoming_by_label : Array[Bool],
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::If => {
      let then_has_branches = dead_code_elimination_region_has_incoming_branches(
        func,
        has_incoming_by_label,
        @ir.hot_region_then_ref(func, node_id),
      )
      let else_has_branches = match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          dead_code_elimination_region_has_incoming_branches(
            func, has_incoming_by_label, else_region,
          )
        None => false
      }
      then_has_branches || else_has_branches
    }
    @ir.HotOp::Try => {
      let body_has_branches = dead_code_elimination_region_has_incoming_branches(
        func,
        has_incoming_by_label,
        @ir.hot_region_body_ref(func, node_id),
      )
      let catch_has_branches = match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          dead_code_elimination_region_has_incoming_branches(
            func, has_incoming_by_label, catch_region,
          )
        None => false
      }
      body_has_branches || catch_has_branches
    }
    @ir.HotOp::TryTable =>
      dead_code_elimination_region_has_incoming_branches(
        func,
        has_incoming_by_label,
        @ir.hot_region_body_ref(func, node_id),
      ) ||
      dead_code_elimination_region_has_incoming_branches(
        func,
        has_incoming_by_label,
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
fn dead_code_elimination_region_has_terminal_last_live_root(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  let mut idx = @ir.hot_region_root_count(func, region_ref) - 1
  while idx >= 0 {
    let node_id = @ir.hot_region_get(func, region_ref, idx)
    if node_id >= 0 && @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_get(func, node_id).op {
        @ir.HotOp::Br
        | @ir.HotOp::BrTable
        | @ir.HotOp::Return
        | @ir.HotOp::Throw
        | @ir.HotOp::ThrowRef
        | @ir.HotOp::Rethrow
        | @ir.HotOp::Delegate
        | @ir.HotOp::Unreachable => return true
        _ => return false
      }
    }
    idx -= 1
  }
  false
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
      dead_code_elimination_label_has_incoming_branch(
        dead_code_elimination_require_has_incoming_branches_by_label(
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
      let has_incoming_by_label = dead_code_elimination_require_has_incoming_branches_by_label(
        branch_user_cache, func,
      )
      if dead_code_elimination_label_has_incoming_branch(
          has_incoming_by_label,
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
      let has_incoming_by_label = dead_code_elimination_require_has_incoming_branches_by_label(
        branch_user_cache, func,
      )
      if dead_code_elimination_label_has_incoming_branch(
          has_incoming_by_label,
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
      let has_incoming_by_label = dead_code_elimination_require_has_incoming_branches_by_label(
        branch_user_cache, func,
      )
      dead_code_elimination_label_has_incoming_branch(
        has_incoming_by_label,
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
fn DeadCodeEliminationStackedForwarderTail::new(
  payload_if : Int,
  rewrite_region : @ir.HotRegionRef,
  rewrite_idx : Int,
) -> DeadCodeEliminationStackedForwarderTail {
  { payload_if, rewrite_region, rewrite_idx }
}

///|
fn dead_code_elimination_try_extract_stacked_forwarder_tail(
  func : @ir.HotFunc,
  candidate_node : Int,
  rewrite_region : @ir.HotRegionRef,
  rewrite_idx : Int,
) -> DeadCodeEliminationStackedForwarderTail? {
  if candidate_node < 0 ||
    !@ir.hot_node_is_live(func, candidate_node) ||
    @ir.hot_node_result_arity(func, candidate_node) == 0 {
    return None
  }
  match @ir.hot_node_get(func, candidate_node).op {
    @ir.HotOp::If =>
      Some(
        DeadCodeEliminationStackedForwarderTail::new(
          candidate_node, rewrite_region, rewrite_idx,
        ),
      )
    @ir.HotOp::Block => {
      let wrapper_body = @ir.hot_region_body_ref(func, candidate_node)
      let wrapper_root_count = @ir.hot_region_root_count(func, wrapper_body)
      if wrapper_root_count == 0 || wrapper_root_count > 2 {
        return None
      }
      let wrapper_prefix = @ir.hot_region_get(func, wrapper_body, 0)
      if wrapper_prefix < 0 || !@ir.hot_node_is_live(func, wrapper_prefix) {
        return None
      }
      match @ir.hot_node_get(func, wrapper_prefix).op {
        @ir.HotOp::Block => ()
        _ => return None
      }
      let wrapper_prefix_body = @ir.hot_region_body_ref(func, wrapper_prefix)
      let wrapper_prefix_root_count = @ir.hot_region_root_count(
        func, wrapper_prefix_body,
      )
      if wrapper_prefix_root_count < 2 {
        return None
      }
      let wrapper_br_idx = wrapper_prefix_root_count - 1
      let wrapper_br = @ir.hot_region_get(
        func, wrapper_prefix_body, wrapper_br_idx,
      )
      if wrapper_br < 0 ||
        !@ir.hot_node_is_live(func, wrapper_br) ||
        @ir.hot_branch_target(func, wrapper_br) !=
        Some(@ir.hot_control_node_label(func, candidate_node)) ||
        dead_code_elimination_branch_payload_count(func, wrapper_br) != 0 {
        return None
      }
      match @ir.hot_node_get(func, wrapper_br).op {
        @ir.HotOp::Br => ()
        _ => return None
      }
      dead_code_elimination_try_extract_stacked_forwarder_tail(
        func,
        @ir.hot_region_get(func, wrapper_prefix_body, wrapper_br_idx - 1),
        wrapper_prefix_body,
        wrapper_br_idx,
      )
    }
    _ => None
  }
}

///|
fn dead_code_elimination_try_rewrite_branch_payload_forwarder(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  node_id : Int,
) -> Bool {
  let mut trace_candidate = false
  let trace_reason = fn(reason : String) {
    if trace_candidate {
      pipeline_trace_hook(
        ctx.trace,
        "dead-code-elimination",
        "payload-forwarder-reject",
        payload="node=\{node_id} reason=\{reason}",
      )
    }
  }
  let trace_shape = fn(kind : String, payload : String) {
    if trace_candidate {
      pipeline_trace_hook(
        ctx.trace,
        "dead-code-elimination",
        kind,
        payload=payload,
      )
    }
  }
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    dead_code_elimination_branch_payload_count(func, node_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br => ()
    _ => return false
  }
  let payload_block = @ir.hot_child_get(func, node_id, 0)
  if payload_block < 0 || !@ir.hot_node_is_live(func, payload_block) {
    return false
  }
  match @ir.hot_node_get(func, payload_block).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let payload_body = @ir.hot_region_body_ref(func, payload_block)
  let payload_root_count = @ir.hot_region_root_count(func, payload_body)
  if payload_root_count == 0 || payload_root_count > 2 {
    return false
  }
  let forwarder = @ir.hot_region_get(func, payload_body, 0)
  if forwarder < 0 || !@ir.hot_node_is_live(func, forwarder) {
    return false
  }
  match @ir.hot_node_get(func, forwarder).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  trace_candidate = @ir.hot_local_count(func) == 1727 ||
    @ir.hot_local_count(func) == 3 ||
    @ir.hot_local_count(func) > 700
  if trace_candidate {
    let payload_tags : Array[String] = []
    for root_idx = 0; root_idx < payload_root_count; root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, payload_body, root_idx)
      payload_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
    }
    trace_shape(
      "payload-forwarder-shape",
      "node=\{node_id} payload=\{payload_block} roots=\{payload_root_count} tags=\{payload_tags}",
    )
  }
  let forwarder_body = @ir.hot_region_body_ref(func, forwarder)
  let forwarder_root_count = @ir.hot_region_root_count(func, forwarder_body)
  if trace_candidate {
    let forwarder_tags : Array[String] = []
    for root_idx = 0; root_idx < forwarder_root_count; root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, forwarder_body, root_idx)
      forwarder_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
    }
    trace_shape(
      "payload-forwarder-forwarder-shape",
      "node=\{node_id} forwarder=\{forwarder} roots=\{forwarder_root_count} tags=\{forwarder_tags}",
    )
  }
  if forwarder_root_count == 0 {
    trace_reason("empty-forwarder-body")
    return false
  }
  let mut inner_br_idx = forwarder_root_count - 1
  let mut inner_br = @ir.hot_region_get(func, forwarder_body, inner_br_idx)
  let mut trimmed_unreachable = false
  if inner_br_idx > 0 &&
    inner_br >= 0 &&
    @ir.hot_node_is_live(func, inner_br) {
    match @ir.hot_node_get(func, inner_br).op {
      @ir.HotOp::Unreachable => {
        trimmed_unreachable = true
        inner_br_idx = inner_br_idx - 1
        inner_br = @ir.hot_region_get(func, forwarder_body, inner_br_idx)
      }
      _ => ()
    }
  }
  let mut payload_if = -1
  let mut stacked_tail = false
  let mut direct_tail_if = false
  let mut stacked_rewrite_region = forwarder_body
  let mut stacked_rewrite_idx = inner_br_idx
  if inner_br >= 0 &&
    @ir.hot_node_is_live(func, inner_br) &&
    @ir.hot_branch_target(func, inner_br) ==
    Some(@ir.hot_control_node_label(func, payload_block)) {
    match @ir.hot_node_get(func, inner_br).op {
      @ir.HotOp::Br =>
        if dead_code_elimination_branch_payload_count(func, inner_br) == 1 {
          payload_if = @ir.hot_child_get(func, inner_br, 0)
        } else if dead_code_elimination_branch_payload_count(func, inner_br) ==
          0 &&
          inner_br_idx > 0 {
          match
            dead_code_elimination_try_extract_stacked_forwarder_tail(
              func,
              @ir.hot_region_get(func, forwarder_body, inner_br_idx - 1),
              forwarder_body,
              inner_br_idx,
            ) {
            Some(match_) => {
              payload_if = match_.payload_if
              stacked_tail = true
              stacked_rewrite_region = match_.rewrite_region
              stacked_rewrite_idx = match_.rewrite_idx
            }
            None => return false
          }
        } else {
          trace_reason("inner-branch-payload-count")
          return false
        }
      _ => return false
    }
  } else if inner_br >= 0 && @ir.hot_node_is_live(func, inner_br) {
    match @ir.hot_node_get(func, inner_br).op {
      @ir.HotOp::If =>
        if @ir.hot_node_result_arity(func, inner_br) > 0 ||
          (
            @ir.hot_node_result_arity(func, inner_br) == 0 &&
            @ir.hot_node_result_arity(func, forwarder) > 0 &&
            payload_root_count == 2 &&
            forwarder_root_count >= 2 &&
            trimmed_unreachable
          ) {
          payload_if = inner_br
          direct_tail_if = true
        } else {
          if trace_candidate {
            pipeline_trace_hook(
              ctx.trace,
              "dead-code-elimination",
              "payload-forwarder-inner-target",
              payload="node=\{node_id} inner_br=\{inner_br} inner_target=\{@ir.hot_branch_target(func, inner_br)} payload_label=\{@ir.hot_control_node_label(func, payload_block)} forwarder_roots=\{forwarder_root_count}",
            )
          }
          trace_reason("inner-branch-target")
          return false
        }
      _ => {
        if trace_candidate {
          pipeline_trace_hook(
            ctx.trace,
            "dead-code-elimination",
            "payload-forwarder-inner-target",
            payload="node=\{node_id} inner_br=\{inner_br} inner_target=\{@ir.hot_branch_target(func, inner_br)} payload_label=\{@ir.hot_control_node_label(func, payload_block)} forwarder_roots=\{forwarder_root_count}",
          )
        }
        trace_reason("inner-branch-target")
        return false
      }
    }
  } else {
    if trace_candidate {
      pipeline_trace_hook(
        ctx.trace,
        "dead-code-elimination",
        "payload-forwarder-inner-target",
        payload="node=\{node_id} inner_br=\{inner_br} inner_op=\{@ir.hot_node_get(func, inner_br).op} inner_arity=\{@ir.hot_node_result_arity(func, inner_br)} inner_target=\{@ir.hot_branch_target(func, inner_br)} payload_label=\{@ir.hot_control_node_label(func, payload_block)} forwarder_roots=\{forwarder_root_count}",
      )
    }
    trace_reason("inner-branch-target")
    return false
  }
  if payload_if < 0 ||
    !@ir.hot_node_is_live(func, payload_if) ||
    (
      @ir.hot_node_result_arity(func, payload_if) == 0 &&
      !(
        direct_tail_if &&
        @ir.hot_node_result_arity(func, forwarder) > 0 &&
        payload_root_count == 2 &&
        trimmed_unreachable
      )
    ) ||
    (
      !stacked_tail &&
      dead_code_elimination_node_use_count(node_use_cache, func, payload_if) !=
      1
    ) {
    trace_reason("payload-if-uses")
    return false
  }
  match @ir.hot_node_get(func, payload_if).op {
    @ir.HotOp::If => ()
    _ => {
      trace_reason("payload-not-if")
      return false
    }
  }
  let then_region = @ir.hot_region_then_ref(func, payload_if)
  let else_region = match @ir.hot_region_else_ref(func, payload_if) {
    Some(else_region) => else_region
    None => return false
  }
  if @ir.hot_region_root_count(func, then_region) == 0 ||
    @ir.hot_region_root_count(func, else_region) == 0 {
    trace_reason("empty-if-arm")
    return false
  }
  let then_tail = @ir.hot_region_get(
    func,
    then_region,
    @ir.hot_region_root_count(func, then_region) - 1,
  )
  let else_tail = @ir.hot_region_get(
    func,
    else_region,
    @ir.hot_region_root_count(func, else_region) - 1,
  )
  if then_tail < 0 ||
    else_tail < 0 ||
    !@ir.hot_node_is_live(func, then_tail) ||
    !@ir.hot_node_is_live(func, else_tail) {
    trace_reason("dead-if-arm-tail")
    return false
  }
  let then_is_br = match @ir.hot_node_get(func, then_tail).op {
    @ir.HotOp::Br => true
    _ => false
  }
  let else_is_br = match @ir.hot_node_get(func, else_tail).op {
    @ir.HotOp::Br => true
    _ => false
  }
  if !then_is_br || !else_is_br {
    trace_shape(
      "payload-forwarder-arm-shape",
      "node=\{node_id} payload_if=\{payload_if} then_tail=\{@ir.hot_node_get(func, then_tail).op}#\{then_tail} then_target=\{@ir.hot_branch_target(func, then_tail)} else_tail=\{@ir.hot_node_get(func, else_tail).op}#\{else_tail} else_target=\{@ir.hot_branch_target(func, else_tail)} stacked=\{stacked_tail}",
    )
    if !stacked_tail || then_is_br == else_is_br {
      trace_reason("if-tail-not-br")
      return false
    }
    let payload_label = @ir.hot_control_node_label(func, payload_block)
    if then_is_br &&
      @ir.hot_branch_target(func, then_tail) != Some(payload_label) {
      trace_reason("then-tail-target")
      return false
    }
    if else_is_br &&
      @ir.hot_branch_target(func, else_tail) != Some(payload_label) {
      trace_reason("else-tail-target")
      return false
    }
    if !then_is_br {
      ignore(pass_splice_region(ctx, func, then_region, @ir.hot_region_root_count(func, then_region) - 1, 1, [
        @ir.hot_build_br(func, payload_label, values=[then_tail]),
      ]))
    }
    if !else_is_br {
      ignore(pass_splice_region(ctx, func, else_region, @ir.hot_region_root_count(func, else_region) - 1, 1, [
        @ir.hot_build_br(func, payload_label, values=[else_tail]),
      ]))
    }
  }

  @ir.hot_control_result_type_set(func, payload_if, @ir.hot_type_void(func))
  @ir.hot_control_result_type_set(func, forwarder, @ir.hot_type_void(func))
  pass_mark_mutated(ctx, func)
  if stacked_tail {
    let removed = pass_splice_region(
      ctx,
      func,
      stacked_rewrite_region,
      stacked_rewrite_idx,
      1,
      [@ir.hot_build_unreachable(func)],
    )
    dead_code_elimination_delete_unused_nodes(
      ctx, func, node_use_cache, removed,
    )
  } else if direct_tail_if {
    ignore(
      dead_code_elimination_ensure_explicit_unreachable_tail(
        ctx, func, forwarder_body, inner_br_idx,
      ),
    )
  } else {
    ignore(
      dead_code_elimination_replace_root_with_child(
        ctx, func, node_use_cache, forwarder_body, inner_br_idx, payload_if,
      ),
    )
    ignore(
      dead_code_elimination_ensure_explicit_unreachable_tail(
        ctx, func, forwarder_body, inner_br_idx,
      ),
    )
  }
  dead_code_elimination_invalidate_branch_user_cache(branch_user_cache)
  if trace_candidate {
    pipeline_trace_hook(
      ctx.trace,
      "dead-code-elimination",
      "payload-forwarder-success",
      payload="node=\{node_id}",
    )
  }
  true
}

///|
fn dead_code_elimination_try_rewrite_branch_payload_forwarder_in_value_subtree(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if dead_code_elimination_try_rewrite_branch_payload_forwarder(
      ctx, func, branch_user_cache, node_use_cache, node_id,
    ) {
    return true
  }
  if @ir.hot_local_count(func) == 3 {
    let payload_tags : Array[String] = []
    let payload_count = dead_code_elimination_branch_payload_count(func, node_id)
    for child_idx = 0; child_idx < payload_count; child_idx = child_idx + 1 {
      let child_id = @ir.hot_child_get(func, node_id, child_idx)
      payload_tags.push("\{child_idx}:\{@ir.hot_node_get(func, child_id).op}#\{child_id}")
    }
    pipeline_trace_hook(
      ctx.trace,
      "dead-code-elimination",
      "subtree-walk",
      payload="node=\{node_id} op=\{@ir.hot_node_get(func, node_id).op} payloads=\{payload_tags}",
    )
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop => {
      let body = @ir.hot_region_body_ref(func, node_id)
      for root_idx = 0; root_idx < @ir.hot_region_root_count(func, body); root_idx = root_idx + 1 {
        if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_value_subtree(
            ctx,
            func,
            branch_user_cache,
            node_use_cache,
            @ir.hot_region_get(func, body, root_idx),
          ) {
          return true
        }
      }
      false
    }
    @ir.HotOp::Br => {
      for child_idx = 0; child_idx < dead_code_elimination_branch_payload_count(func, node_id); child_idx = child_idx + 1 {
        if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_value_subtree(
            ctx,
            func,
            branch_user_cache,
            node_use_cache,
            @ir.hot_child_get(func, node_id, child_idx),
          ) {
          return true
        }
      }
      false
    }
    _ => false
  }
}

///|
fn dead_code_elimination_try_rewrite_branch_payload_forwarder_in_subtree(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    @ir.hot_child_count(func, node_id) == 0 {
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    return false
  }
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop => ()
    _ => return false
  }
  if @ir.hot_node_count(func) > 10000 {
    let walk_chain = fn(start : Int) -> Bool {
      let mut current = start
      for _ in 0..<16 {
        if current < 0 || !@ir.hot_node_is_live(func, current) {
          return false
        }
        if dead_code_elimination_try_rewrite_branch_payload_forwarder(
            ctx, func, branch_user_cache, node_use_cache, current,
          ) {
          return true
        }
        match @ir.hot_node_get(func, current).op {
          @ir.HotOp::Block | @ir.HotOp::Loop => {
            let body = @ir.hot_region_body_ref(func, current)
            let root_count = @ir.hot_region_root_count(func, body)
            if root_count == 0 {
              return false
            }
            current = if root_count == 1 {
              @ir.hot_region_get(func, body, 0)
            } else {
              @ir.hot_region_get(func, body, root_count - 1)
            }
          }
          @ir.HotOp::Br => {
            if dead_code_elimination_branch_payload_count(func, current) == 0 {
              return false
            }
            current = @ir.hot_child_get(func, current, 0)
          }
          _ => return false
        }
      }
      false
    }
    if walk_chain(value_id) {
      return true
    }
    match @ir.hot_node_get(func, value_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop => {
        let body = @ir.hot_region_body_ref(func, value_id)
        if @ir.hot_region_root_count(func, body) > 0 {
          let first_root = @ir.hot_region_get(func, body, 0)
          if first_root != value_id && walk_chain(first_root) {
            return true
          }
        }
      }
      _ => ()
    }
    return false
  }
  dead_code_elimination_try_rewrite_branch_payload_forwarder_in_value_subtree(
    ctx, func, branch_user_cache, node_use_cache, value_id,
  )
}

///|
fn dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  region_ref : @ir.HotRegionRef,
) -> Bool {
  for idx = 0; idx < @ir.hot_region_root_count(func, region_ref); idx = idx + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, idx)
    if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_tree(
        ctx, func, branch_user_cache, node_use_cache, root_id,
      ) {
      return true
    }
  }
  false
}

///|
fn dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_tree(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  node_id : Int,
) -> Bool {
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    return false
  }
  if dead_code_elimination_try_rewrite_branch_payload_forwarder(
      ctx, func, branch_user_cache, node_use_cache, node_id,
    ) {
    return true
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block | @ir.HotOp::Loop =>
      dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        @ir.hot_region_body_ref(func, node_id),
      )
    @ir.HotOp::If => {
      if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
          ctx,
          func,
          branch_user_cache,
          node_use_cache,
          @ir.hot_region_then_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_else_ref(func, node_id) {
        Some(else_region) =>
          dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
            ctx, func, branch_user_cache, node_use_cache, else_region,
          )
        None => false
      }
    }
    @ir.HotOp::Try => {
      if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
          ctx,
          func,
          branch_user_cache,
          node_use_cache,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
      match @ir.hot_region_catch_ref(func, node_id) {
        Some(catch_region) =>
          dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
            ctx, func, branch_user_cache, node_use_cache, catch_region,
          )
        None => false
      }
    }
    @ir.HotOp::TryTable => {
      if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
          ctx,
          func,
          branch_user_cache,
          node_use_cache,
          @ir.hot_region_body_ref(func, node_id),
        ) {
        return true
      }
      dead_code_elimination_try_rewrite_branch_payload_forwarder_in_control_region(
        ctx,
        func,
        branch_user_cache,
        node_use_cache,
        @ir.hot_region_catch_list_ref(func, node_id),
      )
    }
    _ => false
  }
}

///|
fn dead_code_elimination_try_rewrite_split_local_set_wrapper_forwarder(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  node_id : Int,
) -> Bool {
  let trace_split = fn(reason : String) {
    if @ir.hot_local_count(func) == 3 || @ir.hot_local_count(func) > 700 {
      pipeline_trace_hook(
        ctx.trace,
        "dead-code-elimination",
        "split-wrapper",
        payload="idx=\{idx} node=\{node_id} op=\{@ir.hot_node_get(func, node_id).op} arity=\{@ir.hot_node_result_arity(func, node_id)} reason=\{reason}",
      )
    }
  }
  if node_id < 0 || !@ir.hot_node_is_live(func, node_id) {
    trace_split("precheck")
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => {
      trace_split("node-not-local-set")
      return false
    }
  }
  if @ir.hot_child_count(func, node_id) == 0 {
    trace_split("local-set-no-child")
    return false
  }
  let value_id = @ir.hot_child_get(func, node_id, 0)
  if value_id < 0 || !@ir.hot_node_is_live(func, value_id) {
    trace_split("value-dead")
    return false
  }
  match @ir.hot_node_get(func, value_id).op {
    @ir.HotOp::Block => ()
    _ => {
      trace_split("value-not-block")
      return false
    }
  }
  if @ir.hot_node_result_arity(func, value_id) == 0 {
    trace_split("value-not-result")
    return false
  }
  let outer_body = @ir.hot_region_body_ref(func, value_id)
  let outer_root_count = @ir.hot_region_root_count(func, outer_body)
  if outer_root_count == 0 ||
    (
      outer_root_count > 2 &&
      !(@ir.hot_local_count(func) > 700)
    ) {
    if @ir.hot_local_count(func) == 3 || @ir.hot_local_count(func) > 700 {
      let outer_tags : Array[String] = []
      for root_idx = 0; root_idx < outer_root_count; root_idx = root_idx + 1 {
        let root_id = @ir.hot_region_get(func, outer_body, root_idx)
        outer_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
      }
      pipeline_trace_hook(
        ctx.trace,
        "dead-code-elimination",
        "split-wrapper-outer-shape",
        payload="node=\{node_id} roots=\{outer_root_count} tags=\{outer_tags}",
      )
    }
    trace_split("outer-root-count")
    return false
  }
  let outer_wrapper = @ir.hot_region_get(func, outer_body, 0)
  if outer_wrapper < 0 || !@ir.hot_node_is_live(func, outer_wrapper) {
    trace_split("outer-wrapper-dead")
    return false
  }
  match @ir.hot_node_get(func, outer_wrapper).op {
    @ir.HotOp::Block => ()
    _ => {
      trace_split("outer-wrapper-not-block")
      return false
    }
  }
  let outer_wrapper_body = @ir.hot_region_body_ref(func, outer_wrapper)
  let outer_wrapper_root_count = @ir.hot_region_root_count(func, outer_wrapper_body)
  if @ir.hot_local_count(func) == 3 || @ir.hot_local_count(func) > 700 {
    let root_tags : Array[String] = []
    for root_idx = 0; root_idx < outer_wrapper_root_count; root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, outer_wrapper_body, root_idx)
      root_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
    }
    pipeline_trace_hook(
      ctx.trace,
      "dead-code-elimination",
      "split-wrapper-shape",
      payload="node=\{node_id} roots=\{outer_wrapper_root_count} tags=\{root_tags}",
    )
  }
  if outer_wrapper_root_count == 0 {
    trace_split("outer-wrapper-root-count")
    return false
  }
  let mut payload_block = -1
  let mut outer_br = -1
  if outer_wrapper_root_count == 1 {
    outer_br = @ir.hot_region_get(func, outer_wrapper_body, 0)
    if outer_br < 0 || !@ir.hot_node_is_live(func, outer_br) {
      trace_split("outer-br-dead")
      return false
    }
    match @ir.hot_node_get(func, outer_br).op {
      @ir.HotOp::Br => ()
      _ => {
        trace_split("outer-br-not-br")
        return false
      }
    }
    if @ir.hot_branch_target(func, outer_br) !=
      Some(@ir.hot_control_node_label(func, value_id)) ||
      dead_code_elimination_branch_payload_count(func, outer_br) != 1 {
      trace_split("outer-br-shape")
      return false
    }
    payload_block = @ir.hot_child_get(func, outer_br, 0)
  } else {
    payload_block = @ir.hot_region_get(
      func,
      outer_wrapper_body,
      outer_wrapper_root_count - 2,
    )
    outer_br = @ir.hot_region_get(
      func,
      outer_wrapper_body,
      outer_wrapper_root_count - 1,
    )
    if payload_block < 0 ||
      outer_br < 0 ||
      !@ir.hot_node_is_live(func, payload_block) ||
      !@ir.hot_node_is_live(func, outer_br) ||
      @ir.hot_branch_target(func, outer_br) !=
      Some(@ir.hot_control_node_label(func, value_id)) ||
      dead_code_elimination_branch_payload_count(func, outer_br) != 0 {
      trace_split("outer-br-shape")
      return false
    }
    match @ir.hot_node_get(func, outer_br).op {
      @ir.HotOp::Br => ()
      _ => {
        trace_split("outer-br-not-br")
        return false
      }
    }
  }
  if payload_block < 0 ||
    !@ir.hot_node_is_live(func, payload_block) ||
    @ir.hot_node_result_arity(func, payload_block) == 0 {
    trace_split("payload-dead")
    return false
  }
  match @ir.hot_node_get(func, payload_block).op {
    @ir.HotOp::Block => ()
    _ => {
      trace_split("payload-not-block")
      return false
    }
  }
  let payload_body = @ir.hot_region_body_ref(func, payload_block)
  let payload_root_count = @ir.hot_region_root_count(func, payload_body)
  if @ir.hot_local_count(func) == 3 || @ir.hot_local_count(func) > 700 {
    let payload_tags : Array[String] = []
    for root_idx = 0; root_idx < payload_root_count; root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, payload_body, root_idx)
      payload_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
    }
    pipeline_trace_hook(
      ctx.trace,
      "dead-code-elimination",
      "split-wrapper-payload-shape",
      payload="node=\{node_id} payload=\{payload_block} roots=\{payload_root_count} tags=\{payload_tags}",
    )
  }
  if payload_root_count == 0 || payload_root_count > 2 {
    trace_split("payload-root-count")
    return false
  }
  let payload_forwarder = @ir.hot_region_get(func, payload_body, 0)
  if payload_forwarder < 0 || !@ir.hot_node_is_live(func, payload_forwarder) {
    trace_split("payload-forwarder-dead")
    return false
  }
  match @ir.hot_node_get(func, payload_forwarder).op {
    @ir.HotOp::Block => ()
    _ => {
      trace_split("payload-forwarder-not-block")
      return false
    }
  }
  let payload_forwarder_body = @ir.hot_region_body_ref(func, payload_forwarder)
  let payload_forwarder_root_count = @ir.hot_region_root_count(
    func,
    payload_forwarder_body,
  )
  if @ir.hot_local_count(func) == 3 || @ir.hot_local_count(func) > 700 {
    let forwarder_tags : Array[String] = []
    for root_idx = 0; root_idx < payload_forwarder_root_count; root_idx = root_idx + 1 {
      let root_id = @ir.hot_region_get(func, payload_forwarder_body, root_idx)
      forwarder_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
    }
    pipeline_trace_hook(
      ctx.trace,
      "dead-code-elimination",
      "split-wrapper-forwarder-shape",
      payload="node=\{node_id} forwarder=\{payload_forwarder} roots=\{payload_forwarder_root_count} tags=\{forwarder_tags}",
    )
  }
  if payload_forwarder_root_count == 1 {
    let direct_br = @ir.hot_region_get(func, payload_forwarder_body, 0)
    if direct_br >= 0 && @ir.hot_node_is_live(func, direct_br) {
      match @ir.hot_node_get(func, direct_br).op {
        @ir.HotOp::Br =>
          if dead_code_elimination_branch_payload_count(func, direct_br) == 1 {
            let direct_if = @ir.hot_child_get(func, direct_br, 0)
            if direct_if >= 0 &&
              @ir.hot_node_is_live(func, direct_if) &&
              @ir.hot_node_result_arity(func, direct_if) == 1 {
              match @ir.hot_node_get(func, direct_if).op {
                @ir.HotOp::If => {
                  let then_region = @ir.hot_region_then_ref(func, direct_if)
                  let else_region = match @ir.hot_region_else_ref(func, direct_if) {
                    Some(else_region) => else_region
                    None => {
                      trace_split("direct-if-no-else")
                      return false
                    }
                  }
                  let if_label = @ir.hot_control_node_label(func, direct_if)
                  let direct_target = match @ir.hot_branch_target(func, direct_br) {
                    Some(target) => target
                    None => {
                      trace_split("direct-br-no-target")
                      return false
                    }
                  }
                  let try_build = fn(
                    branch_ref : @ir.HotRegionRef,
                    body_ref : @ir.HotRegionRef,
                    negate_condition : Bool,
                  ) -> Bool {
                    if @ir.hot_region_root_count(func, branch_ref) != 1 ||
                      @ir.hot_region_root_count(func, body_ref) == 0 {
                      return false
                    }
                    let branch_root = @ir.hot_region_get(func, branch_ref, 0)
                    if branch_root < 0 || !@ir.hot_node_is_live(func, branch_root) {
                      return false
                    }
                    let branch_node = @ir.hot_node_get(func, branch_root)
                    match branch_node.op {
                      @ir.HotOp::Br if branch_node.child_count == 0 => ()
                      _ => return false
                    }
                    if branch_node.imm0 == if_label {
                      return false
                    }
                    let body_tail_idx = @ir.hot_region_root_count(func, body_ref) - 1
                    let body_payload = @ir.hot_region_get(func, body_ref, body_tail_idx)
                    if body_payload < 0 ||
                      !@ir.hot_node_is_live(func, body_payload) ||
                      @ir.hot_node_result_arity(func, body_payload) != 1 {
                      return false
                    }
                    let body_prefix : Array[Int] = []
                    for root_idx = 0; root_idx < body_tail_idx; root_idx = root_idx + 1 {
                      let root_id = @ir.hot_region_get(func, body_ref, root_idx)
                      if @ir.cfg_terminator_edge_kinds(@ir.hot_node_get(func, root_id).op).length() >
                        0 {
                        return false
                      }
                      body_prefix.push(root_id)
                    }
                    let guard_condition = if negate_condition {
                      dead_code_elimination_build_i32_eqz(
                        func,
                        @ir.hot_child_get(func, direct_if, 0),
                      )
                    } else {
                      @ir.hot_child_get(func, direct_if, 0)
                    }
                    let replacement = [
                      @ir.hot_build_br_if(func, branch_node.imm0, guard_condition),
                    ] + body_prefix + [
                      @ir.hot_build_br(func, direct_target, values=[body_payload]),
                      @ir.hot_build_unreachable(func),
                    ]
                    ignore(
                      pass_splice_region(
                        ctx,
                        func,
                        payload_forwarder_body,
                        0,
                        1,
                        replacement,
                      ),
                    )
                    dead_code_elimination_invalidate_branch_user_cache(branch_user_cache)
                    trace_split("direct-branch-if")
                    return true
                  }
                  if try_build(else_region, then_region, true) ||
                    try_build(then_region, else_region, false) {
                    return true
                  }
                }
                _ => ()
              }
            }
          }
        _ => ()
      }
    }
  }
  if outer_wrapper_root_count == 1 &&
    payload_root_count == 2 &&
    payload_forwarder_root_count >= 2 {
    let payload_forwarder_tail = @ir.hot_region_get(
      func,
      payload_forwarder_body,
      payload_forwarder_root_count - 2,
    )
    let payload_forwarder_last = @ir.hot_region_get(
      func,
      payload_forwarder_body,
      payload_forwarder_root_count - 1,
    )
    if payload_forwarder_tail >= 0 &&
      payload_forwarder_last >= 0 &&
      @ir.hot_node_is_live(func, payload_forwarder_tail) &&
      @ir.hot_node_is_live(func, payload_forwarder_last) {
      let tail_is_void_if = match @ir.hot_node_get(func, payload_forwarder_tail).op {
        @ir.HotOp::If => @ir.hot_node_result_arity(func, payload_forwarder_tail) == 0
        _ => false
      }
      let last_is_unreachable = match @ir.hot_node_get(func, payload_forwarder_last).op {
        @ir.HotOp::Unreachable => true
        _ => false
      }
      if tail_is_void_if && last_is_unreachable {
        @ir.hot_control_result_type_set(
          func,
          payload_forwarder_tail,
          @ir.hot_type_void(func),
        )
        let then_region = @ir.hot_region_then_ref(func, payload_forwarder_tail)
        let else_region = match @ir.hot_region_else_ref(func, payload_forwarder_tail) {
          Some(else_region) => else_region
          None => {
            trace_split("void-if-no-else")
            return false
          }
        }
        let arm_is_bare_br = fn(region_ref : @ir.HotRegionRef) -> Bool {
          let root_count = @ir.hot_region_root_count(func, region_ref)
          if root_count == 0 {
            return false
          }
          let tail = @ir.hot_region_get(func, region_ref, root_count - 1)
          if tail < 0 || !@ir.hot_node_is_live(func, tail) {
            return false
          }
          match @ir.hot_node_get(func, tail).op {
            @ir.HotOp::Br => dead_code_elimination_branch_payload_count(func, tail) == 0
            _ => false
          }
        }
        if !arm_is_bare_br(then_region) || !arm_is_bare_br(else_region) {
          trace_split("void-if-arm-shape")
          return false
        }
        let payload_block_type = match @ir.hot_type_get(
          func,
          @ir.hot_node_type(func, payload_block),
        ) {
          @ir.HotTypeInfo::BlockResult(block_type) => block_type
          @ir.HotTypeInfo::BlockResultResolved(block_type, _) => block_type
          _ => {
            trace_split("payload-block-type")
            return false
          }
        }
        let lifted_payload_roots : Array[Int] = []
        for root_idx = 0; root_idx < payload_root_count; root_idx = root_idx + 1 {
          lifted_payload_roots.push(@ir.hot_region_get(func, payload_body, root_idx))
        }
        let lifted_payload = @ir.hot_build_block(
          func,
          payload_block_type,
          lifted_payload_roots,
        )
        let lifted_outer_br = @ir.hot_build_br(
          func,
          @ir.hot_control_node_label(func, payload_block),
          values=[lifted_payload],
        )
        @ir.hot_replace_node(
          func,
          outer_br,
          @ir.hot_node_get(func, lifted_outer_br),
        )
        let payload_wrapper_roots : Array[Int] = [outer_wrapper]
        for root_idx = 1; root_idx < outer_root_count; root_idx = root_idx + 1 {
          payload_wrapper_roots.push(@ir.hot_region_get(func, outer_body, root_idx))
        }
        @ir.hot_region_replace_body(
          func,
          @ir.hot_region_body_ref(func, payload_block),
          payload_wrapper_roots,
        )
        @ir.hot_child_set(func, node_id, 0, payload_block)
        pass_mark_mutated(ctx, func)
        dead_code_elimination_invalidate_branch_user_cache(branch_user_cache)
        if @ir.hot_local_count(func) > 700 {
          let new_outer_tags : Array[String] = []
          let new_outer_body = @ir.hot_region_body_ref(func, value_id)
          for root_idx = 0
              ; root_idx < @ir.hot_region_root_count(func, new_outer_body)
              ; root_idx = root_idx + 1 {
            let root_id = @ir.hot_region_get(func, new_outer_body, root_idx)
            new_outer_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
          }
          let new_payload_tags : Array[String] = []
          let new_payload_body = @ir.hot_region_body_ref(func, payload_block)
          for root_idx = 0
              ; root_idx < @ir.hot_region_root_count(func, new_payload_body)
              ; root_idx = root_idx + 1 {
            let root_id = @ir.hot_region_get(func, new_payload_body, root_idx)
            new_payload_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
          }
          pipeline_trace_hook(
            ctx.trace,
            "dead-code-elimination",
            "split-wrapper-post",
            payload="node=\{node_id} value=\{value_id} value_roots=\{new_outer_tags} payload=\{payload_block} payload_roots=\{new_payload_tags}",
          )
        }
        trace_split("void-if-lifted-payload")
        return true
      }
    }
  }
  if payload_forwarder_root_count < 2 {
    trace_split("payload-forwarder-root-count")
    return false
  }
  let match_ = match dead_code_elimination_try_extract_stacked_forwarder_tail(
    func,
    @ir.hot_region_get(func, payload_forwarder_body, payload_forwarder_root_count - 2),
    payload_forwarder_body,
    payload_forwarder_root_count - 1,
  ) {
    Some(match_) => match_
    None => {
      trace_split("stacked-tail-none")
      return false
    }
  }
  let inner_br = @ir.hot_region_get(
    func,
    match_.rewrite_region,
    match_.rewrite_idx,
  )
  if inner_br < 0 ||
    !@ir.hot_node_is_live(func, inner_br) ||
    @ir.hot_branch_target(func, inner_br) !=
    Some(@ir.hot_control_node_label(func, payload_block)) {
    trace_split("inner-br-target")
    return false
  }
  match @ir.hot_node_get(func, inner_br).op {
    @ir.HotOp::Br => ()
    _ => {
      trace_split("inner-br-not-br")
      return false
    }
  }

  let node_roots : Array[Int] = []
  for root_idx = 0; root_idx < payload_root_count; root_idx = root_idx + 1 {
    node_roots.push(@ir.hot_region_get(func, payload_body, root_idx))
  }
  for root_idx = 1; root_idx < outer_root_count; root_idx = root_idx + 1 {
    node_roots.push(@ir.hot_region_get(func, outer_body, root_idx))
  }

  @ir.hot_control_result_type_set(func, match_.payload_if, @ir.hot_type_void(func))
  let outer_br_replacement = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, payload_block),
  )
  @ir.hot_replace_node(
    func,
    outer_br,
    @ir.hot_node_get(func, outer_br_replacement),
  )
  let inner_br_replacement = @ir.hot_build_br(
    func,
    @ir.hot_control_node_label(func, value_id),
  )
  @ir.hot_replace_node(
    func,
    inner_br,
    @ir.hot_node_get(func, inner_br_replacement),
  )
  let wrapper_roots : Array[Int] = []
  for root_idx = 0; root_idx < outer_wrapper_root_count - 2; root_idx = root_idx + 1 {
    wrapper_roots.push(@ir.hot_region_get(func, outer_wrapper_body, root_idx))
  }
  wrapper_roots.push(value_id)
  wrapper_roots.push(outer_br)
  @ir.hot_region_replace_body(func, outer_wrapper_body, wrapper_roots)
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, value_id),
    node_roots,
  )
  @ir.hot_region_replace_body(
    func,
    @ir.hot_region_body_ref(func, payload_block),
    [outer_wrapper],
  )
  @ir.hot_child_set(func, node_id, 0, payload_block)
  pass_mark_mutated(ctx, func)
  ignore(
    pass_splice_region(
      ctx,
      func,
      match_.rewrite_region,
      match_.rewrite_idx,
      1,
      [@ir.hot_build_unreachable(func)],
    ),
  )
  dead_code_elimination_invalidate_branch_user_cache(branch_user_cache)
  trace_split("success")
  true
}

///|
fn dead_code_elimination_try_fold_nonfallthrough_prefix_into_branch_payload(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  node_id : Int,
) -> Bool {
  if idx <= 0 ||
    node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    @ir.hot_node_count(func) > 5000 ||
    idx + 1 != @ir.hot_region_root_count(func, region_ref) ||
    dead_code_elimination_branch_payload_count(func, node_id) != 1 {
    return false
  }
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Br => ()
    _ => return false
  }
  let payload_id = @ir.hot_child_get(func, node_id, 0)
  if payload_id < 0 ||
    !@ir.hot_node_is_live(func, payload_id) ||
    @ir.hot_node_result_arity(func, payload_id) != 1 {
    return false
  }
  let prefix_id = @ir.hot_region_get(func, region_ref, idx - 1)
  if prefix_id < 0 ||
    !@ir.hot_node_is_live(func, prefix_id) ||
    @ir.hot_node_result_arity(func, prefix_id) != 0 {
    return false
  }
  match @ir.hot_node_get(func, prefix_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  let prefix_region = @ir.hot_region_body_ref(func, prefix_id)
  let prefix_root_count = @ir.hot_region_root_count(func, prefix_region)
  if prefix_root_count == 0 || prefix_root_count > 2 {
    return false
  }
  match @ir.hot_node_get(func, payload_id).op {
    @ir.HotOp::Const | @ir.HotOp::LocalGet | @ir.HotOp::LocalTee => ()
    _ => return false
  }
  let payload_types = @ir.hot_type_results(
    func,
    @ir.hot_node_type(func, payload_id),
  )
  if payload_types.length() != 1 {
    return false
  }
  let payload_block = @ir.hot_build_block(
    func,
    @lib.BlockType::val_type(payload_types[0]),
    [prefix_id, payload_id],
  )
  @ir.hot_child_set(func, node_id, 0, payload_block)
  ignore(pass_splice_region(ctx, func, region_ref, idx - 1, 1, []))
  pass_mark_mutated(ctx, func)
  true
}

///|
fn dead_code_elimination_try_voidify_split_drop_control(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  purity_cache : DeadCodeEliminationPurityCache,
  region_ref : @ir.HotRegionRef,
  idx : Int,
  node_id : Int,
) -> Bool {
  if node_id < 0 ||
    !@ir.hot_node_is_live(func, node_id) ||
    @ir.hot_node_result_arity(func, node_id) == 0 ||
    idx + 1 >= @ir.hot_region_root_count(func, region_ref) {
    return false
  }
  let drop_id = @ir.hot_region_get(func, region_ref, idx + 1)
  if drop_id < 0 ||
    !@ir.hot_node_is_live(func, drop_id) ||
    @ir.hot_child_count(func, drop_id) != 1 ||
    @ir.hot_child_get(func, drop_id, 0) != node_id {
    return false
  }
  match @ir.hot_node_get(func, drop_id).op {
    @ir.HotOp::Drop => ()
    _ => return false
  }
  if !dead_code_elimination_voidify_control(
      ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
      node_id,
    ) {
    return false
  }
  ignore(
    dead_code_elimination_remove_roots(
      ctx,
      func,
      node_use_cache,
      region_ref,
      idx + 1,
      1,
    ),
  )
  true
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
  let has_incoming_by_label = dead_code_elimination_require_has_incoming_branches_by_label(
    branch_user_cache, func,
  )
  if !is_loop &&
    dead_code_elimination_label_has_incoming_branch(
      has_incoming_by_label, label_id,
    ) {
    return false
  }
  let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
    branch_user_cache, func,
  )
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
fn dead_code_elimination_try_voidify_nonfallthrough_block_with_pure_incoming_branches(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  branch_user_cache : DeadCodeEliminationBranchUserCache,
  node_use_cache : DeadCodeEliminationNodeUseCache,
  fallthrough_cache : DeadCodeEliminationFallthroughCache,
  purity_cache : DeadCodeEliminationPurityCache,
  node_id : Int,
) -> Bool {
  match @ir.hot_node_get(func, node_id).op {
    @ir.HotOp::Block => ()
    _ => return false
  }
  if @ir.hot_node_result_arity(func, node_id) == 0 {
    return false
  }
  let label_id = @ir.hot_control_node_label(func, node_id)
  let has_incoming_by_label = dead_code_elimination_require_has_incoming_branches_by_label(
    branch_user_cache, func,
  )
  let body_ref = @ir.hot_region_body_ref(func, node_id)
  if !dead_code_elimination_label_has_incoming_branch(
      has_incoming_by_label, label_id,
    ) ||
    !dead_code_elimination_region_has_terminal_last_live_root(func, body_ref) ||
    dead_code_elimination_region_may_fallthrough(
      func, branch_user_cache, fallthrough_cache, body_ref,
    ) {
    return false
  }
  let branch_users_by_label = dead_code_elimination_require_branch_users_by_label(
    branch_user_cache, func,
  )
  if label_id < 0 || label_id >= branch_users_by_label.length() {
    return false
  }
  if branch_users_by_label[label_id].length() != 1 {
    return false
  }
  let detached : Array[Int] = []
  let branch_rewrites : Array[@ir.HotChildSpanRewrite] = []
  for branch_id in branch_users_by_label[label_id] {
    if !@ir.hot_node_is_live(func, branch_id) {
      continue
    }
    match @ir.hot_node_get(func, branch_id).op {
      @ir.HotOp::Br => ()
      _ => return false
    }
    let payload_count = dead_code_elimination_branch_payload_count(
      func, branch_id,
    )
    if payload_count != 1 {
      return false
    }
    for slot = 0; slot < payload_count; slot = slot + 1 {
      let child_id = @ir.hot_child_get(func, branch_id, slot)
      if child_id < 0 || !@ir.hot_node_is_live(func, child_id) {
        continue
      }
      if !dead_code_elimination_node_is_pure(purity_cache, func, child_id) {
        return false
      }
      dead_code_elimination_collect_detached_nodes(func, child_id, detached, 32)
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
    branch_rewrites.push(@ir.HotChildSpanRewrite::new(branch_id, new_children))
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

    if dead_code_elimination_try_rewrite_branch_payload_forwarder(
        ctx, func, branch_user_cache, node_use_cache, node_id,
      ) {
      changed = true
      continue
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee =>
        if dead_code_elimination_try_rewrite_branch_payload_forwarder_in_subtree(
            ctx, func, branch_user_cache, node_use_cache, node_id,
          ) {
          changed = true
          continue
        }
      _ => ()
    }
    if dead_code_elimination_try_fold_nonfallthrough_prefix_into_branch_payload(
        ctx, func, region_ref, idx, node_id,
      ) {
      changed = true
      continue
    }
    if dead_code_elimination_try_rewrite_split_local_set_wrapper_forwarder(
        ctx, func, branch_user_cache, region_ref, idx, node_id,
      ) {
      changed = true
      ignore(
        dead_code_elimination_try_rewrite_branch_payload_forwarder_in_subtree(
          ctx,
          func,
          branch_user_cache,
          node_use_cache,
          node_id,
        ),
      )
      if @ir.hot_local_count(func) > 700 {
        let child_id = @ir.hot_child_get(func, node_id, 0)
        let child_tags : Array[String] = []
        if child_id >= 0 && @ir.hot_node_is_live(func, child_id) {
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::Block => {
              let child_body = @ir.hot_region_body_ref(func, child_id)
              for root_idx = 0
                  ; root_idx < @ir.hot_region_root_count(func, child_body)
                  ; root_idx = root_idx + 1 {
                let root_id = @ir.hot_region_get(func, child_body, root_idx)
                child_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
              }
            }
            _ => ()
          }
        }
        pipeline_trace_hook(
          ctx.trace,
          "dead-code-elimination",
          "split-wrapper-followup",
          payload="idx=\{idx} node=\{node_id} child=\{child_id} child_op=\{@ir.hot_node_get(func, child_id).op} child_roots=\{child_tags}",
        )
        if child_id >= 0 &&
          @ir.hot_node_is_live(func, child_id) {
          match @ir.hot_node_get(func, child_id).op {
            @ir.HotOp::Block =>
              if @ir.hot_region_root_count(func, @ir.hot_region_body_ref(func, child_id)) >
                0 {
                let first_root = @ir.hot_region_get(
                  func,
                  @ir.hot_region_body_ref(func, child_id),
                  0,
                )
                if first_root >= 0 && @ir.hot_node_is_live(func, first_root) {
                  match @ir.hot_node_get(func, first_root).op {
                    @ir.HotOp::Block => {
                      let first_tags : Array[String] = []
                      let first_body = @ir.hot_region_body_ref(func, first_root)
                      for root_idx = 0
                          ; root_idx < @ir.hot_region_root_count(func, first_body)
                          ; root_idx = root_idx + 1 {
                        let root_id = @ir.hot_region_get(func, first_body, root_idx)
                        first_tags.push("\{root_idx}:\{@ir.hot_node_get(func, root_id).op}#\{root_id}")
                      }
                      pipeline_trace_hook(
                        ctx.trace,
                        "dead-code-elimination",
                        "split-wrapper-followup-first",
                        payload="idx=\{idx} node=\{node_id} first=\{first_root} first_roots=\{first_tags}",
                      )
                    }
                    _ => ()
                  }
                }
              }
            _ => ()
          }
        }
      }
      idx += 1
      continue
    }
    if dead_code_elimination_try_voidify_split_drop_control(
        ctx, func, branch_user_cache, node_use_cache, fallthrough_cache, purity_cache,
        region_ref, idx, node_id,
      ) {
      changed = true
      continue
    }

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
            (
              dead_code_elimination_voidify_control(
                ctx, func, branch_user_cache, node_use_cache, fallthrough_cache,
                purity_cache, child_id,
              ) ||
              dead_code_elimination_try_voidify_nonfallthrough_block_with_pure_incoming_branches(
                ctx, func, branch_user_cache, node_use_cache, fallthrough_cache,
                purity_cache, child_id,
              )
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
