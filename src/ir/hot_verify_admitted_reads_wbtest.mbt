///|
// Frozen checked traversal. Callers must first validate node spans and refs,
// as hot_verify_core_impl does before either child-graph implementation.
fn admitted_reads_reference_child_graph(
  func : HotFunc,
  postorder : Array[NodeId]?,
) -> Result[Unit, HotVerifyError] {
  let marks = Array::make(hot_node_count(func), b'\x00')
  let nodes : Array[NodeId] = []
  let slots : Array[Int32] = []
  for start in 0..<hot_node_count(func) {
    if !hot_node_is_live(func, start) || marks[start] != b'\x00' {
      continue
    }
    marks[start] = b'\x01'
    nodes.push(start)
    slots.push(0)
    while !nodes.is_empty() {
      let top = nodes.length() - 1
      let current = nodes[top]
      let node = hot_node_get(func, current)
      let slot = slots[top]
      if slot == node.child_count {
        marks[current] = b'\x02'
        if postorder is Some(order) {
          order.push(current)
        }
        ignore(nodes.pop())
        ignore(slots.pop())
        continue
      }
      slots[top] = slot + 1
      let child = hot_child_get(func, current, slot)
      if child == HOT_NONE_NODE {
        continue
      }
      if marks[child] == b'\x01' {
        return Err(HotVerifyError::InvalidChildRef(current, slot, child))
      }
      if marks[child] == b'\x00' {
        marks[child] = b'\x01'
        nodes.push(child)
        slots.push(0)
      }
    }
  }
  Ok(())
}

///|
fn admitted_reads_assert_control(
  func : HotFunc,
  expected : Result[Unit, HotVerifyError],
) -> Unit raise {
  let revision = hot_revision_current(func)
  let nodes = func.nodes.copy()
  let children = func.children.copy()
  let roots = func.roots.copy()
  assert_eq(hot_verify_control(func), expected)
  assert_eq(hot_verify_all(func, cache=Some(())), expected)
  assert_eq(func.nodes, nodes)
  assert_eq(func.children, children)
  assert_eq(func.roots, roots)
  assert_eq(hot_revision_current(func), revision)
}

///|
test "admitted verifier reads preserve malformed detached span ref and cycle priority" {
  // These intentionally invalid detached graphs must fail before traversal.
  let func = HotFunc::new()
  let value = hot_build_const_i32(func, @lib.I32(1))
  let cycle = hot_build_drop(func, value)
  hot_child_set(func, cycle, 0, cycle)
  let later = hot_build_drop(func, value)
  let saved = hot_node_get(func, later)
  let invalid_base = func.children.length() + 1
  func.nodes[later] = { ..saved, child_base: invalid_base, }
  admitted_reads_assert_control(
    func,
    Err(HotVerifyError::InvalidChildSpan(later, invalid_base, 1)),
  )
  func.nodes[later] = saved
  let missing = hot_node_count(func) + 7
  func.children[saved.child_base] = missing
  admitted_reads_assert_control(
    func,
    Err(HotVerifyError::InvalidChildRef(later, 0, missing)),
  )
  func.children[saved.child_base] = value
  admitted_reads_assert_control(
    func,
    Err(HotVerifyError::InvalidChildRef(cycle, 0, cycle)),
  )
}

///|
test "admitted verifier reads preserve absent control children after core admission" {
  // The sentinel is valid core storage, but invalid as a block body child.
  let func = HotFunc::new()
  let child = hot_build_nop(func)
  let block = hot_build_block(func, @lib.BlockType::void_(), [child])
  let node = hot_node_get(func, block)
  func.children[node.child_base] = HOT_NONE_NODE
  assert_eq(hot_verify_core(func), Ok(()))
  admitted_reads_assert_control(
    func,
    Err(HotVerifyError::InvalidControlChild(block, 0, HOT_NONE_NODE)),
  )
}

///|
test "admitted verifier reads preserve shared scope rejection and repeated root admission" {
  let func = HotFunc::new()
  let outer = hot_build_block(func, @lib.BlockType::void_(), [])
  let target = hot_control_node_label(func, outer)
  let branch = hot_build_br(func, target)
  let inner = hot_build_block(func, @lib.BlockType::void_(), [branch])
  ignore(hot_replace_child_span(func, outer, [inner]))
  hot_root_append(func, outer)
  admitted_reads_assert_control(func, Ok(()))
  hot_root_append(func, inner)
  // This intentionally invalid occurrence lacks the outer target's scope.
  admitted_reads_assert_control(
    func,
    Err(HotVerifyError::InvalidBranchTarget(branch, target)),
  )
  ignore(func.roots.pop())
  hot_root_append(func, outer)
  admitted_reads_assert_control(func, Ok(()))
}

///|
test "admitted verifier reads preserve postorder sharing tombstones and catch controls" {
  for shared in [false, true] {
    let func = admitted_reads_perf_fixture(8, shared)
    let before : Array[NodeId] = []
    let after : Array[NodeId] = []
    assert_eq(admitted_reads_reference_child_graph(func, Some(before)), Ok(()))
    assert_eq(hot_verify_child_graph(func, Some(after)), Ok(()))
    assert_eq(after, before)
    admitted_reads_assert_control(func, Ok(()))
  }
  for with_catch in [false, true] {
    admitted_reads_assert_control(
      catch_layout_perf_fixture(8, with_catch),
      Ok(()),
    )
  }
}
