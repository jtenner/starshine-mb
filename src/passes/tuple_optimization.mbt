///|
struct HotTupleOptimizationGroup {
  producer : Int
  lane_locals : Array[Int]
  defining_nodes : Array[Int]
  mut host_lane : Int?
  mut copy_source : Int?
  mut copy_payload_locals : Array[Int]?
  mut uses : Int
  mut valid_uses : Int
  neighbors : Array[Int]
  mut bad : Bool
} derive(Eq, Show, Debug)

///|
struct HotTupleOptimizationAnalysis {
  groups : Array[HotTupleOptimizationGroup]
  local_group_ids : Array[Int]
  copy_read_nodes : Array[Bool]
} derive(Eq, Show, Debug)

///|
struct HotTupleOptimizationRootSlot {
  region_ref : @ir.HotRegionRef
  lane_idx : Int
  slot : Int
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
  let mut host_lane : Int? = None
  for lane_idx = 0; lane_idx < defining_nodes.length(); lane_idx = lane_idx + 1 {
    match @ir.hot_node_get(func, defining_nodes[lane_idx]).op {
      @ir.HotOp::LocalTee =>
        match host_lane {
          Some(_) => ()
          None => host_lane = Some(lane_idx)
        }
      _ => ()
    }
  }
  Some({
    producer,
    lane_locals,
    defining_nodes,
    host_lane,
    copy_source: None,
    copy_payload_locals: None,
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
fn tuple_optimization_resolve_copy_payload_local(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  local_group_ids : Array[Int],
  local_id : Int,
  visiting : Array[Bool],
) -> (Int, Array[Int])? {
  if local_id < 0 || local_id >= local_group_ids.length() {
    return None
  }
  if local_group_ids[local_id] >= 0 {
    return Some((local_id, []))
  }
  if local_id >= visiting.length() || visiting[local_id] {
    return None
  }
  visiting[local_id] = true
  let writes = @ir.local_write_nodes_borrowed(use_def, local_id)
  if writes.length() != 1 {
    return None
  }
  let write_id = writes[0]
  let write = @ir.hot_node_get(func, write_id)
  match write.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
    _ => return None
  }
  if write.imm0 != local_id || @ir.hot_child_count(func, write_id) != 1 {
    return None
  }
  let child = @ir.hot_child_get(func, write_id, 0)
  let child_node = @ir.hot_node_get(func, child)
  let next_local = match child_node.op {
    @ir.HotOp::LocalGet => child_node.imm0
    @ir.HotOp::LocalTee => child_node.imm0
    _ => return None
  }
  match
    tuple_optimization_resolve_copy_payload_local(
      func, use_def, local_group_ids, next_local, visiting,
    ) {
    Some((resolved_local, alias_read_nodes)) =>
      Some((resolved_local, [child] + alias_read_nodes))
    None => None
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
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  local_group_ids : Array[Int],
  copy_read_nodes : Array[Bool],
  copy_write_nodes : Array[Bool],
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
    let payload_locals : Array[Int] = []
    let resolved_source_locals : Array[Int] = []
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
      payload_locals.push(local_id)
      let (resolved_local, alias_read_nodes) = match
        tuple_optimization_resolve_copy_payload_local(
          func,
          use_def,
          local_group_ids,
          local_id,
          Array::make(@ir.hot_local_count(func), false),
        ) {
        Some(found) => found
        None => {
          exact_copy = false
          break
        }
      }
      if resolved_local < 0 || resolved_local >= local_group_ids.length() {
        exact_copy = false
        break
      }
      let mut current_source = local_group_ids[resolved_local]
      if current_source == group_id &&
        source_group >= 0 &&
        source_group < groups.length() &&
        groups[group_id].lane_locals[lane_idx] == resolved_local &&
        lane_idx < groups[source_group].lane_locals.length() &&
        groups[source_group].lane_locals[lane_idx] == resolved_local {
        current_source = source_group
      }
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
        groups[current_source].lane_locals[lane_idx] != resolved_local {
        exact_copy = false
        break
      }
      read_nodes.push(read_node)
      for alias_read_node in alias_read_nodes {
        read_nodes.push(alias_read_node)
      }
      resolved_source_locals.push(resolved_local)
    }
    if !exact_copy || source_group < 0 || source_group == group_id {
      continue
    }
    groups[group_id].copy_source = Some(source_group)
    groups[group_id].copy_payload_locals = Some(payload_locals)
    tuple_optimization_add_neighbor(groups[group_id].neighbors, source_group)
    tuple_optimization_add_neighbor(groups[source_group].neighbors, group_id)
    groups[source_group].uses = groups[source_group].uses + 1
    groups[source_group].valid_uses = groups[source_group].valid_uses + 1
    for read_node in read_nodes {
      copy_read_nodes[read_node] = true
    }
    for lane_idx = 0
        lane_idx < resolved_source_locals.length()
        lane_idx = lane_idx + 1 {
      if groups[group_id].lane_locals[lane_idx] !=
        resolved_source_locals[lane_idx] {
        continue
      }
      let defining_node = groups[group_id].defining_nodes[lane_idx]
      if defining_node >= 0 && defining_node < copy_write_nodes.length() {
        copy_write_nodes[defining_node] = true
      }
    }
  }
}

///|
fn tuple_optimization_collect_scalar_forward_copy_group(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  local_group_ids : Array[Int],
  copy_read_nodes : Array[Bool],
  source_group_id : Int,
) -> (HotTupleOptimizationGroup, Array[Int], Int)? {
  if source_group_id < 0 || source_group_id >= groups.length() {
    return None
  }
  let source = groups[source_group_id]
  let seen_locals = Array::make(@ir.hot_local_count(func), false)
  let lane_locals : Array[Int] = []
  let defining_nodes : Array[Int] = []
  let read_nodes : Array[Int] = []
  let mut consumed_source_tees = 0
  let mut has_forwarded_lane = false
  for lane_idx = 0
      lane_idx < source.lane_locals.length()
      lane_idx = lane_idx + 1 {
    let local_id = source.lane_locals[lane_idx]
    let mut forwarded_local = -1
    let mut forwarding_def = -1
    let mut forwarding_read = -1
    let mut found = false
    let mut direct_non_forward_reads = 0
    for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
      if read_id >= 0 &&
        read_id < copy_read_nodes.length() &&
        copy_read_nodes[read_id] {
        continue
      }
      match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
        Some((next_local, next_def, _)) => {
          if found ||
            next_local < 0 ||
            next_local >= local_group_ids.length() ||
            local_group_ids[next_local] >= 0 ||
            next_local >= seen_locals.length() ||
            seen_locals[next_local] {
            return None
          }
          found = true
          forwarded_local = next_local
          forwarding_def = next_def
          forwarding_read = read_id
        }
        None => direct_non_forward_reads = direct_non_forward_reads + 1
      }
    }
    if !found {
      if direct_non_forward_reads == 1 {
        if local_id < 0 ||
          local_id >= seen_locals.length() ||
          seen_locals[local_id] {
          return None
        }
        found = true
        forwarded_local = local_id
        forwarding_def = source.defining_nodes[lane_idx]
      } else {
        let defining_node = source.defining_nodes[lane_idx]
        match @ir.hot_node_get(func, defining_node).op {
          @ir.HotOp::LocalTee => {
            let sites = @ir.node_use_sites_borrowed(use_def, defining_node)
            if sites.length() != 1 {
              return None
            }
            let site = sites[0]
            match site.kind {
              @ir.HotUseSlotKind::ChildUseSlot => ()
              _ => return None
            }
            let user = @ir.hot_node_get(func, site.user)
            match user.op {
              @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
                let next_local = user.imm0
                if next_local < 0 ||
                  next_local >= local_group_ids.length() ||
                  local_group_ids[next_local] >= 0 ||
                  next_local >= seen_locals.length() ||
                  seen_locals[next_local] ||
                  @ir.local_write_nodes_borrowed(use_def, next_local).length() !=
                  1 {
                  return None
                }
                found = true
                forwarded_local = next_local
                forwarding_def = site.user
                consumed_source_tees = consumed_source_tees + 1
              }
              _ => return None
            }
          }
          _ => ()
        }
      }
    }
    if !found {
      return None
    }
    seen_locals[forwarded_local] = true
    lane_locals.push(forwarded_local)
    defining_nodes.push(forwarding_def)
    if forwarding_read >= 0 {
      read_nodes.push(forwarding_read)
      if forwarded_local != local_id {
        has_forwarded_lane = true
      }
    }
  }
  if !has_forwarded_lane {
    return None
  }
  Some(
    (
      {
        producer: -1,
        lane_locals,
        defining_nodes,
        host_lane: source.host_lane,
        copy_source: Some(source_group_id),
        copy_payload_locals: None,
        uses: tuple_optimization_count_tee_defs(func, defining_nodes),
        valid_uses: tuple_optimization_count_tee_defs(func, defining_nodes),
        neighbors: [source_group_id],
        bad: false,
      },
      read_nodes,
      consumed_source_tees,
    ),
  )
}

