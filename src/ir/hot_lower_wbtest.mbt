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

///|
test "hot lower dependency suffix minima skip pure roots and retain earlier effects" {
  let func = HotFunc::new(locals=HotLocals::new(locals=[@lib.ValType::i32()]))
  let carried_call = hot_build_call(func, 0, [@lib.ValType::i32()], [])
  let pure_read = hot_build_drop(func, hot_build_local_get(func, 0))
  let later_call = hot_build_call(func, 1, [@lib.ValType::i32()], [carried_call])
  let future_call_use = hot_build_drop(func, later_call)
  let roots = [pure_read, future_call_use]
  let cache = Array::make(hot_node_count(func), -2)

  let suffix_minima = hot_lower_impl_build_preceding_dependency_suffix_minima(
    func, roots, cache,
  )
  @debug.assert_eq(suffix_minima.length(), 3)
  @debug.assert_eq(suffix_minima[2], hot_node_count(func))
  @debug.assert_eq(suffix_minima[1], carried_call)
  @debug.assert_eq(suffix_minima[0], carried_call)

  let pure_drop = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(7)))
  let pure_suffix = hot_lower_impl_build_preceding_dependency_suffix_minima(
    func,
    [pure_drop],
    Array::make(hot_node_count(func), -2),
  )
  @debug.assert_eq(pure_suffix, [hot_node_count(func), hot_node_count(func)])
  assert_false(
    hot_lower_impl_roots_may_need_future_dependencies(
      func,
      [pure_drop],
      Array::make(hot_node_count(func), -1),
    ),
  )
  assert_true(
    hot_lower_impl_roots_may_need_future_dependencies(
      func,
      [pure_read],
      Array::make(hot_node_count(func), -1),
    ),
  )
}
