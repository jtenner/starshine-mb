///|
test "DAE stable path array copies preserve prefixes across workspace growth" {
  let root = DaeStablePath::empty()
  let prefix = root.append(4)
  let left = prefix.append(0).append(7)
  let right = prefix.append(1).append(9)
  let paths = [left, right]
  let saved = paths.copy()
  let nodes = root.workspace.nodes.copy()
  let left_node = nodes[left.tail]
  paths[0] = left.append(0).append(13)
  // An array copy owns its slots while each path retains the shared workspace.
  nodes[left.tail] = { parent: -1, value: 88, depth: 1, first_child: -1, }
  assert_eq(root.to_array(), [])
  assert_eq(prefix.to_array(), [4])
  assert_eq(saved[0].to_array(), [4, 0, 7])
  assert_eq(saved[1].to_array(), [4, 1, 9])
  assert_eq(paths[0].to_array(), [4, 0, 7, 0, 13])
  assert_eq(left_node.parent, prefix.append(0).tail)
  assert_eq(left_node.value, 7)
  assert_eq(left_node.depth, 3)
  assert_eq(root.workspace.nodes[left.tail].value, 7)
  assert_true(physical_equal(saved[0].workspace, paths[0].workspace))
  let repeated = prefix.append(0).append(7)
  assert_eq(repeated.tail, left.tail)
  assert_true(dae_stable_path_equal(repeated, saved[0]))
  let out = [91]
  saved[1].append_to(out)
  assert_eq(out, [91, 4, 1, 9])
}

///|
test "DAE stable path branch selection retains shared prefixes and owner checks" {
  let root = DaeStablePath::empty()
  let prefix = root.append(4)
  let left_branch = prefix.append(0)
  let right_branch = prefix.append(1)
  let left = left_branch.append(7)
  let right = right_branch.append(9)
  let unrelated = prefix.append(2).append(11)
  let selection = dae_stable_rewrite_selection([left, right]).unwrap()
  assert_eq(selection.selected_nodes, 5)
  assert_eq(
    dae_stable_rewrite_selected_child(selection, -1, 4),
    Some(prefix.tail),
  )
  assert_eq(
    dae_stable_rewrite_selected_child(selection, prefix.tail, 0),
    Some(left_branch.tail),
  )
  assert_eq(
    dae_stable_rewrite_selected_child(selection, prefix.tail, 1),
    Some(right_branch.tail),
  )
  assert_eq(dae_stable_rewrite_selected_child(selection, prefix.tail, 2), None)
  assert_eq(unrelated.to_array(), [4, 2, 11])
  let foreign = dae_stable_path_from_array([4, 0, 7])
  assert_true(dae_stable_path_equal(left, foreign))
  // Equal path values from distinct workspaces cannot form one rewrite owner.
  assert_true(dae_stable_rewrite_selection([left, foreign]) is None)
  assert_eq(left.to_array(), [4, 0, 7])
  assert_eq(right.to_array(), [4, 1, 9])
}
