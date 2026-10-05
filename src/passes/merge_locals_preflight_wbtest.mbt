///|
test "merge-locals stack-carried preflight scans a flat copy region once" {
  let count = 64
  let copies = Array::make(count, "local.get 0 local.set 1").join(" ")
  let func = pass_test_lift_first_func(
    "(module (func (param i32) (local i32) " + copies + "))",
  )
  let visits = [0]

  assert_false(
    merge_locals_region_has_stack_carried_copy(
      func,
      @ir.HotRegionRef::root(),
      visits=Some(visits),
    ),
  )
  assert_true(visits[0] <= count * 3, msg="visits=\{visits[0]}")
}

///|
fn merge_locals_preflight_nested_hazard(kind : Int) -> Bool {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let source_older_read = @ir.hot_build_local_get(func, 0)
  let copy = @ir.hot_build_local_set(func, 1, @ir.hot_build_local_get(func, 0))
  let later_read = @ir.hot_build_drop(func, source_older_read)
  let control = if kind == 0 {
    @ir.hot_build_try(
      func,
      @lib.BlockType::void_(),
      [copy, later_read],
      catch_body=Some([]),
    )
  } else {
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::void_(),
      [],
      [copy, later_read],
      catch_list_body=[],
    )
  }
  @ir.hot_root_append(func, control)
  merge_locals_region_has_stack_carried_copy(func, @ir.HotRegionRef::root())
}

///|
test "merge-locals stack-carried preflight traverses legacy try and try-table regions" {
  assert_true(merge_locals_preflight_nested_hazard(0))
  assert_true(merge_locals_preflight_nested_hazard(1))
}

///|
test "merge-locals stack-carried preflight visits shared DAG nodes once" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut value = @ir.hot_build_local_get(func, 0)
  for _ in 0..<18 {
    value = @ir.hot_build_binary(func, @lib.ValType::i32(), value, value)
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  let visits = [0]
  assert_false(
    merge_locals_region_has_stack_carried_copy(
      func,
      @ir.HotRegionRef::root(),
      visits=Some(visits),
    ),
  )
  assert_true(
    visits[0] <= @ir.hot_node_count(func),
    msg="visits=\{visits[0]} nodes=\{@ir.hot_node_count(func)}",
  )
}

///|
test "merge-locals stack-carried preflight visits deep control once" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut root = @ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0))
  for _ in 0..<512 {
    root = @ir.hot_build_block(func, @lib.BlockType::void_(), [root])
  }
  @ir.hot_root_append(func, root)
  let visits = [0]
  assert_false(
    merge_locals_region_has_stack_carried_copy(
      func,
      @ir.HotRegionRef::root(),
      visits=Some(visits),
    ),
  )
  assert_true(
    visits[0] <= @ir.hot_node_count(func),
    msg="visits=\{visits[0]} nodes=\{@ir.hot_node_count(func)}",
  )
}
