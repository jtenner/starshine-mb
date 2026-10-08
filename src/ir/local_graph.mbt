///|
pub enum HotLocalGraphSource {
  EntrySource(LocalId)
  SetSource(NodeId)
} derive(Eq, Debug)

///|
/// Scalar source description for allocation-free indexed queries. Entry
/// indices identify locals; other indices identify write nodes. No graph
/// storage or encoded source identity escapes through this value.
#valtype
pub struct HotLocalGraphSourceValue {
  is_entry : Bool
  index : Int
} derive(Eq, Debug)

///|
fn HotLocalGraphSourceValue::new(
  is_entry : Bool,
  index : Int,
) -> HotLocalGraphSourceValue {
  { is_entry, index, }
}

///|
pub struct HotLocalGraph {
  local_count : Int
  param_count : Int
  get_source_ids : Array[Array[Int]]
  set_influence_gets : Array[Array[NodeId]]
  write_local_ids : Array[LocalId]
  write_is_tees : Array[Bool]
  local_is_already_ssa : Array[Bool]
  local_has_legal_default : Array[Bool]
} derive(Eq, Debug)

///|
/// Immutable reaching-read sources, without writer influences or SSA facts.
/// A zero source count remains unknown; consumers must keep their fallback.
pub struct HotLocalReadSources {
  priv local_count : Int
  priv get_source_ids : Array[Array[Int]]
} derive(Debug)

///|
fn HotLocalReadSources::new(
  local_count : Int,
  get_source_ids : Array[Array[Int]],
) -> HotLocalReadSources {
  { local_count, get_source_ids, }
}

///|
// Shared solver result. Optional metadata is requested only by full graphs;
// this internal type never masquerades as a complete HotLocalGraph.
priv struct LocalGraphFlowRows {
  get_source_ids : Array[Array[Int]]
  write_influences : Array[Array[NodeId]]
  write_facts : LocalGraphWriteFacts
}

///|
fn LocalGraphFlowRows::new(
  get_source_ids : Array[Array[Int]],
  write_influences : Array[Array[NodeId]],
  write_facts : LocalGraphWriteFacts,
) -> LocalGraphFlowRows {
  { get_source_ids, write_influences, write_facts, }
}

///|
fn LocalGraphFlowRows::select_gets(
  self : LocalGraphFlowRows,
  selected_gets : Array[Bool]?,
) -> LocalGraphFlowRows {
  match selected_gets {
    Some(mask) =>
      for node in 0..<self.get_source_ids.length() {
        if !mask[node] {
          self.get_source_ids[node] = []
        }
      }
    None => ()
  }
  self
}

///|
fn local_graph_finish_full_flow(
  func : HotFunc,
  rows : LocalGraphFlowRows,
) -> HotLocalGraph {
  let local_count = hot_local_count(func)
  {
    local_count,
    param_count: hot_param_count(func),
    get_source_ids: rows.get_source_ids,
    set_influence_gets: rows.write_influences,
    write_local_ids: rows.write_facts.local_ids,
    write_is_tees: rows.write_facts.is_tees,
    local_is_already_ssa: local_graph_build_local_already_ssa(
      func,
      local_count,
      rows.get_source_ids,
    ),
    local_has_legal_default: local_graph_build_local_defaultability(
      func, local_count,
    ),
  }
}

///|
/// Include exceptional flow with the same ordered sources as the full graph.
/// An optional arena-sized read mask limits published rows to selected gets.
/// Unselected rows are empty/unknown; every selected row keeps full-flow sources.
/// The mask is borrowed only during construction, never retained or mutated.
pub fn local_graph_build_read_sources(
  func : HotFunc,
  cfg : HotCfg,
  selected_gets? : Array[Bool]? = None,
) -> HotLocalReadSources {
  match selected_gets {
    Some(mask) => {
      if mask.length() != hot_node_count(func) {
        abort("selected read mask requires one lane per arena node")
      }
      if !mask.any(fn(selected) { selected }) {
        return HotLocalReadSources::new(
          hot_local_count(func),
          Array::make(hot_node_count(func), []),
        )
      }
    }
    None => ()
  }
  let rows = local_graph_build_reverse_rows(
    func,
    cfg,
    true,
    full_metadata=false,
    selected_gets~,
  )
  HotLocalReadSources::new(hot_local_count(func), rows.get_source_ids)
}

///|
#inline
pub fn local_read_source_count_for_get(
  graph : HotLocalReadSources,
  node_id : NodeId,
) -> Int {
  if node_id < 0 || node_id >= graph.get_source_ids.length() {
    abort("local graph query requires a valid node id")
  }
  graph.get_source_ids[node_id].length()
}

///|
#inline
pub fn local_read_source_value_for_get(
  graph : HotLocalReadSources,
  node_id : NodeId,
  source_index : Int,
) -> HotLocalGraphSourceValue {
  if node_id < 0 || node_id >= graph.get_source_ids.length() {
    abort("local graph query requires a valid node id")
  }
  let source_id = graph.get_source_ids[node_id][source_index]
  let is_entry = source_id < graph.local_count
  HotLocalGraphSourceValue::new(
    is_entry,
    if is_entry {
      source_id
    } else {
      source_id - graph.local_count
    },
  )
}

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
fn local_graph_require_write(graph : HotLocalGraph, node_id : NodeId) -> Unit {
  local_graph_require_node_range(graph, node_id)
  if graph.write_local_ids[node_id] < 0 {
    abort("local graph write query requires local.set or local.tee")
  }
}

