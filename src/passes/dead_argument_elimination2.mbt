// Licensing scope: see ../../LICENSE and this directory's LICENSE and NOTICE.
// Conservative attribution from pinned Binaryen version_130 counterpart:
// Copyright 2025 WebAssembly Community Group participants
// Counterpart: src/passes/DeadArgumentElimination2.cpp (5d704ad5); origin remains unconfirmed.
// Potentially incorporated Binaryen expression retains Apache-2.0 terms.
// Original Starshine contributions use the scoped MIT grant in ../../LICENSE.
// Modified for Starshine through 2026: implementation and validation use
// Starshine's representations and APIs; this is not an unchanged upstream file.
// Conservative notice retention does not establish copying or independence.

///|
// Binaryen 132 DAE2: parameter and whole-result liveness share a least fixed
// point. All locations start unused. Observable uses seed a backwards worklist;
// a forwarding cycle does not become live merely because it contains a cycle.
// Flat insertion-ordered adjacency avoids an empty heap array per location.
// first/last link only actual edges; solve preserves the original queue order.
priv struct Dae2Graph {
  edges : Array[Int32]
  next_edge : Array[Int32]
  first_edge : Array[Int32]
  last_edge : Array[Int32]
  used : Array[Bool]
  work : Array[Int32]
  mut cursor : Int32
}

///|
fn Dae2Graph::for_solved_rewrite(self : Dae2Graph) -> Dae2Graph {
  // The owned analysis graph dies at this transfer. Keep its solved bitvector
  // while dropping adjacency, without mutable array fields on hot edge paths.
  {
    edges: [],
    next_edge: [],
    first_edge: [],
    last_edge: [],
    work: [],
    used: self.used,
    cursor: self.cursor,
  }
}

///|
fn Dae2Graph::new() -> Dae2Graph {
  {
    edges: [],
    next_edge: [],
    first_edge: [],
    last_edge: [],
    used: [],
    work: [],
    cursor: 0,
  }
}

///|
fn Dae2Graph::location(self : Dae2Graph) -> Int32 {
  let id = self.used.length()
  self.first_edge.push(-1)
  self.last_edge.push(-1)
  self.used.push(false)
  id
}

///|
fn Dae2Graph::locations(self : Dae2Graph, count : Int32) -> Int32 {
  let base = self.used.length()
  let end = base + count
  if count < 0 || end < base {
    abort("DAE2 graph location count is out of range")
  }
  if end > self.used.capacity() {
    // Array.resize grows to the exact requested size. Preserve the scalar
    // allocator's amortized growth across many adjacent function ranges.
    let doubled = self.used.capacity() * 2
    let capacity = if doubled > end { doubled } else { end }
    self.first_edge.reserve_capacity(capacity)
    self.last_edge.reserve_capacity(capacity)
    self.used.reserve_capacity(capacity)
  }
  self.first_edge.resize(end, -1)
  self.last_edge.resize(end, -1)
  self.used.resize(end, false)
  base
}

///|
fn Dae2Graph::edge(self : Dae2Graph, consumer : Int32, source : Int32) -> Unit {
  if self.cursor != 0 {
    abort("DAE2 graph edges must be complete before solving")
  }
  if consumer >= 0 && source >= 0 {
    let edge = self.edges.length()
    self.edges.push(source)
    self.next_edge.push(-1)
    let previous = self.last_edge[consumer]
    if previous < 0 {
      self.first_edge[consumer] = edge
    } else {
      self.next_edge[previous] = edge
    }
    self.last_edge[consumer] = edge
  }
}

///|
fn Dae2Graph::observe(self : Dae2Graph, location : Int32) -> Unit {
  if location >= 0 && !self.used[location] {
    self.used[location] = true
    self.work.push(location)
  }
}

///|
fn Dae2Graph::solve(self : Dae2Graph) -> Unit {
  // Each location enters the queue once, so convergence is bounded by the
  // graph size, including recursive call and result dependencies.
  while self.cursor < self.work.length() {
    let consumer = self.work[self.cursor]
    self.cursor = self.cursor + 1
    let mut edge = self.first_edge[consumer]
    while edge >= 0 {
      self.observe(self.edges[edge])
      edge = self.next_edge[edge]
    }
  }
}

///|
priv struct Dae2Function {
  params : Array[@lib.ValType]
  results : Array[@lib.ValType]
  param_locations : Array[Int32]
  result_location : Int32
  mut node_location_base : Int32
  mut node_count : Int32
  mut raw_analysis : Bool
  mut raw_write_locations : Array[(Int32, Int32)]?
  call_infos : Array[Int32]
  mut call_infos_ready : Bool
  control_type_infos : Array[Int32]
}

///|
fn Dae2Function::new(
  graph : Dae2Graph,
  params : Array[@lib.ValType],
  results : Array[@lib.ValType],
) -> Dae2Function {
  {
    params,
    results,
    param_locations: params.map(fn(_) { graph.location() }),
    result_location: graph.location(),
    node_location_base: 0,
    node_count: 0,
    raw_analysis: false,
    raw_write_locations: None,
    call_infos: [],
    call_infos_ready: false,
    control_type_infos: [],
  }
}

///|
fn Dae2Function::assign_node_locations(
  self : Dae2Function,
  graph : Dae2Graph,
  count : Int32,
) -> Unit {
  // Allocation is contiguous in storage-node order. The immutable analysis
  // snapshot keeps only this range; mutation relifts must preserve its count.
  self.node_location_base = graph.locations(count)
  self.node_count = count
}

///|
fn dae2_node_location(info : Dae2Function, node : Int32) -> Int32 {
  if node >= 0 && node < info.node_count {
    info.node_location_base + node
  } else {
    -1
  }
}

///|
fn dae2_observe_branch_target(
  graph : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
  target : @ir.LabelId,
) -> Unit {
  if target == @ir.HOT_IMPLICIT_FUNCTION_LABEL {
    graph.observe(info.result_location)
    return
  }
  if !@ir.hot_label_is_live(func, target) {
    abort("DAE2 branch target is not a live ordinary label")
  }
  graph.observe(dae2_node_location(info, @ir.hot_label_get(func, target).owner))
}

///|
fn dae2_removable_node(func : @ir.HotFunc, node : Int32) -> Bool {
  let op = @ir.hot_node_op(func, node)
  // Local writes require DAE2's reaching-definition liveness proof. They
  // are not generally discardable when another pass proves a value constant.
  op is @ir.LocalSet ||
  op is @ir.LocalTee ||
  pass_can_discard_unused_value(func, node)
}

///|
#valtype
priv struct Dae2WriteFacts {
  sole : Array[Int32]?
  opaque : Bool
}

///|
fn Dae2WriteFacts::new(sole : Array[Int32]?, opaque : Bool) -> Dae2WriteFacts {
  { sole, opaque, }
}

///|
// Immutable per-analysis facts. Allocate a local row only on an actual writer;
// -1 means unwritten, -2 means multiple live writers, otherwise the sole node.
// Full analysis must finish the census even across opaque controls. Standalone
// entry admission may retain its historical first-opaque early return.
fn dae2_scan_write_facts(
  func : @ir.HotFunc,
  early_opaque~ : Bool = false,
  visits~ : Array[Int32]? = None,
) -> Dae2WriteFacts {
  let mut sole : Array[Int32]? = None
  let mut opaque = false
  for node in 0..<@ir.hot_node_count(func) {
    if visits is Some(visits) {
      visits[0] += 1
    }
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let op = @ir.hot_node_op(func, node)
    if op is @ir.Try || op is @ir.TryTable || op is @ir.Continuation {
      opaque = true
      if early_opaque {
        return Dae2WriteFacts::new(None, true)
      }
    }
    if op is @ir.LocalSet || op is @ir.LocalTee {
      if sole is None {
        sole = Some(Array::make(@ir.hot_local_count(func), -1))
      }
      let row = sole.unwrap()
      let local = @ir.hot_node_get(func, node).imm0
      row[local] = if row[local] == -1 { node } else { -2 }
    }
  }
  Dae2WriteFacts::new(sole, opaque)
}

