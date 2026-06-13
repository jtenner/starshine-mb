///|
pub enum HotLocalGraphSource {
  EntrySource(LocalId)
  SetSource(NodeId)
} derive(Eq, Debug)

///|
pub struct HotLocalGraph {
  local_count : Int
  get_source_ids : Array[Array[Int]]
  set_influence_gets : Array[Array[NodeId]]
} derive(Eq, Debug)

///|
fn local_graph_require_node_range(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Unit {
  if node_id < 0 || node_id >= graph.get_source_ids.length() {
    abort("local graph query requires a valid node id")
  }
}

///|
fn local_graph_entry_source_id(local_id : LocalId) -> Int {
  local_id
}

///|
fn local_graph_set_source_id(local_count : Int, node_id : NodeId) -> Int {
  local_count + node_id
}

///|
fn local_graph_source_from_id(
  local_count : Int,
  source_id : Int,
) -> HotLocalGraphSource {
  if source_id < local_count {
    HotLocalGraphSource::EntrySource(source_id)
  } else {
    HotLocalGraphSource::SetSource(source_id - local_count)
  }
}

///|
fn local_graph_array_contains(values : Array[Int], value : Int) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn local_graph_node_array_contains(
  values : Array[NodeId],
  value : NodeId,
) -> Bool {
  for existing in values {
    if existing == value {
      return true
    }
  }
  false
}

///|
fn local_graph_union_into(target : Array[Int], src : Array[Int]) -> Bool {
  let mut changed = false
  for value in src {
    if !local_graph_array_contains(target, value) {
      target.push(value)
      changed = true
    }
  }
  changed
}

///|
fn local_graph_state_clone(state : Array[Array[Int]]) -> Array[Array[Int]] {
  let out : Array[Array[Int]] = []
  for sources in state {
    out.push(sources.copy())
  }
  out
}

///|
fn local_graph_state_equal(
  lhs : Array[Array[Int]],
  rhs : Array[Array[Int]],
) -> Bool {
  if lhs.length() != rhs.length() {
    return false
  }
  for idx = 0; idx < lhs.length(); idx = idx + 1 {
    if lhs[idx].length() != rhs[idx].length() {
      return false
    }
    for value in lhs[idx] {
      if !local_graph_array_contains(rhs[idx], value) {
        return false
      }
    }
  }
  true
}

///|
fn local_graph_empty_state(local_count : Int) -> Array[Array[Int]] {
  let state : Array[Array[Int]] = []
  for _ in 0..<local_count {
    state.push([])
  }
  state
}

///|
fn local_graph_entry_state(local_count : Int) -> Array[Array[Int]] {
  let state : Array[Array[Int]] = []
  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    state.push([local_graph_entry_source_id(local_id)])
  }
  state
}