///|
fn tuple_optimization_link_scalar_forward_copy_groups(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  local_group_ids : Array[Int],
  copy_read_nodes : Array[Bool],
) -> Unit {
  let mut group_id = 0
  while group_id < groups.length() {
    let group = groups[group_id]
    let mut can_link = false
    match group.copy_source {
      Some(source_group) =>
        if group.producer < 0 &&
          source_group >= 0 &&
          source_group < groups.length() {
          for lane_idx = 0
              lane_idx < group.lane_locals.length()
              lane_idx = lane_idx + 1 {
            if lane_idx < groups[source_group].lane_locals.length() &&
              group.lane_locals[lane_idx] ==
              groups[source_group].lane_locals[lane_idx] {
              can_link = true
              break
            }
          }
        }
      None =>
        if group.producer >= 0 {
          match @ir.hot_node_get(func, group.producer).op {
            @ir.HotOp::Block => ()
            _ => can_link = true
          }
        }
    }
    if !can_link {
      group_id = group_id + 1
      continue
    }
    match
      tuple_optimization_collect_scalar_forward_copy_group(
        func, use_def, groups, local_group_ids, copy_read_nodes, group_id,
      ) {
      Some((group, read_nodes, consumed_source_tees)) => {
        let new_group_id = groups.length()
        groups.push(group)
        for local_id in group.lane_locals {
          if local_id < 0 || local_id >= local_group_ids.length() {
            abort("tuple-optimization scalar copy groups must stay in range")
          }
          local_group_ids[local_id] = new_group_id
        }
        tuple_optimization_add_neighbor(
          groups[group_id].neighbors,
          new_group_id,
        )
        groups[group_id].uses = groups[group_id].uses + 1 - consumed_source_tees
        groups[group_id].valid_uses = groups[group_id].valid_uses +
          1 -
          consumed_source_tees
        for read_node in read_nodes {
          if read_node >= 0 && read_node < copy_read_nodes.length() {
            copy_read_nodes[read_node] = true
          }
        }
      }
      None => ()
    }
    group_id = group_id + 1
  }
}

///|
fn tuple_optimization_node_has_direct_non_scalar_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> Bool {
  for site in @ir.node_use_sites_borrowed(use_def, node_id) {
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot =>
        match @ir.hot_node_get(func, site.user).op {
          @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => ()
          _ => return true
        }
      _ => return true
    }
  }
  false
}

///|
fn tuple_optimization_node_has_direct_non_drop_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  node_id : Int,
) -> Bool {
  for site in @ir.node_use_sites_borrowed(use_def, node_id) {
    match site.kind {
      @ir.HotUseSlotKind::ChildUseSlot =>
        match @ir.hot_node_get(func, site.user).op {
          @ir.HotOp::LocalSet | @ir.HotOp::LocalTee | @ir.HotOp::Drop => ()
          _ => return true
        }
      _ => return true
    }
  }
  false
}

///|
fn tuple_optimization_scalar_forward_local(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  read_id : Int,
) -> (Int, Int, Bool)? {
  let sites = @ir.node_use_sites_borrowed(use_def, read_id)
  if sites.length() != 1 {
    return None
  }
  let site = sites[0]
  match site.kind {
    @ir.HotUseSlotKind::ChildUseSlot => ()
    _ => return None
  }
  let user = @ir.hot_node_get(func, site.user)
  match user.op {
    @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
      let forwarded_local = user.imm0
      if @ir.local_write_nodes_borrowed(use_def, forwarded_local).length() != 1 {
        return None
      }
      let is_tee = match user.op {
        @ir.HotOp::LocalTee => true
        _ => false
      }
      Some((forwarded_local, site.user, is_tee))
    }
    _ => None
  }
}

///|
fn tuple_optimization_local_has_forwarded_non_scalar_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  local_id : Int,
  visited : Array[Bool],
) -> Bool {
  if local_id < 0 || local_id >= visited.length() || visited[local_id] {
    return false
  }
  visited[local_id] = true
  for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
    match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
      Some((next_local, next_def, next_is_tee)) => {
        if next_is_tee &&
          tuple_optimization_node_has_direct_non_scalar_use(
            func, use_def, next_def,
          ) {
          return true
        }
        if tuple_optimization_local_has_forwarded_non_scalar_use(
            func, use_def, next_local, visited,
          ) {
          return true
        }
      }
      None => return true
    }
  }
  false
}

///|
fn tuple_optimization_local_has_forwarded_non_drop_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  local_id : Int,
  visited : Array[Bool],
) -> Bool {
  if local_id < 0 || local_id >= visited.length() || visited[local_id] {
    return false
  }
  visited[local_id] = true
  for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
    match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
      Some((next_local, next_def, next_is_tee)) => {
        if next_is_tee &&
          tuple_optimization_node_has_direct_non_drop_use(
            func, use_def, next_def,
          ) {
          return true
        }
        if tuple_optimization_local_has_forwarded_non_drop_use(
            func, use_def, next_local, visited,
          ) {
          return true
        }
      }
      None =>
        if tuple_optimization_node_has_direct_non_drop_use(
            func, use_def, read_id,
          ) {
          return true
        }
    }
  }
  false
}

///|
fn tuple_optimization_local_has_forwarded_any_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  local_id : Int,
  visited : Array[Bool],
) -> Bool {
  if local_id < 0 || local_id >= visited.length() || visited[local_id] {
    return false
  }
  visited[local_id] = true
  for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
    match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
      Some((next_local, _, _)) =>
        if tuple_optimization_local_has_forwarded_any_use(
            func, use_def, next_local, visited,
          ) {
          return true
        }
      None => return true
    }
  }
  false
}

///|
fn tuple_optimization_local_has_forwarded_host_tee_use(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  local_id : Int,
  visited : Array[Bool],
) -> Bool {
  if local_id < 0 || local_id >= visited.length() || visited[local_id] {
    return false
  }
  visited[local_id] = true
  let mut locally_tee_defined = false
  for write_id in @ir.local_write_nodes_borrowed(use_def, local_id) {
    match @ir.hot_node_get(func, write_id).op {
      @ir.HotOp::LocalTee => {
        locally_tee_defined = true
        break
      }
      _ => ()
    }
  }
  for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
    match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
      Some((next_local, next_def, next_is_tee)) => {
        if next_is_tee &&
          tuple_optimization_node_has_direct_non_scalar_use(
            func, use_def, next_def,
          ) {
          return true
        }
        if tuple_optimization_local_has_forwarded_host_tee_use(
            func, use_def, next_local, visited,
          ) {
          return true
        }
      }
      None =>
        if locally_tee_defined &&
          tuple_optimization_node_has_direct_non_scalar_use(
            func, use_def, read_id,
          ) {
          return true
        }
    }
  }
  false
}

///|
fn tuple_optimization_read_is_invalid_scalar_copy_through(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  read_id : Int,
) -> Bool {
  match tuple_optimization_scalar_forward_local(func, use_def, read_id) {
    Some((forwarded_local, forwarding_def, is_tee)) => {
      if is_tee &&
        tuple_optimization_node_has_direct_non_scalar_use(
          func, use_def, forwarding_def,
        ) {
        return false
      }
      let visited = Array::make(@ir.hot_local_count(func), false)
      !tuple_optimization_local_has_forwarded_non_scalar_use(
        func, use_def, forwarded_local, visited,
      )
    }
    None => false
  }
}

///|
fn tuple_optimization_finalize_host_lanes(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
) -> Unit {
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    if groups[group_id].host_lane is Some(_) {
      continue
    }
    let mut candidate : Int? = None
    let mut multiple = false
    for lane_idx = 0
        lane_idx < groups[group_id].lane_locals.length()
        lane_idx = lane_idx + 1 {
      let defining_node = groups[group_id].defining_nodes[lane_idx]
      let has_direct_host_tee_use = match
        @ir.hot_node_get(func, defining_node).op {
        @ir.HotOp::LocalTee =>
          tuple_optimization_node_has_direct_non_scalar_use(
            func, use_def, defining_node,
          )
        _ => false
      }
      let visited = Array::make(@ir.hot_local_count(func), false)
      if !has_direct_host_tee_use &&
        !tuple_optimization_local_has_forwarded_host_tee_use(
          func,
          use_def,
          groups[group_id].lane_locals[lane_idx],
          visited,
        ) {
        continue
      }
      match candidate {
        Some(_) => {
          multiple = true
          break
        }
        None => candidate = Some(lane_idx)
      }
    }
    if !multiple {
      groups[group_id].host_lane = candidate
    }
  }
}

///|
fn tuple_optimization_find_overlap_lane_between_groups(
  groups : Array[HotTupleOptimizationGroup],
  source_group_id : Int,
  copy_group_id : Int,
  local_id : Int,
) -> Int? {
  if source_group_id < 0 ||
    source_group_id >= groups.length() ||
    copy_group_id < 0 ||
    copy_group_id >= groups.length() {
    return None
  }
  for lane_idx = 0
      lane_idx < groups[source_group_id].lane_locals.length()
      lane_idx = lane_idx + 1 {
    if lane_idx >= groups[copy_group_id].lane_locals.length() {
      return None
    }
    if groups[source_group_id].lane_locals[lane_idx] == local_id &&
      groups[copy_group_id].lane_locals[lane_idx] == local_id {
      return Some(lane_idx)
    }
  }
  None
}

