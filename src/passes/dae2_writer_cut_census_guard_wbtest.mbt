///|
fn dae2_writer_cut_census_reject(
  guard_reason : Array[Int32],
  reason : Int32,
) -> Dae2WriterCut? {
  guard_reason[0] = reason
  None
}

///|
fn dae2_writer_cut_census_prepare(
  guard_reason : Array[Int32],
  source : Dae2Graph,
  info : Dae2Function,
  func : @ir.HotFunc,
  original : @lib.Func,
) -> Dae2WriterCut? {
  if !info.raw_analysis {
    return dae2_writer_cut_census_reject(guard_reason, 1)
  }
  let @lib.Func(body_locals, _) = original
  let accesses = match func.lifted_local_accesses {
    Some(accesses) if accesses.revision == @ir.hot_revision_current(func) =>
      accesses
    _ => return dae2_writer_cut_census_reject(guard_reason, 2)
  }
  let captures = match accesses.capture_sources {
    Some(captures) => captures
    None => return dae2_writer_cut_census_reject(guard_reason, 3)
  }
  let writes = match info.raw_write_locations {
    Some(writes) => writes
    None => []
  }
  if accesses.writes.length() != writes.length() ||
    accesses.local_count != info.params.length() + body_locals.length() ||
    @ir.hot_local_count(func) != accesses.local_count + captures.length() {
    return dae2_writer_cut_census_reject(guard_reason, 4)
  }
  let count = @ir.hot_node_count(func)
  let mut concrete_gets = 0
  let mut previous_get = -1
  for (local, node) in accesses.gets {
    if local < 0 || local >= accesses.local_count {
      return dae2_writer_cut_census_reject(guard_reason, 5)
    }
    if node == -1 {
      continue
    }
    if node < 0 ||
      node >= @ir.hot_node_count(func) ||
      node <= previous_get ||
      !@ir.hot_node_is_live(func, node) {
      return dae2_writer_cut_census_reject(guard_reason, 6)
    }
    let data = @ir.hot_node_get(func, node)
    if !(data.op is @ir.LocalGet) || data.imm0 != local {
      return dae2_writer_cut_census_reject(guard_reason, 7)
    }
    previous_get = node
    concrete_gets += 1
  }
  if concrete_gets == 0 && captures.is_empty() {
    return dae2_writer_cut_census_reject(guard_reason, 8)
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
      return dae2_writer_cut_census_reject(guard_reason, 9)
    }
    let used = source.used[location]
    demands.push(used)
    if node < 0 {
      if node != -1 || used {
        return dae2_writer_cut_census_reject(guard_reason, 10)
      }
      continue
    }
    if node >= count || node <= previous || !@ir.hot_node_is_live(func, node) {
      return dae2_writer_cut_census_reject(guard_reason, 11)
    }
    let data = @ir.hot_node_get(func, node)
    if (!(data.op is @ir.LocalSet) && !(data.op is @ir.LocalTee)) ||
      data.imm0 != local {
      return dae2_writer_cut_census_reject(guard_reason, 12)
    }
    previous = node
    concrete_writes += 1
  }
  if concrete_writes == 0 && captures.is_empty() {
    return dae2_writer_cut_census_reject(guard_reason, 13)
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
      return dae2_writer_cut_census_reject(guard_reason, 14)
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
      return dae2_writer_cut_census_reject(guard_reason, 15)
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
      return dae2_writer_cut_census_reject(guard_reason, 16)
    }
    if data.op is @ir.LocalGet ||
      data.op is @ir.LocalSet ||
      data.op is @ir.LocalTee {
      if data.imm0 < 0 || data.imm0 >= @ir.hot_local_count(func) {
        return dae2_writer_cut_census_reject(guard_reason, 17)
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
            return dae2_writer_cut_census_reject(guard_reason, 18)
          }
          seen_capture_reads += 1
        } else {
          if !(data.op is @ir.LocalSet) || pair.1 != node {
            return dae2_writer_cut_census_reject(guard_reason, 19)
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
    return dae2_writer_cut_census_reject(guard_reason, 20)
  }
  Some({
    revision: accesses.revision,
    source_local_count: accesses.local_count,
    accesses,
    writer_demands: demands,
    captures,
  })
}
