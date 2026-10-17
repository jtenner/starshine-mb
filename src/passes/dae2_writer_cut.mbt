///|
/// Proposed only: original-writer cut for one fresh raw-origin rewrite lift.
priv struct Dae2WriterCut {
  revision : Int32
  source_local_count : Int32
  accesses : @ir.HotLiftLocalAccesses
  writer_demands : Array[Bool]
  captures : Array[(Int32, Int32)]
}

///|
fn dae2_writer_cut_prepare(
  source : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
  original : @lib.Func,
) -> Dae2WriterCut? {
  if !info.raw_analysis {
    return None
  }
  let @lib.Func(body_locals, _) = original
  let accesses = match func.lifted_local_accesses {
    Some(accesses) if accesses.revision == @ir.hot_revision_current(func) =>
      accesses
    _ => return None
  }
  let captures = match accesses.capture_sources {
    Some(captures) => captures
    None => return None
  }
  let writes = match info.raw_write_locations {
    Some(writes) => writes
    None => []
  }
  if accesses.writes.length() != writes.length() ||
    accesses.local_count != info.params.length() + body_locals.length() ||
    @ir.hot_local_count(func) != accesses.local_count + captures.length() {
    return None
  }
  let count = @ir.hot_node_count(func)
  let mut concrete_gets = 0
  let mut previous_get = -1
  for (local, node) in accesses.gets {
    if local < 0 || local >= accesses.local_count {
      return None
    }
    if node == -1 {
      continue
    }
    if node < 0 ||
      node >= @ir.hot_node_count(func) ||
      node <= previous_get ||
      !@ir.hot_node_is_live(func, node) {
      return None
    }
    let data = @ir.hot_node_get(func, node)
    if !(data.op is @ir.LocalGet) || data.imm0 != local {
      return None
    }
    previous_get = node
    concrete_gets += 1
  }
  if concrete_gets == 0 && captures.is_empty() {
    return None
  }
  let demands : Array[Bool] = []
  let mut previous = -1
  let mut concrete_writes = 0
  for index in 0..<writes.length() {
    let (raw_local, location) = writes[index]
    let (local, node) = accesses.writes[index]
    if local != raw_local ||
      local < 0 ||
      local >= accesses.local_count ||
      location < 0 ||
      location >= source.used.length() {
      return None
    }
    let used = source.used[location]
    demands.push(used)
    if node < 0 {
      if node != -1 || used {
        return None
      }
      continue
    }
    if node >= count || node <= previous || !@ir.hot_node_is_live(func, node) {
      return None
    }
    let data = @ir.hot_node_get(func, node)
    if (!(data.op is @ir.LocalSet) && !(data.op is @ir.LocalTee)) ||
      data.imm0 != local {
      return None
    }
    previous = node
    concrete_writes += 1
  }
  if concrete_writes == 0 && captures.is_empty() {
    return None
  }
  let mut previous_read = -1
  for index in 0..<captures.length() {
    let (read, write) = captures[index]
    if read < 0 ||
      read >= count ||
      write < 0 ||
      write >= count ||
      read <= previous_read ||
      !@ir.hot_node_is_live(func, read) ||
      !@ir.hot_node_is_live(func, write) {
      return None
    }
    let get = @ir.hot_node_get(func, read)
    let set = @ir.hot_node_get(func, write)
    let local = accesses.local_count + index
    if !(get.op is @ir.LocalGet) ||
      !(set.op is @ir.LocalSet) ||
      get.imm0 != local ||
      set.imm0 != local ||
      get.child_count != 0 ||
      set.child_count != 1 ||
      write >= read {
      return None
    }
    previous_read = read
  }
  // Account for every live original writer and synthetic access. Fresh capture
  // locals are appended once, in journal order. Never infer a source from a
  // sole writer in arbitrary user-supplied HOT.
  let mut seen_original_gets = 0
  let mut seen_original_writes = 0
  let mut seen_capture_reads = 0
  let mut seen_capture_writes = 0
  for node in 0..<count {
    if !@ir.hot_node_is_live(func, node) {
      continue
    }
    let data = @ir.hot_node_get(func, node)
    if data.op is @ir.TryTable || data.op is @ir.Continuation {
      return None
    }
    if data.op is @ir.LocalGet ||
      data.op is @ir.LocalSet ||
      data.op is @ir.LocalTee {
      if data.imm0 < 0 || data.imm0 >= @ir.hot_local_count(func) {
        return None
      }
      if data.imm0 < accesses.local_count {
        if data.op is @ir.LocalGet {
          seen_original_gets += 1
        }
        if data.op is @ir.LocalSet || data.op is @ir.LocalTee {
          seen_original_writes += 1
        }
      } else {
        let pair = captures[data.imm0 - accesses.local_count]
        if data.op is @ir.LocalGet {
          if pair.0 != node {
            return None
          }
          seen_capture_reads += 1
        } else {
          if !(data.op is @ir.LocalSet) || pair.1 != node {
            return None
          }
          seen_capture_writes += 1
        }
      }
    }
  }
  if seen_original_gets != concrete_gets ||
    seen_original_writes != concrete_writes ||
    seen_capture_reads != captures.length() ||
    seen_capture_writes != captures.length() {
    return None
  }
  Some({
    revision: accesses.revision,
    source_local_count: accesses.local_count,
    accesses,
    writer_demands: demands,
    captures,
  })
}

