///|
test "coalesce dense live cliques update exact interference bits without pair insertion" {
  let actual = CLCfgSparseInterferences::new(70)
  let reference = CLCfgSparseInterferences::new(70)
  let members = Array::makei(32, fn(i) { i * 2 })
  cl_cfg_sparse_add_interference(actual, 1, 69)
  cl_cfg_sparse_add_interference(reference, 1, 69)
  let pairs = cl_cfg_sparse_add_live_member_interferences(actual, members)
  ignore(cl_clique_reference(reference, members))
  assert_eq(actual.rows, reference.rows)
  assert_eq(pairs, 0)
  for local in 0..<70 {
    assert_false(cl_cfg_sparse_interferes(actual, local, local))
  }
  assert_true(cl_cfg_sparse_interferes(actual, 1, 69))
}

///|
test "coalesce dense live cliques preserve filtering duplicates and partial words" {
  let actual = CLCfgSparseInterferences::new(70)
  let reference = CLCfgSparseInterferences::new(70)
  let members = [
    -1, 70, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 64, 65, 66, 67, 68, 69, 69,
  ]
  for _ in 0..<2 {
    ignore(cl_cfg_sparse_add_live_member_interferences(actual, members))
    ignore(cl_clique_reference(reference, members))
    assert_eq(actual.rows, reference.rows)
  }
  for row in actual.rows {
    assert_eq(row.words[1] >> 6, 0UL)
  }
  assert_false(cl_cfg_sparse_interferes(actual, 69, 69))
  assert_true(cl_cfg_sparse_interferes(actual, 0, 69))
  assert_false(cl_cfg_sparse_interferes(actual, 9, 10))
}
