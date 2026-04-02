///|
struct HotTupleOptimizationGroup {
  producer : Int
  lane_locals : Array[Int]
  defining_nodes : Array[Int]
  mut copy_source : Int?
  mut uses : Int
  mut valid_uses : Int
  neighbors : Array[Int]
  mut bad : Bool
} derive(Eq, Show, Debug)

///|
struct HotTupleOptimizationAnalysis {
  groups : Array[HotTupleOptimizationGroup]
  local_group_ids : Array[Int]
} derive(Eq, Show, Debug)

///|
pub fn tuple_optimization_descriptor() -> @ir.HotPassDescriptor {
  @ir.HotPassDescriptor::new(
    "tuple-optimization",
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
pub fn tuple_optimization_summary() -> String {
  "Split exact HOT multivalue spill and copy bridges into fresh scalar locals before later local cleanup."
}

///|
fn tuple_optimization_may_have_candidates(func : @ir.HotFunc) -> Bool {
  let mut has_multivalue = false
  let mut has_local_writes = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    if @ir.hot_node_result_arity(func, node_id) > 1 {
      has_multivalue = true
    }
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => has_local_writes = true
      _ => ()
    }
    if has_multivalue && has_local_writes {
      return true
    }
  }
  false
}

///|
fn tuple_optimization_count_tee_defs(
  func : @ir.HotFunc,
  defining_nodes : Array[Int],
) -> Int {
  let mut count = 0
  for node_id in defining_nodes {
    match @ir.hot_node_get(func, node_id).op {
      @ir.HotOp::LocalTee => count = count + 1
      _ => ()
    }
  }
  count
}

///|
fn tuple_optimization_collect_seed_group(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  producer : Int,
) -> HotTupleOptimizationGroup? {
  let result_arity = @ir.hot_node_result_arity(func, producer)
  if result_arity <= 1 {
    return None
  }
  let use_sites = @ir.node_use_sites_borrowed(use_def, producer)
  if use_sites.length() != result_arity {
    return None
  }
  let seen_locals = Array::make(@ir.hot_local_count(func), false)
  let lane_locals_rev : Array[Int] = []
  let defining_nodes_rev : Array[Int] = []
  for site in use_sites {
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot => if site.slot != 0 { return None }
      _ => return None
    }
    let user = @ir.hot_node_get(func, site.user)
    match user.op {
      @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
      _ => return None
    }
    let local_id = user.imm0
    if local_id < 0 || local_id >= seen_locals.length() || seen_locals[local_id] {
      return None
    }
    seen_locals[local_id] = true
    lane_locals_rev.push(local_id)
    defining_nodes_rev.push(site.user)
  }
  let lane_locals : Array[Int] = []
  let defining_nodes : Array[Int] = []
  for idx = lane_locals_rev.length() - 1; idx >= 0; idx = idx - 1 {
    lane_locals.push(lane_locals_rev[idx])
    defining_nodes.push(defining_nodes_rev[idx])
  }
  Some({
    producer,
    lane_locals,
    defining_nodes,
    copy_source: None,
    uses: 1 + tuple_optimization_count_tee_defs(func, defining_nodes),
    valid_uses: 1 + tuple_optimization_count_tee_defs(func, defining_nodes),
    neighbors: [],
    bad: false,
  })
}

///|
fn tuple_optimization_collect_seed_groups(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
) -> Array[HotTupleOptimizationGroup] {
  let groups : Array[HotTupleOptimizationGroup] = []
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    match tuple_optimization_collect_seed_group(func, use_def, node_id) {
      Some(group) => groups.push(group)
      None => ()
    }
  }
  groups
}

///|
fn tuple_optimization_build_local_group_ids(
  func : @ir.HotFunc,
  groups : Array[HotTupleOptimizationGroup],
) -> Array[Int] {
  let local_group_ids = Array::make(@ir.hot_local_count(func), -1)
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    for local_id in groups[group_id].lane_locals {
      if local_id < 0 || local_id >= local_group_ids.length() {
        abort("tuple-optimization groups must reference existing locals")
      }
      local_group_ids[local_id] = group_id
    }
  }
  local_group_ids
}