///|
fn Dae2WriterCut::seed(
  self : Dae2WriterCut,
  graph : Dae2Graph,
  info : Dae2Function,
) -> Unit {
  for index in 0..<self.writer_demands.length() {
    let (_, node) = self.accesses.writes[index]
    if node >= 0 && self.writer_demands[index] {
      graph.observe(dae2_node_location(info, node))
    }
  }
}

///|
/// Extra local writer gate; complete parameter/result gate remains unchanged.
fn Dae2WriterCut::matches_writers(
  self : Dae2WriterCut,
  graph : Dae2Graph,
  info : Dae2Function,
) -> Bool {
  for index in 0..<self.writer_demands.length() {
    let (_, node) = self.accesses.writes[index]
    if node >= 0 &&
      graph.used[dae2_node_location(info, node)] != self.writer_demands[index] {
      return false
    }
  }
  true
}

///|
/// Shared production seed/analyze/solve/reset gate. A caller must keep the
/// prepared carrier in this private fresh-lift scope; it must never escape to lower.
fn dae2_writer_cut_analyze_prepared_replay(
  replay : Dae2RawReplayState,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  func : @ir.HotFunc,
  cut : Dae2WriterCut?,
  local_graph_builds~ : Array[Int32]? = None,
  fallback_write_builds~ : Array[Int32]? = None,
  intrinsic_imports~ : Array[Bool]? = None,
) -> Bool {
  let info = infos[index]
  info.assign_node_locations(replay.graph, @ir.hot_node_count(func))
  dae2_analyze_function(
    replay.graph,
    infos,
    index,
    type_infos,
    func,
    local_graph_builds~,
    fallback_write_builds~,
    intrinsic_imports~,
    writer_cut=cut,
  )
  let mut replay_ok = replay.solve_function(info, infos)
  if replay_ok && cut is Some(cut) && !cut.matches_writers(replay.graph, info) {
    replay.reset()
    info.assign_node_locations(replay.graph, @ir.hot_node_count(func))
    dae2_analyze_function(
      replay.graph,
      infos,
      index,
      type_infos,
      func,
      local_graph_builds~,
      fallback_write_builds~,
      intrinsic_imports~,
    )
    replay_ok = replay.solve_function(info, infos)
  }
  replay_ok
}

///|
/// The carrier is owned only inside this callback-free function. Main gets a
/// Bool and a solved private replay, never a carrier or source-journal alias.
fn dae2_writer_cut_analyze_raw_replay(
  source : Dae2Graph,
  replay : Dae2RawReplayState,
  infos : Array[Dae2Function],
  index : Int32,
  type_infos : Array[Int32],
  func : @ir.HotFunc,
  original : @lib.Func,
  local_graph_builds~ : Array[Int32]? = None,
  fallback_write_builds~ : Array[Int32]? = None,
  intrinsic_imports~ : Array[Bool]? = None,
) -> Bool {
  let ok = {
    let cut = dae2_writer_cut_prepare(source, infos[index], func, original)
    dae2_writer_cut_analyze_prepared_replay(
      replay,
      infos,
      index,
      type_infos,
      func,
      cut,
      local_graph_builds~,
      fallback_write_builds~,
      intrinsic_imports~,
    )
  }
  @ir.hot_lift_release_local_accesses(func)
  ok
}

///|
/// Keep the actual rewrite lift and its source-recording policy shared with
/// bounded behavior and native controls. Lift/repair/errors remain unchanged.
fn dae2_lift_for_rewrite(
  mod_ : @lib.Module,
  context : @ir.HotModuleContext,
  index : Int32,
  info : Dae2Function,
) -> Result[@ir.HotFunc, String] {
  let record_sources = if info.raw_analysis {
    match info.raw_write_locations {
      Some(writes) => !writes.is_empty()
      None => false
    }
  } else {
    false
  }
  dae2_lift_for_analysis(
    mod_,
    context,
    index,
    record_local_accesses=record_sources,
    record_capture_sources=record_sources,
  )
}
