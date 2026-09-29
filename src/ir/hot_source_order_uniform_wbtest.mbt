///|
fn source_order_uniform_fixture(
  count : Int,
  local : Int,
) -> (HotFunc, Array[NodeId], NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let roots : Array[NodeId] = []
  let mut value = hot_build_local_get(func, 0)
  roots.push(value)
  for _ in 0..<count {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_local_get(func, 0),
    )
    hot_node_exact_instr_set(func, value, @lib.Instruction::i32_add())
    roots.push(value)
  }
  let write = hot_build_local_set(
    func,
    local,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  hot_root_append(func, hot_build_drop(func, value))
  hot_root_append(func, write)
  (func, roots, write)
}

///|
test "uniform source-order conflicts preserve both directions and strict bounds" {
  for local in [0, 1] {
    let (func, roots, write) = source_order_uniform_fixture(4, local)
    hot_verify_all(func).unwrap()
    let facts = HotSourceOrderFacts::new(func)
    for root in roots {
      assert_false(
        hot_lower_impl_carried_local_write_conflicts(func, root, write, facts),
      )
      assert_eq(
        hot_lower_impl_carried_local_write_conflicts(func, write, root, facts),
        local == 0,
      )
      assert_false(
        hot_lower_impl_carried_local_write_conflicts(
          func,
          write,
          root,
          facts,
          before_access_order=hot_node_get(func, roots[0]).order,
        ),
      )
      assert_false(
        hot_lower_impl_carried_local_write_conflicts(
          func,
          write,
          root,
          facts,
          after_order=hot_node_get(func, write).order,
        ),
      )
    }
  }
}

///|
test "uniform source-order summary retains the latest eligible write and earliest access" {
  let func = HotFunc::new(locals=HotLocals::new(params=[@lib.ValType::i32()]))
  let first = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  let last = hot_build_local_tee(
    func,
    0,
    hot_build_const_i32(func, @lib.I32(2)),
  )
  let carried = hot_build_binary(func, @lib.ValType::i32(), first, last)
  hot_node_exact_instr_set(func, carried, @lib.Instruction::i32_add())
  let current = hot_build_local_get(func, 0)
  hot_root_append(func, hot_build_drop(func, carried))
  hot_root_append(func, hot_build_drop(func, current))
  hot_verify_all(func).unwrap()
  let facts = HotSourceOrderFacts::new(func)
  assert_true(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      after_order=hot_node_get(func, first).order,
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      after_order=hot_node_get(func, last).order,
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      before_access_order=hot_node_get(func, current).order,
    ),
  )
  assert_false(
    hot_lower_impl_carried_local_write_conflicts(
      func,
      carried,
      current,
      facts,
      access_before_order=Some(hot_node_get(func, current).order),
    ),
  )
}