///|
fn tuple_optimization_try_payload_source_read(
  func : @ir.HotFunc,
  node_id : Int,
) -> (Int, Int)? {
  let node = @ir.hot_node_get(func, node_id)
  match node.op {
    @ir.HotOp::LocalGet => Some((node.imm0, node_id))
    @ir.HotOp::LocalTee => {
      if @ir.hot_child_count(func, node_id) != 1 {
        return None
      }
      let child = @ir.hot_child_get(func, node_id, 0)
      let child_node = @ir.hot_node_get(func, child)
      match child_node.op {
        @ir.HotOp::LocalGet => Some((child_node.imm0, child))
        _ => None
      }
    }
    _ => None
  }
}

///|
fn tuple_optimization_add_neighbor(
  neighbors : Array[Int],
  neighbor : Int,
) -> Unit {
  for existing in neighbors {
    if existing == neighbor {
      return
    }
  }
  neighbors.push(neighbor)
}

///|
fn tuple_optimization_link_copy_groups(
  func : @ir.HotFunc,
  groups : Array[HotTupleOptimizationGroup],
  local_group_ids : Array[Int],
  copy_read_nodes : Array[Bool],
) -> Unit {
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    let producer = groups[group_id].producer
    match @ir.hot_node_get(func, producer).op {
      @ir.HotOp::Block => ()
      _ => continue
    }
    let body_ref = @ir.hot_region_body_ref(func, producer)
    let payload = match
      @ir.hot_region_split_trailing_payload_roots(
        func,
        body_ref,
        groups[group_id].lane_locals.length(),
      ) {
      Some((_, payload)) => payload
      None => continue
    }
    if payload.length() != groups[group_id].lane_locals.length() {
      continue
    }
    let mut source_group = -1
    let read_nodes : Array[Int] = []
    let mut exact_copy = true
    for lane_idx = 0; lane_idx < payload.length(); lane_idx = lane_idx + 1 {
      let (local_id, read_node) = match
        tuple_optimization_try_payload_source_read(func, payload[lane_idx]) {
        Some(found) => found
        None => {
          exact_copy = false
          break
        }
      }
      if local_id < 0 || local_id >= local_group_ids.length() {
        exact_copy = false
        break
      }
      let current_source = local_group_ids[local_id]
      if current_source < 0 {
        exact_copy = false
        break
      }
      if source_group < 0 {
        source_group = current_source
      } else if source_group != current_source {
        exact_copy = false
        break
      }
      if groups[current_source].lane_locals.length() != payload.length() ||
        groups[current_source].lane_locals[lane_idx] != local_id {
        exact_copy = false
        break
      }
      read_nodes.push(read_node)
    }
    if !exact_copy || source_group < 0 || source_group == group_id {
      continue
    }
    groups[group_id].copy_source = Some(source_group)
    tuple_optimization_add_neighbor(groups[group_id].neighbors, source_group)
    tuple_optimization_add_neighbor(groups[source_group].neighbors, group_id)
    groups[source_group].uses = groups[source_group].uses + 1
    groups[source_group].valid_uses = groups[source_group].valid_uses + 1
    for read_node in read_nodes {
      copy_read_nodes[read_node] = true
    }
  }
}

///|
fn tuple_optimization_count_lane_traffic(
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  copy_read_nodes : Array[Bool],
) -> Unit {
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    for lane_idx = 0
        lane_idx < groups[group_id].lane_locals.length()
        lane_idx = lane_idx + 1 {
      let local_id = groups[group_id].lane_locals[lane_idx]
      let defining_node = groups[group_id].defining_nodes[lane_idx]
      for write_id in @ir.local_write_nodes_borrowed(use_def, local_id) {
        if write_id == defining_node {
          continue
        }
        groups[group_id].uses = groups[group_id].uses + 1
      }
      for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
        if read_id >= 0 &&
          read_id < copy_read_nodes.length() &&
          copy_read_nodes[read_id] {
          continue
        }
        groups[group_id].uses = groups[group_id].uses + 1
        groups[group_id].valid_uses = groups[group_id].valid_uses + 1
      }
    }
  }
}

