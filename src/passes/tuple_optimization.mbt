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
