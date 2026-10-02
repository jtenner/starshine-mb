///|
test "Coalesce small single-word cliques preserve exact edges without pair insertion" {
  let actual = CLCfgSparseInterferences::new(8)
  let expected = CLCfgSparseInterferences::new(8)
  let members = [0, 1, 3]
  let saved = members.copy()
  // Pair insertion preserves preexisting diagonals and unrelated edges.
  actual.rows[1][1] = true
  expected.rows[1][1] = true
  cl_cfg_sparse_add_interference(actual, 2, 6)
  cl_cfg_sparse_add_interference(expected, 2, 6)
  ignore(cl_clique_reference(expected, members))
  let pairs = cl_cfg_sparse_add_live_member_interferences(actual, members)
  assert_eq(actual.rows, expected.rows)
  assert_true(actual.rows[1][1])
  assert_true(cl_cfg_sparse_interferes(actual, 2, 6))
  assert_eq(members, saved)
  assert_eq(pairs, 0)
}

///|
test "Coalesce scalar clique retains intentional invalid-member filtering and duplicate semantics" {
  let actual = CLCfgSparseInterferences::new(64)
  let expected = CLCfgSparseInterferences::new(64)
  let members = [-1, 64, 0, 31, 63, 63]
  for _ in 0..<2 {
    ignore(cl_clique_reference(expected, members))
    ignore(cl_cfg_sparse_add_live_member_interferences(actual, members))
    assert_eq(actual.rows, expected.rows)
  }
  assert_false(cl_cfg_sparse_interferes(actual, 63, 63))
  assert_true(cl_cfg_sparse_interferes(actual, 0, 63))
  assert_true(cl_cfg_sparse_interferes(actual, 31, 63))
  assert_false(cl_cfg_sparse_interferes(actual, 1, 63))
}

///|
test "Coalesce scalar clique leaves tiny and wider pair paths complete" {
  for count in [2, 65] {
    let actual = CLCfgSparseInterferences::new(count)
    let expected = CLCfgSparseInterferences::new(count)
    let members = if count == 2 { [0, 1] } else { [0, 63, 64] }
    ignore(cl_clique_reference(expected, members))
    let pairs = cl_cfg_sparse_add_live_member_interferences(actual, members)
    assert_eq(actual.rows, expected.rows)
    assert_eq(pairs, if count == 2 { 1 } else { 3 })
  }
}

///|
test "Coalesce noncanonical private row shape retains checked pair fallback" {
  let actual = CLCfgSparseInterferences::new(8)
  let expected = CLCfgSparseInterferences::new(8)
  // This private table intentionally violates the ordinary uniform-row shape.
  // Keep the original path rather than treating a larger row as canonical.
  actual.rows[1].grow(65)
  expected.rows[1].grow(65)
  actual.rows[1][64] = true
  expected.rows[1][64] = true
  ignore(cl_clique_reference(expected, [0, 1, 3]))
  let pairs = cl_cfg_sparse_add_live_member_interferences(actual, [0, 1, 3])
  assert_eq(actual.rows, expected.rows)
  assert_true(actual.rows[1][64])
  assert_eq(pairs, 3)
}