///|
fn local_graph_is_region_slot(op : HotOp, slot : Int) -> Bool {
  match op {
    HotOp::Block | HotOp::Loop => true
    HotOp::If => slot == 1 || slot == 2
    HotOp::Try | HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
fn local_graph_transfer_node(
  func : HotFunc,
  local_count : Int,
  node_id : NodeId,
  state : Array[Array[Int]],
  get_sources : Array[Array[Int]]?,
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if local_graph_is_region_slot(node.op, slot) {
      continue
    }
    local_graph_transfer_node(
      func,
      local_count,
      hot_child_get(func, node_id, slot),
      state,
      get_sources,
    )
  }
  match node.op {
    HotOp::LocalGet =>
      match get_sources {
        Some(sources_by_node) =>
          sources_by_node[node_id] = state[node.imm0].copy()
        None => ()
      }
    HotOp::LocalSet | HotOp::LocalTee =>
      state[node.imm0] = [local_graph_set_source_id(local_count, node_id)]
    _ => ()
  }
}

///|
fn local_graph_transfer_block(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
  in_state : Array[Array[Int]],
  get_sources : Array[Array[Int]]?,
) -> Array[Array[Int]] {
  let state = local_graph_state_clone(in_state)
  for node_id in cfg_block_get(cfg, block_id).nodes {
    local_graph_transfer_node(
      func,
      hot_local_count(func),
      node_id,
      state,
      get_sources,
    )
  }
  state
}

///|
fn local_graph_merge_predecessors(
  cfg : HotCfg,
  block_id : BlockId,
  local_count : Int,
  out_states : Array[Array[Array[Int]]],
) -> Array[Array[Int]] {
  let merged = local_graph_empty_state(local_count)
  for pred in cfg_predecessor_edges(cfg, block_id) {
    if pred.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    let pred_state = out_states[pred.block]
    for local_id = 0; local_id < local_count; local_id = local_id + 1 {
      ignore(local_graph_union_into(merged[local_id], pred_state[local_id]))
    }
  }
  merged
}

///|
fn local_graph_build_in_states(
  func : HotFunc,
  cfg : HotCfg,
) -> Array[Array[Array[Int]]] {
  let local_count = hot_local_count(func)
  let in_states : Array[Array[Array[Int]]] = []
  let out_states : Array[Array[Array[Int]]] = []
  for _ in 0..<cfg_block_count(cfg) {
    in_states.push(local_graph_empty_state(local_count))
    out_states.push(local_graph_empty_state(local_count))
  }
  in_states[cfg_entry_block(cfg)] = local_graph_entry_state(local_count)
  let mut changed = true
  while changed {
    changed = false
    for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
      let next_in = if block_id == cfg_entry_block(cfg) {
        local_graph_entry_state(local_count)
      } else {
        local_graph_merge_predecessors(cfg, block_id, local_count, out_states)
      }
      if !local_graph_state_equal(in_states[block_id], next_in) {
        in_states[block_id] = next_in
        changed = true
      }
      let next_out = local_graph_transfer_block(
        func,
        cfg,
        block_id,
        in_states[block_id],
        None,
      )
      if !local_graph_state_equal(out_states[block_id], next_out) {
        out_states[block_id] = next_out
        changed = true
      }
    }
  }
  in_states
}

///|
fn local_graph_build_influences(
  local_count : Int,
  get_sources : Array[Array[Int]],
) -> Array[Array[NodeId]] {
  let influences : Array[Array[NodeId]] = []
  for _ in 0..<get_sources.length() {
    influences.push([])
  }
  for get_id = 0; get_id < get_sources.length(); get_id = get_id + 1 {
    for source_id in get_sources[get_id] {
      if source_id >= local_count {
        let set_id = source_id - local_count
        if set_id >= 0 && set_id < influences.length() {
          if !local_graph_node_array_contains(influences[set_id], get_id) {
            influences[set_id].push(get_id)
          }
        }
      }
    }
  }
  influences
}

///|
pub fn local_graph_build(func : HotFunc, cfg : HotCfg) -> HotLocalGraph {
  let local_count = hot_local_count(func)
  let get_sources : Array[Array[Int]] = []
  for _ in 0..<hot_node_count(func) {
    get_sources.push([])
  }
  let in_states = local_graph_build_in_states(func, cfg)
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    ignore(
      local_graph_transfer_block(
        func,
        cfg,
        block_id,
        in_states[block_id],
        Some(get_sources),
      ),
    )
  }
  {
    local_count,
    get_source_ids: get_sources,
    set_influence_gets: local_graph_build_influences(local_count, get_sources),
  }
}

