///|
fn dae2_entry_finalization_reference(
  func : @ir.HotFunc,
  visits? : Array[Int]? = None,
  interval_builds? : Array[Int]? = None,
  known_writes? : Array[Int]? = None,
  opaque? : Bool = false,
  write_census_visits? : Array[Int]? = None,
  entry_row_slots? : Array[Int]? = None,
) -> Array[Int]? {
  if opaque {
    return None
  }
  let root_writes : Array[Int] = []
  for root in @ir.hot_root_span(func) {
    if root >= 0 && @ir.hot_node_op(func, root) is @ir.LocalSet {
      root_writes.push(root)
    }
  }
  if root_writes.is_empty() {
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
  let mut entry_writes : Array[Int]? = None
  let mut single_local = -1
  let mut single_write = -1
  let mut admitted = 0
  for root in root_writes {
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
fn dae2_entry_finalization_fixture(
  depth : Int,
  two_writes? : Bool = true,
) -> (@ir.HotFunc, Array[Int]) {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=Array::make(3, @lib.ValType::i32())),
  )
  let before = @ir.hot_build_local_get(func, 0)
  let cross = @ir.hot_build_local_get(func, 0)
  let operand = @ir.hot_build_local_get(func, 1)
  let mut shared = cross
  for _ in 0..<depth {
    shared = @ir.hot_build_binary(func, @lib.ValType::i32(), shared, shared)
  }
  let write0 = @ir.hot_build_local_set(func, 0, operand)
  let write1 = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(17)),
  )
  let after0 = @ir.hot_build_local_get(func, 0)
  let after1 = @ir.hot_build_local_get(func, 1)
  let unadmitted = @ir.hot_build_local_get(func, 2)
  let detached = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, before))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, write0)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, after0))
  if two_writes {
    @ir.hot_root_append(func, write1)
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, shared))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, after1))
  @ir.hot_root_append(func, @ir.hot_build_drop(func, unadmitted))
  (
    func,
    [
      before, cross, operand, after0, after1, unadmitted, detached, write0, write1,
    ],
  )
}

///|
test "DAE2 entry finalization preserves complete shared-DAG source rows" {
  let (func, ids) = dae2_entry_finalization_fixture(4)
  let roots = @ir.hot_root_span(func)
  let revision = @ir.hot_revision_current(func)
  let actual = dae2_entry_read_sources(func).unwrap()
  assert_eq(actual, dae2_entry_finalization_reference(func).unwrap())
  assert_eq(actual[ids[0]], -1)
  assert_eq(actual[ids[1]], -3)
  assert_eq(actual[ids[2]], -1)
  assert_eq(actual[ids[3]], ids[7])
  assert_eq(actual[ids[4]], ids[8])
  assert_eq(actual[ids[5]], -2)
  assert_eq(actual[ids[6]], -2)
  for node in 0..<@ir.hot_node_count(func) {
    if !(@ir.hot_node_op(func, node) is @ir.LocalGet) {
      assert_eq(actual[node], -2)
    }
  }
  assert_eq(@ir.hot_root_span(func), roots)
  assert_eq(@ir.hot_revision_current(func), revision)
}

///|
test "DAE2 entry finalization keeps prior rows independent after new writes" {
  let (func, ids) = dae2_entry_finalization_fixture(2)
  let first = dae2_entry_read_sources(func).unwrap()
  let saved = first.copy()
  @ir.hot_root_append(
    func,
    @ir.hot_build_local_set(
      func,
      0,
      @ir.hot_build_const_i32(func, @lib.I32(31)),
    ),
  )
  let later = dae2_entry_read_sources(func).unwrap()
  assert_eq(later, dae2_entry_finalization_reference(func).unwrap())
  assert_eq(later[ids[3]], -2)
  assert_eq(first, saved)
  assert_eq(first[ids[3]], ids[7])
}

///|
test "DAE2 entry finalization retains full-flow fallback for shared root writes" {
  let (func, ids) = dae2_entry_finalization_fixture(2)
  // A write also nested under another root is intentionally unsupported by
  // this entry-only proof; the caller must use the complete LocalGraph path.
  @ir.hot_root_append(
    func,
    @ir.hot_build_block(func, @lib.BlockType::void_(), [ids[7]]),
  )
  let revision = @ir.hot_revision_current(func)
  assert_true(dae2_entry_read_sources(func) is None)
  assert_true(dae2_entry_finalization_reference(func) is None)
  assert_eq(@ir.hot_revision_current(func), revision)
}