///|
fn tuple_optimization_propagate_badness(
  groups : Array[HotTupleOptimizationGroup],
) -> Unit {
  let queue : Array[Int] = []
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    if groups[group_id].uses > groups[group_id].valid_uses {
      groups[group_id].bad = true
      queue.push(group_id)
    }
  }
  let mut queue_head = 0
  while queue_head < queue.length() {
    let group_id = queue[queue_head]
    queue_head = queue_head + 1
    for neighbor in groups[group_id].neighbors {
      if neighbor < 0 || neighbor >= groups.length() || groups[neighbor].bad {
        continue
      }
      groups[neighbor].bad = true
      queue.push(neighbor)
    }
  }
}

///|
fn tuple_optimization_analyze(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
) -> HotTupleOptimizationAnalysis {
  if !tuple_optimization_may_have_candidates(func) {
    return {
      groups: [],
      local_group_ids: Array::make(@ir.hot_local_count(func), -1),
    }
  }
  let groups = tuple_optimization_collect_seed_groups(func, use_def)
  let local_group_ids = tuple_optimization_build_local_group_ids(func, groups)
  let copy_read_nodes = Array::make(@ir.hot_node_count(func), false)
  tuple_optimization_link_copy_groups(
    func, groups, local_group_ids, copy_read_nodes,
  )
  tuple_optimization_count_lane_traffic(use_def, groups, copy_read_nodes)
  tuple_optimization_propagate_badness(groups)
  { groups, local_group_ids }
}

///|
fn tuple_optimization_require_local_type(
  func : @ir.HotFunc,
  local_id : Int,
) -> @lib.ValType {
  match @ir.hot_local_type(func, local_id) {
    Some(ty) => ty
    None => abort("tuple-optimization rewrite requires valid local ids")
  }
}

///|
fn tuple_optimization_group_should_rewrite(
  group : HotTupleOptimizationGroup,
) -> Bool {
  !group.bad && group.valid_uses > 1
}

///|
fn tuple_optimization_replace_with_built(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  target_id : Int,
  replacement_id : Int,
) -> Unit {
  let replacement = @ir.hot_node_get(func, replacement_id)
  match replacement.op {
    @ir.HotOp::Block
    | @ir.HotOp::Loop
    | @ir.HotOp::If
    | @ir.HotOp::Try
    | @ir.HotOp::TryTable =>
      @ir.hot_label_owner_set(func, replacement.imm0, target_id)
    _ => ()
  }
  @ir.hot_delete_node(func, replacement_id)
  pass_replace_node(ctx, func, target_id, replacement)
}

///|
fn tuple_optimization_build_group_rewrite_mask(
  groups : Array[HotTupleOptimizationGroup],
) -> Array[Bool] {
  let rewrite_mask : Array[Bool] = []
  for group in groups {
    rewrite_mask.push(tuple_optimization_group_should_rewrite(group))
  }
  rewrite_mask
}

///|
fn tuple_optimization_ensure_split_locals(
  func : @ir.HotFunc,
  groups : Array[HotTupleOptimizationGroup],
  rewrite_mask : Array[Bool],
  split_locals_by_group : Array[Array[Int]],
  split_ready : Array[Bool],
  split_visiting : Array[Bool],
  group_id : Int,
) -> Array[Int] {
  if group_id < 0 || group_id >= groups.length() {
    abort("tuple-optimization rewrite group ids must stay in range")
  }
  if !rewrite_mask[group_id] {
    abort(
      "tuple-optimization rewrite only allocates split locals for good groups",
    )
  }
  if split_ready[group_id] {
    return split_locals_by_group[group_id]
  }
  if split_visiting[group_id] {
    abort("tuple-optimization rewrite copy graph must stay acyclic")
  }
  split_visiting[group_id] = true
  let source_lane_locals = match groups[group_id].copy_source {
    Some(source_group) => {
      if source_group < 0 ||
        source_group >= groups.length() ||
        !rewrite_mask[source_group] {
        abort(
          "tuple-optimization rewrite copy sources must stay within good groups",
        )
      }
      tuple_optimization_ensure_split_locals(
        func, groups, rewrite_mask, split_locals_by_group, split_ready, split_visiting,
        source_group,
      )
    }
    None => groups[group_id].lane_locals
  }
  let split_locals : Array[Int] = []
  for local_id in source_lane_locals {
    split_locals.push(
      @ir.hot_append_body_local(
        func,
        tuple_optimization_require_local_type(func, local_id),
      ),
    )
  }
  split_locals_by_group[group_id] = split_locals
  split_ready[group_id] = true
  split_visiting[group_id] = false
  split_locals
}

