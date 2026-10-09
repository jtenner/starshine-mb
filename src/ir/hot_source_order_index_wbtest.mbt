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
  // Later reads remain relevant after the first access falls below the bound.
  assert_true(
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
test "source-order conflict checks later reads after the lower bound" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let write0 = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let write1 = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let carried = hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [write0, write1],
  )
  let read0 = hot_build_local_get(func, 0)
  let read1 = hot_build_local_get(func, 1)
  let current = hot_build_tuple_make(
    func,
    [@lib.ValType::i32(), @lib.ValType::i32()],
    [read0, read1],
  )
  let facts = HotSourceOrderFacts::new(func)
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      before_access_order=hot_node_get(func, read0).order,
    ),
  )
}

///|
test "bounded source-order conflicts scan wide readers once" {
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
  let early = Array::makei(32, fn(local) { hot_build_local_get(func, local) })
  let late = Array::makei(32, fn(local) { hot_build_local_get(func, local) })
  let reads : Array[NodeId] = []
  for id in early {
    reads.push(id)
  }
  for id in late {
    reads.push(id)
  }
  let current = hot_build_tuple_make(
    func,
    Array::make(64, @lib.ValType::i32()),
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
      before_access_order=hot_node_get(func, early[31]).order,
      access_visits=Some(visits),
    ),
  )
  assert_true(visits[0] <= 128, msg="visited \{visits[0]} accesses")
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
        // Exhaustive reference retains the first matching access in range.
        let mut first = count
        for write_id in writes {
          let write = hot_node_get(func, write_id)
          if write.order > after {
            for access_id in accesses {
              let access = hot_node_get(func, access_id)
              if access.imm0 == write.imm0 &&
                access.order > before &&
                access.order < first {
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