///|
pub fn local_graph_reaching_sources_for_get(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Array[HotLocalGraphSource] {
  local_graph_require_node_range(graph, node_id)
  let out : Array[HotLocalGraphSource] = []
  for source_id in graph.get_source_ids[node_id] {
    out.push(local_graph_source_from_id(graph.local_count, source_id))
  }
  out
}

///|
pub fn local_graph_influenced_gets_for_set(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Array[NodeId] {
  local_graph_require_node_range(graph, node_id)
  graph.set_influence_gets[node_id].copy()
}

///|
fn local_graph_flatten_node(
  func : HotFunc,
  node_id : NodeId,
  out : Array[NodeId],
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  let node = hot_node_get(func, node_id)
  for slot = 0; slot < node.child_count; slot = slot + 1 {
    if local_graph_is_region_slot(node.op, slot) {
      continue
    }
    local_graph_flatten_node(func, hot_child_get(func, node_id, slot), out)
  }
  out.push(node_id)
}

///|
fn local_graph_block_sequence(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
) -> Array[NodeId] {
  let out : Array[NodeId] = []
  for node_id in cfg_block_get(cfg, block_id).nodes {
    local_graph_flatten_node(func, node_id, out)
  }
  out
}

///|
fn local_graph_sequences(func : HotFunc, cfg : HotCfg) -> Array[Array[NodeId]] {
  let out : Array[Array[NodeId]] = []
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    out.push(local_graph_block_sequence(func, cfg, block_id))
  }
  out
}

///|
fn local_graph_sequence_find(seq : Array[NodeId], node_id : NodeId) -> Int {
  for idx = 0; idx < seq.length(); idx = idx + 1 {
    if seq[idx] == node_id {
      return idx
    }
  }
  -1
}

///|
fn local_graph_path_reaches_get_avoiding_obstacle(
  cfg : HotCfg,
  sequences : Array[Array[NodeId]],
  block_id : BlockId,
  start_idx : Int,
  get_id : NodeId,
  obstacle_id : NodeId,
  seen : Array[Bool],
  key_stride : Int,
) -> Bool {
  let key = block_id * key_stride + start_idx
  if key >= 0 && key < seen.length() {
    if seen[key] {
      return false
    }
    seen[key] = true
  }
  let seq = sequences[block_id]
  for idx = start_idx; idx < seq.length(); idx = idx + 1 {
    let node_id = seq[idx]
    if node_id == get_id {
      return true
    }
    if node_id == obstacle_id {
      return false
    }
  }
  for succ in cfg_successor_edges(cfg, block_id) {
    if succ.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    if local_graph_path_reaches_get_avoiding_obstacle(
        cfg,
        sequences,
        succ.block,
        0,
        get_id,
        obstacle_id,
        seen,
        key_stride,
      ) {
      return true
    }
  }
  false
}

///|
fn local_graph_can_reach_get_after_set_avoiding_obstacle(
  cfg : HotCfg,
  sequences : Array[Array[NodeId]],
  set_id : NodeId,
  get_id : NodeId,
  obstacle_id : NodeId,
) -> Bool {
  let stride = hot_node_count_from_cfg_sequences(sequences) + 1
  for block_id = 0; block_id < sequences.length(); block_id = block_id + 1 {
    let seq = sequences[block_id]
    let set_idx = local_graph_sequence_find(seq, set_id)
    if set_idx < 0 {
      continue
    }
    let seen = Array::make(sequences.length() * stride, false)
    if local_graph_path_reaches_get_avoiding_obstacle(
        cfg,
        sequences,
        block_id,
        set_idx + 1,
        get_id,
        obstacle_id,
        seen,
        stride,
      ) {
      return true
    }
  }
  false
}

///|
fn hot_node_count_from_cfg_sequences(sequences : Array[Array[NodeId]]) -> Int {
  let mut max_node = 0
  for seq in sequences {
    for node_id in seq {
      if node_id > max_node {
        max_node = node_id
      }
    }
  }
  max_node + 1
}

///|
pub fn local_graph_can_move_set_past_node(
  func : HotFunc,
  cfg : HotCfg,
  graph : HotLocalGraph,
  set_id : NodeId,
  obstacle_id : NodeId,
) -> Array[NodeId] {
  let sequences = local_graph_sequences(func, cfg)
  let out : Array[NodeId] = []
  for get_id in local_graph_influenced_gets_for_set(graph, set_id) {
    if local_graph_can_reach_get_after_set_avoiding_obstacle(
        cfg, sequences, set_id, get_id, obstacle_id,
      ) {
      out.push(get_id)
    }
  }
  out
}