///|
fn tuple_optimization_count_lane_traffic(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  local_group_ids : Array[Int],
  copy_read_nodes : Array[Bool],
  copy_write_nodes : Array[Bool],
) -> Unit {
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    for lane_idx = 0
        lane_idx < groups[group_id].lane_locals.length()
        lane_idx = lane_idx + 1 {
      let local_id = groups[group_id].lane_locals[lane_idx]
      let defining_node = groups[group_id].defining_nodes[lane_idx]
      let mut overlap_owner_lane : Int? = None
      if local_id >= 0 && local_id < local_group_ids.length() {
        let owner_group = local_group_ids[local_id]
        if owner_group >= 0 &&
          owner_group != group_id &&
          owner_group < groups.length() &&
          groups[owner_group].copy_source == Some(group_id) {
          overlap_owner_lane = tuple_optimization_find_overlap_lane_between_groups(
            groups, group_id, owner_group, local_id,
          )
        }
      }
      let mut overlap_source_lane : Int? = None
      match groups[group_id].copy_source {
        Some(source_group) =>
          overlap_source_lane = tuple_optimization_find_overlap_lane_between_groups(
            groups, source_group, group_id, local_id,
          )
        None => ()
      }
      for write_id in @ir.local_write_nodes_borrowed(use_def, local_id) {
        if write_id == defining_node ||
          (
            write_id >= 0 &&
            write_id < copy_write_nodes.length() &&
            copy_write_nodes[write_id]
          ) {
          continue
        }
        let mut skip_overlap_write = false
        match overlap_owner_lane {
          Some(_) => skip_overlap_write = true
          None => ()
        }
        match overlap_source_lane {
          Some(source_lane_idx) =>
            match groups[group_id].copy_source {
              Some(source_group) =>
                if write_id ==
                  groups[source_group].defining_nodes[source_lane_idx] {
                  skip_overlap_write = true
                }
              _ => ()
            }
          None => ()
        }
        if skip_overlap_write {
          continue
        }
        groups[group_id].uses = groups[group_id].uses + 1
      }
      for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
        match overlap_owner_lane {
          Some(_) => continue
          None => ()
        }
        if read_id >= 0 &&
          read_id < copy_read_nodes.length() &&
          copy_read_nodes[read_id] {
          continue
        }
        groups[group_id].uses = groups[group_id].uses + 1
        if tuple_optimization_read_is_invalid_scalar_copy_through(
            func, use_def, read_id,
          ) {
          continue
        }
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
      copy_read_nodes: Array::make(@ir.hot_node_count(func), false),
    }
  }
  let groups = tuple_optimization_collect_seed_groups(func, use_def)
  let mut local_group_ids = tuple_optimization_build_local_group_ids(
    func, groups,
  )
  let copy_read_nodes = Array::make(@ir.hot_node_count(func), false)
  let copy_write_nodes = Array::make(@ir.hot_node_count(func), false)
  tuple_optimization_link_copy_groups(
    func, use_def, groups, local_group_ids, copy_read_nodes, copy_write_nodes,
  )
  tuple_optimization_link_scalar_forward_copy_groups(
    func, use_def, groups, local_group_ids, copy_read_nodes,
  )
  local_group_ids = tuple_optimization_build_local_group_ids(func, groups)
  tuple_optimization_count_lane_traffic(
    func, use_def, groups, local_group_ids, copy_read_nodes, copy_write_nodes,
  )
  tuple_optimization_finalize_host_lanes(func, use_def, groups)
  tuple_optimization_propagate_badness(groups)
  { groups, local_group_ids, copy_read_nodes }
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
  let exact_copy_group = group.producer >= 0 && group.copy_source is Some(_)
  !group.bad &&
  (group.valid_uses > 1 || exact_copy_group) &&
  (group.producer >= 0 || tuple_optimization_group_host_lane(group) is Some(_))
}

///|
fn tuple_optimization_copy_group_redundant_with_source_host_chain(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  group_id : Int,
) -> Bool {
  if group_id < 0 || group_id >= groups.length() {
    return false
  }
  let group = groups[group_id]
  let source_group_id = match group.copy_source {
    Some(source_group_id) => source_group_id
    None => return false
  }
  if source_group_id < 0 || source_group_id >= groups.length() {
    return false
  }
  if groups[source_group_id].copy_source is None &&
    tuple_optimization_source_group_has_host_copy_consumer(
      groups, source_group_id,
    ) {
    return false
  }
  let source_host_lane = match
    tuple_optimization_group_host_lane(groups[source_group_id]) {
    Some(source_host_lane) => source_host_lane
    None => return false
  }
  let host_lane = match tuple_optimization_group_host_lane(group) {
    Some(host_lane) => host_lane
    None => return false
  }
  let chain = match
    tuple_optimization_find_passthrough_root_chain(
      func,
      use_def,
      groups[source_group_id].defining_nodes[source_host_lane],
    ) {
    Some(chain) if !chain.is_empty() => chain
    _ => return false
  }
  chain[chain.length() - 1] == group.defining_nodes[host_lane]
}

///|
fn tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  group : HotTupleOptimizationGroup,
) -> Bool {
  if group.copy_source is Some(_) || group.lane_locals.is_empty() {
    return false
  }
  let mut inner_block = -1
  for lane_idx = 0
      lane_idx < group.lane_locals.length()
      lane_idx = lane_idx + 1 {
    let local_id = group.lane_locals[lane_idx]
    let reads = @ir.local_read_nodes_borrowed(use_def, local_id)
    let mut matched = false
    for read_id in reads {
      let sites = @ir.node_use_sites_borrowed(use_def, read_id)
      if sites.length() != 1 {
        continue
      }
      let site = sites[0]
      match site.kind {
        @ir.HotUseSlotKind::RootUseSlot =>
          if site.slot == lane_idx {
            match @ir.hot_node_get(func, site.user).op {
              @ir.HotOp::Block => {
                match inner_block {
                  -1 => inner_block = site.user
                  _ => if inner_block != site.user { return false }
                }
                matched = true
                break
              }
              _ => ()
            }
          }
        _ => ()
      }
    }
    if !matched {
      return false
    }
  }
  if inner_block < 0 {
    return false
  }
  let inner_sites = @ir.node_use_sites_borrowed(use_def, inner_block)
  if inner_sites.length() != group.lane_locals.length() {
    return false
  }
  let mut outer_block = -1
  for lane_idx = 0; lane_idx < inner_sites.length(); lane_idx = lane_idx + 1 {
    let site = inner_sites[lane_idx]
    match site.kind {
      @ir.HotUseSlotKind::RootUseSlot =>
        if site.slot == lane_idx {
          match @ir.hot_node_get(func, site.user).op {
            @ir.HotOp::Block =>
              match outer_block {
                -1 => outer_block = site.user
                _ => if outer_block != site.user { return false }
              }
            _ => return false
          }
        } else {
          return false
        }
      _ => return false
    }
  }
  if outer_block < 0 {
    return false
  }
  let outer_sites = @ir.node_use_sites_borrowed(use_def, outer_block)
  if outer_sites.length() != 1 {
    return false
  }
  match outer_sites[0].kind {
    @ir.HotUseSlotKind::ChildUseSlot =>
      match @ir.hot_node_get(func, outer_sites[0].user).op {
        @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => true
        _ => false
      }
    _ => false
  }
}

///|
fn tuple_optimization_group_should_rewrite_in_func(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  group_id : Int,
) -> Bool {
  if group_id < 0 || group_id >= groups.length() {
    return false
  }
  let group = groups[group_id]
  let mut copy_group_non_drop_lane_count = 0
  let mut copy_group_only_uses_host_non_drop = false
  match (group.copy_source, tuple_optimization_group_host_lane(group)) {
    (Some(_), host_lane) => {
      let mut only_host = true
      for lane_idx = 0
          lane_idx < group.lane_locals.length()
          lane_idx = lane_idx + 1 {
        let non_drop_visited = Array::make(@ir.hot_local_count(func), false)
        let has_non_drop_use = tuple_optimization_local_has_forwarded_non_drop_use(
          func,
          use_def,
          group.lane_locals[lane_idx],
          non_drop_visited,
        )
        if has_non_drop_use {
          copy_group_non_drop_lane_count += 1
          match host_lane {
            Some(host_lane) if lane_idx == host_lane => ()
            _ => only_host = false
          }
          continue
        }
        let any_use_visited = Array::make(@ir.hot_local_count(func), false)
        if tuple_optimization_local_has_forwarded_any_use(
            func,
            use_def,
            group.lane_locals[lane_idx],
            any_use_visited,
          ) {
          ()
        }
      }
      copy_group_only_uses_host_non_drop = only_host &&
        copy_group_non_drop_lane_count > 0
    }
    _ => ()
  }
  let mut suppressed_child_copy_count = 0
  for child_group_id = 0
      child_group_id < groups.length()
      child_group_id = child_group_id + 1 {
    if groups[child_group_id].copy_source != Some(group_id) {
      continue
    }
    let mut child_non_drop_lane_count = 0
    let mut child_has_drop_only_lane_use = false
    for lane_idx = 0
        lane_idx < groups[child_group_id].lane_locals.length()
        lane_idx = lane_idx + 1 {
      let child_local = groups[child_group_id].lane_locals[lane_idx]
      let child_non_drop_visited = Array::make(@ir.hot_local_count(func), false)
      if tuple_optimization_local_has_forwarded_non_drop_use(
          func, use_def, child_local, child_non_drop_visited,
        ) {
        child_non_drop_lane_count += 1
        continue
      }
      let child_any_use_visited = Array::make(@ir.hot_local_count(func), false)
      if tuple_optimization_local_has_forwarded_any_use(
          func, use_def, child_local, child_any_use_visited,
        ) {
        child_has_drop_only_lane_use = true
      }
    }
    if groups[child_group_id].producer < 0 &&
      child_non_drop_lane_count <= 1 &&
      (
        child_has_drop_only_lane_use ||
        child_non_drop_lane_count < groups[child_group_id].lane_locals.length()
      ) {
      suppressed_child_copy_count += 1
      continue
    }
    suppressed_child_copy_count = -1
    break
  }
  tuple_optimization_group_should_rewrite(groups[group_id]) &&
  !(group.copy_source is Some(_) &&
  group.producer < 0 &&
  copy_group_non_drop_lane_count <= 1 &&
  copy_group_non_drop_lane_count < group.lane_locals.length()) &&
  !(group.copy_source is Some(_) &&
  group.producer < 0 &&
  suppressed_child_copy_count > 0 &&
  groups[group_id].valid_uses ==
  1 +
  tuple_optimization_count_tee_defs(func, groups[group_id].defining_nodes) +
  suppressed_child_copy_count) &&
  !(group.copy_source is Some(_) &&
  group.producer < 0 &&
  copy_group_only_uses_host_non_drop) &&
  !tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(
    func, use_def, group,
  ) &&
  !tuple_optimization_copy_group_redundant_with_source_host_chain(
    func, use_def, groups, group_id,
  )
}

