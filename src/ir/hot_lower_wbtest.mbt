///|
test "hot lower local-read cache distinguishes constant and local-dependent roots" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let constant_set = hot_build_local_set(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let dependent_set = hot_build_local_set(func, 1, hot_build_local_get(func, 0))
  let cache = Array::make(hot_node_count(func), -1)

  assert_false(hot_lower_impl_node_reads_local(func, constant_set, cache))
  @debug.assert_eq(cache[constant_set], 0)
  assert_true(hot_lower_impl_node_reads_local(func, dependent_set, cache))
  @debug.assert_eq(cache[dependent_set], 1)
}