///|
fn dae2_entry_read_sources(
  func : @ir.HotFunc,
  visits~ : Array[Int32]? = None,
  interval_builds~ : Array[Int32]? = None,
  known_writes~ : Array[Int32]? = None,
  opaque~ : Bool = false,
  write_census_visits~ : Array[Int32]? = None,
  entry_row_slots~ : Array[Int32]? = None,
) -> Array[Int32]? {
  if opaque {
    return None
  }
  let mut has_root_write = false
  for root in @ir.hot_root_span(func) {
    if root >= 0 && @ir.hot_node_op(func, root) is @ir.LocalSet {
      has_root_write = true
      break
    }
  }
  if !has_root_write {
    return None
  }
  let writes = match known_writes {
    Some(writes) => writes
    None => {
      let facts = dae2_scan_write_facts(
        func,
        early_opaque=true,
        visits=write_census_visits,
      )
      if facts.opaque {
        return None
      }
      guard facts.sole is Some(writes) else { return None }
      writes
    }
  }
  let mut entry_writes : Array[Int32]? = None
  let mut single_local = -1
  let mut single_write = -1
  let mut admitted = 0
  for root in @ir.hot_root_span(func) {
    if root < 0 || !(@ir.hot_node_op(func, root) is @ir.LocalSet) {
      continue
    }
    let local = @ir.hot_node_get(func, root).imm0
    if writes[local] != root {
      continue
    }
    if admitted == 0 {
      single_local = local
      single_write = root
      admitted = 1
    } else if local != single_local {
      let row = match entry_writes {
        Some(row) => row
        None => {
          if entry_row_slots is Some(slots) {
            slots[0] += writes.length()
          }
          let row = Array::make(writes.length(), -1)
          row[single_local] = single_write
          entry_writes = Some(row)
          row
        }
      }
      if row[local] < 0 {
        admitted += 1
      }
      row[local] = root
    }
  }
  if admitted == 0 {
    return None
  }
  if admitted == 1 {
    return dae2_entry_single_read_sources(
      func,
      single_local,
      single_write,
      visits~,
    )
  }
  let entry_writes = entry_writes.unwrap()
  match interval_builds {
    Some(count) => count[0] += 1
    None => ()
  }
  let count = @ir.hot_node_count(func)
  let root_count = @ir.hot_root_count(func)
  let write_roots = Array::make(writes.length(), -1)
  let sources = Array::make(count, -2)
  let first_roots = Array::make(count, root_count)
  let postorder : Array[Int32] = []
  let stack : Array[Int32] = []
  // First obtain a unique DAG postorder. Sources doubles as the discovery
  // marker and then the greatest reaching root ordinal, avoiding a seen array.
  for root in @ir.hot_root_span(func) {
    if root < 0 {
      continue
    }
    stack.push(root)
    while !stack.is_empty() {
      let item = stack.pop().unwrap()
      if item >= 0 {
        if !@ir.hot_node_is_live(func, item) {
          continue
        }
        if sources[item] != -2 {
          continue
        }
        sources[item] = -1
        match visits {
          Some(count) => count[0] += 1
          None => ()
        }
        let data = @ir.hot_node_get(func, item)
        // This checked header bounds every slot; the source walk does not edit HOT.
        stack.push(-item - 1)
        for slot = data.child_count - 1; slot >= 0; slot = slot - 1 {
          let child = func.children[data.child_base + slot]
          if child >= 0 {
            stack.push(child)
          }
        }
      } else {
        postorder.push(-item - 1)
      }
    }
  }
  for ordinal in 0..<root_count {
    let root = @ir.hot_root_get(func, ordinal)
    if root < 0 || !@ir.hot_node_is_live(func, root) {
      continue
    }
    first_roots[root] = first_roots[root].min(ordinal)
    sources[root] = sources[root].max(ordinal)
    let data = @ir.hot_node_get(func, root)
    if data.op is @ir.LocalSet && entry_writes[data.imm0] == root {
      // Repeated roots also execute the write repeatedly and need full flow.
      if write_roots[data.imm0] >= 0 {
        return None
      }
      write_roots[data.imm0] = ordinal
    }
  }
  // Parents precede all children in reverse postorder, so each edge propagates
  // its root interval once even when shared across many unrelated writes.
  for position = postorder.length() - 1; position >= 0; position = position - 1 {
    let node = postorder[position]
    let data = @ir.hot_node_get(func, node)
    match visits {
      Some(count) => count[0] += 1
      None => ()
    }
    if data.op is @ir.LocalSet && entry_writes[data.imm0] == node {
      let ordinal = write_roots[data.imm0]
      if first_roots[node] != ordinal || sources[node] != ordinal {
        // A write shared below another root is not an unconditional root-only
        // definition. Preserve the complete LocalGraph fallback in that case.
        return None
      }
    }
    for slot in 0..<data.child_count {
      let child = func.children[data.child_base + slot]
      if child >= 0 && @ir.hot_node_is_live(func, child) {
        first_roots[child] = first_roots[child].min(first_roots[node])
        sources[child] = sources[child].max(sources[node])
      }
    }
    // Every parent has already contributed to this node's interval, and its
    // children now have that interval too. No later DAG node can read this
    // slot as a parent's interval, so finalize it without another arena scan.
    // Detached nodes retain their initialized unknown (-2) source slots.
    let last_root = sources[node]
    sources[node] = if data.op is @ir.LocalGet &&
      entry_writes[data.imm0] >= 0 &&
      last_root >= 0 {
      let write_root = write_roots[data.imm0]
      if last_root <= write_root {
        // The write root's operands execute before its local.set completes.
        -1
      } else if first_roots[node] > write_root {
        entry_writes[data.imm0]
      } else {
        // A shared read reached both before and after the write is unknown.
        -3
      }
    } else {
      -2
    }
  }
  Some(sources)
}

///|
// With one admitted write there are only two visit epochs. This retains linear
// DAG work while avoiding interval/postorder scratch on the common small path.
fn dae2_entry_single_read_sources(
  func : @ir.HotFunc,
  local : Int32,
  write : Int32,
  visits~ : Array[Int32]? = None,
) -> Array[Int32]? {
  let mut completed = false
  let sources = Array::make(@ir.hot_node_count(func), -2)
  let stack : Array[Int32] = []
  let mut epoch = 0
  for root in @ir.hot_root_span(func) {
    if root < 0 {
      continue
    }
    stack.push(root)
    while !stack.is_empty() {
      let item = stack.pop().unwrap()
      if item >= 0 {
        if !@ir.hot_node_is_live(func, item) {
          continue
        }
        match visits {
          Some(count) => count[0] += 1
          None => ()
        }
        let data = @ir.hot_node_get(func, item)
        if data.op is @ir.LocalSet && write == item && item != root {
          return None
        }
        if !(data.op is @ir.LocalGet) {
          // HOT shares value subtrees. Visit each non-read once between root
          // writes instead of expanding its tree once per incoming use. Read
          // sources occupy their own nodes; other source slots cache the epoch.
          let marker = -4 - epoch
          if sources[item] == marker {
            continue
          }
          sources[item] = marker
        }
        stack.push(-item - 1)
        for slot = data.child_count - 1; slot >= 0; slot = slot - 1 {
          let child = @ir.hot_child_get(func, item, slot)
          if child >= 0 {
            stack.push(child)
          }
        }
      } else {
        let node = -item - 1
        let data = @ir.hot_node_get(func, node)
        if data.op is @ir.LocalGet && data.imm0 == local {
          let source = if completed { write } else { -1 }
          sources[node] = if sources[node] == -2 || sources[node] == source {
            source
          } else {
            -3
          }
        } else if data.op is @ir.LocalSet && write == node {
          // A sole top-level write dominates later roots. A write also shared
          // under another root does not have that proof. Revisited reads that
          // span the write remain unknown, preserving the complete fallback.
          if node != root {
            return None
          }
          if completed {
            return None
          }
          completed = true
          epoch += 1
        }
      }
    }
  }
  Some(sources)
}