///|
fn tuple_optimization_has_nested_rootslot_host_copy_wrapper_group(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
) -> Bool {
  for group in groups {
    if tuple_optimization_group_has_nested_rootslot_host_copy_wrapper(
        func, use_def, group,
      ) {
      return true
    }
  }
  false
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
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
) -> Array[Bool] {
  if tuple_optimization_has_nested_rootslot_host_copy_wrapper_group(
      func, use_def, groups,
    ) {
    return Array::make(groups.length(), false)
  }
  let rewrite_mask : Array[Bool] = []
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    rewrite_mask.push(
      tuple_optimization_group_should_rewrite_in_func(
        func, use_def, groups, group_id,
      ),
    )
  }
  rewrite_mask
}

///|
fn tuple_optimization_ensure_split_locals(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  copy_read_nodes : Array[Bool],
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
    match groups[group_id].copy_source {
      Some(_) => {
        let split_locals = groups[group_id].lane_locals
        split_locals_by_group[group_id] = split_locals
        split_ready[group_id] = true
        split_visiting[group_id] = false
        return split_locals
      }
      None =>
        abort(
          "tuple-optimization rewrite only allocates split locals for good groups",
        )
    }
  }
  if split_ready[group_id] {
    return split_locals_by_group[group_id]
  }
  if split_visiting[group_id] {
    abort("tuple-optimization rewrite copy graph must stay acyclic")
  }
  split_visiting[group_id] = true
  if !tuple_optimization_group_needs_dedicated_split_locals(
      func,
      use_def,
      groups,
      copy_read_nodes,
      rewrite_mask,
      group_id,
      groups[group_id],
    ) {
    let split_locals = groups[group_id].lane_locals
    split_locals_by_group[group_id] = split_locals
    split_ready[group_id] = true
    split_visiting[group_id] = false
    return split_locals
  }
  let source_lane_locals = match groups[group_id].copy_source {
    Some(source_group) => {
      if source_group < 0 || source_group >= groups.length() {
        abort(
          "tuple-optimization rewrite copy sources must stay within good groups",
        )
      }
      tuple_optimization_ensure_split_locals(
        func, use_def, groups, copy_read_nodes, rewrite_mask, split_locals_by_group,
        split_ready, split_visiting, source_group,
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
fn tuple_optimization_group_host_lane(
  group : HotTupleOptimizationGroup,
) -> Int? {
  group.host_lane
}

///|
fn tuple_optimization_source_group_has_host_copy_consumer(
  groups : Array[HotTupleOptimizationGroup],
  source_group_id : Int,
) -> Bool {
  if source_group_id < 0 || source_group_id >= groups.length() {
    return false
  }
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    if group_id == source_group_id {
      continue
    }
    if groups[group_id].copy_source == Some(source_group_id) &&
      tuple_optimization_group_host_lane(groups[group_id]) is Some(_) {
      return true
    }
  }
  false
}

///|
fn tuple_optimization_source_group_has_rewritten_host_copy_consumer(
  groups : Array[HotTupleOptimizationGroup],
  rewrite_mask : Array[Bool],
  source_group_id : Int,
) -> Bool {
  if source_group_id < 0 || source_group_id >= groups.length() {
    return false
  }
  for group_id = 0; group_id < groups.length(); group_id = group_id + 1 {
    if group_id == source_group_id {
      continue
    }
    if group_id >= rewrite_mask.length() || !rewrite_mask[group_id] {
      continue
    }
    if groups[group_id].copy_source == Some(source_group_id) &&
      tuple_optimization_group_host_lane(groups[group_id]) is Some(_) {
      return true
    }
  }
  false
}

///|
fn tuple_optimization_source_group_host_copy_consumer_needs_preserved_lanes(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  copy_read_nodes : Array[Bool],
  source_group_id : Int,
) -> Bool {
  if source_group_id < 0 || source_group_id >= groups.length() {
    return false
  }
  let group = groups[source_group_id]
  for lane_idx = 0
      lane_idx < group.lane_locals.length()
      lane_idx = lane_idx + 1 {
    let defining_node = group.defining_nodes[lane_idx]
    match @ir.hot_node_get(func, defining_node).op {
      @ir.HotOp::LocalTee =>
        if tuple_optimization_node_has_direct_non_scalar_use(
            func, use_def, defining_node,
          ) {
          return true
        }
      _ => ()
    }
    let local_id = group.lane_locals[lane_idx]
    for read_id in @ir.local_read_nodes_borrowed(use_def, local_id) {
      if read_id >= 0 &&
        read_id < copy_read_nodes.length() &&
        copy_read_nodes[read_id] {
        continue
      }
      return true
    }
  }
  false
}

///|
fn tuple_optimization_lane_locals_are_strictly_increasing(
  lane_locals : Array[Int],
) -> Bool {
  if lane_locals.length() <= 1 {
    return true
  }
  for lane_idx = 1; lane_idx < lane_locals.length(); lane_idx = lane_idx + 1 {
    if lane_locals[lane_idx - 1] >= lane_locals[lane_idx] {
      return false
    }
  }
  true
}

///|
fn tuple_optimization_group_needs_dedicated_split_locals(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  groups : Array[HotTupleOptimizationGroup],
  copy_read_nodes : Array[Bool],
  rewrite_mask : Array[Bool],
  group_id : Int,
  group : HotTupleOptimizationGroup,
) -> Bool {
  if group.copy_source is None &&
    tuple_optimization_source_group_has_rewritten_host_copy_consumer(
      groups, rewrite_mask, group_id,
    ) &&
    tuple_optimization_source_group_host_copy_consumer_needs_preserved_lanes(
      func, use_def, groups, copy_read_nodes, group_id,
    ) {
    return true
  }
  if group.copy_source is Some(_) &&
    !tuple_optimization_lane_locals_are_strictly_increasing(group.lane_locals) {
    return true
  }
  match tuple_optimization_group_host_lane(group) {
    Some(host_lane) =>
      match
        tuple_optimization_find_root_slot(
          func,
          group.defining_nodes[host_lane],
          host_lane,
        ) {
        Some(_) => false
        None =>
          match
            tuple_optimization_find_passthrough_root_chain(
              func,
              use_def,
              group.defining_nodes[host_lane],
            ) {
            Some(chain) if !chain.is_empty() => false
            _ =>
              match
                tuple_optimization_pick_root_anchor_slot(func, group, host_lane) {
                Some(_) => true
                None => false
              }
          }
      }
    None =>
      match tuple_optimization_pick_no_host_root_carrier_slot(func, group) {
        Some(slot) => slot.region_ref != @ir.HotRegionRef::root()
        None => false
      }
  }
}

///|
fn tuple_optimization_split_reuses_group_lanes(
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
) -> Bool {
  split_locals == group.lane_locals
}

///|
fn tuple_optimization_find_root_slot_in_region(
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
  target_id : Int,
) -> (@ir.HotRegionRef, Int)? {
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, slot)
    if root_id == target_id {
      return Some((region_ref, slot))
    }
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        match
          tuple_optimization_find_root_slot_in_region(
            func,
            @ir.hot_region_body_ref(func, root_id),
            target_id,
          ) {
          Some(found) => return Some(found)
          None => ()
        }
      @ir.HotOp::If => {
        match
          tuple_optimization_find_root_slot_in_region(
            func,
            @ir.hot_region_then_ref(func, root_id),
            target_id,
          ) {
          Some(found) => return Some(found)
          None => ()
        }
        match @ir.hot_region_else_ref(func, root_id) {
          Some(else_ref) =>
            match
              tuple_optimization_find_root_slot_in_region(
                func, else_ref, target_id,
              ) {
              Some(found) => return Some(found)
              None => ()
            }
          None => ()
        }
      }
      @ir.HotOp::Try =>
        match
          tuple_optimization_find_root_slot_in_region(
            func,
            @ir.hot_region_body_ref(func, root_id),
            target_id,
          ) {
          Some(found) => return Some(found)
          None =>
            match @ir.hot_region_catch_ref(func, root_id) {
              Some(catch_ref) =>
                match
                  tuple_optimization_find_root_slot_in_region(
                    func, catch_ref, target_id,
                  ) {
                  Some(found) => return Some(found)
                  None => ()
                }
              None => ()
            }
        }
      @ir.HotOp::TryTable =>
        match
          tuple_optimization_find_root_slot_in_region(
            func,
            @ir.hot_region_body_ref(func, root_id),
            target_id,
          ) {
          Some(found) => return Some(found)
          None =>
            match
              tuple_optimization_find_root_slot_in_region(
                func,
                @ir.hot_region_catch_list_ref(func, root_id),
                target_id,
              ) {
              Some(found) => return Some(found)
              None => ()
            }
        }
      _ => ()
    }
  }
  None
}

