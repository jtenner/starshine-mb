///|
// Frozen full-header implementation of DAE2's child replacement admission.
fn dae2_field_query_children_reference(
  func : @ir.HotFunc,
  node : Int32,
  children : Array[Int32],
) -> Bool {
  let data = @ir.hot_node_get(func, node)
  if data.child_count == children.length() {
    let mut same = true
    for slot in 0..<children.length() {
      if @ir.hot_child_get(func, node, slot) != children[slot] {
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
// Test-only candidate. Keep the same checked node and child-slot admission.
fn dae2_field_query_children_candidate(
  func : @ir.HotFunc,
  node : Int32,
  children : Array[Int32],
) -> Bool {
  if @ir.hot_child_count(func, node) == children.length() {
    let mut same = true
    for slot in 0..<children.length() {
      if @ir.hot_child_get(func, node, slot) != children[slot] {
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
fn dae2_field_query_prefix_reference(
  func : @ir.HotFunc,
  nodes : Array[Int32],
) -> Array[Int32] {
  nodes.filter(fn(node) { !(@ir.hot_node_get(func, node).op is @ir.Nop) })
}

///|
fn dae2_field_query_prefix_candidate(
  func : @ir.HotFunc,
  nodes : Array[Int32],
) -> Array[Int32] {
  nodes.filter(fn(node) { !(@ir.hot_node_op(func, node) is @ir.Nop) })
}

///|
test "DAE2 child field queries match frozen headers after reordered and resized spans" {
  for implementation in 0..<3 {
    let (func, add, left, right) = dae2_child_fixture()
    let replace = fn(children : Array[Int32]) {
      match implementation {
        0 => dae2_field_query_children_reference(func, add, children)
        1 => dae2_field_query_children_candidate(func, add, children)
        _ => dae2_replace_children_if_changed(func, add, children)
      }
    }
    let saved = @ir.hot_child_span(func, add)
    let revision = @ir.hot_revision_current(func)
    assert_false(replace([left, right]))
    assert_eq(@ir.hot_revision_current(func), revision)
    assert_true(replace([right, left]))
    assert_eq(@ir.hot_child_span(func, add), [right, left])
    assert_eq(saved, [left, right])
    let changed_revision = @ir.hot_revision_current(func)
    assert_false(replace([right, left]))
    assert_eq(@ir.hot_revision_current(func), changed_revision)
    // A rewrite can temporarily clear the span before restoring its operands.
    ignore(@ir.hot_replace_child_span(func, add, []))
    assert_true(replace([left, right]))
    assert_eq(@ir.hot_child_span(func, add), saved)
    assert_false(replace(saved))
    @ir.hot_verify_core(func).unwrap()
  }
}

///|
test "DAE2 prefix field queries preserve effects order and refresh edited live node opcodes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let nop = @ir.hot_build_nop(func)
  let read = @ir.hot_build_local_get(func, 0)
  let write = @ir.hot_build_local_tee(func, 0, read)
  let spare = @ir.hot_build_nop(func)
  let prefix = [nop, write, nop, read, write]
  let saved = prefix.copy()
  let revision = @ir.hot_revision_current(func)
  assert_eq(dae2_field_query_prefix_candidate(func, prefix), [
    write, read, write,
  ])
  assert_eq(
    dae2_field_query_prefix_candidate(func, prefix),
    dae2_field_query_prefix_reference(func, prefix),
  )
  assert_eq(prefix, saved)
  assert_eq(@ir.hot_revision_current(func), revision)
  @ir.hot_delete_node(func, spare)
  // The deletion bitmap path must retain every live effect and repeated use.
  assert_eq(dae2_field_query_prefix_candidate(func, prefix), [
    write, read, write,
  ])
  // HOT allocation appends IDs; edit the same live node through its checked API.
  let saved_nop = @ir.hot_node_get(func, nop)
  @ir.hot_node_set(func, nop, @ir.hot_node_get(func, read))
  assert_true(saved_nop.op is @ir.Nop)
  assert_true(@ir.hot_node_op(func, nop) is @ir.LocalGet)
  let revision = @ir.hot_revision_current(func)
  assert_eq(dae2_field_query_prefix_candidate(func, prefix), prefix)
  assert_eq(
    dae2_field_query_prefix_candidate(func, prefix),
    dae2_field_query_prefix_reference(func, prefix),
  )
  assert_eq(@ir.hot_revision_current(func), revision)
  assert_eq(prefix, saved)
  @ir.hot_verify_core(func).unwrap()
}