///|
fn dae2_analyze_function(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  func : @ir.HotFunc,
  local_graph_builds~ : Array[Int32]? = None,
  fallback_write_builds~ : Array[Int32]? = None,
  analysis_child_snapshots~ : Array[Int32]? = None,
  intrinsic_imports~ : Array[Bool]? = None,
  write_census_visits~ : Array[Int32]? = None,
  writer_cut~ : Dae2WriterCut? = None,
) -> Unit {
  // This phase changes only the dependency graph; HOT child slots stay stable.
  ignore(analysis_child_snapshots)
  let info = infos[index]
  let writer_cut = match writer_cut {
    Some(cut) if cut.revision == @ir.hot_revision_current(func) => Some(cut)
    _ => None
  }
  let mut cut_active = false
  let mut local_flow : @ir.HotLocalReadSources? = None
  let mut fallback_writes : Array[Array[Int32]]? = None
  let mut fallback_sources : Array[Int32]? = None
  let mut written_locals : Array[Int32]? = None
  let mut writes_scanned = false
  let mut opaque_writes = false
  let mut entry_read_sources : Array[Int32]? = None
  let mut entry_source_attempted = false
  for node = 0; node < info.node_count; node = node + 1 {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let value = info.node_location_base + node
    let data = @ir.hot_node_get(func, node)
    // Bounded child loops reuse this checked, immutable header. Fixed/callee
    // argument accesses retain the general getter and its slot checks.
    match data.op {
      @ir.LocalGet => {
        if cut_active {
          match writer_cut {
            Some(cut) => {
              if data.imm0 >= cut.source_local_count {
                let (_, write) = cut.captures[data.imm0 - cut.source_local_count]
                graph.edge(value, dae2_node_location(info, write))
              }
              continue
            }
            None => ()
          }
        }
        if !writes_scanned {
          let facts = dae2_scan_write_facts(func, visits=write_census_visits)
          written_locals = facts.sole
          opaque_writes = facts.opaque
          writes_scanned = true
        }
        let written = written_locals
        // With no write anywhere in this body, every read has its entry value,
        // including reads in control regions not represented by LocalGraph.
        // Default-initialized body locals need no parameter dependency.
        if written is None || written.unwrap()[data.imm0] == -1 {
          if data.imm0 < info.params.length() {
            graph.edge(value, info.param_locations[data.imm0])
          }
          continue
        }
        if !entry_source_attempted {
          entry_read_sources = dae2_entry_read_sources(
            func,
            known_writes=written,
            opaque=opaque_writes,
            write_census_visits~,
          )
          entry_source_attempted = true
        }
        match entry_read_sources {
          Some(sources) if sources[node] >= -1 => {
            let source = sources[node]
            if source >= 0 {
              graph.edge(value, dae2_node_location(info, source))
            } else if data.imm0 < info.params.length() {
              graph.edge(value, info.param_locations[data.imm0])
            }
            continue
          }
          _ => ()
        }
        // Preserve the old no-write and entry-source fast paths. Activate
        // only at the exact point where this read would build the full CFG.
        match writer_cut {
          Some(cut) => {
            match local_graph_builds {
              Some(count) if count.length() > 1 => count[1] += 1
              _ => ()
            }
            @ir.hot_verify_all_or_abort(func)
            cut.seed(graph, info)
            cut_active = true
            if data.imm0 >= cut.source_local_count {
              let (_, write) = cut.captures[data.imm0 - cut.source_local_count]
              graph.edge(value, dae2_node_location(info, write))
            }
            continue
          }
          None => ()
        }
        let locals = match local_flow {
          Some(locals) => locals
          None => {
            match local_graph_builds {
              Some(count) => count[0] += 1
              None => ()
            }
            let selected_gets = dae2_unresolved_flow_reads(
              func,
              written.unwrap(),
              entry_read_sources,
            )
            let locals = @ir.local_graph_build_read_sources(
              func,
              // A stacked read can precede a later control root even when
              // its consuming parent follows that root. Expand operands so
              // both entry reads and earlier writes keep their actual sources.
              @ir.cfg_build(func, expand_operand_control=true),
              selected_gets=Some(selected_gets),
            )
            local_flow = Some(locals)
            locals
          }
        }
        let source_count = @ir.local_read_source_count_for_get(locals, node)
        // A get inside control not represented by LocalGraph has no recorded
        // sources. That is unknown, not proof that its entry value is unused.
        if source_count == 0 {
          let writes = match fallback_writes {
            Some(writes) => writes
            None => {
              match fallback_write_builds {
                Some(count) => count[0] += 1
                None => ()
              }
              let writes : Array[Array[Int32]] = Array::makei(
                @ir.hot_local_count(func),
                fn(_) { [] },
              )
              // Unrepresented reads retain every possible write, including
              // nodes outside the represented CFG, exactly as before.
              for write = 0; write < info.node_count; write = write + 1 {
                let data = @ir.hot_node_get(func, write)
                if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
                  writes[data.imm0].push(write)
                }
              }
              fallback_writes = Some(writes)
              fallback_sources = Some(
                Array::make(@ir.hot_local_count(func), -1),
              )
              writes
            }
          }
          let sources = fallback_sources.unwrap()
          let mut source = sources[data.imm0]
          if source < 0 {
            // All unknown reads of this local have the same conservative
            // source set. Share its fanout so R reads and W writes need R + W
            // edges, while observing a read retains every possible definition.
            source = graph.location()
            sources[data.imm0] = source
            if data.imm0 < info.params.length() {
              graph.edge(source, info.param_locations[data.imm0])
            }
            for write in writes[data.imm0] {
              graph.edge(source, dae2_node_location(info, write))
            }
          }
          graph.edge(value, source)
        }
        for source_index in 0..<source_count {
          let source = @ir.local_read_source_value_for_get(
            locals, node, source_index,
          )
          if source.is_entry {
            if source.index < info.params.length() {
              graph.edge(value, info.param_locations[source.index])
            }
          } else {
            graph.edge(value, dae2_node_location(info, source.index))
          }
        }
      }
      @ir.Call
      | @ir.ReturnCall
      | @ir.CallIndirect
      | @ir.CallRef
      | @ir.ReturnCallIndirect
      | @ir.ReturnCallRef => {
        let callee_index = dae2_call_info_index_from_data(
          type_infos, func, data,
        )
        if !info.call_infos_ready {
          info.call_infos.push(callee_index)
        }
        if data.op is @ir.Call {
          match intrinsic_imports {
            Some(imports) if imports[data.imm0] && data.child_count > 0 => {
              let target = @ir.hot_node_get(
                func,
                @ir.hot_child_get(func, node, data.child_count - 1),
              )
              if target.op is @ir.RefFunc {
                let target_info = infos[target.imm0]
                for location in target_info.param_locations {
                  graph.observe(location)
                }
                graph.observe(target_info.result_location)
              }
            }
            _ => ()
          }
        }
        let callee = infos[callee_index]
        let indirect = !(data.op is @ir.Call || data.op is @ir.ReturnCall)
        for arg = 0; arg < callee.params.length(); arg = arg + 1 {
          graph.edge(
            callee.param_locations[arg],
            dae2_node_location(info, @ir.hot_child_get(func, node, arg)),
          )
        }
        if indirect {
          graph.observe(
            dae2_node_location(
              info,
              @ir.hot_child_get(func, node, data.child_count - 1),
            ),
          )
        }
        if data.op is @ir.ReturnCall ||
          data.op is @ir.ReturnCallIndirect ||
          data.op is @ir.ReturnCallRef {
          graph.edge(info.result_location, callee.result_location)
          graph.edge(callee.result_location, info.result_location)
        } else {
          graph.edge(value, callee.result_location)
        }
      }
      @ir.Return =>
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = func.children[data.child_base + slot]
          graph.edge(info.result_location, dae2_node_location(info, child))
        }
      @ir.Drop => ()
      @ir.Block | @ir.Loop =>
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = func.children[data.child_base + slot]
          if child >= 0 && @ir.hot_node_result_arity(func, child) > 0 {
            graph.edge(value, dae2_node_location(info, child))
          }
        }
      @ir.If => {
        graph.observe(
          dae2_node_location(info, @ir.hot_child_get(func, node, 0)),
        )
        for arm = 1; arm < data.child_count; arm = arm + 1 {
          graph.edge(
            value,
            dae2_node_location(info, func.children[data.child_base + arm]),
          )
        }
      }
      @ir.TryTable => {
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = func.children[data.child_base + slot]
          graph.observe(dae2_node_location(info, child))
        }
        for arm in @ir.hot_catch_info_get(func, data.imm1).catches {
          let label = match arm {
            @ir.HotCatchArm::CatchArm(_, label)
            | @ir.HotCatchArm::CatchRefArm(_, label)
            | @ir.HotCatchArm::CatchAllArm(label)
            | @ir.HotCatchArm::CatchAllRefArm(label) => label
          }
          dae2_observe_branch_target(graph, info, func, label)
        }
      }
      @ir.Continuation => {
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = func.children[data.child_base + slot]
          graph.observe(dae2_node_location(info, child))
        }
        for label in @ir.hot_continuation_targets(func, node) {
          dae2_observe_branch_target(graph, info, func, label)
        }
      }
      @ir.Br
      | @ir.BrIf
      | @ir.BrTable
      | @ir.BrOnNull
      | @ir.BrOnNonNull
      | @ir.BrOnCast
      | @ir.BrOnCastFail => {
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = func.children[data.child_base + slot]
          graph.observe(dae2_node_location(info, child))
        }
        // Branch payload types stay fixed. A result-bearing target therefore
        // keeps its fallthrough value as well as its incoming branch values.
        for label in @ir.hot_branch_table_targets_for_node(func, node) {
          dae2_observe_branch_target(graph, info, func, label)
        }
        match @ir.hot_branch_target(func, node) {
          Some(label) => dae2_observe_branch_target(graph, info, func, label)
          None => ()
        }
      }
      _ =>
        if data.child_count > 0 {
          let removable = dae2_removable_node(func, node)
          for slot = 0; slot < data.child_count; slot = slot + 1 {
            let child = func.children[data.child_base + slot]
            let source = dae2_node_location(info, child)
            if removable {
              graph.edge(value, source)
            } else {
              graph.observe(source)
            }
          }
        }
    }
  }
  for slot = 0; slot < @ir.hot_root_count(func); slot = slot + 1 {
    let root = @ir.hot_root_get(func, slot)
    if root >= 0 && @ir.hot_node_result_arity(func, root) > 0 {
      graph.edge(info.result_location, dae2_node_location(info, root))
    }
  }
}

///|
fn dae2_discard(func : @ir.HotFunc, node : Int32) -> Int32 {
  if @ir.hot_node_result_arity(func, node) > 0 {
    @ir.hot_build_drop(func, node)
  } else {
    node
  }
}

///|
fn dae2_void_sequence(func : @ir.HotFunc, nodes : Array[Int32]) -> Int32 {
  let kept = nodes.filter(fn(id) { !(@ir.hot_node_op(func, id) is @ir.Nop) })
  match kept {
    [] => @ir.hot_build_nop(func)
    [node] => node
    _ => @ir.hot_build_block(func, @lib.BlockType::void_(), kept)
  }
}

///|
fn dae2_replace_region_entry_uses(
  func : @ir.HotFunc,
  region : Int32,
  original : Int32,
  replacements : Array[Int32],
) -> Unit {
  let node_limit = @ir.hot_node_count(func)
  let visited = Array::make(node_limit, false)
  let pending = [region]
  while !pending.is_empty() {
    let node = pending.pop().unwrap()
    if node < 0 || node >= node_limit || visited[node] {
      continue
    }
    visited[node] = true
    let children = @ir.hot_child_span(func, node)
    let mut changed = false
    let mut slot = 0
    while slot < children.length() {
      if children[slot] == original {
        let mut end = slot + 1
        while end < children.length() && children[end] == original {
          end += 1
        }
        if replacements.length() == 1 {
          for lane in slot..<end {
            children[lane] = replacements[0]
          }
        } else if end - slot == replacements.length() {
          for lane in 0..<replacements.length() {
            children[slot + lane] = replacements[lane]
          }
        } else {
          abort("dae2 typed entry tuple use does not match its captured lanes")
        }
        changed = true
        slot = end
      } else {
        let child = children[slot]
        if child >= 0 && child < node_limit {
          pending.push(child)
        }
        slot += 1
      }
    }
    if changed {
      ignore(@ir.hot_replace_child_span(func, node, children))
    }
  }
}

///|
// Keep generic leaf rewriting scalar. Calls and structural controls still
// require their family/result updates in the complete rewrite below.
#inline
fn dae2_rewrite_leaf(
  func : @ir.HotFunc,
  node : Int32,
  data : @ir.HotNode,
  used : Bool,
) -> Int32 {
  if data.child_count != 0 {
    return -1
  }
  match data.op {
    @ir.Call
    | @ir.ReturnCall
    | @ir.CallIndirect
    | @ir.CallRef
    | @ir.ReturnCallIndirect
    | @ir.ReturnCallRef
    | @ir.Return
    | @ir.Block
    | @ir.Loop
    | @ir.If
    | @ir.Drop => -1
    _ =>
      if used {
        node
      } else if dae2_removable_node(func, node) {
        @ir.hot_build_nop(func)
      } else {
        dae2_discard(func, node)
      }
  }
}

///|
// Descendant edits allocate new child spans and cannot change this parent's
// slots in a valid HOT DAG. Read slots directly until a replacement is needed.
#inline
fn dae2_rewrite_children(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  func : @ir.HotFunc,
  node : Int32,
  memo : Array[Int32],
  old_arities : Array[Int32],
  lower_state : HotPipelineLowerState,
  type_infos : Array[Int32],
) -> Array[Int32]? {
  let count = @ir.hot_child_count(func, node)
  let typed_if_entries = if @ir.hot_node_op(func, node) is @ir.If && count > 3 {
    count - 3
  } else {
    0
  }
  let mut changed : Array[Int32]? = None
  for step in 0..<count {
    // Typed-if entries execute before the condition and can be shared with
    // their arm placeholders. Rewrite them first so a removed effect remains
    // at the entry instead of becoming conditional through memo ownership.
    let slot = if typed_if_entries > 0 {
      if step < typed_if_entries {
        step + 3
      } else {
        step - typed_if_entries
      }
    } else {
      step
    }
    let original = @ir.hot_child_get(func, node, slot)
    let child = dae2_rewrite_node(
      graph, infos, index, func, original, memo, old_arities, lower_state, type_infos,
    )
    if child != original {
      let children = match changed {
        Some(children) => children
        None => {
          let children = @ir.hot_child_span(func, node)
          changed = Some(children)
          children
        }
      }
      children[slot] = child
    }
  }
  changed
}