///|
fn tuple_optimization_find_root_slot(
  func : @ir.HotFunc,
  target_id : Int,
  lane_idx : Int,
) -> HotTupleOptimizationRootSlot? {
  match
    tuple_optimization_find_root_slot_in_region(
      func,
      @ir.HotRegionRef::root(),
      target_id,
    ) {
    Some((region_ref, slot)) => Some({ region_ref, lane_idx, slot })
    None => None
  }
}

///|
fn tuple_optimization_pick_root_anchor_slot(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  host_lane : Int,
) -> HotTupleOptimizationRootSlot? {
  let mut anchor : HotTupleOptimizationRootSlot? = None
  for lane_idx = 0
      lane_idx < group.defining_nodes.length()
      lane_idx = lane_idx + 1 {
    if lane_idx == host_lane {
      continue
    }
    let slot = match
      tuple_optimization_find_root_slot(
        func,
        group.defining_nodes[lane_idx],
        lane_idx,
      ) {
      Some(slot) => slot
      None => return None
    }
    match anchor {
      Some(current) => {
        if current.region_ref != slot.region_ref {
          return None
        }
        if slot.slot < current.slot {
          anchor = Some(slot)
        }
      }
      None => anchor = Some(slot)
    }
  }
  anchor
}

///|
fn tuple_optimization_find_passthrough_root_chain_step(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  current : Int,
  chain : Array[Int],
) -> Array[Int]? {
  let sites = @ir.node_use_sites_borrowed(use_def, current)
  if sites.length() != 1 {
    return None
  }
  let site = sites[0]
  match site.kind {
    @ir.HotUseSlotKind::RootUseSlot => Some(chain)
    @ir.HotUseSlotKind::ChildUseSlot => {
      if site.slot != 0 {
        return None
      }
      let user = @ir.hot_node_get(func, site.user)
      match user.op {
        @ir.HotOp::LocalSet | @ir.HotOp::LocalTee => {
          if @ir.hot_child_count(func, site.user) != 1 {
            return None
          }
          tuple_optimization_find_passthrough_root_chain_step(
            func,
            use_def,
            site.user,
            chain + [site.user],
          )
        }
        _ => None
      }
    }
  }
}

///|
fn tuple_optimization_find_passthrough_root_chain(
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  target_id : Int,
) -> Array[Int]? {
  tuple_optimization_find_passthrough_root_chain_step(
    func,
    use_def,
    target_id,
    [],
  )
}

///|
fn tuple_optimization_wrap_passthrough_root_chain(
  func : @ir.HotFunc,
  chain : Array[Int],
  inner : Int,
) -> Int {
  let mut wrapped = inner
  for node_id in chain {
    let node = @ir.hot_node_get(func, node_id)
    wrapped = match node.op {
      @ir.HotOp::LocalSet => @ir.hot_build_local_set(func, node.imm0, wrapped)
      @ir.HotOp::LocalTee => @ir.hot_build_local_tee(func, node.imm0, wrapped)
      _ =>
        abort(
          "tuple-optimization passthrough root chains must stay within local.set/local.tee",
        )
    }
  }
  wrapped
}

///|
fn tuple_optimization_build_source_host_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
) -> Int {
  let host_lane = tuple_optimization_group_host_lane(group)
  if tuple_optimization_split_reuses_group_lanes(group, split_locals) {
    let body : Array[Int] = []
    match host_lane {
      Some(host_lane) => {
        for lane_idx = group.lane_locals.length() - 1
            lane_idx >= 0
            lane_idx = lane_idx - 1 {
          if lane_idx == host_lane {
            continue
          }
          body.push(
            @ir.hot_build_local_set(
              func,
              group.lane_locals[lane_idx],
              group.producer,
            ),
          )
        }
        return @ir.hot_build_local_tee(
          func,
          group.lane_locals[host_lane],
          @ir.hot_build_block(
            func,
            @lib.BlockType::val_type(
              tuple_optimization_require_local_type(
                func,
                group.lane_locals[host_lane],
              ),
            ),
            body + [group.producer],
          ),
        )
      }
      None => {
        for lane_idx = group.lane_locals.length() - 1
            lane_idx >= 0
            lane_idx = lane_idx - 1 {
          body.push(
            @ir.hot_build_local_set(
              func,
              group.lane_locals[lane_idx],
              group.producer,
            ),
          )
        }
        return @ir.hot_build_block(func, @lib.BlockType::void_(), body)
      }
    }
  }
  let body : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    body.push(
      @ir.hot_build_local_set(func, split_locals[lane_idx], group.producer),
    )
  }
  match host_lane {
    Some(host_lane) => {
      for lane_idx = split_locals.length() - 1
          lane_idx >= 0
          lane_idx = lane_idx - 1 {
        if lane_idx == host_lane {
          continue
        }
        body.push(
          @ir.hot_build_local_set(
            func,
            group.lane_locals[lane_idx],
            @ir.hot_build_local_get(func, split_locals[lane_idx]),
          ),
        )
      }
      @ir.hot_build_local_tee(
        func,
        group.lane_locals[host_lane],
        @ir.hot_build_block(
          func,
          @lib.BlockType::val_type(
            tuple_optimization_require_local_type(
              func,
              group.lane_locals[host_lane],
            ),
          ),
          body + [@ir.hot_build_local_get(func, split_locals[host_lane])],
        ),
      )
    }
    None => {
      for lane_idx = split_locals.length() - 1
          lane_idx >= 0
          lane_idx = lane_idx - 1 {
        body.push(
          @ir.hot_build_local_set(
            func,
            group.lane_locals[lane_idx],
            @ir.hot_build_local_get(func, split_locals[lane_idx]),
          ),
        )
      }
      @ir.hot_build_block(func, @lib.BlockType::void_(), body)
    }
  }
}

///|
fn tuple_optimization_build_source_passthrough_init_root(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  host_lane : Int,
  carrier_local : Int,
) -> Int {
  if host_lane < 0 || host_lane >= split_locals.length() {
    abort("tuple-optimization passthrough init host lane must stay in range")
  }
  let init_body : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    init_body.push(
      @ir.hot_build_local_set(func, split_locals[lane_idx], group.producer),
    )
  }
  let body = [
    @ir.hot_build_local_set(
      func,
      carrier_local,
      @ir.hot_build_local_tee(
        func,
        split_locals[host_lane],
        @ir.hot_build_block(
          func,
          @lib.BlockType::val_type(
            tuple_optimization_require_local_type(func, split_locals[host_lane]),
          ),
          init_body + [group.producer],
        ),
      ),
    ),
  ]
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    body.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, split_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_block(func, @lib.BlockType::void_(), body)
}

///|
fn tuple_optimization_build_source_root_anchor_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  host_lane : Int,
) -> Int {
  let body : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    body.push(
      @ir.hot_build_local_set(func, split_locals[lane_idx], group.producer),
    )
  }
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    body.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, split_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_block(func, @lib.BlockType::void_(), body)
}

///|
fn tuple_optimization_build_tuple_make_from_locals(
  func : @ir.HotFunc,
  lane_locals : Array[Int],
) -> Int {
  let values : Array[Int] = []
  let result_types : Array[@lib.ValType] = []
  for local_id in lane_locals {
    values.push(@ir.hot_build_local_get(func, local_id))
    result_types.push(tuple_optimization_require_local_type(func, local_id))
  }
  @ir.hot_build_tuple_make(func, result_types, values)
}

///|
fn tuple_optimization_build_host_carrier_replacement_from_producer(
  func : @ir.HotFunc,
  lane_locals : Array[Int],
  host_lane : Int,
  producer : Int,
) -> Int {
  if host_lane < 0 || host_lane >= lane_locals.length() {
    abort("tuple-optimization synthetic host carrier lane must stay in range")
  }
  let body : Array[Int] = []
  for lane_idx = lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    body.push(@ir.hot_build_local_set(func, lane_locals[lane_idx], producer))
  }
  @ir.hot_build_local_tee(
    func,
    lane_locals[host_lane],
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(
        tuple_optimization_require_local_type(func, lane_locals[host_lane]),
      ),
      body + [producer],
    ),
  )
}

