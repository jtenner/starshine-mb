///|
test "DAE path interning keeps signed values distinct across parent nodes" {
  let values = [-2147483648, -1, 0, 1, 2147483647]
  let root = DaeStablePath::empty()
  let prefixes = values.map(fn(value) { root.append(value) })
  let paths : Array[DaeStablePath] = []
  for prefix in prefixes {
    for value in values {
      paths.push(prefix.append(value))
    }
  }
  assert_eq(root.workspace.nodes.length(), 30)
  let mut index = 0
  for parent in 0..<values.length() {
    for value in values {
      let path = paths[index]
      assert_eq(path.to_array(), [values[parent], value])
      assert_eq(prefixes[parent].append(value).tail, path.tail)
      assert_eq(root.workspace.nodes[path.tail].parent, prefixes[parent].tail)
      index += 1
    }
    assert_eq(root.append(values[parent]).tail, prefixes[parent].tail)
    assert_eq(prefixes[parent].to_array(), [values[parent]])
  }
  assert_eq(root.workspace.nodes.length(), 30)
  assert_eq(root.to_array(), [])
}

///|
test "DAE path selection resolves extreme signed keys without selecting siblings" {
  let root = DaeStablePath::empty()
  let high = root.append(2147483647)
  let low = root.append(-2147483648)
  let high_arm = high.append(0)
  let low_arm = low.append(4)
  let first = high_arm.append(-2147483648)
  let second = low_arm.append(2147483647)
  let sibling = high.append(1).append(-1)
  let selection = dae_stable_rewrite_selection([first, second]).unwrap()
  assert_eq(selection.selected_nodes, 6)
  assert_eq(
    dae_stable_rewrite_selected_child(selection, -1, 2147483647),
    Some(high.tail),
  )
  assert_eq(
    dae_stable_rewrite_selected_child(selection, -1, -2147483648),
    Some(low.tail),
  )
  assert_eq(
    dae_stable_rewrite_selected_child(selection, high_arm.tail, -2147483648),
    Some(first.tail),
  )
  assert_eq(
    dae_stable_rewrite_selected_child(selection, low_arm.tail, 2147483647),
    Some(second.tail),
  )
  assert_eq(dae_stable_rewrite_selected_child(selection, high.tail, 1), None)
  assert_eq(dae_stable_rewrite_selected_child(selection, -1, -1), None)
  assert_eq(first.to_array(), [2147483647, 0, -2147483648])
  assert_eq(second.to_array(), [-2147483648, 4, 2147483647])
  assert_eq(sibling.to_array(), [2147483647, 1, -1])
}