///|
fn dae2_rewrite_node(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  func : @ir.HotFunc,
  node : Int32,
  memo : Array[Int32],
  old_arities : Array[Int32],
  lower_state : HotPipelineLowerState,
  type_infos : Array[Int32],
) -> Int32 {
  if node < 0 {
    return node
  }
  if memo[node] >= 0 {
    // A lifted stack producer may be referenced once per result lane. Once
    // its result disappears, those references must not repeat its effects.
    if old_arities[node] > 0 && @ir.hot_node_result_arity(func, memo[node]) == 0 {
      return @ir.hot_build_nop(func)
    }
    return memo[node]
  }
  let info = infos[index]
  let data = @ir.hot_node_get(func, node)
  let used = graph.used[info.node_location_base + node]
  let leaf = dae2_rewrite_leaf(func, node, data, used)
  if leaf >= 0 {
    memo[node] = leaf
    return leaf
  }
  let removable = dae2_removable_node(func, node)
  let changed_children = dae2_rewrite_children(
    graph, infos, index, func, node, memo, old_arities, lower_state, type_infos,
  )
  if used &&
    changed_children is None &&
    (data.op is @ir.Block || data.op is @ir.Loop || data.op is @ir.If) {
    // Descendants have already been rewritten, including changes made in
    // place. A live control keeps its result type and unchanged child IDs;
    // copying and comparing the same span cannot add another transformation.
    memo[node] = node
    return node
  }
  if changed_children is None &&
    !(data.op is @ir.Call ||
    data.op is @ir.ReturnCall ||
    data.op is @ir.CallIndirect ||
    data.op is @ir.CallRef ||
    data.op is @ir.ReturnCallIndirect ||
    data.op is @ir.ReturnCallRef ||
    data.op is @ir.Return ||
    data.op is @ir.Block ||
    data.op is @ir.Loop ||
    data.op is @ir.If ||
    data.op is @ir.Drop) &&
    (used || !removable) {
    let replacement = if used { node } else { dae2_discard(func, node) }
    memo[node] = replacement
    return replacement
  }
  let children = match changed_children {
    Some(children) => children
    None => @ir.hot_child_span(func, node)
  }
  let replacement = match data.op {
    @ir.Call
    | @ir.ReturnCall
    | @ir.CallIndirect
    | @ir.CallRef
    | @ir.ReturnCallIndirect
    | @ir.ReturnCallRef => {
      let callee = dae2_call_info(infos, type_infos, func, node)
      let old_children = @ir.hot_child_span(func, node)
      let indirect = !(data.op is @ir.Call || data.op is @ir.ReturnCall)
      let tail = data.op is @ir.ReturnCall ||
        data.op is @ir.ReturnCallIndirect ||
        data.op is @ir.ReturnCallRef
      let args : Array[Int32] = []
      let prefix : Array[Int32] = []
      let removed = callee.param_locations.any(fn(loc) { !graph.used[loc] })
      let mut arg = 0
      while arg < callee.params.length() {
        let producer = old_children[arg]
        let mut end = arg + 1
        while end < callee.params.length() && old_children[end] == producer {
          end += 1
        }
        if removed &&
          end - arg > 1 &&
          @ir.hot_node_result_arity(func, children[arg]) > 1 {
          // The stack supplies tuple lanes in order, but consumes them from
          // the top. Capture all lanes before selecting kept arguments.
          let slots = Array::make(end - arg, -1)
          for lane = end - 1; lane >= arg; lane = lane - 1 {
            let scratch = @ir.hot_append_body_local(func, callee.params[lane])
            slots[lane - arg] = scratch
            prefix.push(@ir.hot_build_local_set(func, scratch, children[lane]))
          }
          for lane = arg; lane < end; lane = lane + 1 {
            if graph.used[callee.param_locations[lane]] {
              args.push(@ir.hot_build_local_get(func, slots[lane - arg]))
            }
          }
          arg = end
          continue
        }
        if graph.used[callee.param_locations[arg]] {
          if removed {
            // Localize kept arguments so removed arguments retain their
            // position relative to every kept argument's observable effects.
            let scratch_type = match
              @ir.hot_type_results(func, @ir.hot_node_type(func, children[arg])) {
              [value_type] => value_type
              _ => callee.params[arg]
            }
            let scratch = @ir.hot_append_body_local(func, scratch_type)
            prefix.push(@ir.hot_build_local_set(func, scratch, children[arg]))
            args.push(@ir.hot_build_local_get(func, scratch))
          } else {
            args.push(children[arg])
          }
        } else {
          prefix.push(dae2_discard(func, children[arg]))
        }
        arg += 1
      }
      if indirect {
        args.push(children[children.length() - 1])
      }
      if !tail && !graph.used[callee.result_location] {
        @ir.hot_replace_node(
          func,
          node,
          @ir.hot_make_simple_node(
            data.op,
            @ir.hot_type_void(func),
            data.flags,
            data.imm0,
            data.imm1,
            [],
          ),
        )
      }
      ignore(dae2_replace_children_if_changed(func, node, args))
      let call = if !used && !tail { dae2_discard(func, node) } else { node }
      let prefix = prefix.filter(fn(id) {
        !(@ir.hot_node_op(func, id) is @ir.Nop)
      })
      if prefix.is_empty() {
        call
      } else {
        prefix.push(call)
        let result_types = @ir.hot_type_results(
          func,
          @ir.hot_node_type(func, call),
        )
        let replacement = if result_types.is_empty() {
          dae2_void_sequence(func, prefix)
        } else {
          // Intern a resolved signature to retain multi-value calls.
          let block_type = match result_types {
            [value_type] => @lib.BlockType::val_type(value_type)
            _ =>
              @lib.BlockType::type_idx(
                run_hot_pipeline_lower_intern_block_result_type_idx(
                  lower_state, result_types,
                ),
              )
          }
          @ir.hot_build_resolved_block(
            func,
            block_type,
            [],
            result_types,
            prefix,
          )
        }
        // The equivalent wrapper retains argument and call effects inside its
        // region. Its fresh order must not let a later root's carried value
        // cross the original call position during lowering.
        @ir.hot_preserve_replacement_position(func, replacement, node)
        replacement
      }
    }
    @ir.Return =>
      if graph.used[info.result_location] {
        ignore(dae2_replace_children_if_changed(func, node, children))
        node
      } else {
        let parts = children.map(fn(child) { dae2_discard(func, child) })
        ignore(dae2_replace_children_if_changed(func, node, []))
        parts.push(node)
        dae2_void_sequence(func, parts)
      }
    @ir.Block | @ir.Loop | @ir.If => {
      let entry_offset = if data.op is @ir.If { 3 } else { 0 }
      let entry_count = if data.op is @ir.Block && data.imm1 > 0 {
        data.imm1
      } else if data.op is @ir.If {
        match @ir.hot_type_get(func, data.ty) {
          @ir.BlockResultResolved(_, params, _) => params.length()
          _ => 0
        }
      } else {
        0
      }
      let entry_params = if entry_count == 0 {
        []
      } else {
        match @ir.hot_type_get(func, data.ty) {
          @ir.BlockResultResolved(_, params, _) => params
          _ => abort("dae2 typed entry prefix requires resolved parameters")
        }
      }
      if !used {
        let next_type = if entry_count == 0 {
          @ir.hot_type_void(func)
        } else {
          let kept : Array[@lib.ValType] = []
          for slot in 0..<entry_count {
            if @ir.hot_node_result_arity(func, children[entry_offset + slot]) >
              0 {
              kept.push(entry_params[slot])
            }
          }
          let block_type = if kept.is_empty() {
            @lib.BlockType::void_()
          } else {
            let types = lower_state.next_type_sec.unwrap()
            let type_idx = match
              dae_find_equivalent_simple_func_type(types, kept, []) {
              Some(index) => index
              None => {
                let (types, index) = dae_append_new_func_type(types, kept, [])
                lower_state.next_type_sec = Some(types)
                lower_state.type_sec_changed = true
                index
              }
            }
            @lib.BlockType::type_idx(type_idx)
          }
          @ir.hot_type_intern_resolved_block_result(func, block_type, kept, [])
        }
        @ir.hot_control_result_type_set(func, node, next_type)
      }
      let next = if data.op is @ir.If && !used && entry_count > 0 {
        let next : Array[Int32] = [children[0], children[1], children[2]]
        let mut has_removed_effect = false
        for slot in 0..<entry_count {
          let entry = children[entry_offset + slot]
          if @ir.hot_node_result_arity(func, entry) == 0 &&
            !(@ir.hot_node_op(func, entry) is @ir.Nop) {
            has_removed_effect = true
          }
        }
        if has_removed_effect {
          // Typed-if entries execute before the condition. If one dead entry
          // still traps or has effects, capture each surviving producer in an
          // entry block. Attach removed effects to the next surviving entry,
          // or to the condition when they trail all live entries. The control
          // input order then preserves the original entry/condition order.
          let mut slot = 0
          let mut pending : Array[Int32] = []
          while slot < entry_count {
            let original = @ir.hot_child_get(func, node, entry_offset + slot)
            let mut end = slot + 1
            while end < entry_count &&
                  @ir.hot_child_get(func, node, entry_offset + end) == original {
              end += 1
            }
            let first = children[entry_offset + slot]
            if @ir.hot_node_result_arity(func, first) > 0 {
              let locals = Array::make(end - slot, -1)
              let capture_parts = pending
              pending = []
              for lane = end - 1; lane >= slot; lane = lane - 1 {
                let scratch = @ir.hot_append_body_local(
                  func,
                  entry_params[lane],
                )
                locals[lane - slot] = scratch
                capture_parts.push(
                  @ir.hot_build_local_set_from_value(
                    func,
                    scratch,
                    children[entry_offset + lane],
                  ),
                )
              }
              let result_types : Array[@lib.ValType] = []
              for lane = slot; lane < end; lane = lane + 1 {
                result_types.push(entry_params[lane])
                capture_parts.push(
                  @ir.hot_build_local_get(func, locals[lane - slot]),
                )
              }
              let capture_type = match result_types {
                [value_type] => @lib.BlockType::val_type(value_type)
                _ =>
                  @lib.BlockType::type_idx(
                    run_hot_pipeline_lower_intern_block_result_type_idx(
                      lower_state, result_types,
                    ),
                  )
              }
              let capture = @ir.hot_build_resolved_block(
                func,
                capture_type,
                [],
                result_types,
                capture_parts,
              )
              @ir.hot_preserve_replacement_position(func, capture, original)
              for _ in slot..<end {
                next.push(capture)
              }
              let region_replacements = Array::make(end - slot, capture)
              for region in [next[1], next[2]] {
                dae2_replace_region_entry_uses(
                  func, region, original, region_replacements,
                )
              }
            } else {
              for lane = slot; lane < end; lane = lane + 1 {
                let entry = children[entry_offset + lane]
                if !(@ir.hot_node_op(func, entry) is @ir.Nop) {
                  pending.push(entry)
                }
              }
            }
            slot = end
          }
          if !pending.is_empty() {
            pending.push(children[0])
            let condition = @ir.hot_build_resolved_block(
              func,
              @lib.BlockType::val_type(@lib.ValType::i32()),
              [],
              [@lib.ValType::i32()],
              pending,
            )
            @ir.hot_preserve_replacement_position(func, condition, children[0])
            next[0] = condition
          }
        } else {
          for slot in 0..<entry_count {
            let entry = children[entry_offset + slot]
            if @ir.hot_node_result_arity(func, entry) > 0 {
              next.push(entry)
            }
          }
        }
        next
      } else if data.op is @ir.If || used {
        children
      } else {
        children.mapi(fn(slot, child) {
          // Entry slots evaluate before the frame and seed its stack. Dropping
          // a still-needed entry here would evaluate it again in the body.
          if slot < entry_count {
            child
          } else {
            dae2_discard(func, child)
          }
        })
      }
      ignore(dae2_replace_children_if_changed(func, node, next))
      node
    }
    @ir.Drop =>
      dae2_void_sequence(
        func,
        children.map(fn(child) { dae2_discard(func, child) }),
      )
    _ if removable && !used =>
      dae2_void_sequence(
        func,
        children.map(fn(child) { dae2_discard(func, child) }),
      )
    _ => {
      ignore(dae2_replace_children_if_changed(func, node, children))
      if used {
        node
      } else {
        dae2_discard(func, node)
      }
    }
  }
  memo[node] = replacement
  replacement
}