///|
fn local_graph_require_local_range(
  graph : HotLocalGraph,
  local_id : LocalId,
) -> Unit {
  if local_id < 0 || local_id >= graph.local_count {
    abort("local graph query requires a valid local id")
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
fn local_graph_union_into(
  target : Array[Int],
  src : Array[Int],
  buffer_growths? : Array[Int]? = None,
  membership_queries? : Array[Int]? = None,
  start? : Int = 0,
) -> Bool {
  let mut changed = false
  for index = start; index < src.length(); index = index + 1 {
    let value = src[index]
    match membership_queries {
      Some(count) => count[0] += 1
      None => ()
    }
    if !local_graph_array_contains(target, value) {
      match buffer_growths {
        Some(count) => if target.length() == target.capacity() { count[0] += 1 }
        None => ()
      }
      target.push(value)
      changed = true
    }
  }
  changed
}

///|
fn local_graph_state_clone(state : Array[Array[Int]]) -> Array[Array[Int]] {
  // State source sets are immutable. A transfer replaces the affected local's
  // set; forks and block states can therefore share all unchanged sets.
  state.copy()
}

///|
fn local_graph_join_sources(
  lhs : Array[Int],
  rhs : Array[Int],
  buffer_growths? : Array[Int]? = None,
  membership_queries? : Array[Int]? = None,
  minimum_capacity? : Int = 0,
) -> Array[Int] {
  if physical_equal(lhs, rhs) || rhs.is_empty() {
    return lhs
  }
  if lhs.is_empty() {
    return rhs
  }
  if lhs.length() >= 256 && rhs.length() >= 256 {
    return local_graph_join_indexed_sources(lhs, rhs)
  }
  let mut first_new = 0
  while first_new < rhs.length() {
    match membership_queries {
      Some(count) => count[0] += 1
      None => ()
    }
    if !local_graph_array_contains(lhs, rhs[first_new]) {
      break
    }
    first_new += 1
  }
  if first_new == rhs.length() {
    return lhs
  }
  let merged : Array[Int] = Array(
    capacity=(lhs.length() + rhs.length()).max(minimum_capacity),
  )
  merged.append(lhs)
  // The prefix was proved present and this one value was proved absent.
  // Remaining values still need deduplication against the growing union.
  merged.push(rhs[first_new])
  ignore(
    local_graph_union_into(
      merged,
      rhs,
      buffer_growths~,
      membership_queries~,
      start=first_new + 1,
    ),
  )
  merged
}

///|
fn local_graph_state_equal(
  lhs : Array[Array[Int]],
  rhs : Array[Array[Int]],
) -> Bool {
  if physical_equal(lhs, rhs) {
    return true
  }
  if lhs.length() != rhs.length() {
    return false
  }
  for idx = 0; idx < lhs.length(); idx = idx + 1 {
    if physical_equal(lhs[idx], rhs[idx]) {
      continue
    }
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
  Array::make(local_count, [])
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
fn local_graph_is_region_slot(
  node : HotNode,
  slot : Int,
  func? : HotFunc? = None,
) -> Bool {
  match node.op {
    HotOp::Block => slot >= node.imm1
    HotOp::Loop =>
      match func {
        Some(func) => slot >= hot_label_branch_arity(func, node.imm0)
        None => true
      }
    HotOp::If => slot == 1 || slot == 2
    HotOp::Try | HotOp::TryTable => slot == 0 || slot == 1
    _ => false
  }
}

///|
priv struct LocalGraphSourceRecorder {
  rows : Array[Array[Int]]
  mut single_owned : Int
  mut owned : @bitset.BitSet?
}

///|
fn LocalGraphSourceRecorder::new(
  rows : Array[Array[Int]],
) -> LocalGraphSourceRecorder {
  { rows, single_owned: -1, owned: None, }
}

///|
#inline
fn LocalGraphSourceRecorder::record(
  self : LocalGraphSourceRecorder,
  get_id : NodeId,
  sources : Array[Int],
) -> Unit {
  let previous = self.rows[get_id]
  if previous.is_empty() {
    self.rows[get_id] = sources
    // Sparse resolution clears symbolic rows before recording resolved ones.
    // A new borrowed row must not inherit the old row's ownership.
    if self.single_owned == get_id {
      self.single_owned = -1
    }
    match self.owned {
      Some(owned) => owned[get_id] = false
      None => ()
    }
    return
  }
  if physical_equal(previous, sources) || sources.is_empty() {
    return
  }
  if self.single_owned == get_id || (self.owned is Some(owned) && owned[get_id]) {
    ignore(local_graph_union_into(previous, sources))
    return
  }
  // Private observation rows grow across joins; leave room for the next small
  // observations without changing the immutable state rows' allocation policy.
  let merged = local_graph_join_sources(previous, sources, minimum_capacity=4)
  if !physical_equal(previous, merged) {
    self.rows[get_id] = merged
    if self.single_owned < 0 {
      self.single_owned = get_id
      return
    }
    let owned = match self.owned {
      Some(owned) => owned
      None => {
        let owned = @bitset.BitSet::new(self.rows.length())
        self.owned = Some(owned)
        owned
      }
    }
    owned[get_id] = true
  }
}

///|
#inline
fn local_graph_record_get_sources(
  local_count : Int,
  get_id : NodeId,
  sources : Array[Int],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
) -> Unit {
  match get_sources {
    Some(recorder) => recorder.record(get_id, sources)
    None => ()
  }
  match write_influences {
    Some(influences_by_node) =>
      for source_id in sources {
        if source_id >= local_count {
          let set_id = source_id - local_count
          if set_id >= 0 && set_id < influences_by_node.length() {
            let observers = influences_by_node[set_id]
            if observers.is_empty() {
              // Unobserved rows share an immutable empty array. The first
              // observer owns a row with the ordinary small-array growth room.
              let owned : Array[NodeId] = Array(capacity=8)
              owned.push(get_id)
              influences_by_node[set_id] = owned
            } else if !local_graph_node_array_contains(observers, get_id) {
              observers.push(get_id)
            }
          }
        }
      }
    None => ()
  }
}

///|
// CFG blocks own structured roots, but value-producing control may be nested
// under another root. Straight-line transfer is exact; other regions must join
// possible definitions instead of silently retaining only incoming facts.
fn local_graph_nested_block_node_is_straight_line(
  func : HotFunc,
  node_id : NodeId,
) -> Bool {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return true
  }
  if hot_is_terminator_node(func, node_id) {
    return false
  }
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Block =>
      return local_graph_nested_block_region_is_straight_line(
        func,
        hot_region_body_ref(func, node_id),
      )
    HotOp::Loop | HotOp::If | HotOp::Try | HotOp::TryTable => return false
    _ => ()
  }
  for index = 0; index < node.child_count; index = index + 1 {
    let slot = hot_child_evaluation_slot(node, index)
    if !local_graph_nested_block_node_is_straight_line(
        func,
        hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn local_graph_nested_block_region_is_straight_line(
  func : HotFunc,
  region_ref : HotRegionRef,
) -> Bool {
  for idx = 0; idx < hot_region_root_count(func, region_ref); idx = idx + 1 {
    if !local_graph_nested_block_node_is_straight_line(
        func,
        hot_region_get(func, region_ref, idx),
      ) {
      return false
    }
  }
  true
}

///|
// Unlike the reverse analysis's straight-line transfer, the forward transfer
// can fork and join ordinary conditionals nested inside value operands. Reject
// label transfers and exception/loop regions: they need CFG edges of their own.
fn local_graph_nested_operand_can_transfer(
  func : HotFunc,
  node_id : NodeId,
) -> Bool {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return true
  }
  if hot_is_terminator_node(func, node_id) {
    return false
  }
  let node = hot_node_get(func, node_id)
  match node.op {
    HotOp::Block =>
      return local_graph_nested_region_can_transfer(
        func,
        hot_region_body_ref(func, node_id),
      )
    HotOp::If => {
      if !local_graph_nested_region_can_transfer(
          func,
          hot_region_then_ref(func, node_id),
        ) {
        return false
      }
      match hot_region_else_ref(func, node_id) {
        Some(region) =>
          if !local_graph_nested_region_can_transfer(func, region) {
            return false
          }
        None => ()
      }
    }
    HotOp::Loop | HotOp::Try | HotOp::TryTable => return false
    _ => ()
  }
  for index = 0; index < node.child_count; index = index + 1 {
    let slot = hot_child_evaluation_slot(node, index)
    if !local_graph_is_region_slot(node, slot, func=Some(func)) &&
      !local_graph_nested_operand_can_transfer(
        func,
        hot_child_get(func, node_id, slot),
      ) {
      return false
    }
  }
  true
}

///|
fn local_graph_nested_region_can_transfer(
  func : HotFunc,
  region : HotRegionRef,
) -> Bool {
  for idx = 0; idx < hot_region_root_count(func, region); idx = idx + 1 {
    if !local_graph_nested_operand_can_transfer(
        func,
        hot_region_get(func, region, idx),
      ) {
      return false
    }
  }
  true
}

///|
fn local_graph_transfer_nested_region(
  func : HotFunc,
  local_count : Int,
  region : HotRegionRef,
  state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  evaluated_tuples : LocalGraphTupleState,
) -> Unit {
  for idx = 0; idx < hot_region_root_count(func, region); idx = idx + 1 {
    local_graph_transfer_node(
      func,
      local_count,
      hot_region_get(func, region, idx),
      state,
      get_sources,
      write_influences,
      true,
      evaluated_tuples,
    )
  }
}

///|
fn local_graph_transfer_node(
  func : HotFunc,
  local_count : Int,
  node_id : NodeId,
  state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  traverse_nested_blocks : Bool,
  evaluated_tuples : LocalGraphTupleState,
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  let node = hot_node_get(func, node_id)
  // Multiple stack lanes name one evaluation of their producer. Replaying
  // the producer per lane invents local definitions and expands tuple-valued
  // control trees exponentially. Keep this state per execution path.
  let is_tuple = match hot_type_get(func, node.ty) {
    Results(values) | BlockResultResolved(_, _, values) => values.length() > 1
    _ => false
  }
  if traverse_nested_blocks && is_tuple {
    if evaluated_tuples.already_evaluated(node_id) {
      return
    }
  }
  if node.op == HotOp::Loop {
    // Entry operands run before the loop body, including repeated complete
    // producers. Separate tuple state per evaluation avoids replay per lane.
    let count = hot_label_branch_arity(func, node.imm0)
    let mut slot = 0
    while slot < count {
      let producer = hot_child_get(func, node_id, slot)
      let mut end = slot + 1
      while end < count && hot_child_get(func, node_id, end) == producer {
        end += 1
      }
      let span = hot_node_result_arity(func, producer).max(1)
      let evaluations = (end - slot + span - 1) / span
      if evaluations == 1 {
        local_graph_transfer_node(
          func, local_count, producer, state, get_sources, write_influences, true,
          evaluated_tuples,
        )
      } else {
        // Keep retained tuple marks within one producer group. Each complete
        // evaluation already visits this same graph, which bounds clear work.
        let occurrence = LocalGraphTupleState::new(
          evaluated_tuples.slots,
          join_visits=evaluated_tuples.join_visits,
          local_count~,
        )
        occurrence.write_journal = evaluated_tuples.write_journal
        for _ in 0..<evaluations {
          match occurrence.evaluated {
            Some(entries) => entries.clear()
            None => ()
          }
          local_graph_transfer_node(
            func, local_count, producer, state, get_sources, write_influences, true,
            occurrence,
          )
        }
      }
      slot = end
    }
  }
  for index = 0; index < node.child_count; index = index + 1 {
    let slot = hot_child_evaluation_slot(node, index)
    if node.op == HotOp::Loop ||
      local_graph_is_region_slot(node, slot, func=Some(func)) {
      continue
    }
    local_graph_transfer_node(
      func,
      local_count,
      hot_child_get(func, node_id, slot),
      state,
      get_sources,
      write_influences,
      true,
      evaluated_tuples,
    )
  }
  if traverse_nested_blocks {
    match node.op {
      HotOp::If => {
        let write_journal = evaluated_tuples.prepare_write_journal()
        let first_write = match write_journal {
          Some(journal) => journal.locals.length()
          None => 0
        }
        let yes = local_graph_state_clone(state)
        let no = local_graph_state_clone(state)
        let yes_tuples = evaluated_tuples.copy()
        let no_tuples = evaluated_tuples.copy()
        let yes_region = hot_region_then_ref(func, node_id)
        for idx = 0
            idx < hot_region_root_count(func, yes_region)
            idx = idx + 1 {
          local_graph_transfer_node(
            func,
            local_count,
            hot_region_get(func, yes_region, idx),
            yes,
            get_sources,
            write_influences,
            true,
            yes_tuples,
          )
        }
        if hot_region_else_ref(func, node_id) is Some(no_region) {
          for idx = 0
              idx < hot_region_root_count(func, no_region)
              idx = idx + 1 {
            local_graph_transfer_node(
              func,
              local_count,
              hot_region_get(func, no_region, idx),
              no,
              get_sources,
              write_influences,
              true,
              no_tuples,
            )
          }
        }
        evaluated_tuples.intersect_paths(yes_tuples, no_tuples)
        match write_journal {
          Some(journal) => {
            for index = first_write
                index < journal.locals.length()
                index = index + 1 {
              let local_id = journal.locals[index]
              if !journal.seen[local_id] {
                journal.seen[local_id] = true
                if evaluated_tuples.join_visits is Some(visits) {
                  visits[0] += 1
                }
                state[local_id] = local_graph_join_sources(
                  yes[local_id],
                  no[local_id],
                )
              }
            }
            // No mark survives a completed join. The shared scratch can be
            // reused by the next sibling or outer join without losing a write.
            for index = first_write
                index < journal.locals.length()
                index = index + 1 {
              journal.seen[journal.locals[index]] = false
            }
          }
          None =>
            for local_id = 0; local_id < local_count; local_id = local_id + 1 {
              if evaluated_tuples.join_visits is Some(visits) {
                visits[0] += 1
              }
              state[local_id] = local_graph_join_sources(
                yes[local_id],
                no[local_id],
              )
            }
        }
      }
      HotOp::Block =>
        if local_graph_nested_operand_can_transfer(func, node_id) {
          local_graph_transfer_nested_region(
            func,
            local_count,
            hot_region_body_ref(func, node_id),
            state,
            get_sources,
            write_influences,
            evaluated_tuples,
          )
        } else {
          local_graph_transfer_unknown_control(
            func,
            local_count,
            node_id,
            state,
            get_sources,
            write_influences,
            write_journal=evaluated_tuples.write_journal,
          )
        }
      HotOp::Loop | HotOp::Try | HotOp::TryTable =>
        local_graph_transfer_unknown_control(
          func,
          local_count,
          node_id,
          state,
          get_sources,
          write_influences,
          write_journal=evaluated_tuples.write_journal,
        )
      _ => ()
    }
  }
  match node.op {
    HotOp::LocalGet =>
      local_graph_record_get_sources(
        local_count,
        node_id,
        state[node.imm0],
        get_sources,
        write_influences,
      )
    HotOp::LocalSet | HotOp::LocalTee => {
      if evaluated_tuples.write_journal is Some(journal) {
        journal.locals.push(node.imm0)
      }
      state[node.imm0] = [local_graph_set_source_id(local_count, node_id)]
    }
    _ => ()
  }
}

///|
fn local_graph_transfer_block(
  func : HotFunc,
  cfg : HotCfg,
  block_id : BlockId,
  in_state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  tuple_slots? : Array[Int]? = None,
  join_visits? : Array[Int]? = None,
) -> Array[Array[Int]] {
  if cfg_block_get(cfg, block_id).nodes.is_empty() {
    return in_state
  }
  let local_count = hot_local_count(func)
  if cfg.operands_expanded {
    let mut state = in_state
    let mut owned = false
    for node_id in cfg_block_get(cfg, block_id).nodes {
      // The CFG already lists each operand at its execution position.
      // Descending again invents extra reads and writes across control edges.
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalGet =>
          local_graph_record_get_sources(
            local_count,
            node_id,
            state[node.imm0],
            get_sources,
            write_influences,
          )
        HotOp::LocalSet | HotOp::LocalTee => {
          if !owned {
            state = state.copy()
            owned = true
          }
          state[node.imm0] = [local_graph_set_source_id(local_count, node_id)]
        }
        _ => ()
      }
    }
    return state
  }
  // Recursive transfer can replace state through nested control. Keep its
  // owned-copy path and sparse tuple evaluation state separate from the CFG.
  let state = local_graph_state_clone(in_state)
  let evaluated_tuples = LocalGraphTupleState::new(
    tuple_slots,
    join_visits~,
    local_count~,
  )
  for node_id in cfg_block_get(cfg, block_id).nodes {
    local_graph_transfer_node(
      func, local_count, node_id, state, get_sources, write_influences, false, evaluated_tuples,
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
  include_exceptional : Bool,
) -> Array[Array[Int]] {
  // Published block states and their source sets are immutable. A transfer
  // takes its own outer-array copy before replacing any local's source set.
  let mut merged : Array[Array[Int]]? = None
  let mut owned = false
  for pred in cfg_predecessor_edges(cfg, block_id) {
    if !include_exceptional && pred.kind == CfgEdgeKind::ExceptionalEdge {
      continue
    }
    let pred_state = out_states[pred.block]
    match merged {
      None => merged = Some(pred_state)
      Some(previous) => {
        if physical_equal(previous, pred_state) {
          continue
        }
        let mut current = previous
        for local = 0; local < local_count; local = local + 1 {
          let next = local_graph_join_sources(current[local], pred_state[local])
          if !physical_equal(next, current[local]) {
            if !owned {
              current = current.copy()
              owned = true
            }
            current[local] = next
          }
        }
        merged = Some(current)
      }
    }
  }
  match merged {
    Some(state) => state
    None => local_graph_empty_state(local_count)
  }
}

///|
fn local_graph_worklist_push(queue : Array[BlockId], block : BlockId) -> Unit {
  queue.push(block)
  let mut slot = queue.length() - 1
  while slot > 0 {
    let parent = (slot - 1) / 2
    if queue[parent] <= block {
      break
    }
    queue[slot] = queue[parent]
    slot = parent
  }
  queue[slot] = block
}

///|
fn local_graph_worklist_pop(queue : Array[BlockId]) -> BlockId {
  let block = queue[0]
  let last = queue.pop().unwrap()
  if !queue.is_empty() {
    let mut slot = 0
    while slot * 2 + 1 < queue.length() {
      let mut child = slot * 2 + 1
      if child + 1 < queue.length() && queue[child + 1] < queue[child] {
        child += 1
      }
      if last <= queue[child] {
        break
      }
      queue[slot] = queue[child]
      slot = child
    }
    queue[slot] = last
  }
  block
}

///|
fn local_graph_build_in_states(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  block_transfers? : Array[Int]? = None,
  block_merges? : Array[Int]? = None,
) -> Array[Array[Array[Int]]] {
  let local_count = hot_local_count(func)
  let block_count = cfg_block_count(cfg)
  let in_states : Array[Array[Array[Int]]] = []
  let out_states : Array[Array[Array[Int]]] = []
  for _ in 0..<block_count {
    in_states.push(local_graph_empty_state(local_count))
    out_states.push(local_graph_empty_state(local_count))
  }
  let entry_state = local_graph_entry_state(local_count)
  in_states[cfg_entry_block(cfg)] = entry_state
  // Every block runs initially, including disconnected regions with local writes.
  // Later visits retain ascending block order in each original solver round.
  // Earlier successors wait for the next round; later ones can run this round.
  let queued = Array::make(block_count, true)
  let mut current : Array[BlockId] = []
  let mut next : Array[BlockId] = []
  let mut first_round = true
  while first_round || !current.is_empty() {
    let mut initial_block = 0
    while (first_round && initial_block < block_count) ||
          (!first_round && !current.is_empty()) {
      let block_id = if first_round {
        let block = initial_block
        initial_block += 1
        block
      } else {
        local_graph_worklist_pop(current)
      }
      queued[block_id] = false
      if block_id != cfg_entry_block(cfg) {
        match block_merges {
          Some(count) => count[0] += 1
          None => ()
        }
      }
      let next_in = if block_id == cfg_entry_block(cfg) {
        entry_state
      } else {
        local_graph_merge_predecessors(
          cfg, block_id, local_count, out_states, include_exceptional,
        )
      }
      let input_changed = !local_graph_state_equal(in_states[block_id], next_in)
      if input_changed {
        in_states[block_id] = next_in
      }
      if first_round || input_changed {
        match block_transfers {
          Some(count) => count[0] += 1
          None => ()
        }
        let next_out = local_graph_transfer_block(
          func,
          cfg,
          block_id,
          in_states[block_id],
          None,
          None,
        )
        if !local_graph_state_equal(out_states[block_id], next_out) {
          out_states[block_id] = next_out
          for edge in cfg_successor_edges(cfg, block_id) {
            if (
                !include_exceptional &&
                edge.kind == CfgEdgeKind::ExceptionalEdge
              ) ||
              queued[edge.block] {
              continue
            }
            queued[edge.block] = true
            if edge.block <= block_id {
              local_graph_worklist_push(next, edge.block)
            } else if !first_round {
              local_graph_worklist_push(current, edge.block)
            }
          }
        }
      }
    }
    first_round = false
    let emptied = current
    current = next
    next = emptied
  }
  in_states
}

///|
fn local_graph_empty_influences(func : HotFunc) -> Array[Array[NodeId]] {
  Array::make(hot_node_count(func), [])
}

///|
#valtype
priv struct LocalGraphWriteFacts {
  local_ids : Array[LocalId]
  is_tees : Array[Bool]
}

///|
fn LocalGraphWriteFacts::new(
  local_ids : Array[LocalId],
  is_tees : Array[Bool],
) -> LocalGraphWriteFacts {
  { local_ids, is_tees, }
}

///|
fn local_graph_build_write_facts(
  func : HotFunc,
  include_tees? : Bool = true,
) -> LocalGraphWriteFacts {
  let count = hot_node_count(func)
  let local_ids = Array::make(count, -1)
  let is_tees = if include_tees { Array::make(count, false) } else { [] }
  // Both immutable graph fields cover the same arena. Build them together
  // at their final span, preserving sentinel rows for deleted nodes.
  for node_id in 0..<count {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalSet => local_ids[node_id] = node.imm0
      HotOp::LocalTee => {
        local_ids[node_id] = node.imm0
        if include_tees {
          is_tees[node_id] = true
        }
      }
      _ => ()
    }
  }
  LocalGraphWriteFacts::new(local_ids, is_tees)
}

///|
fn local_graph_build_write_local_ids(func : HotFunc) -> Array[LocalId] {
  let write_local_ids : Array[LocalId] = []
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if hot_node_is_live(func, node_id) {
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalSet | HotOp::LocalTee => write_local_ids.push(node.imm0)
        _ => write_local_ids.push(-1)
      }
    } else {
      write_local_ids.push(-1)
    }
  }
  write_local_ids
}

///|
fn local_graph_build_write_is_tees(func : HotFunc) -> Array[Bool] {
  let write_is_tees : Array[Bool] = []
  for node_id = 0; node_id < hot_node_count(func); node_id = node_id + 1 {
    if hot_node_is_live(func, node_id) {
      let node = hot_node_get(func, node_id)
      match node.op {
        HotOp::LocalTee => write_is_tees.push(true)
        _ => write_is_tees.push(false)
      }
    } else {
      write_is_tees.push(false)
    }
  }
  write_is_tees
}

///|
fn local_graph_build_local_defaultability(
  func : HotFunc,
  local_count : Int,
) -> Array[Bool] {
  let out : Array[Bool] = []
  for local_id = 0; local_id < local_count; local_id = local_id + 1 {
    match hot_local_type(func, local_id) {
      Some(val_type) => out.push(@lib.has_default(val_type))
      None => out.push(false)
    }
  }
  out
}

///|
fn local_graph_build_local_already_ssa(
  func : HotFunc,
  local_count : Int,
  get_sources : Array[Array[Int]],
) -> Array[Bool] {
  if local_count == 0 {
    return []
  }
  // Finalized source IDs are nonnegative; sparse symbols are resolved first.
  // Only singleton identity matters. -1 means unseen and -2 means multiple;
  // retain no growing union after a second distinct source is observed.
  let reads = Array::make(local_count, -1)
  let writes = Array::make(local_count, -1)
  for node_id in 0..<hot_node_count(func) {
    if !hot_node_is_live(func, node_id) {
      continue
    }
    let node = hot_node_get(func, node_id)
    match node.op {
      HotOp::LocalGet => {
        let mut source = reads[node.imm0]
        if source == -2 {
          continue
        }
        for incoming in get_sources[node_id] {
          if source == -1 {
            source = incoming
          } else if source != incoming {
            source = -2
            break
          }
        }
        reads[node.imm0] = source
      }
      HotOp::LocalSet | HotOp::LocalTee => {
        let source = local_graph_set_source_id(local_count, node_id)
        let previous = writes[node.imm0]
        writes[node.imm0] = if previous == -1 || previous == source {
          source
        } else {
          -2
        }
      }
      _ => ()
    }
  }
  let out : Array[Bool] = Array(capacity=local_count)
  for local in 0..<local_count {
    out.push(
      reads[local] >= 0 &&
      (writes[local] == -1 || writes[local] == reads[local]),
    )
  }
  out
}

///|
fn local_graph_build_with_exceptional_policy(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
) -> HotLocalGraph {
  let local_count = hot_local_count(func)
  let get_sources : Array[Array[Int]] = Array::make(hot_node_count(func), [])
  let recorded_sources = LocalGraphSourceRecorder::new(get_sources)
  let write_influences = local_graph_empty_influences(func)
  let in_states = local_graph_build_in_states(func, cfg, include_exceptional)
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    ignore(
      local_graph_transfer_block(
        func,
        cfg,
        block_id,
        in_states[block_id],
        Some(recorded_sources),
        Some(write_influences),
      ),
    )
  }
  let write_facts = local_graph_build_write_facts(func)
  {
    local_count,
    param_count: hot_param_count(func),
    get_source_ids: get_sources,
    set_influence_gets: write_influences,
    write_local_ids: write_facts.local_ids,
    write_is_tees: write_facts.is_tees,
    local_is_already_ssa: local_graph_build_local_already_ssa(
      func, local_count, get_sources,
    ),
    local_has_legal_default: local_graph_build_local_defaultability(
      func, local_count,
    ),
  }
}

///|
pub fn local_graph_build(func : HotFunc, cfg : HotCfg) -> HotLocalGraph {
  local_graph_build_with_exceptional_policy(func, cfg, false)
}

///|
pub fn local_graph_build_full_flow(
  func : HotFunc,
  cfg : HotCfg,
) -> HotLocalGraph {
  local_graph_build_reverse_flow(func, cfg, true)
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
/// Read a stable LocalGraph snapshot without materializing an owned source
/// array. Zero sources means the read has no represented reaching definition;
/// consumers that require a complete proof must retain their unknown fallback.
#inline
pub fn local_graph_reaching_source_count_for_get(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Int {
  local_graph_require_node_range(graph, node_id)
  graph.get_source_ids[node_id].length()
}

///|
/// Read one source in the same order as the owned query. The source index
/// must be below local_graph_reaching_source_count_for_get. This query does
/// not expose or copy the graph's internal source row.
#inline
pub fn local_graph_reaching_source_for_get(
  graph : HotLocalGraph,
  node_id : NodeId,
  source_index : Int,
) -> HotLocalGraphSource {
  local_graph_require_node_range(graph, node_id)
  local_graph_source_from_id(
    graph.local_count,
    graph.get_source_ids[node_id][source_index],
  )
}

///|
/// Same checked indices and order as the enum query, with a scalar return.
#inline
pub fn local_graph_reaching_source_value_for_get(
  graph : HotLocalGraph,
  node_id : NodeId,
  source_index : Int,
) -> HotLocalGraphSourceValue {
  local_graph_require_node_range(graph, node_id)
  let source_id = graph.get_source_ids[node_id][source_index]
  let is_entry = source_id < graph.local_count
  HotLocalGraphSourceValue::new(
    is_entry,
    if is_entry {
      source_id
    } else {
      source_id - graph.local_count
    },
  )
}

///|
pub fn local_graph_entry_source_is_param(
  graph : HotLocalGraph,
  local_id : LocalId,
) -> Bool {
  local_id >= 0 && local_id < graph.param_count
}

///|
pub fn local_graph_entry_source_is_default(
  graph : HotLocalGraph,
  local_id : LocalId,
) -> Bool {
  local_id >= graph.param_count && local_id < graph.local_count
}

///|
pub fn local_graph_source_is_param_entry(
  graph : HotLocalGraph,
  source : HotLocalGraphSource,
) -> Bool {
  match source {
    HotLocalGraphSource::EntrySource(local_id) =>
      local_graph_entry_source_is_param(graph, local_id)
    _ => false
  }
}

///|
pub fn local_graph_source_is_default_entry(
  graph : HotLocalGraph,
  source : HotLocalGraphSource,
) -> Bool {
  match source {
    HotLocalGraphSource::EntrySource(local_id) =>
      local_graph_entry_source_is_default(graph, local_id)
    _ => false
  }
}

///|
pub fn local_graph_entry_source_has_legal_default(
  graph : HotLocalGraph,
  local_id : LocalId,
) -> Bool {
  local_graph_require_local_range(graph, local_id)
  local_graph_entry_source_is_default(graph, local_id) &&
  graph.local_has_legal_default[local_id]
}

///|
pub fn local_graph_source_is_defaultable_entry(
  graph : HotLocalGraph,
  source : HotLocalGraphSource,
) -> Bool {
  match source {
    HotLocalGraphSource::EntrySource(local_id) =>
      local_graph_entry_source_has_legal_default(graph, local_id)
    _ => false
  }
}

///|
pub fn local_graph_get_is_single_source(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_node_range(graph, node_id)
  graph.get_source_ids[node_id].length() == 1
}

///|
pub fn local_graph_get_is_merge(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_node_range(graph, node_id)
  graph.get_source_ids[node_id].length() > 1
}

///|
pub fn local_graph_local_is_already_ssa(
  graph : HotLocalGraph,
  local_id : LocalId,
) -> Bool {
  local_graph_require_local_range(graph, local_id)
  graph.local_is_already_ssa[local_id]
}

///|
pub fn local_graph_node_is_write(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_node_range(graph, node_id)
  graph.write_local_ids[node_id] >= 0
}

///|
pub fn local_graph_write_local_id(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> LocalId {
  local_graph_require_write(graph, node_id)
  graph.write_local_ids[node_id]
}

///|
pub fn local_graph_write_is_set(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_write(graph, node_id)
  !graph.write_is_tees[node_id]
}

///|
pub fn local_graph_write_is_tee(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_write(graph, node_id)
  graph.write_is_tees[node_id]
}

///|
pub fn local_graph_influenced_gets_for_write(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Array[NodeId] {
  local_graph_require_write(graph, node_id)
  graph.set_influence_gets[node_id].copy()
}

///|
pub fn local_graph_write_has_merge_influences(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_write(graph, node_id)
  for get_id in graph.set_influence_gets[node_id] {
    if local_graph_get_is_merge(graph, get_id) {
      return true
    }
  }
  false
}

///|
pub fn local_graph_write_is_no_merge_freshenable(
  graph : HotLocalGraph,
  node_id : NodeId,
) -> Bool {
  local_graph_require_write(graph, node_id)
  let local_id = graph.write_local_ids[node_id]
  !graph.local_is_already_ssa[local_id] &&
  !local_graph_write_has_merge_influences(graph, node_id)
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
  for index = 0; index < node.child_count; index = index + 1 {
    let slot = hot_child_evaluation_slot(node, index)
    if local_graph_is_region_slot(node, slot, func=Some(func)) {
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
  if cfg.operands_expanded {
    return cfg_block_get(cfg, block_id).nodes.copy()
  }
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
fn local_graph_reverse_actions_node(
  func : HotFunc,
  node_id : NodeId,
  out : Array[NodeId],
  traverse_nested_blocks : Bool,
) -> Unit {
  if node_id == HOT_NONE_NODE || !hot_node_is_live(func, node_id) {
    return
  }
  let node = hot_node_get(func, node_id)
  for index = 0; index < node.child_count; index = index + 1 {
    let slot = hot_child_evaluation_slot(node, index)
    if local_graph_is_region_slot(node, slot, func=Some(func)) {
      continue
    }
    local_graph_reverse_actions_node(
      func,
      hot_child_get(func, node_id, slot),
      out,
      true,
    )
  }
  if traverse_nested_blocks && node.op == HotOp::Block {
    let body_ref = hot_region_body_ref(func, node_id)
    if local_graph_nested_block_region_is_straight_line(func, body_ref) {
      for idx = 0; idx < hot_region_root_count(func, body_ref); idx = idx + 1 {
        local_graph_reverse_actions_node(
          func,
          hot_region_get(func, body_ref, idx),
          out,
          true,
        )
      }
    }
  }
  match node.op {
    HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee => out.push(node_id)
    _ => ()
  }
}

///|
fn local_graph_reverse_action_sequences(
  func : HotFunc,
  cfg : HotCfg,
) -> Array[Array[NodeId]] {
  let sequences : Array[Array[NodeId]] = []
  for block_id = 0; block_id < cfg_block_count(cfg); block_id = block_id + 1 {
    let actions : Array[NodeId] = []
    for node_id in cfg_block_get(cfg, block_id).nodes {
      if cfg.operands_expanded {
        // The CFG has already ordered operands, including stack-carried
        // reads and control inputs. Recursing repeats their evaluations.
        match hot_node_op(func, node_id) {
          HotOp::LocalGet | HotOp::LocalSet | HotOp::LocalTee =>
            actions.push(node_id)
          _ => ()
        }
      } else {
        local_graph_reverse_actions_node(func, node_id, actions, false)
      }
    }
    sequences.push(actions)
  }
  sequences
}

///|
fn local_graph_reverse_find_last_write(
  write_local_ids : Array[LocalId],
  actions : Array[NodeId],
  end : Int,
  local_id : LocalId,
) -> NodeId? {
  let mut idx = if end < actions.length() { end } else { actions.length() }
  while idx > 0 {
    idx -= 1
    let node_id = actions[idx]
    if write_local_ids[node_id] == local_id {
      return Some(node_id)
    }
  }
  None
}

///|
fn local_graph_reverse_indexed_last_write(
  write_local_ids : Array[LocalId],
  actions : Array[Array[NodeId]],
  block : BlockId,
  local_id : LocalId,
  indices : Array[@hashmap.HashMap[Int, NodeId]?],
) -> NodeId? {
  let nodes = actions[block]
  if nodes.length() <= 4 {
    return local_graph_reverse_find_last_write(
      write_local_ids,
      nodes,
      nodes.length(),
      local_id,
    )
  }
  let index = match indices[block] {
    Some(index) => index
    None => {
      let index : @hashmap.HashMap[Int, NodeId] = @hashmap.new()
      for node in nodes {
        let local = write_local_ids[node]
        if local >= 0 {
          index.set(local, node)
        }
      }
      indices[block] = Some(index)
      index
    }
  }
  index.get(local_id)
}

///|
fn local_graph_reverse_transparent_predecessors(
  write_local_ids : Array[LocalId],
  cfg : HotCfg,
  actions : Array[Array[NodeId]],
  include_exceptional : Bool,
) -> Array[BlockId] {
  let count = cfg_block_count(cfg)
  let next = Array::makei(count, fn(block) { block })
  for block in 0..<count {
    let mut writes = false
    for node in actions[block] {
      if write_local_ids[node] >= 0 {
        writes = true
        break
      }
    }
    if writes {
      continue
    }
    let mut predecessor = -1
    for edge in cfg_predecessor_edges(cfg, block) {
      if !include_exceptional && edge.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      if predecessor >= 0 {
        predecessor = -2
        break
      }
      predecessor = edge.block
    }
    if predecessor >= 0 {
      next[block] = predecessor
    }
  }
  // The eligible links form a functional graph. Resolve each chain once;
  // a closed read-only cycle has no external source and retains one
  // representative so the query's existing visited set terminates it.
  let state = Array::make(count, 0)
  let path : Array[BlockId] = []
  for block in 0..<count {
    if state[block] != 0 {
      continue
    }
    let mut current = block
    while state[current] == 0 {
      state[current] = 1
      path.push(current)
      if next[current] == current {
        break
      }
      current = next[current]
    }
    let target = if state[current] == 2 { next[current] } else { current }
    for member in path {
      next[member] = target
      state[member] = 2
    }
    path.clear()
  }
  next
}

///|
fn local_graph_reverse_entry_sources(
  write_local_ids : Array[LocalId],
  cfg : HotCfg,
  actions : Array[Array[NodeId]],
  transparent_predecessors : Array[BlockId],
  block_id : BlockId,
  local_id : LocalId,
  include_exceptional : Bool,
  cache : Array[@hashmap.HashMap[Int, Array[Int]]?],
  last_writes : Array[@hashmap.HashMap[Int, NodeId]?],
  seen : Array[Bool],
  visited : Array[BlockId],
  work : Array[BlockId],
  local_count : Int,
  cache_slots? : Array[Int]? = None,
) -> Array[Int] {
  local_graph_reverse_entry_sources_impl(
    write_local_ids,
    cfg,
    actions,
    transparent_predecessors,
    block_id,
    local_id,
    include_exceptional,
    cache,
    last_writes,
    seen,
    visited,
    work,
    local_count,
    None,
    None,
    cache_slots,
  )
}

///|
fn local_graph_reverse_entry_sources_impl(
  write_local_ids : Array[LocalId],
  cfg : HotCfg,
  actions : Array[Array[NodeId]],
  transparent_predecessors : Array[BlockId],
  block_id : BlockId,
  local_id : LocalId,
  include_exceptional : Bool,
  cache : Array[@hashmap.HashMap[Int, Array[Int]]?],
  last_writes : Array[@hashmap.HashMap[Int, NodeId]?],
  seen : Array[Bool],
  visited : Array[BlockId],
  work : Array[BlockId],
  local_count : Int,
  writer_blocks : Array[Int]?,
  membership_queries : Array[Int]?,
  cache_slots : Array[Int]?,
) -> Array[Int] {
  if cache[block_id] is Some(row) {
    if row.get(local_id) is Some(sources) {
      // Completed rows are immutable; readers either borrow or copy on write.
      return sources
    }
  }
  let sources : Array[Int] = []
  let mut root_write_seen = false
  let mut writer_marks = false
  work.push(block_id)
  seen[block_id] = true
  visited.push(block_id)
  while !work.is_empty() {
    let current = work.pop().unwrap()
    let mut has_predecessor = false
    for edge in cfg_predecessor_edges(cfg, current) {
      if !include_exceptional && edge.kind == CfgEdgeKind::ExceptionalEdge {
        continue
      }
      has_predecessor = true
      let pred = transparent_predecessors[edge.block]
      match
        local_graph_reverse_indexed_last_write(
          write_local_ids, actions, pred, local_id, last_writes,
        ) {
        Some(write_id) => {
          let source_id = local_graph_set_source_id(local_count, write_id)
          match writer_blocks {
            Some(_) => {
              // Unique-action admission gives each writer one owning block.
              // A writer stops this local's walk, so its block is never queued.
              // The query root is already seen, but can contribute a loop write.
              // Tiny rows stay on the bounded contiguous scan. Promote
              // once, before the first search that could exceed eight lanes.
              if !writer_marks && sources.length() >= 8 {
                match writer_blocks {
                  Some(owners) =>
                    for source in sources {
                      if source >= local_count {
                        let owner = owners[source - local_count]
                        if owner == block_id {
                          root_write_seen = true
                        } else {
                          seen[owner] = true
                          match membership_queries {
                            Some(count) if count.length() > 1 => count[1] += 1
                            _ => ()
                          }
                        }
                      }
                    }
                  None => ()
                }
                writer_marks = true
              }
              if writer_marks {
                let already_seen = if pred == block_id {
                  root_write_seen
                } else {
                  seen[pred]
                }
                if !already_seen {
                  if pred == block_id {
                    root_write_seen = true
                  } else {
                    seen[pred] = true
                    match membership_queries {
                      Some(count) if count.length() > 1 => count[1] += 1
                      _ => ()
                    }
                  }
                  sources.push(source_id)
                }
              } else {
                match membership_queries {
                  Some(count) => count[0] += 1
                  None => ()
                }
                if !local_graph_array_contains(sources, source_id) {
                  sources.push(source_id)
                }
              }
            }
            None => {
              match membership_queries {
                Some(count) => count[0] += 1
                None => ()
              }
              if !local_graph_array_contains(sources, source_id) {
                sources.push(source_id)
              }
            }
          }
        }
        None =>
          if !seen[pred] {
            seen[pred] = true
            visited.push(pred)
            work.push(pred)
          }
      }
    }
    if !has_predecessor && current == cfg_entry_block(cfg) {
      let entry_source = local_graph_entry_source_id(local_id)
      match writer_blocks {
        Some(_) => sources.push(entry_source)
        None => {
          match membership_queries {
            Some(count) => count[0] += 1
            None => ()
          }
          if !local_graph_array_contains(sources, entry_source) {
            sources.push(entry_source)
          }
        }
      }
    }
  }
  if writer_marks {
    match writer_blocks {
      Some(owners) =>
        for source in sources {
          if source >= local_count {
            seen[owners[source - local_count]] = false
            match membership_queries {
              Some(count) if count.length() > 1 => count[1] += 1
              _ => ()
            }
          }
        }
      None => ()
    }
  }
  for block in visited {
    seen[block] = false
  }
  visited.clear()
  let row = match cache[block_id] {
    Some(row) => row
    None => {
      let row = @hashmap.new()
      cache[block_id] = Some(row)
      row
    }
  }
  row.set(local_id, sources)
  match cache_slots {
    Some(count) => count[0] += 1
    None => ()
  }
  sources
}

///|
// Reverse flow visits each get once, and each source row is already unique.
// Append influences directly instead of repeatedly searching prior readers.
fn local_graph_record_unique_get_sources(
  local_count : Int,
  get_id : NodeId,
  sources : Array[Int],
  get_sources : Array[Array[Int]],
  write_influences : Array[Array[NodeId]],
) -> Unit {
  get_sources[get_id] = sources
  for source_id in sources {
    if source_id >= local_count {
      let set_id = source_id - local_count
      if set_id >= 0 && set_id < write_influences.length() {
        let observers = write_influences[set_id]
        if observers.is_empty() {
          let owned : Array[NodeId] = Array(capacity=8)
          owned.push(get_id)
          write_influences[set_id] = owned
        } else {
          observers.push(get_id)
        }
      }
    }
  }
}

///|
fn local_graph_build_reverse_flow(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  cache_slots? : Array[Int]? = None,
) -> HotLocalGraph {
  local_graph_finish_full_flow(
    func,
    local_graph_build_reverse_rows(
      func,
      cfg,
      include_exceptional,
      cache_slots~,
      full_metadata=true,
    ),
  )
}

///|
fn local_graph_build_reverse_rows(
  func : HotFunc,
  cfg : HotCfg,
  include_exceptional : Bool,
  cache_slots? : Array[Int]? = None,
  full_metadata~ : Bool,
  selected_gets? : Array[Bool]? = None,
) -> LocalGraphFlowRows {
  let local_count = hot_local_count(func)
  let node_count = hot_node_count(func)
  // Reverse scans require a complete linear action list for every CFG block.
  // Nested branching operands have multiple paths and use the forward join.
  for block in cfg.blocks {
    if cfg.operands_expanded {
      // Operand control is represented by CFG edges rather than hidden in
      // a root's subtree, so every block already has a linear action list.
      break
    }
    for root in block.nodes {
      let data = hot_node_get(func, root)
      for slot = 0; slot < data.child_count; slot = slot + 1 {
        if !local_graph_is_region_slot(data, slot, func=Some(func)) &&
          !local_graph_nested_block_node_is_straight_line(
            func,
            hot_child_get(func, root, slot),
          ) {
          return local_graph_build_sparse_rows(
            func,
            cfg,
            include_exceptional,
            full_metadata~,
          ).select_gets(selected_gets)
        }
      }
    }
  }
  let actions = local_graph_reverse_action_sequences(func, cfg)
  let node_blocks = Array::make(node_count, -1)
  let nearest_writes = Array::make(node_count, -1)
  let last_writes = Array::make(local_count, -1)
  let written_anywhere = Array::make(local_count, false)
  let written_locals : Array[Int] = []
  for block_id = 0; block_id < actions.length(); block_id = block_id + 1 {
    for idx = 0; idx < actions[block_id].length(); idx = idx + 1 {
      let node_id = actions[block_id][idx]
      if node_id >= 0 && node_id < node_count {
        if node_blocks[node_id] >= 0 {
          // A shared expression can have several reaching contexts.
          return local_graph_build_sparse_rows(
            func,
            cfg,
            include_exceptional,
            full_metadata~,
          ).select_gets(selected_gets)
        }
        node_blocks[node_id] = block_id
        let node = hot_node_get(func, node_id)
        match node.op {
          HotOp::LocalSet | HotOp::LocalTee => {
            written_anywhere[node.imm0] = true
            if last_writes[node.imm0] < 0 {
              written_locals.push(node.imm0)
            }
            last_writes[node.imm0] = node_id
          }
          HotOp::LocalGet => {
            // Keep complete action/write admission and CFG flow. Only selected
            // reads need nearest/source rows; unselected reads remain unknown.
            if selected_gets is Some(mask) && !mask[node_id] {
              continue
            }
            nearest_writes[node_id] = if last_writes[node.imm0] >= 0 {
              last_writes[node.imm0]
            } else {
              // Keep the local in the existing per-node scratch row. -1
              // remains a nonread; known writers retain their node IDs.
              -node.imm0 - 2
            }
          }
          _ => ()
        }
      }
    }
    for local_id in written_locals {
      last_writes[local_id] = -1
    }
    written_locals.clear()
  }

  // The final graph already needs this immutable index. Reuse it for every
  // predecessor query instead of decoding the same node at each visit.
  let write_facts = local_graph_build_write_facts(
    func,
    include_tees=full_metadata,
  )
  let write_local_ids = write_facts.local_ids
  let transparent_predecessors = local_graph_reverse_transparent_predecessors(
    write_local_ids, cfg, actions, include_exceptional,
  )
  let get_sources : Array[Array[Int]] = Array::make(node_count, [])
  let write_influences = if full_metadata {
    local_graph_empty_influences(func)
  } else {
    []
  }
  let cache : Array[@hashmap.HashMap[Int, Array[Int]]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let block_writes : Array[@hashmap.HashMap[Int, NodeId]?] = Array::make(
    cfg_block_count(cfg),
    None,
  )
  let seen = Array::make(cfg_block_count(cfg), false)
  let visited : Array[BlockId] = []
  let work : Array[BlockId] = []
  let entry_rows : Array[Array[Int]] = Array::make(local_count, [])
  if local_graph_has_immutable_entry_read(
      actions, nearest_writes, written_anywhere,
    ) {
    let entry = cfg_entry_block(cfg)
    // Match the reverse query's exact origin rule: entry contributes only
    // when it has no admitted predecessors. Closed/unreachable cycles must
    // retain unknown rows rather than inventing an entry definition.
    let mut entry_origin = true
    for edge in cfg_predecessor_edges(cfg, entry) {
      if include_exceptional || edge.kind != CfgEdgeKind::ExceptionalEdge {
        entry_origin = false
        break
      }
    }
    if entry_origin {
      work.push(entry)
      seen[entry] = true
      visited.push(entry)
      while !work.is_empty() {
        let current = work.pop().unwrap()
        for node_id in actions[current] {
          let encoded = nearest_writes[node_id]
          if encoded <= -2 {
            let local_id = -encoded - 2
            if !written_anywhere[local_id] {
              // A disjoint negative range marks reachable immutable reads.
              nearest_writes[node_id] = encoded - local_count
            }
          }
        }
        for edge in cfg_successor_edges(cfg, current) {
          if !include_exceptional && edge.kind == CfgEdgeKind::ExceptionalEdge {
            continue
          }
          if !seen[edge.block] {
            seen[edge.block] = true
            visited.push(edge.block)
            work.push(edge.block)
          }
        }
      }
      for block in visited {
        seen[block] = false
      }
      visited.clear()
    }
  }
  match cache_slots {
    Some(count) => count[0] += cache.length()
    None => ()
  }
  // Publish the admitted immutable owner index once. Constructing its
  // nullable argument at every query otherwise repeats reference-count work.
  let writer_blocks = Some(node_blocks)
  for node_id = 0; node_id < node_count; node_id = node_id + 1 {
    // Admission already validated every action and records only read tags.
    // Unmapped/orphan/deleted/nonread nodes keep -1. Preserve node-ID order
    // without decoding their headers again; writer facts still span the arena.
    let write_id = nearest_writes[node_id]
    if write_id == -1 {
      continue
    }
    let block_id = node_blocks[node_id]
    if block_id < 0 {
      continue
    }
    let local_id = if write_id >= 0 {
      write_local_ids[write_id]
    } else if write_id <= -local_count - 2 {
      -write_id - local_count - 2
    } else {
      -write_id - 2
    }
    let sources = if write_id >= 0 {
      [local_graph_set_source_id(local_count, write_id)]
    } else if !written_anywhere[local_id] {
      if write_id <= -local_count - 2 {
        if entry_rows[local_id].is_empty() {
          entry_rows[local_id] = [local_graph_entry_source_id(local_id)]
        }
        // Source rows are immutable borrowed graph data, as with completed
        // reverse-cache rows. Share one entry row across this local's reads.
        entry_rows[local_id]
      } else {
        []
      }
    } else {
      local_graph_reverse_entry_sources_impl(
        write_local_ids,
        cfg,
        actions,
        transparent_predecessors,
        block_id,
        local_id,
        include_exceptional,
        cache,
        block_writes,
        seen,
        visited,
        work,
        local_count,
        writer_blocks,
        None,
        cache_slots,
      )
    }
    if full_metadata {
      local_graph_record_unique_get_sources(
        local_count, node_id, sources, get_sources, write_influences,
      )
    } else {
      get_sources[node_id] = sources
    }
  }
  LocalGraphFlowRows::new(get_sources, write_influences, write_facts)
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

///|
// A nested region absent from the CFG can bypass assignments or repeat them.
// Keep both incoming definitions and every contained write, including sources
// for reads within that region. Ignoring the region is not an unknown summary.
fn local_graph_transfer_unknown_control(
  func : HotFunc,
  local_count : Int,
  node : NodeId,
  state : Array[Array[Int]],
  get_sources : LocalGraphSourceRecorder?,
  write_influences : Array[Array[NodeId]]?,
  write_journal? : LocalGraphWriteJournal? = None,
) -> Unit {
  let work = [node]
  let seen = Array::make(hot_node_count(func), false)
  let reads : Array[NodeId] = []
  while !work.is_empty() {
    let current = work.pop().unwrap()
    if current < 0 || seen[current] {
      continue
    }
    seen[current] = true
    let data = hot_node_get(func, current)
    match data.op {
      HotOp::LocalSet | HotOp::LocalTee => {
        if write_journal is Some(journal) {
          journal.locals.push(data.imm0)
        }
        state[data.imm0] = local_graph_join_sources(state[data.imm0], [
          local_graph_set_source_id(local_count, current),
        ])
      }
      HotOp::LocalGet => reads.push(current)
      _ => ()
    }
    for child in hot_child_span(func, current) {
      work.push(child)
    }
  }
  for read in reads {
    local_graph_record_get_sources(
      local_count,
      read,
      state[hot_node_get(func, read).imm0],
      get_sources,
      write_influences,
    )
  }
}

///|
fn local_graph_has_immutable_entry_read(
  actions : Array[Array[NodeId]],
  nearest_writes : Array[Int],
  written_anywhere : Array[Bool],
) -> Bool {
  // All writes are known now. Demand entry reachability only for an observed
  // read with no writer anywhere; unused locals and orphan arena reads do not
  // require a CFG walk. Borrow the already validated compact action tags.
  for block in actions {
    for node_id in block {
      let encoded = nearest_writes[node_id]
      if encoded <= -2 && !written_anywhere[-encoded - 2] {
        return true
      }
    }
  }
  false
}
