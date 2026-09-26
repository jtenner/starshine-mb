///|
test "source-order conflicts index repeated local accesses once" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(32, @lib.ValType::i32())),
  )
  let writes = Array::makei(32, fn(local) {
    hot_build_local_tee(func, local, hot_build_const_i32(func, @lib.I32(local)))
  })
  let carried = hot_build_tuple_make(
    func,
    Array::make(32, @lib.ValType::i32()),
    writes,
  )
  let reads = Array::makei(32, fn(local) { hot_build_local_get(func, local) })
  let current = hot_build_tuple_make(
    func,
    Array::make(32, @lib.ValType::i32()),
    reads,
  )
  let facts = HotSourceOrderFacts::new(func)
  let visits = [0]
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      access_visits=Some(visits),
    ),
  )
  assert_eq(visits[0], 32)
  visits[0] = 0
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      access_visits=Some(visits),
    ),
  )
  assert_eq(visits[0], 0)
  // The minimum access determines the interval, not any later matching read.
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      before_access_order=hot_node_get(func, reads[0]).order,
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      access_before_order=Some(hot_node_get(func, reads[0]).order),
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      after_order=hot_node_get(func, writes[31]).order,
    ),
  )
}

///|
test "source-order access index preserves filtered writes and strict minimum bounds" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(16, @lib.ValType::i32())),
  )
  let writes = [1, 2, 0].map(fn(local) {
    hot_build_local_tee(func, local, hot_build_const_i32(func, @lib.I32(local)))
  })
  let carried = hot_build_tuple_make(
    func,
    Array::make(3, @lib.ValType::i32()),
    writes,
  )
  let accesses = [0, 1, 1, 10].map(fn(local) {
    hot_build_local_get(func, local)
  })
  accesses.push(
    hot_build_local_tee(func, 2, hot_build_const_i32(func, @lib.I32(9))),
  )
  accesses.push(hot_build_local_get(func, 1))
  let current = hot_build_tuple_make(
    func,
    Array::make(6, @lib.ValType::i32()),
    accesses,
  )
  let unrelated = hot_build_tuple_make(
    func,
    Array::make(6, @lib.ValType::i32()),
    Array::makei(6, fn(_) { hot_build_local_get(func, 15) }),
  )
  let facts = HotSourceOrderFacts::new(func)
  let count = hot_node_count(func)
  for after in [-1, hot_node_get(func, writes[0]).order, count] {
    for before in [-1, hot_node_get(func, accesses[0]).order, count] {
      for upper in [None, Some(hot_node_get(func, accesses[4]).order)] {
        // Exhaustive reference retains the minimum across every matching pair.
        let mut first = count
        for write_id in writes {
          let write = hot_node_get(func, write_id)
          if write.order > after {
            for access_id in accesses {
              let access = hot_node_get(func, access_id)
              if access.imm0 == write.imm0 && access.order < first {
                first = access.order
              }
            }
          }
        }
        assert_eq(
          hot_lower_impl_carried_local_write_conflicts(
            func,
            carried,
            current,
            facts,
            after_order=after,
            before_access_order=before,
            access_before_order=upper,
          ),
          first < upper.or(count) && first > before,
        )
      }
    }
  }
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func, carried, unrelated, facts,
    ),
  )
}