///|
fn dae2_run_module_pass(
  mod_ : @lib.Module,
  closed_world : Bool,
  cleanup_module_env_builds~ : Array[Int32]? = None,
  rewrite_lifts~ : Array[Int32]? = None,
  local_graph_builds~ : Array[Int32]? = None,
  fallback_write_builds~ : Array[Int32]? = None,
  analysis_lifts~ : Array[Int32]? = None,
  perf~ : HotPerfSession? = None,
  raw_analysis~ : Bool = true,
  raw_conditionals~ : Bool = true,
  raw_rewrite~ : Bool = true,
  raw_sparse_replay~ : Bool = true,
  stack_suffix_rewrite~ : Bool = true,
) -> Result[@lib.Module, String] {
  if pass_module_has_offset_sensitive_metadata(mod_) {
    return Ok(mod_)
  }
  let prepare_start = perf_start_timer_opt(perf, "detail:dae2:prepare")
  let original = mod_
  let mod_ = match dae2_prepare_legacy_handlers(mod_) {
    Ok(prepared) => prepared
    Err(err) => return Err(err)
  }
  let context = @ir.hot_module_context_from_module(mod_)
  // Direct Module callers can supply invalid types. Check the equal-arity
  // invariant before family locations or identity-preservation rewrites index it.
  match dae2_check_type_family_arities(mod_, context) {
    Ok(_) => ()
    Err(err) => return Err(err)
  }
  let imported = dae_imported_func_count(mod_)
  let indices = dae_collect_func_type_indices(mod_)
  let total_funcs = indices.length()
  let suffix_state = if raw_rewrite && stack_suffix_rewrite {
    Some(Dae2StackSuffixState::new(total_funcs, context~))
  } else {
    None
  }
  let graph = Dae2Graph::new()
  let infos : Array[Dae2Function] = []
  for index = 0; index < indices.length(); index = index + 1 {
    let @lib.FuncType(params, results) = match
      @ir.hot_module_resolve_func_type(
        context,
        @lib.FuncIdx::new(index.reinterpret_as_uint()),
      ) {
      Some(sig) => sig
      None => return Err("dae2: missing function signature")
    }
    infos.push(Dae2Function::new(graph, params, results))
  }
  let exposure = dae_collect_original_exposure(
    dae2_exposure_module(mod_),
    total_funcs,
    indices,
  )
  let private_elements = dae2_private_element_mask(
    mod_, context, exposure, closed_world,
  )
  let type_infos = dae2_prepare_type_locations(
    mod_,
    context,
    graph,
    infos,
    exposure,
    closed_world,
    private_elements~,
  )
  let boundary_count = graph.used.length()
  let intrinsic_imports = dae2_intrinsic_import_mask(context)
  perf_stop_timer_opt(perf, "detail:dae2:prepare", prepare_start)
  let analysis_start = perf_start_timer_opt(perf, "detail:dae2:analysis")
  let mut lift_us = 0UL
  let mut dependency_us = 0UL
  let mut admission_env : @validate.Env? = None
  // Keep only the dependency graph between functions. Each HOT body and its
  // CFG/local overlays die after this iteration; relift a body for mutation
  // only after the complete module-wide fixed point has been solved.
  for index = imported; index < total_funcs; index = index + 1 {
    let info = infos[index]
    let original_func = mod_.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(raw_body)) = original_func
    ignore(
      dae2_collect_control_type_infos(
        raw_body,
        type_infos,
        info.control_type_infos,
        call_infos=Some(info.call_infos),
        suffix_state~,
        function_index=index,
      ),
    )
    info.call_infos_ready = true
    dae2_pin_flat_observable_params(
      graph, infos, index, raw_body, indices, type_infos, exposure,
    )
    let pinned_boundary = dae2_boundary_is_pinned(
      graph, infos, index, indices, type_infos, exposure,
    )
    // Edges within fully pinned boundaries cannot change any signature. Raw
    // call/control metadata still drives rewrite admission after solving.
    // Intrinsic calls require HOT analysis to pin their literal ref.func target.
    if pinned_boundary &&
      info.control_type_infos.all(fn(family) {
        dae2_boundary_is_pinned(
          graph, infos, family, indices, type_infos, exposure,
        )
      }) &&
      info.call_infos.all(fn(callee) {
        let intrinsic = match intrinsic_imports {
          Some(mask) => callee >= 0 && callee < mask.length() && mask[callee]
          None => false
        }
        !intrinsic &&
        dae2_boundary_is_pinned(
          graph, infos, callee, indices, type_infos, exposure,
        )
      }) {
      let env = match admission_env {
        Some(env) => env
        None => {
          let env = @ir.hot_module_context_validation_env(context)
          admission_env = Some(env)
          env
        }
      }
      match
        @validate.validate_func_body_against_functype(
          env,
          @lib.FuncType::new(info.params, info.results),
          original_func,
        ) {
        Ok(_) => continue
        Err(error) => return Err("dae2: validate function \{index}: \{error}")
      }
    }
    if raw_analysis {
      let dependency_start = perf_start_timer_opt(
        perf, "detail:dae2:analysis:dependencies",
      )
      let plan = dae2_raw_dependency_plan(
        graph,
        infos,
        index,
        type_infos,
        original_func,
        intrinsic_imports,
        module_context=Some(context),
        conditionals=raw_conditionals,
      )
      dependency_us += perf_elapsed_since_start_opt(perf, dependency_start)
      match plan {
        Some(plan) => {
          let env = match admission_env {
            Some(env) => env
            None => {
              let env = @ir.hot_module_context_validation_env(context)
              admission_env = Some(env)
              env
            }
          }
          match
            @validate.validate_func_body_against_functype(
              env,
              @lib.FuncType::new(info.params, info.results),
              original_func,
            ) {
            Ok(_) => ()
            Err(error) =>
              return Err("dae2: validate function \{index}: \{error}")
          }
          plan.commit(graph)
          info.raw_analysis = true
          info.raw_write_locations = plan.write_locations
          continue
        }
        None => ()
      }
    }
    match analysis_lifts {
      Some(count) => count[0] += 1
      None => ()
    }
    let lift_start = perf_start_timer_opt(perf, "detail:dae2:analysis:lift")
    let func = match
      dae2_lift_for_analysis(
        mod_,
        context,
        index,
        write_provenance=match suffix_state {
          Some(state) if state.admissions[index] == 1 => Some(state)
          _ => None
        },
        record_local_accesses=false,
      ) {
      Ok(func) => func
      Err(err) => return Err(err)
    }
    lift_us += perf_elapsed_since_start_opt(perf, lift_start)
    info.assign_node_locations(graph, @ir.hot_node_count(func))
    let dependency_start = perf_start_timer_opt(
      perf, "detail:dae2:analysis:dependencies",
    )
    dae2_analyze_function(
      graph,
      infos,
      index,
      type_infos,
      func,
      local_graph_builds~,
      fallback_write_builds~,
      intrinsic_imports~,
    )
    dependency_us += perf_elapsed_since_start_opt(perf, dependency_start)
  }
  perf_stop_timer_opt(perf, "detail:dae2:analysis", analysis_start)
  perf_record_timer_elapsed_opt(perf, "detail:dae2:analysis:lift", lift_us)
  perf_record_timer_elapsed_opt(
    perf, "detail:dae2:analysis:dependencies", dependency_us,
  )
  let solve_start = perf_start_timer_opt(perf, "detail:dae2:solve-and-admit")
  graph.solve()
  match mod_.type_sec {
    Some(types) => dae2_preserve_type_identity(types, graph, infos, type_infos)
    None => ()
  }
  // Identity closure can restore parameters. Freeze decisions only after its
  // final solve, then reuse them for repeated direct and indirect callees.
  let signature_changes = infos.map(fn(info) {
    dae2_signature_changes(graph, info)
  })
  let mut signature_change = false
  for index = 0; index < total_funcs; index = index + 1 {
    let info = infos[index]
    signature_change = signature_change ||
      signature_changes[index] ||
      info.call_infos.any(fn(callee) { signature_changes[callee] })
  }
  perf_stop_timer_opt(perf, "detail:dae2:solve-and-admit", solve_start)
  if !signature_change {
    // Captures and legacy-handler adaptation are analysis scaffolding. When
    // no definition or call signature changes, keep the original expression
    // structure rather than making users pay for that scaffolding in output.
    return Ok(dfe_cleanup_simple_type_encoding(original))
  }
  let graph = graph.for_solved_rewrite()
  let source_types = match mod_.type_sec {
    Some(types) => types
    None => return Ok(mod_)
  }
  let type_workspace = Dae2TypeWorkspace::new(source_types)
  let new_indices : Array[@lib.TypeIdx] = []
  let mut private_group : Dae2PrivateGroup? = None
  let bodies : Array[@lib.Func] = []
  let local_remaps : Array[Array[Int32]?] = []
  let control_types : @hashmap.HashMap[Int32, @lib.TypeIdx] = @hashmap.new()
  let rewrite_start = perf_start_timer_opt(perf, "detail:dae2:rewrite")
  let mut rewrite_lift_us = 0UL
  let mut lower_us = 0UL
  let mut raw_rewrite_state : Dae2RawReplayState? = None
  let mut stack_suffix_plan : Dae2StackSuffixPlan? = None
  for index = imported; index < total_funcs; index = index + 1 {
    let info = infos[index]
    let (kept_params, removed_params) = if signature_changes[index] {
      dae2_parameter_plan(graph, info)
    } else {
      (info.params, [])
    }
    let results = if graph.used[info.result_location] {
      info.results
    } else {
      []
    }
    let original_func = mod_.code_sec.unwrap().0[index - imported]
    let @lib.Func(_, @lib.Expr(original_body)) = original_func
    let needs_rewrite = signature_changes[index] ||
      info.call_infos.any(fn(callee) { signature_changes[callee] })
    let control_rewrite = info.control_type_infos.any(fn(family) {
      family < 0 || family >= infos.length() || signature_changes[family]
    })
    let direct = if raw_rewrite && (needs_rewrite || control_rewrite) {
      // Raw replay proves retained headers keep their full original signature.
      // Changed private control families receive separate header types below.
      let flat = if info.raw_analysis {
        dae2_rewrite_raw_function(
          graph, infos, index, original_func, context, kept_params, removed_params,
        )
      } else {
        None
      }
      match flat {
        Some(_) => flat
        None if !needs_rewrite || control_rewrite => None
        None =>
          match suffix_state {
            Some(state) if state.admissions[index] == 1 => {
              let plan = match stack_suffix_plan {
                Some(plan) => plan
                None => {
                  let plan = Dae2StackSuffixPlan::new(graph, infos)
                  stack_suffix_plan = Some(plan)
                  plan
                }
              }
              dae2_rewrite_stack_suffix_function(
                plan, graph, info, index, original_func, state,
              )
            }
            _ => None
          }
      }
    } else {
      None
    }
    if !needs_rewrite && !control_rewrite {
      // Analysis already records every direct and indirect callee. With no
      // changed boundary or changed indexed control family, preserve the original body
      // without rebuilding its HOT graph and deterministic captures.
      bodies.push(original_func)
      local_remaps.push(None)
    } else if direct is Some((body, local_map)) {
      if control_rewrite {
        let @lib.Func(locals, @lib.Expr(instructions)) = body
        dae2_preserve_raw_control_types(
          instructions, context, graph, infos, type_infos, type_workspace, control_types,
        )
        bodies.push(
          @lib.Func::new(
            locals,
            @lib.Expr::new(
              dae2_original_control_types(instructions, control_types),
            ),
          ),
        )
      } else {
        bodies.push(body)
      }
      local_remaps.push(Some(local_map))
    } else {
      match rewrite_lifts {
        Some(count) => count[0] += 1
        None => ()
      }
      let rewrite_lift_start = perf_start_timer_opt(
        perf, "detail:dae2:rewrite:lift",
      )
      let func = match dae2_lift_for_rewrite(mod_, context, index, info) {
        Ok(func) => func
        Err(err) => return Err(err)
      }
      rewrite_lift_us += perf_elapsed_since_start_opt(perf, rewrite_lift_start)
      let rewrite_graph = if info.raw_analysis {
        let replay = match raw_rewrite_state {
          Some(replay) => {
            replay.reset()
            replay
          }
          None => {
            let replay = Dae2RawReplayState::new(
              graph,
              boundary_count,
              sparse=raw_sparse_replay,
            )
            raw_rewrite_state = Some(replay)
            replay
          }
        }
        let replay_ok = dae2_writer_cut_analyze_raw_replay(
          graph,
          replay,
          infos,
          index,
          type_infos,
          func,
          original_func,
          local_graph_builds~,
          fallback_write_builds~,
          intrinsic_imports~,
        )
        if !replay_ok {
          // Qualification must reproduce the complete boundary fixed point.
          // Re-run the original module through HOT if a new dependency appears.
          return dae2_run_module_pass(
            original,
            closed_world,
            cleanup_module_env_builds~,
            rewrite_lifts~,
            local_graph_builds~,
            fallback_write_builds~,
            analysis_lifts~,
            perf~,
            raw_analysis=false,
            stack_suffix_rewrite~,
          )
        }
        replay.graph
      } else {
        graph
      }
      if @ir.hot_node_count(func) != info.node_count {
        return Err("dae2: analysis relift changed node identities")
      }
      let lower_state : HotPipelineLowerState = {
        next_type_sec: Some(type_workspace.types),
        type_sec_changed: false,
      }
      dae2_preserve_control_types(
        func, context, rewrite_graph, infos, type_infos, lower_state, control_types,
      )
      if !needs_rewrite {
        type_workspace.adopt_lower_types(lower_state)
        let @lib.Func(locals, @lib.Expr(body)) = mod_.code_sec.unwrap().0[index -
          imported]
        bodies.push(
          @lib.Func::new(
            locals,
            @lib.Expr::new(dae2_original_control_types(body, control_types)),
          ),
        )
        local_remaps.push(None)
      } else {
        let old_arities = Array::makei(@ir.hot_node_count(func), fn(node) {
          @ir.hot_node_result_arity(func, node)
        })
        let memo = Array::make(info.node_count, -1)
        let roots = @ir.hot_root_span(func).map(fn(node) {
          let rewritten = dae2_rewrite_node(
            rewrite_graph, infos, index, func, node, memo, old_arities, lower_state,
            type_infos,
          )
          if results.is_empty() {
            dae2_discard(func, rewritten)
          } else {
            rewritten
          }
        })
        ignore(@ir.hot_root_splice(func, 0, @ir.hot_root_count(func), roots))
        @ir.hot_body_result_type_set(
          func,
          @ir.hot_type_intern_results(func, results),
        )
        run_hot_pipeline_prepare_tuple_make_lowering(func, lower_state)
        type_workspace.adopt_lower_types(lower_state)
        // Control verification includes core checks and supplies the same
        // child postorder to scope checks. Repeat core only on the error path
        // to retain the existing core-versus-control diagnostic prefix.
        match @ir.hot_verify_control(func) {
          Ok(_) => ()
          Err(err) =>
            match @ir.hot_verify_core(func) {
              Err(core_err) =>
                return Err("dae2: rewritten HOT function \{index}: \{core_err}")
              Ok(_) =>
                return Err(
                  "dae2: rewritten HOT control in function \{index}: \{err}",
                )
            }
        }
        let lower_start = perf_start_timer_opt(
          perf, "detail:dae2:rewrite:lower",
        )
        let @lib.Func(locals, @lib.Expr(body)) = @ir.hot_lower_func_unverified(
          func,
        )
        lower_us += perf_elapsed_since_start_opt(perf, lower_start)
        let local_map = Array::make(info.params.length() + locals.length(), -1)
        let mut kept = 0
        let mut removed = 0
        for param = 0; param < info.params.length(); param = param + 1 {
          if graph.used[info.param_locations[param]] {
            local_map[param] = kept
            kept += 1
          } else {
            local_map[param] = kept_params.length() +
              locals.length() +
              removed_params.length() -
              1 -
              removed
            removed += 1
          }
        }
        for local_idx = 0
            local_idx < locals.length()
            local_idx = local_idx + 1 {
          local_map[info.params.length() + local_idx] = kept_params.length() +
            local_idx
        }
        let new_locals = locals.copy()
        for slot = removed_params.length() - 1; slot >= 0; slot = slot - 1 {
          new_locals.push(removed_params[slot])
        }
        let (body, capture_map) = pass_lower_compact_captures_with_map(
          @lib.Func::new(
            new_locals,
            @lib.Expr::new(dae_rewrite_locals_instrs(body, local_map)),
          ),
          mod_.code_sec.unwrap().0[index - imported],
          kept_params,
        )
        local_remaps.push(Some(local_map.map(fn(index) { capture_map[index] })))
        bodies.push(body)
      }
    }
    let original_type_slot = dae2_type_slot(indices[index], 0)
    let type_changed = signature_changes[type_infos[original_type_slot]]
    let private_element = match private_elements {
      Some(mask) => mask[index]
      None => false
    }
    if private_element &&
      (kept_params != info.params || results != info.results) {
      let group = match private_group {
        Some(group) => group
        None => {
          let group = Dae2PrivateGroup::new()
          private_group = Some(group)
          group
        }
      }
      group.slots.push(new_indices.length())
      group.signatures.push(
        @lib.SubType::comp_type(
          @lib.CompType::func(
            dae2_owned_signature_params(kept_params, info.params),
            results,
          ),
        ),
      )
      // Assign the final group member index after all lowering has appended
      // its block signatures. Original module indices stay valid until then.
      new_indices.push(indices[index])
    } else if dae_function_exposure_blocks_boundary(exposure[index]) ||
      (kept_params == info.params && results == info.results && !type_changed) {
      new_indices.push(indices[index])
    } else {
      let metadata = context.subtypes[original_type_slot].metadata()
      new_indices.push(
        type_workspace.append_signature(
          dae2_owned_signature_params(kept_params, info.params),
          results,
          metadata,
        ),
      )
    }
  }
  perf_stop_timer_opt(perf, "detail:dae2:rewrite", rewrite_start)
  perf_record_timer_elapsed_opt(
    perf, "detail:dae2:rewrite:lift", rewrite_lift_us,
  )
  perf_record_timer_elapsed_opt(perf, "detail:dae2:rewrite:lower", lower_us)
  let finalize_start = perf_start_timer_opt(perf, "detail:dae2:finalize")
  let private_group_changed = match private_group {
    Some(group) => group.append(type_workspace, new_indices)
    None => false
  }
  let types = dae2_rewrite_type_section(
    type_workspace.types,
    graph,
    infos,
    type_infos,
    signature_changes=Some(signature_changes),
  )
  // Signature rewriting can make a new private definition identical to an
  // existing function type. Resolve this only after type-family rewrites have
  // converged. Redirect newly allocated function signatures, never identities
  // already referenced by the source module. The shared canonicalizer admits
  // only single, non-subtyping function groups and compares full metadata.
  let @lib.TypeSec(rewritten_groups) = types
  let canonical_types = dfe_duplicate_simple_type_canonical_map(
    rewritten_groups,
  )
  for index = 0; index < new_indices.length(); index = index + 1 {
    if new_indices[index] is @lib.TypeIdx(raw) &&
      raw.to_int() >= context.subtypes.length() {
      new_indices[index] = dfe_rewrite_type_idx(
        new_indices[index],
        canonical_types,
      )
    }
  }
  let mut candidate = mod_
    .with_type_sec(types)
    .with_func_sec(@lib.FuncSec::new(new_indices))
    .with_code_sec(@lib.CodeSec::new(bodies))
  match rl_rewrite_name_sec(mod_.name_sec, imported, local_remaps) {
    Some(names) =>
      // Control wrappers and removed expression values can renumber labels.
      // Other index spaces retain their identities through this pass.
      candidate = candidate.with_name_sec(
        @lib.NameSec::new(
          module_name=names.module_name,
          func_names=names.func_names,
          local_names=names.local_names,
          label_names=None,
          type_names=names.type_names,
          table_names=names.table_names,
          memory_names=names.memory_names,
          global_names=names.global_names,
          elem_names=names.elem_names,
          data_names=names.data_names,
          field_names=names.field_names,
          tag_names=names.tag_names,
        ),
      )
    None => candidate = candidate.without_name_sec()
  }
  // Signature pruning can expose a statically selected adapted handler. Fold
  // only plain catches of fresh local tags with non-throwing payload producers.
  candidate = dae2_fold_known_local_throws(candidate)
  // Removed arguments can leave result wrappers around ordered producers.
  // Only flatten blocks without label-dependent control transfers.
  match cleanup_module_env_builds {
    Some(builds) => builds[0] += 1
    None => ()
  }
  // Every body is cleaned against the same finalized signature/type snapshot.
  let cleanup_env = @validate.Env::new().with_module(candidate)
  let cleanup_start = perf_start_timer_opt(perf, "detail:dae2:finalize:cleanup")
  let cleaned_bodies = candidate.code_sec.unwrap().0.map(fn(func) {
    pass_lower_cleanup_branchless_blocks(
      func,
      candidate,
      module_env=Some(cleanup_env),
      flatten_parameter_blocks=true,
    ).0
  })
  candidate = candidate.with_code_sec(@lib.CodeSec::new(cleaned_bodies))
  if private_group_changed {
    candidate = dae2_prune_private_element_source_types(candidate)
  }
  perf_stop_timer_opt(perf, "detail:dae2:finalize:cleanup", cleanup_start)
  // No mutation escapes until every definition and call site has its new
  // signature. The module dispatcher rebuilds the HOT module context/caches.
  let finalized = dae2_finalize_candidate(candidate, perf~)
  perf_stop_timer_opt(perf, "detail:dae2:finalize", finalize_start)
  finalized
}

