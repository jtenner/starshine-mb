///|
fn dae2_single_row_reference_entry(
  func : @ir.HotFunc,
  visits? : Array[Int]? = None,
  interval_builds? : Array[Int]? = None,
  known_writes? : Array[Int]? = None,
  opaque? : Bool = false,
  write_census_visits? : Array[Int]? = None,
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
    return dae2_single_row_reference_sources(func, entry_writes, visits~)
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
fn dae2_single_row_reference_sources(
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
