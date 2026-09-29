///|
// Frozen v3 epoch traversal: compare complete source-query work and ownership.
fn dae2_entry_epoch_reference(
  func : @ir.HotFunc,
  visits? : Array[Int]? = None,
) -> Array[Int]? {
  let root_writes : Array[Int] = []
  for root in @ir.hot_root_span(func) {
    if root >= 0 && @ir.hot_node_get(func, root).op is @ir.LocalSet {
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
  let mut admitted = false
  for root in root_writes {
    let local = @ir.hot_node_get(func, root).imm0
    if writes[local] == root {
      entry_writes[local] = root
      admitted = true
    }
  }
  if !admitted {
    return None
  }
  let completed = Array::make(writes.length(), false)
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
          let source = if completed[data.imm0] {
            entry_writes[data.imm0]
          } else {
            -1
          }
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
          completed[data.imm0] = true
          epoch += 1
        }
      }
    }
  }
  Some(sources)
}

///|
fn dae2_entry_interval_bench(
  it : @bench.T,
  writes : Int,
  depth : Int,
  reference : Bool,
) -> Unit {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(writes, @lib.ValType::i32())),
  )
  let read = @ir.hot_build_local_get(func, 0)
  let mut shared = read
  for _ in 0..<depth {
    shared = @ir.hot_build_binary(func, @lib.ValType::i32(), shared, shared)
  }
  let write = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(11)),
  )
  @ir.hot_root_append(func, write)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  for local in 1..<writes {
    @ir.hot_root_append(
      func,
      @ir.hot_build_local_set(
        func,
        local,
        @ir.hot_build_const_i32(func, @lib.I32(local)),
      ),
    )
    @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  }
  let count = @ir.hot_node_count(func)
  let revision = @ir.hot_revision_current(func)
  if dae2_entry_epoch_reference(func).unwrap()[read] != write ||
    dae2_entry_read_sources(func).unwrap()[read] != write {
    abort("entry-interval benchmark changed the reaching definition")
  }
  if reference {
    it.bench(fn() { it.keep(dae2_entry_epoch_reference(func)) })
  } else {
    it.bench(fn() { it.keep(dae2_entry_read_sources(func)) })
  }
  if @ir.hot_node_count(func) != count ||
    @ir.hot_revision_current(func) != revision {
    abort("entry-interval benchmark mutated its analysis snapshot")
  }
}

///|
test "bench DAE2 entry epoch writes=1 depth=0" (it : @bench.T) {
  dae2_entry_interval_bench(it, 1, 0, true)
}

///|
test "bench DAE2 entry interval writes=1 depth=0" (it : @bench.T) {
  dae2_entry_interval_bench(it, 1, 0, false)
}

///|
test "bench DAE2 entry epoch writes=1 depth=64" (it : @bench.T) {
  dae2_entry_interval_bench(it, 1, 64, true)
}

///|
test "bench DAE2 entry interval writes=1 depth=64" (it : @bench.T) {
  dae2_entry_interval_bench(it, 1, 64, false)
}

///|
test "bench DAE2 entry epoch writes=32 depth=64" (it : @bench.T) {
  dae2_entry_interval_bench(it, 32, 64, true)
}

///|
test "bench DAE2 entry interval writes=32 depth=64" (it : @bench.T) {
  dae2_entry_interval_bench(it, 32, 64, false)
}