///|
fn tuple_optimization_lane_copy_needs_tuple_carrier(
  lane_locals : Array[Int],
  source_lane_locals : Array[Int],
) -> Bool {
  if lane_locals.length() != source_lane_locals.length() {
    return true
  }
  for source_lane = 0
      source_lane < source_lane_locals.length()
      source_lane = source_lane + 1 {
    let source_local = source_lane_locals[source_lane]
    for dest_lane = 0
        dest_lane < lane_locals.length()
        dest_lane = dest_lane + 1 {
      if source_local == lane_locals[dest_lane] && source_lane != dest_lane {
        return true
      }
    }
  }
  false
}

///|
fn tuple_optimization_build_host_carrier_replacement_from_locals(
  func : @ir.HotFunc,
  lane_locals : Array[Int],
  host_lane : Int,
  source_lane_locals : Array[Int],
) -> Int {
  if lane_locals.length() != source_lane_locals.length() {
    abort("tuple-optimization host copy carriers must preserve arity")
  }
  if tuple_optimization_lane_copy_needs_tuple_carrier(
      lane_locals, source_lane_locals,
    ) {
    return tuple_optimization_build_host_carrier_replacement_from_producer(
      func,
      lane_locals,
      host_lane,
      tuple_optimization_build_tuple_make_from_locals(func, source_lane_locals),
    )
  }
  let body : Array[Int] = []
  for lane_idx = lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    body.push(
      @ir.hot_build_local_set(
        func,
        lane_locals[lane_idx],
        @ir.hot_build_local_get(func, source_lane_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_local_tee(
    func,
    lane_locals[host_lane],
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(
        tuple_optimization_require_local_type(func, lane_locals[host_lane]),
      ),
      body + [@ir.hot_build_local_get(func, source_lane_locals[host_lane])],
    ),
  )
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
  let host_lane = tuple_optimization_group_host_lane(group)
  match host_lane {
    Some(host_lane) => {
      let producer_lane_locals = if tuple_optimization_split_reuses_group_lanes(
          group, split_locals,
        ) {
        source_split_locals
      } else {
        split_locals
      }
      let host_carrier = tuple_optimization_build_host_carrier_replacement_from_locals(
        func,
        group.lane_locals,
        host_lane,
        producer_lane_locals,
      )
      if tuple_optimization_split_reuses_group_lanes(group, split_locals) {
        return host_carrier
      }
      let prefix : Array[Int] = []
      for lane_idx = split_locals.length() - 1
          lane_idx >= 0
          lane_idx = lane_idx - 1 {
        prefix.push(
          @ir.hot_build_local_set(
            func,
            split_locals[lane_idx],
            @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
          ),
        )
      }
      return @ir.hot_build_block(
        func,
        @lib.BlockType::val_type(
          tuple_optimization_require_local_type(
            func,
            group.lane_locals[host_lane],
          ),
        ),
        prefix + [host_carrier],
      )
    }
    None => ()
  }
  if tuple_optimization_split_reuses_group_lanes(group, split_locals) {
    let body : Array[Int] = []
    for lane_idx = split_locals.length() - 1
        lane_idx >= 0
        lane_idx = lane_idx - 1 {
      body.push(
        @ir.hot_build_local_set(
          func,
          group.lane_locals[lane_idx],
          @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
        ),
      )
    }
    return @ir.hot_build_block(func, @lib.BlockType::void_(), body)
  }
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
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    body.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, split_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_block(func, @lib.BlockType::void_(), body)
}

///|
fn tuple_optimization_build_copy_root_anchor_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals : Array[Int],
  host_lane : Int,
) -> Int {
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
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    body.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, split_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_block(func, @lib.BlockType::void_(), body)
}

///|
fn tuple_optimization_build_copy_root_anchor_tuple_carrier_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals : Array[Int],
  host_lane : Int,
) -> Int {
  ignore(split_locals)
  @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_drop(
      func,
      tuple_optimization_build_host_carrier_replacement_from_producer(
        func,
        group.lane_locals,
        host_lane,
        tuple_optimization_build_tuple_make_from_locals(
          func, source_split_locals,
        ),
      ),
    ),
  ])
}

///|
fn tuple_optimization_pick_no_host_root_carrier_slot(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
) -> HotTupleOptimizationRootSlot? {
  if group.producer < 0 || group.lane_locals.is_empty() {
    return None
  }
  match tuple_optimization_find_root_slot(func, group.defining_nodes[0], 0) {
    Some(slot) => Some(slot)
    None => None
  }
}

///|
fn tuple_optimization_build_source_root_carrier_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  carrier_lane : Int,
) -> Int {
  if carrier_lane < 0 || carrier_lane >= group.lane_locals.length() {
    abort("tuple-optimization synthetic source carrier lane must stay in range")
  }
  tuple_optimization_build_root_carrier_replacement_from_producer(
    func,
    group.producer,
    group.lane_locals,
    carrier_lane,
  )
}

///|
fn tuple_optimization_build_source_nested_root_tuple_carrier_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  carrier_lane : Int,
) -> Int {
  if carrier_lane < 0 || carrier_lane >= group.lane_locals.length() {
    abort(
      "tuple-optimization synthetic nested source carrier lane must stay in range",
    )
  }
  if split_locals.length() != group.lane_locals.length() {
    abort(
      "tuple-optimization nested source root tuple carriers must preserve arity",
    )
  }
  let prefix : Array[Int] = []
  for lane_idx = split_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    prefix.push(
      @ir.hot_build_local_set(func, split_locals[lane_idx], group.producer),
    )
  }
  let values : Array[Int] = []
  let result_types : Array[@lib.ValType] = []
  for local_id in split_locals {
    values.push(@ir.hot_build_local_get(func, local_id))
    result_types.push(tuple_optimization_require_local_type(func, local_id))
  }
  @ir.hot_build_block(
    func,
    @lib.BlockType::void_(),
    prefix +
    [
      tuple_optimization_build_root_carrier_replacement_from_producer(
        func,
        @ir.hot_build_tuple_make(func, result_types, values),
        group.lane_locals,
        carrier_lane,
      ),
    ],
  )
}

///|
fn tuple_optimization_build_root_carrier_replacement_from_producer(
  func : @ir.HotFunc,
  producer : Int,
  lane_locals : Array[Int],
  carrier_lane : Int,
) -> Int {
  if carrier_lane < 0 || carrier_lane >= lane_locals.length() {
    abort("tuple-optimization synthetic root carrier lane must stay in range")
  }
  let body : Array[Int] = []
  for lane_idx = lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == carrier_lane {
      continue
    }
    body.push(@ir.hot_build_local_set(func, lane_locals[lane_idx], producer))
  }
  @ir.hot_build_local_set(
    func,
    lane_locals[carrier_lane],
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(
        tuple_optimization_require_local_type(func, lane_locals[carrier_lane]),
      ),
      body + [producer],
    ),
  )
}

///|
fn tuple_optimization_build_copy_root_carrier_replacement(
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  source_split_locals : Array[Int],
  carrier_lane : Int,
) -> Int {
  if carrier_lane < 0 || carrier_lane >= group.lane_locals.length() {
    abort("tuple-optimization synthetic copy carrier lane must stay in range")
  }
  if group.lane_locals.length() != source_split_locals.length() {
    abort("tuple-optimization synthetic copy carriers must preserve arity")
  }
  if !tuple_optimization_lane_locals_are_strictly_increasing(group.lane_locals) ||
    !tuple_optimization_lane_locals_are_strictly_increasing(source_split_locals) {
    let values : Array[Int] = []
    let result_types : Array[@lib.ValType] = []
    for lane_idx = 0
        lane_idx < source_split_locals.length()
        lane_idx = lane_idx + 1 {
      let local_id = source_split_locals[lane_idx]
      values.push(@ir.hot_build_local_get(func, local_id))
      result_types.push(tuple_optimization_require_local_type(func, local_id))
    }
    return tuple_optimization_build_root_carrier_replacement_from_producer(
      func,
      @ir.hot_build_tuple_make(func, result_types, values),
      group.lane_locals,
      carrier_lane,
    )
  }
  let body : Array[Int] = []
  for lane_idx = group.lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == carrier_lane {
      continue
    }
    body.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
      ),
    )
  }
  @ir.hot_build_local_set(
    func,
    group.lane_locals[carrier_lane],
    @ir.hot_build_block(
      func,
      @lib.BlockType::val_type(
        tuple_optimization_require_local_type(
          func,
          group.lane_locals[carrier_lane],
        ),
      ),
      body + [@ir.hot_build_local_get(func, source_split_locals[carrier_lane])],
    ),
  )
}