///|
fn tuple_optimization_collect_rewrite_order_visit(
  groups : Array[HotTupleOptimizationGroup],
  rewrite_mask : Array[Bool],
  seen : Array[Bool],
  out : Array[Int],
  group_id : Int,
) -> Unit {
  if group_id < 0 || group_id >= groups.length() || seen[group_id] {
    return
  }
  seen[group_id] = true
  match groups[group_id].copy_source {
    Some(source_group) =>
      tuple_optimization_collect_rewrite_order_visit(
        groups, rewrite_mask, seen, out, source_group,
      )
    None => ()
  }
  if rewrite_mask[group_id] {
    out.push(group_id)
  }
}

///|
fn tuple_optimization_collect_rewrite_order(
  groups : Array[HotTupleOptimizationGroup],
  rewrite_mask : Array[Bool],
) -> Array[Int] {
  let order : Array[Int] = []
  let seen = Array::make(groups.length(), false)
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    if rewrite_mask[group_id] {
      tuple_optimization_collect_rewrite_order_visit(
        groups, rewrite_mask, seen, order, group_id,
      )
    }
  }
  order
}

///|
fn tuple_optimization_build_source_host_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
) -> Int {
  let host_lane = split_locals.length() - 1
  let body : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    body.push(
      @ir.hot_build_local_set(func, split_locals[lane_idx], group.producer),
    )
  }
  let host = @ir.hot_node_get(func, group.defining_nodes[host_lane])
  match host.op {
    @ir.HotOp::LocalTee => {
      body.push(@ir.hot_build_local_get(func, split_locals[host_lane]))
      @ir.hot_build_block(
        func,
        @lib.BlockType::val_type(
          tuple_optimization_require_local_type(func, split_locals[host_lane]),
        ),
        body,
      )
    }
    _ => @ir.hot_build_block(func, @lib.BlockType::void_(), body)
  }
}

///|
fn tuple_optimization_build_copy_host_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals : Array[Int],
) -> Int {
  if split_locals.length() != source_split_locals.length() {
    abort("tuple-optimization rewrite copy groups must preserve lane arity")
  }
  let host_lane = split_locals.length() - 1
  let body : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    body.push(
      @ir.hot_build_local_set(
        func,
        split_locals[lane_idx],
        @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
      ),
    )
  }
  let host = @ir.hot_node_get(func, group.defining_nodes[host_lane])
  match host.op {
    @ir.HotOp::LocalTee => {
      body.push(@ir.hot_build_local_get(func, split_locals[host_lane]))
      @ir.hot_build_block(
        func,
        @lib.BlockType::val_type(
          tuple_optimization_require_local_type(func, split_locals[host_lane]),
        ),
        body,
      )
    }
    _ => @ir.hot_build_block(func, @lib.BlockType::void_(), body)
  }
}

///|
fn tuple_optimization_rewrite_group_reads(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
) -> Unit {
  for lane_idx = 0
      lane_idx < group.lane_locals.length()
      lane_idx = lane_idx + 1 {
    for
      read_id in @ir.local_read_nodes_borrowed(
        use_def,
        group.lane_locals[lane_idx],
      ) {
      if !@ir.hot_node_is_live(func, read_id) {
        continue
      }
      tuple_optimization_replace_with_built(
        ctx,
        func,
        read_id,
        @ir.hot_build_local_get(func, split_locals[lane_idx]),
      )
    }
  }
}

