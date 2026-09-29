///|
test "ordered local source union checks each right-hand candidate once" {
  let lhs = [0, 1, 2]
  let rhs = [0, 1, 3, 3, 4]
  let queries = [0]
  let actual = local_graph_join_sources(
    lhs,
    rhs,
    membership_queries=Some(queries),
  )
  assert_eq(actual, [0, 1, 2, 3, 4])
  assert_eq(lhs, [0, 1, 2])
  assert_eq(rhs, [0, 1, 3, 3, 4])
  assert_eq(queries[0], rhs.length())
  queries[0] = 0
  let subset = local_graph_join_sources(
    lhs,
    [2, 1, 0, 2],
    membership_queries=Some(queries),
  )
  assert_eq(subset, [0, 1, 2])
  assert_true(physical_equal(subset, lhs))
  assert_eq(queries[0], 4)
}
