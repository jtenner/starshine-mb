///|
test "large local-flow joins preserve encounter order and immutable subsets" {
  let lhs = Array::makei(40, fn(index) { 79 - index })
  let rhs = Array::makei(40, fn(index) { 40 + index })
  let subset = local_graph_join_sources(lhs, rhs)
  assert_true(physical_equal(subset, lhs))
  assert_eq(subset, lhs)
  let rhs = [40, 39, 38, 39, 37, 40, 36, 35, 34]
  let result = local_graph_join_indexed_sources(lhs, rhs)
  let expected = lhs.copy()
  expected.append([39, 38, 37, 36, 35, 34])
  assert_eq(result, expected)
  assert_eq(lhs, Array::makei(40, fn(index) { 79 - index }))
  assert_eq(rhs, [40, 39, 38, 39, 37, 40, 36, 35, 34])
}

///|
test "ordered source subset reuses lhs without a membership index" {
  let lhs = [9, 8, 7, 6, 5, 4, 3, 2, 1]
  let builds = [0]
  let subset = local_graph_join_indexed_sources(
    lhs,
    [7, 6, 5],
    membership_builds=Some(builds),
  )
  assert_true(physical_equal(subset, lhs))
  assert_eq(subset, [9, 8, 7, 6, 5, 4, 3, 2, 1])
  assert_eq(builds[0], 0)
  let extended = local_graph_join_indexed_sources(
    lhs,
    [7, 6, 0],
    membership_builds=Some(builds),
  )
  assert_eq(extended, [9, 8, 7, 6, 5, 4, 3, 2, 1, 0])
  assert_eq(builds[0], 1)
  assert_eq(lhs, [9, 8, 7, 6, 5, 4, 3, 2, 1])
}
