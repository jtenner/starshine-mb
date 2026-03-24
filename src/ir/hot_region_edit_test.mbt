///|
test "root region helpers support insert remove and splice" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let third = hot_build_const_i32(func, @lib.I32(3))
  let root_region = HotRegionRef::root()

  hot_region_insert(func, root_region, 0, [first, second])
  assert_eq(hot_region_root_count(func, root_region), 2)
  assert_eq(hot_region_get(func, root_region, 0), first)
  assert_eq(hot_region_get(func, root_region, 1), second)

  let removed = hot_region_remove(func, root_region, 0, 1)
  assert_eq(removed, [first])
  assert_eq(hot_region_root_count(func, root_region), 1)
  assert_eq(hot_region_get(func, root_region, 0), second)

  let spliced = hot_region_splice(func, root_region, 1, 0, [third])
  assert_eq(spliced, [])
  assert_eq(hot_root_span(func), [second, third])
}

///|
test "body region helpers rewrite direct block and loop bodies" {
  let func = HotFunc::new()
  let first = hot_build_const_i32(func, @lib.I32(1))
  let second = hot_build_const_i32(func, @lib.I32(2))
  let third = hot_build_const_i32(func, @lib.I32(3))
  let block_id = hot_build_block(func, @lib.BlockType::void_(), [first])
  let loop_id = hot_build_loop(func, @lib.BlockType::void_(), [second])

  let block_region = hot_region_body_ref(func, block_id)
  assert_eq(hot_region_root_count(func, block_region), 1)
  hot_region_replace_body(func, block_region, [second, third])
  assert_eq(hot_child_span(func, block_id), [second, third])

  let loop_region = hot_region_body_ref(func, loop_id)
  let removed = hot_region_splice(func, loop_region, 0, 1, [first, third])
  assert_eq(removed, [second])
  assert_eq(hot_child_span(func, loop_id), [first, third])
}

///|
test "structured region refs rewrite if and try wrapper bodies" {
  let func = HotFunc::new()
  let condition = hot_build_const_i32(func, @lib.I32(1))
  let then_a = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(7)))
  let then_b = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(8)))
  let else_a = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(9)))
  let else_b = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(10)))
  let catch_a = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(11)))
  let catch_b = hot_build_drop(func, hot_build_const_i32(func, @lib.I32(12)))
  let if_id = hot_build_if(
    func,
    @lib.BlockType::void_(),
    condition,
    [then_a],
    else_body=Some([else_a]),
  )
  let try_id = hot_build_try(
    func,
    @lib.BlockType::void_(),
    [then_b],
    catch_body=Some([catch_a]),
  )

  let then_region = hot_region_then_ref(func, if_id)
  let else_region = hot_region_else_ref(func, if_id).unwrap()
  let catch_region = hot_region_catch_ref(func, try_id).unwrap()

  hot_region_replace_body(func, then_region, [then_b])
  let removed_else = hot_region_splice(func, else_region, 0, 1, [else_b, else_a])
  let replaced_catch = hot_region_set(func, catch_region, 0, catch_b)

  assert_eq(removed_else, [else_a])
  assert_eq(replaced_catch, catch_a)
  assert_eq(hot_region_root_count(func, then_region), 1)
  assert_eq(hot_region_get(func, then_region, 0), then_b)
  assert_eq(hot_region_root_count(func, else_region), 2)
  assert_eq(hot_region_get(func, else_region, 0), else_b)
  assert_eq(hot_region_get(func, else_region, 1), else_a)
  assert_eq(hot_region_get(func, catch_region, 0), catch_b)
}
