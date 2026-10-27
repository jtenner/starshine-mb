///|
fn dae_first_child_assert_workspace(
  left : DaeStablePath,
  right : DaeStablePath,
) -> Unit raise {
  assert_eq(left.tail, right.tail)
  assert_eq(left.length, right.length)
  assert_eq(left.to_array(), right.to_array())
  assert_eq(left.workspace.nodes.length(), right.workspace.nodes.length())
  for i in 0..<left.workspace.nodes.length() {
    let a = left.workspace.nodes[i]
    let b = right.workspace.nodes[i]
    assert_eq((a.parent, a.value, a.depth), (b.parent, b.value, b.depth))
  }
  assert_eq(left.workspace.active_stamps, right.workspace.active_stamps)
  assert_eq(left.workspace.call_stamps, right.workspace.call_stamps)
  assert_eq(left.workspace.generation, right.workspace.generation)
}

///|
test "DAE first child interning keeps canonical IDs signed siblings and retained paths" {
  let actual = DaeStablePath::empty()
  let reference = DaeStablePath::empty()
  let retained : Array[(DaeStablePath, DaeStablePath)] = []
  for
    values in [
      [4, 0, 7],
      [4, 1, 9],
      [4, 0, 7],
      [-1],
      [-2147483648],
      [2147483647],
      [4, 2, 11],
    ] {
    let mut a = actual
    let mut b = reference
    for value in values {
      a = a.append(value)
      b = dae_first_child_frozen_append(b, value)
      dae_first_child_assert_workspace(a, b)
    }
    retained.push((a, b))
  }
  for i in 0..<48 {
    let a = actual.append(i).append(0).append(i + 1)
    let b = dae_first_child_frozen_append(
      dae_first_child_frozen_append(
        dae_first_child_frozen_append(reference, i),
        0,
      ),
      i + 1,
    )
    dae_first_child_assert_workspace(a, b)
  }
  for pair in retained {
    dae_first_child_assert_workspace(pair.0, pair.1)
  }
  let a_paths = [retained[0].0, retained[1].0]
  let b_paths = [retained[0].1, retained[1].1]
  let a = dae_stable_rewrite_selection(a_paths).unwrap()
  let b = dae_stable_rewrite_selection(b_paths).unwrap()
  assert_eq(a.selected_nodes, b.selected_nodes)
  for parent in -1..<actual.workspace.nodes.length() {
    for value in [-2147483648, -1, 0, 1, 2, 4, 7, 9, 2147483647] {
      assert_eq(
        dae_stable_rewrite_selected_child(a, parent, value),
        dae_stable_rewrite_selected_child(b, parent, value),
      )
    }
  }
  dae_first_child_assert_workspace(actual, reference)
  actual.workspace.generation = 2147483647
  reference.workspace.generation = 2147483647
  let a = dae_stable_rewrite_selection(a_paths).unwrap()
  let b = dae_stable_rewrite_selection(b_paths).unwrap()
  assert_eq(a.generation, 1)
  assert_eq(a.selected_nodes, b.selected_nodes)
  dae_first_child_assert_workspace(actual, reference)
  assert_true(
    dae_stable_rewrite_selection([
      a_paths[0],
      dae_stable_path_from_array([4, 0, 7]),
    ])
    is None,
  )
}

///|
fn dae_first_child_fixture(depth : Int32) -> @lib.Module {
  let wat = StringBuilder()
  wat.write_string(
    "(module (func $a (param i32) (result i32) local.get 0) (func $b (param i64) (result i64) local.get 0) (func (export \"run\") (result i64) ",
  )
  for _ in 0..<depth {
    wat.write_string("block (result i64) ")
  }
  wat.write_string("i32.const 7 call $a drop i64.const 9 call $b ")
  for _ in 0..<depth {
    wat.write_string("end ")
  }
  wat.write_string("))")
  pass_test_module_from_wat(wat.to_string())
}

///|
test "DAE first child graph paths retain productive bytes effects trace and ownership" {
  let input = dae_first_child_fixture(6)
  let saved = @binary.encode_module(input).unwrap()
  let actual = dae_current_boundary_graph_new(input)
  let expected = dae_first_child_frozen_current_boundary_graph_new(input)
  dae_first_child_assert_graph_bounded(actual, expected)
  // This helper checks real parameter removal, exact effects, trace order,
  // output bytes, validity, custom metadata and retained source ownership.
  for optimize in [false, true] {
    dae_boundary_syntax_compare_core(input, optimize)
  }
  dae_first_child_assert_graph_bounded(actual, expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
// A controlled native Callgrind window must inspect calls from the normal
// append owner to UInt64->Int HashMap get/set, not all-time process totals.
fn dae_first_child_profile_once(
  input : @lib.Module,
  expected : DaeCurrentBoundaryGraph,
) -> Unit raise {
  let actual = dae_current_boundary_graph_new(input)
  dae_first_child_assert_graph_bounded(actual, expected)
}

///|
#skip("dedicated actual native hash-call RED after bounded behavior checks")
test "profile DAE first child chain avoids per-prefix hashing" {
  let input = pass_test_module_from_wat(
    "(module (func $target (param i32) (result i32) local.get 0) (func (export \"run\") (result i32) block (result i32) block (result i32) block (result i32) i32.const 7 call $target end end end))",
  )
  let saved = @binary.encode_module(input).unwrap()
  @validate.validate_module(input).unwrap()
  let expected = dae_first_child_frozen_current_boundary_graph_new(input)
  dae_first_child_profile_once(input, expected)
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}
