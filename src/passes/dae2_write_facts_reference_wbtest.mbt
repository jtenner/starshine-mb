///|
fn dae2_writefacts_reference_entry_sources(
  func : @ir.HotFunc,
  visits? : Array[Int]? = None,
  interval_builds? : Array[Int]? = None,
) -> Array[Int]? {
  let root_writes : Array[Int] = []
  for root in @ir.hot_root_span(func) {
    if root >= 0 && @ir.hot_node_op(func, root) is @ir.LocalSet {
      root_writes.push(root)
    }
  }
  if root_writes.is_empty() {
    return None
  }
  let writes = Array::make(@ir.hot_local_count(func), -1)
  for node in 0..<@ir.hot_node_count(func) {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let data = @ir.hot_node_get(func, node)
    // These control families retain the complete LocalGraph/unknown proof.
    if data.op is @ir.Try ||
      data.op is @ir.TryTable ||
      data.op is @ir.Continuation {
      return None
    }
    if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
      writes[data.imm0] = if writes[data.imm0] == -1 { node } else { -2 }
    }
  }
  let entry_writes = Array::make(writes.length(), -1)
  let mut admitted = 0
  for root in root_writes {
    let local = @ir.hot_node_get(func, root).imm0
    if writes[local] == root {
      if entry_writes[local] < 0 {
        admitted += 1
      }
      entry_writes[local] = root
    }
  }
  if admitted == 0 {
    return None
  }
  if admitted == 1 {
    return dae2_writefacts_reference_single_sources(func, entry_writes, visits~)
  }
  match interval_builds {
    Some(count) => count[0] += 1
    None => ()
  }
  let count = @ir.hot_node_count(func)
  let root_count = @ir.hot_root_count(func)
  let write_roots = Array::make(writes.length(), -1)
  let sources = Array::make(count, -2)
  let first_roots = Array::make(count, root_count)
  let postorder : Array[Int] = []
  let stack : Array[Int] = []
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
        stack.push(-item - 1)
        for slot = data.child_count - 1; slot >= 0; slot = slot - 1 {
          let child = @ir.hot_child_get(func, item, slot)
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
      let child = @ir.hot_child_get(func, node, slot)
      if child >= 0 && @ir.hot_node_is_live(func, child) {
        first_roots[child] = first_roots[child].min(first_roots[node])
        sources[child] = sources[child].max(sources[node])
      }
    }
  }
  for node in 0..<count {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let data = @ir.hot_node_get(func, node)
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
fn dae2_writefacts_reference_analyze(
  graph : Dae2Graph,
  infos : Array[Dae2Function],
  index : Int,
  type_infos : Array[Int],
  func : @ir.HotFunc,
  local_graph_builds? : Array[Int]? = None,
  fallback_write_builds? : Array[Int]? = None,
  analysis_child_snapshots? : Array[Int]? = None,
  intrinsic_imports? : Array[Bool]? = None,
) -> Unit {
  // This phase changes only the dependency graph; HOT child slots stay stable.
  ignore(analysis_child_snapshots)
  let info = infos[index]
  let mut local_flow : @ir.HotLocalReadSources? = None
  let mut fallback_writes : Array[Array[Int]]? = None
  let mut written_locals : Array[Bool]? = None
  let mut entry_read_sources : Array[Int]? = None
  let mut entry_source_attempted = false
  for node = 0; node < info.node_count; node = node + 1 {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let value = info.node_location_base + node
    let data = @ir.hot_node_get(func, node)
    match data.op {
      @ir.LocalGet => {
        let written = match written_locals {
          Some(written) => written
          None => {
            let written = Array::make(@ir.hot_local_count(func), false)
            for write in 0..<info.node_count {
              if @ir.hot_node_is_live(func, write) {
                let data = @ir.hot_node_get(func, write)
                if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
                  written[data.imm0] = true
                }
              }
            }
            written_locals = Some(written)
            written
          }
        }
        // With no write anywhere in this body, every read has its entry value,
        // including reads in control regions not represented by LocalGraph.
        // Default-initialized body locals need no parameter dependency.
        if !written[data.imm0] {
          if data.imm0 < info.params.length() {
            graph.edge(value, info.param_locations[data.imm0])
          }
          continue
        }
        if !entry_source_attempted {
          entry_read_sources = dae2_writefacts_reference_entry_sources(func)
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
        let locals = match local_flow {
          Some(locals) => locals
          None => {
            match local_graph_builds {
              Some(count) => count[0] += 1
              None => ()
            }
            let selected_gets = dae2_writefacts_reference_unresolved_reads(
              func, written, entry_read_sources,
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
              let writes : Array[Array[Int]] = Array::makei(
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
              writes
            }
          }
          if data.imm0 < info.params.length() {
            graph.edge(value, info.param_locations[data.imm0])
          }
          for write in writes[data.imm0] {
            graph.edge(value, dae2_node_location(info, write))
          }
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
          let child = @ir.hot_child_get(func, node, slot)
          graph.edge(info.result_location, dae2_node_location(info, child))
        }
      @ir.Drop => ()
      @ir.Block | @ir.Loop =>
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = @ir.hot_child_get(func, node, slot)
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
            dae2_node_location(info, @ir.hot_child_get(func, node, arm)),
          )
        }
      }
      @ir.TryTable => {
        for slot = 0; slot < data.child_count; slot = slot + 1 {
          let child = @ir.hot_child_get(func, node, slot)
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
          let child = @ir.hot_child_get(func, node, slot)
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
          let child = @ir.hot_child_get(func, node, slot)
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
            let child = @ir.hot_child_get(func, node, slot)
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
// One immutable analysis snapshot. DAE2 already resolves unwritten locals and
// proven entry/sole-write reads without LocalGraph; keep every unresolved read,
// including unrepresented control reads which need the existing fallback.
fn dae2_writefacts_reference_unresolved_reads(
  func : @ir.HotFunc,
  written : Array[Bool],
  entry_sources : Array[Int]?,
) -> Array[Bool] {
  Array::makei(@ir.hot_node_count(func), fn(node) {
    if !@ir.hot_node_is_live(func, node) {
      return false
    }
    if entry_sources is Some(sources) && sources[node] >= -1 {
      return false
    }
    let data = @ir.hot_node_get(func, node)
    data.op is @ir.LocalGet && written[data.imm0]
  })
}

///|
fn dae2_writefacts_reference_single_sources(
  func : @ir.HotFunc,
  entry_writes : Array[Int],
  visits? : Array[Int]? = None,
) -> Array[Int]? {
  let mut completed = false
  let sources = Array::make(@ir.hot_node_count(func), -2)
  let stack : Array[Int] = []
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
        if data.op is @ir.LocalSet &&
          entry_writes[data.imm0] == item &&
          item != root {
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
        if data.op is @ir.LocalGet && entry_writes[data.imm0] >= 0 {
          let source = if completed { entry_writes[data.imm0] } else { -1 }
          sources[node] = if sources[node] == -2 || sources[node] == source {
            source
          } else {
            -3
          }
        } else if data.op is @ir.LocalSet && entry_writes[data.imm0] == node {
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
