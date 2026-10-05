///|
test "flatten admission sees local writes embedded below a region root" {
  let func = pass_test_lift_first_func("(module (func (local i32)))")
  let source_older_read = @ir.hot_build_local_get(func, 0)
  let embedded_write = @ir.hot_build_local_tee(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  @ir.hot_region_replace_body(func, @ir.HotRegionRef::root(), [
    @ir.hot_build_drop(func, embedded_write),
    @ir.hot_build_drop(func, source_older_read),
  ])
  assert_true(
    flatten_region_has_stack_carried_local_read_across_write(
      func,
      @ir.HotRegionRef::root(),
    ),
  )
}

///|
test "flatten admission preserves older local reads across nested control roots" {
  let func = pass_test_lift_first_func("(module (func (local i32)))")
  let source_older_read = @ir.hot_build_local_get(func, 0)
  let nested_write = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_local_set(
      func,
      0,
      @ir.hot_build_const_i32(func, @lib.I32(11)),
    ),
  ])
  let nested_read = @ir.hot_build_block(func, @lib.BlockType::void_(), [
    @ir.hot_build_drop(func, source_older_read),
  ])
  @ir.hot_region_replace_body(func, @ir.HotRegionRef::root(), [
    nested_write, nested_read,
  ])
  assert_true(
    flatten_region_has_stack_carried_local_read_across_write(
      func,
      @ir.HotRegionRef::root(),
    ),
  )
}

///|
test "flatten local dependency admission visits a wide region linearly" {
  let func = pass_test_lift_first_func("(module (func (local i32)))")
  let roots : Array[Int] = []
  for value = 0; value < 256; value = value + 1 {
    roots.push(
      @ir.hot_build_local_set(
        func,
        0,
        @ir.hot_build_const_i32(func, @lib.I32(value)),
      ),
    )
  }
  for idx = 0; idx < 256; idx = idx + 1 {
    roots.push(@ir.hot_build_drop(func, @ir.hot_build_local_get(func, 0)))
  }
  @ir.hot_region_replace_body(func, @ir.HotRegionRef::root(), roots)
  let node_visits = [0]
  assert_false(
    flatten_region_has_stack_carried_local_read_across_write(
      func,
      @ir.HotRegionRef::root(),
      node_visits=Some(node_visits),
    ),
  )
  assert_true(node_visits[0] <= @ir.hot_node_count(func) * 2)
}

///|
test "flatten local dependency admission visits a shared DAG once" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let mut value = @ir.hot_build_local_get(func, 0)
  for _ in 0..<18 {
    value = @ir.hot_build_binary(func, @lib.ValType::i32(), value, value)
  }
  @ir.hot_root_append(func, @ir.hot_build_drop(func, value))
  let node_visits = [0]
  assert_false(
    flatten_region_has_stack_carried_local_read_across_write(
      func,
      @ir.HotRegionRef::root(),
      node_visits=Some(node_visits),
    ),
  )
  assert_true(
    node_visits[0] <= @ir.hot_node_count(func),
    msg="visits=\{node_visits[0]} nodes=\{@ir.hot_node_count(func)}",
  )
}

///|
test "flatten local dependency admission reuses local scratch across deep control" {
  let local_count = 128
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(
      locals=Array::make(local_count, @lib.ValType::i32()),
    ),
  )
  let mut root = @ir.hot_build_nop(func)
  for _ in 0..<256 {
    root = @ir.hot_build_block(func, @lib.BlockType::void_(), [root])
  }
  @ir.hot_root_append(func, root)
  let scratch_cells = [0]
  let node_visits = [0]
  assert_false(
    flatten_region_has_stack_carried_local_read_across_write(
      func,
      @ir.HotRegionRef::root(),
      node_visits=Some(node_visits),
      scratch_cells=Some(scratch_cells),
    ),
  )
  assert_true(
    scratch_cells[0] <= local_count * 3,
    msg="scratch cells=\{scratch_cells[0]}",
  )
  assert_true(
    node_visits[0] <= @ir.hot_node_count(func) * 2,
    msg="visits=\{node_visits[0]} nodes=\{@ir.hot_node_count(func)}",
  )
}
