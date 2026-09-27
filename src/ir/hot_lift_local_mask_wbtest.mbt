///|
fn hot_lift_local_mask_fixture(depth : Int) -> (HotFunc, NodeId) {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(128, @lib.ValType::i32())),
  )
  let mut value = hot_build_local_get(func, 0)
  for idx in 0..<depth {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_const_i32(func, @lib.I32(idx)),
    )
  }
  (func, value)
}

///|
test "lift local masks bound repeated negative walks and preserve real dependencies" {
  let (func, value) = hot_lift_local_mask_fixture(8)
  let masks = HotLiftLocalAccessMasks::new()
  let visits = [0]
  for local in 1..<5 {
    assert_false(
      hot_lift_impl_value_conflicts_with_local_access(
        func,
        value,
        local,
        true,
        masks=Some(masks),
        node_visits=Some(visits),
      ),
    )
  }
  assert_true(
    visits[0] <= hot_node_count(func) + 4,
    msg="local dependency node visits: \{visits[0]}",
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(masks),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      false,
      masks=Some(masks),
    ),
  )
}

///|
test "lift local masks resolve collisions exactly and include newly appended values" {
  let (func, value) = hot_lift_local_mask_fixture(4)
  let masks = HotLiftLocalAccessMasks::new()
  // Locals 0 and 64 share a mask bit. A positive bit never establishes a hazard.
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      true,
      masks=Some(masks),
    ),
  )
  let write = hot_build_local_tee(
    func,
    64,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let joined = hot_build_binary(func, @lib.ValType::i32(), value, write)
  for node in [value, write, joined] {
    for local in [0, 1, 63, 64, 65, 127] {
      for is_write in [false, true] {
        assert_eq(
          hot_lift_impl_value_conflicts_with_local_access(
            func,
            node,
            local,
            is_write,
            masks=Some(masks),
          ),
          hot_lift_impl_value_conflicts_with_local_access(
            func, node, local, is_write,
          ),
        )
      }
    }
  }
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      joined,
      64,
      false,
      masks=Some(masks),
    ),
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      joined,
      0,
      true,
      masks=Some(masks),
    ),
  )
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      HOT_NONE_NODE,
      0,
      true,
      masks=Some(masks),
    ),
  )
}

///|
test "lift local masks include both conditional regions without changing capture selection" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(128, @lib.ValType::i32())),
  )
  let left = hot_build_local_tee(
    func,
    1,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let right = hot_build_local_tee(
    func,
    65,
    hot_build_const_i32(func, @lib.I32(9)),
  )
  let value = hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    hot_build_local_get(func, 0),
    [left],
    else_body=Some([right]),
  )
  let masks = HotLiftLocalAccessMasks::new()
  for local in [0, 1, 2, 64, 65, 66] {
    for is_write in [false, true] {
      assert_eq(
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          local,
          is_write,
          masks=Some(masks),
        ),
        hot_lift_impl_value_conflicts_with_local_access(
          func, value, local, is_write,
        ),
      )
    }
  }
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      1,
      false,
      masks=Some(masks),
    ),
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      65,
      false,
      masks=Some(masks),
    ),
  )
}
