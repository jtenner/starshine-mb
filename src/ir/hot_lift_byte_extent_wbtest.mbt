///|
test "lift warmed local masks bound positive and high-id collision walks" {
  for writing_value in [false, true] {
    let func = HotFunc::new(
      locals=HotLocals::new(locals=Array::make(128, @lib.ValType::i32())),
    )
    let mut value = if writing_value {
      hot_build_local_tee(func, 0, hot_build_const_i32(func, @lib.I32(7)))
    } else {
      hot_build_local_get(func, 0)
    }
    for i in 0..<8 {
      value = hot_build_binary(
        func,
        @lib.ValType::i32(),
        value,
        hot_build_const_i32(func, @lib.I32(i)),
      )
    }
    let masks = HotLiftLocalAccessMasks::new()
    assert_false(
      hot_lift_impl_value_conflicts_with_local_access(
        func,
        value,
        1,
        !writing_value,
        masks=Some(masks),
      ),
    )
    let saved = func.nodes.copy()
    let revision = hot_revision_current(func)
    for query in [0, 64] {
      let visits = [0]
      assert_eq(
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          query,
          !writing_value,
          masks=Some(masks),
          node_visits=Some(visits),
        ),
        query == 0,
      )
      assert_eq(
        visits[0],
        1,
        msg="completed exact mask must not repeat operand walks",
      )
    }
    assert_eq(func.nodes, saved)
    assert_eq(hot_revision_current(func), revision)
  }
}

///|
test "lift extent preserves high-local hazards and band collisions" {
  for local_id in [0, 63, 64, 252, 253, 300] {
    for writing_value in [false, true] {
      let func = HotFunc::new(
        locals=HotLocals::new(locals=Array::make(400, @lib.ValType::i32())),
      )
      let leaf = if writing_value {
        hot_build_local_tee(
          func,
          local_id,
          hot_build_const_i32(func, @lib.I32(7)),
        )
      } else {
        hot_build_local_get(func, local_id)
      }
      let value = hot_build_binary(
        func,
        @lib.ValType::i32(),
        leaf,
        hot_build_const_i32(func, @lib.I32(1)),
      )
      let masks = HotLiftLocalAccessMasks::new()
      hot_lift_impl_collect_local_access_masks(func, value, masks, None)
      assert_eq(masks.extent[value].to_int(), 2 + (local_id >> 6))
      for query in [local_id, local_id + 64] {
        for is_write in [false, true] {
          assert_eq(
            hot_lift_impl_value_conflicts_with_local_access(
              func,
              value,
              query,
              is_write,
              masks=Some(masks),
            ),
            hot_lift_impl_value_conflicts_with_local_access(
              func, value, query, is_write,
            ),
          )
        }
      }
    }
  }
}

///|
test "lift extent reuses completed DAG rows across append and rebuilds after mutation" {
  let (func, value) = hot_lift_local_mask_fixture(4)
  let masks = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, masks, None)
  assert_eq(masks.extent[value].to_int(), 2)
  let write = hot_build_local_tee(
    func,
    64,
    hot_build_const_i32(func, @lib.I32(7)),
  )
  let shared = hot_build_binary(func, @lib.ValType::i32(), value, value)
  let joined = hot_build_binary(func, @lib.ValType::i32(), shared, write)
  hot_lift_impl_collect_local_access_masks(func, joined, masks, None)
  assert_eq(masks.extent[value].to_int(), 2)
  assert_eq(masks.extent[shared].to_int(), 2)
  assert_eq(masks.extent[joined].to_int(), 131)
  for query in [0, 1, 63, 64, 65, 127] {
    for is_write in [false, true] {
      assert_eq(
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          joined,
          query,
          is_write,
          masks=Some(masks),
        ),
        hot_lift_impl_value_conflicts_with_local_access(
          func, joined, query, is_write,
        ),
      )
    }
  }
  let saved = masks.extent.copy()
  hot_node_set(func, value, hot_node_get(func, write))
  // Semantic mutation requires a fresh cache. Append-only reuse above is safe.
  let fresh = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, fresh, None)
  assert_eq(fresh.extent[value].to_int(), 3)
  assert_eq(masks.extent, saved)
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      0,
      true,
      masks=Some(fresh),
    ),
  )
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      64,
      false,
      masks=Some(fresh),
    ),
  )
}

///|
test "lift extent saturates intentionally invalid negative-local query fixtures" {
  let (func, value) = hot_lift_local_mask_fixture(4)
  // Intentionally invalid IR for query-bound fallback only; full function
  // admission remains the verifier's responsibility and is not claimed here.
  hot_node_set(func, 0, { ..hot_node_get(func, 0), imm0: -1, })
  let masks = HotLiftLocalAccessMasks::new()
  hot_lift_impl_collect_local_access_masks(func, value, masks, None)
  assert_eq(masks.extent[value].to_int(), 255)
  for query in [-65, -1, 0, 63] {
    for is_write in [false, true] {
      assert_eq(
        hot_lift_impl_value_conflicts_with_local_access(
          func,
          value,
          query,
          is_write,
          masks=Some(masks),
        ),
        hot_lift_impl_value_conflicts_with_local_access(
          func, value, query, is_write,
        ),
      )
    }
  }
}

///|
test "lift warmed same-band masks prove high-local positive hazards" {
  let func = HotFunc::new(
    locals=HotLocals::new(locals=Array::make(400, @lib.ValType::i32())),
  )
  let mut value = hot_build_local_get(func, 300)
  for i in 0..<8 {
    value = hot_build_binary(
      func,
      @lib.ValType::i32(),
      value,
      hot_build_const_i32(func, @lib.I32(i)),
    )
  }
  let masks = HotLiftLocalAccessMasks::new()
  assert_false(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      364,
      true,
      masks=Some(masks),
    ),
  )
  let visits = [0]
  assert_true(
    hot_lift_impl_value_conflicts_with_local_access(
      func,
      value,
      300,
      true,
      masks=Some(masks),
      node_visits=Some(visits),
    ),
  )
  assert_eq(
    visits[0],
    1,
    msg="completed single-band mask must not repeat positive operand walks",
  )
}
