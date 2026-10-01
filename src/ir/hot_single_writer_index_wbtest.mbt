///|
fn single_writer_index_fixture(width : Int) -> (HotFunc, Array[NodeId], NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(width, @lib.ValType::i32())),
  )
  let writes = Array::makei(width, fn(local) {
    hot_build_local_tee(func, local, hot_build_const_i32(func, @lib.I32(local)))
  })
  let current = hot_build_tuple_make(
    func,
    Array::make(width, @lib.ValType::i32()),
    Array::makei(width, fn(local) { hot_build_local_get(func, local) }),
  )
  (func, writes, current)
}

///|
test "source-order singleton writers index a repeatedly queried wide consumer in linear work" {
  let width = 32
  let (func, writes, current) = single_writer_index_fixture(width)
  let facts = HotSourceOrderFacts::new(func)
  let visits = [0]
  for write in writes {
    assert_true(
      hot_lower_impl_carried_local_write_conflicts(
        func,
        write,
        current,
        facts,
        access_visits=Some(visits),
      ),
    )
  }
  assert_true(
    visits[0] <= width * 2,
    msg="singleton queries must not rescan width squared accesses",
  )
}

///|
test "source-order singleton index keeps cold admission snapshot isolation and strict bounds" {
  let (func, writes, current) = single_writer_index_fixture(16)
  let facts = HotSourceOrderFacts::new(func)
  let sibling = HotSourceOrderFacts::new(func)
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      writes[0],
      current,
      facts,
      after_order=hot_node_get(func, writes[0]).order,
    ),
  )
  assert_true(facts.first_local_access_orders.is_empty())
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      writes[0],
      current,
      facts,
    ),
  )
  assert_true(facts.first_local_access_orders.is_empty())
  let visits = [0]
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      writes[1],
      current,
      facts,
      access_visits=Some(visits),
    ),
  )
  assert_eq(visits[0], 16)
  assert_true(facts.first_local_access_orders.contains(current))
  assert_true(sibling.first_local_access_orders.is_empty())
  let minimum = facts.first_local_access_orders
    .get(current)
    .unwrap()
    .get(1)
    .unwrap()
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      writes[1],
      current,
      facts,
      before_access_order=minimum,
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      writes[1],
      current,
      facts,
      access_before_order=Some(minimum),
    ),
  )
}

///|
test "source-order tiny singleton consumers retain allocation-free scans" {
  let (func, writes, current) = single_writer_index_fixture(8)
  let facts = HotSourceOrderFacts::new(func)
  for _ in 0..<2 {
    for write in writes {
      assert_true(
        hot_lower_impl_carried_local_write_conflicts(
          func, write, current, facts,
        ),
      )
    }
  }
  assert_true(facts.first_local_access_orders.is_empty())
}