///|
fn tuple_optimization_try_rewrite_root_host_copy_group_defs(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals : Array[Int],
  host_lane : Int,
) -> Bool {
  if host_lane < 0 || host_lane >= group.lane_locals.length() {
    return false
  }
  if tuple_optimization_lane_copy_needs_tuple_carrier(
      group.lane_locals,
      source_split_locals,
    ) {
    return false
  }
  let root_slot = match
    tuple_optimization_find_root_slot(
      func,
      group.defining_nodes[host_lane],
      host_lane,
    ) {
    Some(root_slot) => root_slot
    None => return false
  }
  let source_lane_locals = if tuple_optimization_split_reuses_group_lanes(
      group, split_locals,
    ) {
    source_split_locals
  } else {
    split_locals
  }
  let prefix : Array[Int] = []
  if !tuple_optimization_split_reuses_group_lanes(group, split_locals) {
    for lane_idx = split_locals.length() - 1
        lane_idx >= 0
        lane_idx = lane_idx - 1 {
      prefix.push(
        @ir.hot_build_local_set(
          func,
          split_locals[lane_idx],
          @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
        ),
      )
    }
  }
  for lane_idx = group.lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    prefix.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, source_lane_locals[lane_idx]),
      ),
    )
  }
  if !prefix.is_empty() {
    @ir.hot_region_insert(func, root_slot.region_ref, root_slot.slot, prefix)
    pass_mark_mutated(ctx, func)
  }
  tuple_optimization_replace_with_built(
    ctx,
    func,
    group.defining_nodes[host_lane],
    @ir.hot_build_local_tee(
      func,
      group.lane_locals[host_lane],
      @ir.hot_build_local_get(func, source_lane_locals[host_lane]),
    ),
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
        @ir.hot_build_local_get(func, source_lane_locals[lane_idx])
      _ => @ir.hot_build_nop(func)
    }
    tuple_optimization_replace_with_built(
      ctx,
      func,
      group.defining_nodes[lane_idx],
      replacement,
    )
  }
  true
}

///|
fn tuple_optimization_try_rewrite_anchor_host_copy_group_defs(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_split_locals : Array[Int],
  host_lane : Int,
  anchor_slot : HotTupleOptimizationRootSlot,
) -> Bool {
  if host_lane < 0 || host_lane >= group.lane_locals.length() {
    return false
  }
  if tuple_optimization_lane_copy_needs_tuple_carrier(
      group.lane_locals,
      source_split_locals,
    ) {
    return false
  }
  let source_lane_locals = if tuple_optimization_split_reuses_group_lanes(
      group, split_locals,
    ) {
    source_split_locals
  } else {
    split_locals
  }
  let carrier_local = @ir.hot_append_body_local(
    func,
    tuple_optimization_require_local_type(func, group.lane_locals[host_lane]),
  )
  let split_host_carrier_local : Int? = if tuple_optimization_split_reuses_group_lanes(
      group, split_locals,
    ) {
    None
  } else {
    Some(
      @ir.hot_append_body_local(
        func,
        tuple_optimization_require_local_type(
          func,
          group.lane_locals[host_lane],
        ),
      ),
    )
  }
  let prefix : Array[Int] = []
  if !tuple_optimization_split_reuses_group_lanes(group, split_locals) {
    for lane_idx = split_locals.length() - 1
        lane_idx >= 0
        lane_idx = lane_idx - 1 {
      if lane_idx == host_lane {
        match split_host_carrier_local {
          Some(split_host_carrier_local) =>
            prefix.push(
              @ir.hot_build_local_set(
                func,
                split_host_carrier_local,
                @ir.hot_build_local_tee(
                  func,
                  split_locals[lane_idx],
                  @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
                ),
              ),
            )
          None =>
            prefix.push(
              @ir.hot_build_local_set(
                func,
                split_locals[lane_idx],
                @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
              ),
            )
        }
      } else {
        prefix.push(
          @ir.hot_build_local_set(
            func,
            split_locals[lane_idx],
            @ir.hot_build_local_get(func, source_split_locals[lane_idx]),
          ),
        )
      }
    }
  }
  for lane_idx = group.lane_locals.length() - 1
      lane_idx >= 0
      lane_idx = lane_idx - 1 {
    if lane_idx == host_lane {
      continue
    }
    prefix.push(
      @ir.hot_build_local_set(
        func,
        group.lane_locals[lane_idx],
        @ir.hot_build_local_get(func, source_lane_locals[lane_idx]),
      ),
    )
  }
  prefix.push(
    @ir.hot_build_local_set(
      func,
      carrier_local,
      @ir.hot_build_local_tee(
        func,
        group.lane_locals[host_lane],
        @ir.hot_build_local_get(
          func,
          match split_host_carrier_local {
            Some(split_host_carrier_local) => split_host_carrier_local
            None => source_lane_locals[host_lane]
          },
        ),
      ),
    ),
  )
  @ir.hot_region_insert(func, anchor_slot.region_ref, anchor_slot.slot, prefix)
  pass_mark_mutated(ctx, func)
  for lane_idx = 0
      lane_idx < group.defining_nodes.length()
      lane_idx = lane_idx + 1 {
    if !@ir.hot_node_is_live(func, group.defining_nodes[lane_idx]) {
      continue
    }
    let replacement = match
      @ir.hot_node_get(func, group.defining_nodes[lane_idx]).op {
      @ir.HotOp::LocalTee =>
        if lane_idx == host_lane {
          @ir.hot_build_local_get(func, carrier_local)
        } else {
          @ir.hot_build_local_get(func, group.lane_locals[lane_idx])
        }
      _ => @ir.hot_build_nop(func)
    }
    tuple_optimization_replace_with_built(
      ctx,
      func,
      group.defining_nodes[lane_idx],
      replacement,
    )
  }
  true
}