///|
fn tuple_optimization_rewrite_group_defs(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals? : Array[Int]? = None,
) -> Unit {
  let host_lane = group.defining_nodes.length() - 1
  let host_replacement = match source_split_locals {
    Some(source_split_locals) =>
      tuple_optimization_build_copy_host_replacement(
        func, group, split_locals, source_split_locals,
      )
    None =>
      tuple_optimization_build_source_host_replacement(
        func, group, split_locals,
      )
  }
  tuple_optimization_replace_with_built(
    ctx,
    func,
    group.defining_nodes[host_lane],
    host_replacement,
  )
  for lane_idx = 0
      lane_idx < group.defining_nodes.length()
      lane_idx = lane_idx + 1 {
    if lane_idx == host_lane ||
      !@ir.hot_node_is_live(func, group.defining_nodes[lane_idx]) {
      continue
    }
    let replacement = match
      @ir.hot_node_get(func, group.defining_nodes[lane_idx]).op {
      @ir.HotOp::LocalTee =>
        @ir.hot_build_local_get(func, split_locals[lane_idx])
      _ => @ir.hot_build_nop(func)
    }
    tuple_optimization_replace_with_built(
      ctx,
      func,
      group.defining_nodes[lane_idx],
      replacement,
    )
  }
}

///|
fn tuple_optimization_rewrite_good_components(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  analysis : HotTupleOptimizationAnalysis,
) -> Bool {
  let rewrite_mask = tuple_optimization_build_group_rewrite_mask(
    analysis.groups,
  )
  let mut has_rewrites = false
  for should_rewrite in rewrite_mask {
    if should_rewrite {
      has_rewrites = true
      break
    }
  }
  if !has_rewrites {
    return false
  }
  let split_locals_by_group : Array[Array[Int]] = []
  for _ in 0..<analysis.groups.length() {
    split_locals_by_group.push([])
  }
  let split_ready = Array::make(analysis.groups.length(), false)
  let split_visiting = Array::make(analysis.groups.length(), false)
  for group_id = 0; group_id < analysis.groups.length(); group_id = group_id + 1 {
    if rewrite_mask[group_id] {
      ignore(
        tuple_optimization_ensure_split_locals(
          func,
          analysis.groups,
          rewrite_mask,
          split_locals_by_group,
          split_ready,
          split_visiting,
          group_id,
        ),
      )
    }
  }
  let rewrite_order = tuple_optimization_collect_rewrite_order(
    analysis.groups,
    rewrite_mask,
  )
  for group_id in rewrite_order {
    let group = analysis.groups[group_id]
    let split_locals = split_locals_by_group[group_id]
    tuple_optimization_rewrite_group_reads(
      ctx,
      func,
      @ir.use_def_build(func),
      group,
      split_locals,
    )
    match group.copy_source {
      Some(source_group) =>
        tuple_optimization_rewrite_group_defs(
          ctx,
          func,
          group,
          split_locals,
          source_split_locals=Some(split_locals_by_group[source_group]),
        )
      None =>
        tuple_optimization_rewrite_group_defs(ctx, func, group, split_locals)
    }
    match group.copy_source {
      Some(_) => {
        @ir.hot_replace_child_spans_and_control_result_type(
          func,
          group.producer,
          @ir.hot_type_void(func),
          [@ir.HotChildSpanRewrite::new(group.producer, [])],
        )
        pass_mark_mutated(ctx, func)
      }
      None => ()
    }
  }
  true
}

///|
fn tuple_optimization_run(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> HotPassResult {
  if !tuple_optimization_may_have_candidates(func) {
    return HotPassResult::unchanged()
  }
  let analysis = tuple_optimization_analyze(
    func,
    pass_require_use_def(ctx, func),
  )
  if tuple_optimization_rewrite_good_components(ctx, func, analysis) {
    HotPassResult::changed()
  } else {
    HotPassResult::unchanged()
  }
}