///|
fn dae2_signature_changes(graph : Dae2Graph, info : Dae2Function) -> Bool {
  info.param_locations.any(fn(location) { !graph.used[location] }) ||
  (!info.results.is_empty() && !graph.used[info.result_location])
}

///|
fn dae2_parameter_plan(
  graph : Dae2Graph,
  info : Dae2Function,
  params~ : Array[@lib.ValType]? = None,
) -> (Array[@lib.ValType], Array[@lib.ValType]) {
  // Subtype families share demand locations, but contravariant members can
  // have different parameter types. Project the declared member's own types.
  let params = match params {
    Some(params) => params
    None => info.params
  }
  let mut first_removed = 0
  while first_removed < params.length() &&
        graph.used[info.param_locations[first_removed]] {
    first_removed += 1
  }
  if first_removed == params.length() {
    return (params, [])
  }
  let kept = Array::makei(first_removed, fn(param) { params[param] })
  let removed : Array[@lib.ValType] = []
  for param = first_removed; param < params.length(); param = param + 1 {
    if graph.used[info.param_locations[param]] {
      kept.push(params[param])
    } else {
      removed.push(params[param])
    }
  }
  (kept, removed)
}

///|
fn dae2_boundary_is_pinned(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int32,
  indices : Array[@lib.TypeIdx],
  type_infos : Array[Int32],
  exposure : Array[DaeFunctionExposure],
) -> Bool {
  if index < 0 || index >= infos.length() {
    return false
  }
  if !dae2_signature_changes(graph, infos[index]) {
    return true
  }
  // Public function locations receive their already-observed family seeds
  // during solve. Private direct functions remain independent of that family.
  index < indices.length() &&
  dae_function_exposure_blocks_boundary(exposure[index]) &&
  !dae2_signature_changes(
    graph,
    infos[type_infos[dae2_type_slot(indices[index], 0)]],
  )
}

