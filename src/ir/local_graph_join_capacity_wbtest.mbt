///|
test "small ordered source joins allocate enough space for newly encountered sources" {
  let lhs = [1, 2, 3]
  let rhs = [2, 5, 1, 6, 5]
  let growths = [0]
  let joined = local_graph_join_sources(lhs, rhs, buffer_growths=Some(growths))
  assert_eq(joined, [1, 2, 3, 5, 6])
  assert_eq(lhs, [1, 2, 3])
  assert_eq(rhs, [2, 5, 1, 6, 5])
  assert_eq(growths[0], 0)
  let subset = local_graph_join_sources(
    joined,
    [6, 1, 3],
    buffer_growths=Some(growths),
  )
  assert_true(physical_equal(subset, joined))
  assert_eq(growths[0], 0)
}