///|
fn tuple_optimization_rewrite_group_defs(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  use_def : @ir.HotUseDef,
  group : HotTupleOptimizationGroup,
  split_locals : Array[Int],
  source_host_copy_consumer? : Bool = false,
  source_split_locals? : Array[Int]? = None,
) -> Unit {
  let actual_host_lane = tuple_optimization_group_host_lane(group)
  let no_host_root_carrier_slot = match actual_host_lane {
    None => tuple_optimization_pick_no_host_root_carrier_slot(func, group)
    Some(_) => None
  }
  let synthetic_carrier_lane = match actual_host_lane {
    None =>
      match no_host_root_carrier_slot {
        Some(slot) => Some(slot.lane_idx)
        None => None
      }
    Some(_) => None
  }
  let synthetic_carrier_needs_tuple = match no_host_root_carrier_slot {
    Some(slot) => slot.region_ref != @ir.HotRegionRef::root()
    None => false
  }
  let primary_lane = match actual_host_lane {
    Some(host_lane) => host_lane
    None =>
      match synthetic_carrier_lane {
        Some(carrier_lane) => carrier_lane
        None => group.defining_nodes.length() - 1
      }
  }
  let host_is_root = match actual_host_lane {
    Some(host_lane) =>
      match
        tuple_optimization_find_root_slot(
          func,
          group.defining_nodes[host_lane],
          host_lane,
        ) {
        Some(_) => true
        None => false
      }
    None => false
  }
  let host_passthrough_chain = match actual_host_lane {
    Some(host_lane) if !host_is_root =>
      match
        tuple_optimization_find_passthrough_root_chain(
          func,
          use_def,
          group.defining_nodes[host_lane],
        ) {
        Some(chain) if !chain.is_empty() => Some(chain)
        _ => None
      }
    _ => None
  }
  if source_split_locals is None &&
    source_host_copy_consumer &&
    !tuple_optimization_split_reuses_group_lanes(group, split_locals) {
    match (actual_host_lane, host_passthrough_chain) {
      (Some(host_lane), Some(chain)) => {
        let root_id = chain[chain.length() - 1]
        let root_slot = match
          tuple_optimization_find_root_slot(func, root_id, host_lane) {
          Some(slot) => slot
          None =>
            abort(
              "tuple-optimization source passthrough staging requires a root slot",
            )
        }
        let carrier_local = @ir.hot_append_body_local(
          func,
          tuple_optimization_require_local_type(
            func,
            group.lane_locals[host_lane],
          ),
        )
        @ir.hot_region_insert(func, root_slot.region_ref, root_slot.slot, [
          tuple_optimization_build_source_passthrough_init_root(
            func, group, split_locals, host_lane, carrier_local,
          ),
        ])
        pass_mark_mutated(ctx, func)
        tuple_optimization_replace_with_built(
          ctx,
          func,
          group.defining_nodes[host_lane],
          @ir.hot_build_local_tee(
            func,
            group.lane_locals[host_lane],
            @ir.hot_build_local_get(func, carrier_local),
          ),
        )
        for lane_idx = 0
            lane_idx < group.defining_nodes.length()
            lane_idx = lane_idx + 1 {
          if lane_idx == host_lane ||
            !@ir.hot_node_is_live(func, group.defining_nodes[lane_idx]) {
            continue
          }
          tuple_optimization_replace_with_built(
            ctx,
            func,
            group.defining_nodes[lane_idx],
            @ir.hot_build_nop(func),
          )
        }
        return
      }
      _ => ()
    }
  }
  let anchor_slot = match actual_host_lane {
    Some(host_lane) if !host_is_root && host_passthrough_chain is None =>
      tuple_optimization_pick_root_anchor_slot(func, group, host_lane)
    _ => None
  }
  match (actual_host_lane, source_split_locals, anchor_slot) {
    (Some(host_lane), Some(source_split_locals), Some(anchor_slot)) =>
      if tuple_optimization_try_rewrite_anchor_host_copy_group_defs(
          ctx, func, group, split_locals, source_split_locals, host_lane, anchor_slot,
        ) {
        return
      }
    _ => ()
  }
  match (actual_host_lane, source_split_locals) {
    (Some(host_lane), Some(source_split_locals)) if host_is_root =>
      if tuple_optimization_try_rewrite_root_host_copy_group_defs(
          ctx, func, group, split_locals, source_split_locals, host_lane,
        ) {
        return
      }
    _ => ()
  }
  let has_anchor_slot = match anchor_slot {
    Some(_) => true
    None => false
  }
  let copy_anchor_uses_tuple_carrier = match source_split_locals {
    Some(source_split_locals) =>
      has_anchor_slot &&
      tuple_optimization_lane_copy_needs_tuple_carrier(
        group.lane_locals,
        source_split_locals,
      )
    None => false
  }
  let host_read_replacement = match actual_host_lane {
    Some(host_lane) if has_anchor_slot =>
      if copy_anchor_uses_tuple_carrier {
        match @ir.hot_node_get(func, group.defining_nodes[host_lane]).op {
          @ir.HotOp::LocalTee =>
            Some(@ir.hot_build_local_get(func, group.lane_locals[host_lane]))
          _ => Some(@ir.hot_build_nop(func))
        }
      } else {
        Some(
          @ir.hot_build_local_tee(
            func,
            group.lane_locals[host_lane],
            @ir.hot_build_local_get(func, split_locals[host_lane]),
          ),
        )
      }
    _ => None
  }
  let raw_host_replacement = match source_split_locals {
    Some(source_split_locals) =>
      match actual_host_lane {
        Some(host_lane) if has_anchor_slot =>
          if copy_anchor_uses_tuple_carrier {
            tuple_optimization_build_copy_root_anchor_tuple_carrier_replacement(
              func, group, split_locals, source_split_locals, host_lane,
            )
          } else {
            tuple_optimization_build_copy_root_anchor_replacement(
              func, group, split_locals, source_split_locals, host_lane,
            )
          }
        None =>
          match synthetic_carrier_lane {
            Some(carrier_lane) =>
              tuple_optimization_build_copy_root_carrier_replacement(
                func, group, source_split_locals, carrier_lane,
              )
            None =>
              tuple_optimization_build_copy_host_replacement(
                func, group, split_locals, source_split_locals,
              )
          }
        _ =>
          tuple_optimization_build_copy_host_replacement(
            func, group, split_locals, source_split_locals,
          )
      }
    None =>
      match actual_host_lane {
        Some(host_lane) if has_anchor_slot =>
          tuple_optimization_build_source_root_anchor_replacement(
            func, group, split_locals, host_lane,
          )
        None =>
          match synthetic_carrier_lane {
            Some(carrier_lane) =>
              if synthetic_carrier_needs_tuple {
                tuple_optimization_build_source_nested_root_tuple_carrier_replacement(
                  func, group, split_locals, carrier_lane,
                )
              } else {
                tuple_optimization_build_source_root_carrier_replacement(
                  func, group, carrier_lane,
                )
              }
            None =>
              tuple_optimization_build_source_host_replacement(
                func, group, split_locals,
              )
          }
        _ =>
          tuple_optimization_build_source_host_replacement(
            func, group, split_locals,
          )
      }
  }
  let host_replacement = match host_passthrough_chain {
    Some(chain) =>
      tuple_optimization_wrap_passthrough_root_chain(
        func, chain, raw_host_replacement,
      )
    None => raw_host_replacement
  }
  let anchor_lane = match anchor_slot {
    Some(anchor_slot) => anchor_slot.lane_idx
    None => -1
  }
  tuple_optimization_replace_with_built(
    ctx,
    func,
    match host_passthrough_chain {
      Some(chain) => chain[chain.length() - 1]
      None =>
        match anchor_slot {
          Some(anchor_slot) => group.defining_nodes[anchor_slot.lane_idx]
          None => group.defining_nodes[primary_lane]
        }
    },
    host_replacement,
  )
  for lane_idx = 0
      lane_idx < group.defining_nodes.length()
      lane_idx = lane_idx + 1 {
    if lane_idx == primary_lane ||
      lane_idx == anchor_lane ||
      !@ir.hot_node_is_live(func, group.defining_nodes[lane_idx]) {
      continue
    }
    let replacement = match
      @ir.hot_node_get(func, group.defining_nodes[lane_idx]).op {
      @ir.HotOp::LocalTee =>
        if copy_anchor_uses_tuple_carrier {
          @ir.hot_build_local_get(func, group.lane_locals[lane_idx])
        } else {
          @ir.hot_build_local_get(func, split_locals[lane_idx])
        }
      _ => @ir.hot_build_nop(func)
    }
    tuple_optimization_replace_with_built(
      ctx,
      func,
      group.defining_nodes[lane_idx],
      replacement,
    )
  }
  match host_read_replacement {
    Some(host_read_replacement) =>
      tuple_optimization_replace_with_built(
        ctx,
        func,
        group.defining_nodes[primary_lane],
        host_read_replacement,
      )
    None => ()
  }
}

///|
fn tuple_optimization_rewrite_good_components(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  analysis : HotTupleOptimizationAnalysis,
) -> Bool {
  let use_def = @ir.use_def_build(func)
  let rewrite_mask = tuple_optimization_build_group_rewrite_mask(
    func,
    use_def,
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
          use_def,
          analysis.groups,
          analysis.copy_read_nodes,
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
    match group.copy_source {
      Some(source_group) =>
        tuple_optimization_rewrite_group_defs(
          ctx,
          func,
          use_def,
          group,
          split_locals,
          source_split_locals=Some(
            match group.copy_payload_locals {
              Some(copy_payload_locals) => copy_payload_locals
              None => split_locals_by_group[source_group]
            },
          ),
        )
      None =>
        tuple_optimization_rewrite_group_defs(
          ctx,
          func,
          use_def,
          group,
          split_locals,
          source_host_copy_consumer=tuple_optimization_source_group_has_rewritten_host_copy_consumer(
            analysis.groups,
            rewrite_mask,
            group_id,
          ),
        )
    }
    match group.copy_source {
      Some(_) =>
        if group.producer >= 0 {
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
  tuple_optimization_cleanup_post_rewrite(ctx, func)
  true
}

///|
fn tuple_optimization_cleanup_drop_local_tees(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  let node_count = @ir.hot_node_count(func)
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    if !@ir.hot_node_is_live(func, node_id) {
      continue
    }
    let node = @ir.hot_node_get(func, node_id)
    match node.op {
      @ir.HotOp::Drop => ()
      _ => continue
    }
    if @ir.hot_child_count(func, node_id) != 1 {
      continue
    }
    let child = @ir.hot_child_get(func, node_id, 0)
    if !@ir.hot_node_is_live(func, child) {
      continue
    }
    let child_node = @ir.hot_node_get(func, child)
    match child_node.op {
      @ir.HotOp::LocalTee => ()
      _ => continue
    }
    if @ir.hot_child_count(func, child) != 1 {
      continue
    }
    tuple_optimization_replace_with_built(
      ctx,
      func,
      node_id,
      @ir.hot_build_local_set(
        func,
        child_node.imm0,
        @ir.hot_child_get(func, child, 0),
      ),
    )
  }
}

///|
fn tuple_optimization_prune_nops_in_region(
  ctx : HotPassContext,
  func : @ir.HotFunc,
  region_ref : @ir.HotRegionRef,
) -> Unit {
  let next : Array[Int] = []
  let mut changed = false
  for slot = 0
      slot < @ir.hot_region_root_count(func, region_ref)
      slot = slot + 1 {
    let root_id = @ir.hot_region_get(func, region_ref, slot)
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Block | @ir.HotOp::Loop =>
        tuple_optimization_prune_nops_in_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, root_id),
        )
      @ir.HotOp::If => {
        tuple_optimization_prune_nops_in_region(
          ctx,
          func,
          @ir.hot_region_then_ref(func, root_id),
        )
        match @ir.hot_region_else_ref(func, root_id) {
          Some(else_ref) =>
            tuple_optimization_prune_nops_in_region(ctx, func, else_ref)
          None => ()
        }
      }
      @ir.HotOp::Try => {
        tuple_optimization_prune_nops_in_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, root_id),
        )
        match @ir.hot_region_catch_ref(func, root_id) {
          Some(catch_ref) =>
            tuple_optimization_prune_nops_in_region(ctx, func, catch_ref)
          None => ()
        }
      }
      @ir.HotOp::TryTable => {
        tuple_optimization_prune_nops_in_region(
          ctx,
          func,
          @ir.hot_region_body_ref(func, root_id),
        )
        tuple_optimization_prune_nops_in_region(
          ctx,
          func,
          @ir.hot_region_catch_list_ref(func, root_id),
        )
      }
      _ => ()
    }
    match @ir.hot_node_get(func, root_id).op {
      @ir.HotOp::Nop => {
        changed = true
        continue
      }
      _ => ()
    }
    next.push(root_id)
  }
  if changed {
    @ir.hot_region_replace_body(func, region_ref, next)
    pass_mark_mutated(ctx, func)
  }
}

///|
fn tuple_optimization_cleanup_post_rewrite(
  ctx : HotPassContext,
  func : @ir.HotFunc,
) -> Unit {
  tuple_optimization_cleanup_drop_local_tees(ctx, func)
  tuple_optimization_prune_nops_in_region(ctx, func, @ir.HotRegionRef::root())
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