///|
fn dae2_lift_for_analysis(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  index : Int32,
  write_provenance~ : Dae2StackSuffixState? = None,
  record_local_accesses~ : Bool = true,
  record_capture_sources~ : Bool = false,
) -> Result[@ir.HotFunc, String] {
  match
    @ir.hot_lift_func_with_context_result(
      mod_,
      @lib.FuncIdx::new(index.reinterpret_as_uint()),
      context,
      capture_stack_locals=true,
      materialize_multi_values=true,
      // Keep the helper's recording contract for reference/tool callers.
      // Production opts out explicitly, but write provenance always needs it.
      record_local_accesses=record_local_accesses || write_provenance is Some(_),
      record_capture_sources~,
    ) {
    Ok(func) => {
      // Use the same deterministic capture preparation in both phases.
      let repaired = @ir.hot_repair_ordered_catch_payloads(func)
      if !repaired {
        match write_provenance {
          Some(state) =>
            // Retain source write IDs only while the lift is unmodified.
            // Catch localization can change that mapping and keeps HOT replay.
            state.original_writes[index] = Some(
              @ir.hot_lift_local_accesses(func).writes,
            )
          None => ()
        }
      }
      Ok(func)
    }
    Err(err) => Err("dae2: lift function \{index}: \{err}")
  }
}

///|
// Compare against the current node: call/control rewriting may have changed
// its metadata or reset its span after the original children were captured.
fn dae2_replace_children_if_changed(
  func : @ir.HotFunc,
  node : Int32,
  children : Array[Int32],
) -> Bool {
  if @ir.hot_child_count(func, node) == children.length() {
    let mut same = true
    for i = 0; i < children.length(); i = i + 1 {
      if @ir.hot_child_get(func, node, i) != children[i] {
        same = false
        break
      }
    }
    if same {
      return false
    }
  }
  ignore(@ir.hot_replace_child_span(func, node, children))
  true
}

///|
test "dae2 lazy lower ordering preserves pre-write call operands during signature pruning" {
  let input = pass_test_module_from_wat(
    "(module (func $callee (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32) local.get 0 local.set 1 local.get 1 local.get 0 i32.const 1 i32.add local.set 1 i32.const 7 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 checked payload queries preserve numeric GC and trapping memory operations" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (memory (export \"memory\") 1) (func $callee (param i32 i32) (result i32) local.get 0 i32.const 7 i32.xor) (func (export \"run\") (param i32) (result i32) i32.const 0 i32.const 17 i32.store local.get 0 i32.load local.get 0 struct.new $s struct.get $s 0 i32.xor i64.extend_i32_u i32.wrap_i64 i32.const 99 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 local-band masks retain pre-write operands and imported call order" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func $f (param i32) (result i32))) (func $callee (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 i32 ) local.get 0 call $f i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 1 i32.add i32.const 7 local.set 64 local.get 0 i32.const 1 i32.add local.set 0 local.get 0 call $f drop i32.const 99 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 value CFG edges preserve GC loop and exception dependencies" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"host\" \"tick\" (func $tick)) (tag $t (param i32)) (func $callee (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 (ref null $s)) block (result i32) try_table (catch $t 0) local.get 0 i32.const 0 i32.lt_s if i32.const 9 throw $t end local.get 0 i32.const 3 i32.and local.set 1 local.get 0 struct.new $s local.set 2 block loop local.get 1 i32.eqz br_if 1 call $tick local.get 1 i32.const 1 i32.sub local.set 1 br 0 end end local.get 2 struct.get $s 0 i32.const 99 call $callee return end i32.const 0 end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 typed pop boundaries preserve numeric SIMD and reference operands" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (import \"host\" \"f\" (func $f (param i32) (result i32))) (table 1 anyref) (func $callee (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) i32.const 0 local.get 0 struct.new $s table.set 0 local.get 0 call $f i64.extend_i32_s i64.const 7 i64.add i32.wrap_i64 i32.const 0 table.get 0 ref.is_null local.get 0 i32.add i32.add local.get 0 i32x4.splat v128.const i32x4 1 1 1 1 v128.xor i32x4.extract_lane 0 i32.add i32.const 99 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 declaration validation retains reference calls and active pruning" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (result i32))) (func $target (type $sig) i32.const 7) (func $callee (param i32 i32) (result i32) local.get 0) (elem declare func $target) (func (export \"run\") (param i32) (result i32) local.get 0 ref.func $target call_ref $sig i32.add i32.const 99 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 lift shape fields preserve indirect calls and memory while pruning" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32) (result i32))) (table 1 funcref) (memory (export \"memory\") 1) (func $target (type $sig) local.get 0 i32.const 1 i32.add) (elem (i32.const 0) $target) (func $callee (param i32 i32) (result i32) local.get 0) (func (export \"run\") (param i32) (result i32) (local i32 i32) i32.const 0 local.get 0 i32.store i32.const 0 i32.load local.set 1 local.get 1 local.set 2 local.get 2 i32.const 0 call_indirect (type $sig) i32.const 99 call $callee i32.const 0 i32.add))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(1U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "dae2 lift data results preserve mixed call result lanes" {
  let input = pass_test_module_from_wat(
    "(module (func $helper (param i32 i32) (result i32 i64) local.get 0 i64.const 9) (func (export \"run\") (param i32) (result i32) (local i64 i32) local.get 0 i32.const 99 call $helper local.set 1 local.set 2 local.get 2 local.get 1 i32.wrap_i64 i32.add))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for optimize in [false, true] {
    let output = dae2_run_module_pass(input, optimize).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
      Some(
        @lib.FuncType::new([@lib.ValType::i32()], [
          @lib.ValType::i32(),
          @lib.ValType::i64(),
        ]),
      ),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 scalar scratch retains nested GC tuple types" {
  let input = pass_test_module_from_wat(
    "(module (type $s (struct (field i32))) (func $pair (param i32 i32) (result (ref $s) i64) local.get 0 struct.new $s i64.const 9) (func (export \"run\") (param i32) (result i32) (local i64 (ref null $s)) local.get 0 if (result (ref $s) i64) local.get 0 i32.const 99 call $pair else i32.const 7 i32.const 99 call $pair end local.set 1 local.set 2 i32.const 0 drop local.get 2 struct.get $s 0 local.get 1 i32.wrap_i64 i32.add))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for optimize in [false, true] {
    let output = dae2_run_module_pass(input, optimize).unwrap()
    @validate.validate_module(output).unwrap()
    let @lib.FuncType(params, results) = @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(0U))
      .unwrap()
    assert_eq(params, [@lib.ValType::i32()])
    assert_eq(results.length(), 2)
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 keeps live single param labels and mixed tuple inputs on raw and HOT rewrite routes" {
  for
    source in [
      "(module (func $callee (param i32 i32 i64) (result i32) local.get 0 block (param i32) (result i32) local.get 1 br_if 0 end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 99 call $callee))",
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func $callee (param i32 i64 i32) (result i64) local.get 1 block (param i64) (result i64) i64.const 1 i64.add end) (func (export \"run\") (result i64) call 0 i32.const 99 call $callee))",
      "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $callee (param i64 i32) (result i64) (local i64) i32.const 19 call 0 local.get 0 block (param i32 i64) (result i64) local.set 2 drop local.get 2 end) (func (export \"run\") (result i64) i64.const 23 i32.const 99 call $callee))",
    ] {
    let input = pass_test_module_from_wat(source)
    let @lib.FuncType(original_params, _) = @validate.Env::new()
      .with_module(input)
      .get_functype_by_funcidx(
        @lib.FuncIdx::new(dae_imported_func_count(input).to_uint()),
      )
      .unwrap()
    let original_count = original_params.length()
    for raw in [false, true] {
      let output = dae2_run_module_pass(
        input,
        false,
        raw_analysis=raw,
        raw_conditionals=raw,
        raw_rewrite=raw,
        stack_suffix_rewrite=raw,
      ).unwrap()
      @validate.validate_module(output).unwrap()
      let bytes = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
      let imported = dae_imported_func_count(output)
      let @lib.FuncType(params, _) = @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(imported.to_uint()))
        .unwrap()
      assert_true(params.length() < original_count)
      let optimizing = run_hot_pipeline(output, HotPipelineOptions::new(), [
        "simplify-locals", "vacuum",
      ]).unwrap()
      @validate.validate_module(optimizing).unwrap()
      @validate.validate_module(
        @binary.decode_module(@binary.encode_module(optimizing).unwrap()).unwrap(),
      ).unwrap()
    }
  }
}

///|
test "dae2 typed block entry preserves effectful producers when pruning a parameter" {
  let input = pass_test_module_from_wat(
    "(module (import \"host\" \"f\" (func (param i32) (result i32))) (global (export \"state\") (mut i32) (i32.const 0)) (func $callee (param i32 i32) (result i32) (local i32) i32.const 17 global.set 0 i32.const 19 call 0 local.get 0 block (param i32 i32) (result i32) i32.div_s end local.set 2 local.get 2 call 0) (func (export \"run\") (param i32) (result i32) local.get 0 i32.const 99 call $callee))",
  )
  let saved = @binary.encode_module(input).unwrap()
  for optimize in [false, true] {
    let output = dae2_run_module_pass(input, optimize).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(
      @validate.Env::new()
      .with_module(output)
      .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
      Some(@lib.FuncType::new([@lib.ValType::i32()], [@lib.ValType::i32()])),
    )
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "dae2 typed block entry preserves labels and discarded trapping results" {
  for
    source in [
      "(module (func $h (param i32 i32 i64) (result i32) local.get 0 local.get 1 block (param i32 i32) (result i32) i32.div_s end) (func (export \"run\") (param i32 i32) local.get 0 local.get 1 i64.const 99 call $h drop))",
      "(module (func $h (param i32 i32 i64) (result i32) local.get 0 local.get 1 block (param i32 i32) (result i32) i32.add br 0 end) (func (export \"run\") (param i32 i32) (result i32) local.get 0 local.get 1 i64.const 99 call $h))",
    ] {
    let input = pass_test_module_from_wat(source)
    for optimize in [false, true] {
      let output = dae2_run_module_pass(input, optimize).unwrap()
      @validate.validate_module(output).unwrap()
      let @lib.FuncType(params, _) = @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(0U))
        .unwrap()
      assert_eq(params, [@lib.ValType::i32(), @lib.ValType::i32()])
    }
  }
}

///|
test "dae2 discarded typed block results evaluate entry imports exactly once" {
  for
    (source, calls) in [
      (
        "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $h (param i32 i32 i64) (result i32) local.get 0 call 0 local.get 1 block (param i32 i32) (result i32) i32.div_s end) (func (export \"run\") (param i32) i32.const 19 local.get 0 i64.const 99 call $h drop i32.const 23 call 0 drop))",
        1,
      ),
      (
        "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $h (param i32 i32 i64) (result i32) local.get 0 call 0 local.get 1 call 0 block (param i32 i32) (result i32) drop i32.const 1 i32.div_s end) (func (export \"run\") (param i32) i32.const 19 local.get 0 i64.const 99 call $h drop))",
        2,
      ),
      (
        "(module (import \"host\" \"f\" (func (param i32) (result i32))) (func $h (param i32 i32 i64) (result i32) local.get 0 call 0 local.get 1 call 0 block (param i32 i32) (result i32) drop drop i32.const 7 end) (func (export \"run\") (param i32) i32.const 19 local.get 0 i64.const 99 call $h drop))",
        2,
      ),
    ] {
    for optimize in [false, true] {
      let input = pass_test_module_from_wat(source)
      let output = dae2_run_module_pass(input, optimize).unwrap()
      @validate.validate_module(output).unwrap()
      let body = output.code_sec.unwrap().0[0]
      assert_eq(dae_count_self_calls_anywhere(body, 0), calls)
      let @lib.Func(_, @lib.Expr(instructions)) = body
      assert_true(
        !instructions.any(fn(instruction) { instruction is @lib.Block(_, _) }),
      )
      assert_eq(
        @validate.Env::new()
        .with_module(output)
        .get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
        Some(@lib.FuncType::new([@lib.ValType::i32(), @lib.ValType::i32()], [])),
      )
    }
  }
}

///|
test "DAE2 parameter plan retains unchanged params and preserves removal order" {
  let graph = Dae2Graph::new()
  let params = [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::f64()]
  let info = Dae2Function::new(graph, params, [])
  for location in info.param_locations {
    graph.observe(location)
  }
  let (unchanged, removed) = dae2_parameter_plan(graph, info)
  assert_eq(unchanged, params)
  assert_true(removed.is_empty())
  assert_true(physical_equal(unchanged, params))
  graph.used[info.param_locations[1]] = false
  let (kept, removed) = dae2_parameter_plan(graph, info)
  assert_eq(kept, [@lib.ValType::i32(), @lib.ValType::f64()])
  assert_eq(removed, [@lib.ValType::i64()])
  assert_eq(params.length(), 3)
}

///|
test "DAE2 indirect targets share family demand despite unequal own liveness" {
  let input = pass_test_module_from_wat(
    "(module (type $sig (func (param i32 i64))) (global $side (mut i32) (i32.const 0)) (table 2 funcref) (func $idle (type $sig)) (func $live (type $sig) local.get 0 global.set $side) (elem (i32.const 0) $idle $live) (func (export \"run\") (param i32) (result i32) i32.const 7 i64.const 9 local.get 0 call_indirect (type $sig) global.get $side))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(input, true).unwrap()
  @validate.validate_module(output).unwrap()
  let env = @validate.Env::new().with_module(output)
  let expected = Some(@lib.FuncType::new([@lib.ValType::i32()], []))
  for index in [0U, 1U] {
    assert_eq(env.get_functype_by_funcidx(@lib.FuncIdx::new(index)), expected)
  }
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  guard body[body.length() - 2] is @lib.CallIndirect(type_idx, _) else {
    fail("expected indirect dispatch")
  }
  assert_eq(env.resolve_functype(type_idx), expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 rejects intentionally invalid unequal-arity subtype families before rewriting" {
  for signature in ["(param i32 i64)", "(param i32) (result i32)"] {
    let input = @wast.wast_to_binary_module(
      "(module (rec (type $P (sub (func (param i32)))) (type $Q (sub $P (func \{signature})))))",
    ).unwrap()
    assert_true(@validate.validate_module(input).is_err())
    assert_true(dae2_run_module_pass(input, true).is_err())
  }
}

///|
test "DAE2 recursive subtype family keeps member parameter variance at dispatch" {
  let input = pass_test_module_from_wat(
    "(module (rec (type $P (sub (func (param eqref i32)))) (type $Q (sub $P (func (param anyref i32))))) (global $side (mut i32) (i32.const 0)) (table 2 funcref) (func $live (type $P) local.get 0 ref.is_null global.set $side) (func $idle (type $Q)) (elem (i32.const 0) $live $idle) (func (export \"run\") (param i32) (result i32) ref.null eq i32.const 7 local.get 0 call_indirect (type $P) global.get $side))",
  )
  let output = dae2_run_module_pass(input, true).unwrap()
  @validate.validate_module(output).unwrap()
  let env = @validate.Env::new().with_module(output)
  let input_env = @validate.Env::new().with_module(input)
  let parent = input_env.resolve_functype(@lib.TypeIdx::new(0U)).unwrap()
  let child = input_env.resolve_functype(@lib.TypeIdx::new(1U)).unwrap()
  let @lib.FuncType(parent_params, _) = parent
  let @lib.FuncType(child_params, _) = child
  assert_eq(
    env.get_functype_by_funcidx(@lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([parent_params[0]], [])),
  )
  assert_eq(
    env.get_functype_by_funcidx(@lib.FuncIdx::new(1U)),
    Some(@lib.FuncType::new([child_params[0]], [])),
  )
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  guard body[body.length() - 2] is @lib.CallIndirect(type_idx, _) else {
    fail("expected recursive-family indirect dispatch")
  }
  assert_eq(
    env.resolve_functype(type_idx),
    Some(@lib.FuncType::new([parent_params[0]], [])),
  )
}
