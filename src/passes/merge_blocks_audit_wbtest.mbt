///|
test "audit merge blocks retains owner used by branch condition" {
  let func = pass_test_lift_first_func(
    "(module (func (param i32) block $outer block (result i32) local.get 0 br_if $outer i32.const 1 end br_if $outer end))",
  )
  assert_false(
    merge_blocks_try_remove_o4z_self_br_if_void_block(
      func,
      @ir.HotRegionRef::root(),
      0,
    ),
  )
}

///|
test "merge-blocks branch memo scratch is lazy across ordinary expression roots" {
  let func = @ir.HotFunc::new()
  for value in 0..<256 {
    @ir.hot_root_append(
      func,
      @ir.hot_build_drop(func, @ir.hot_build_const_i32(func, @lib.I32(value))),
    )
  }
  let workspace = MergeBlocksBranchScanWorkspace::new()
  let labels = @bitset.BitSet::new(0)
  for idx in 0..<@ir.hot_region_root_count(func, @ir.HotRegionRef::root()) {
    assert_eq(
      merge_blocks_lift_expression_block_children(
        func,
        @ir.HotRegionRef::root(),
        idx,
        labels,
        None,
        branch_workspace=Some(workspace),
      ),
      0,
    )
  }
  assert_eq(workspace.initialized_cells, 0)
}

///|
test "merge-blocks branch memo scans legacy try catches" {
  let func = @ir.HotFunc::new()
  let try_id = @ir.hot_build_try(
    func,
    @lib.BlockType::void_(),
    [],
    catch_body=Some([]),
  )
  let catch_ref = @ir.hot_region_catch_ref(func, try_id).unwrap()
  @ir.hot_region_replace_body(func, catch_ref, [
    @ir.hot_build_br(func, @ir.hot_control_node_label(func, try_id)),
  ])
  @ir.hot_root_append(func, try_id)
  assert_true(merge_blocks_node_has_branch(func, try_id))
}

///|
test "merge-blocks reuses loop presence across nested block checks" {
  let source = StringBuilder::new()
  source.write_string("(module (func ")
  for _ in 0..<64 {
    source.write_string("block ")
  }
  source.write_string("loop nop end ")
  for _ in 0..<64 {
    source.write_string("end ")
  }
  source.write_string("))")
  let input = pass_test_module_from_wat(source.to_string())
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let workspace = MergeBlocksBranchScanWorkspace::new()
  let visits = [0]
  let mut region = @ir.HotRegionRef::root()
  for _ in 0..<64 {
    let block_id = @ir.hot_region_get(func, region, 0)
    match @ir.hot_node_get(func, block_id).op {
      @ir.HotOp::Block => ()
      _ => fail("expected nested block")
    }
    region = @ir.hot_region_body_ref(func, block_id)
    assert_true(
      merge_blocks_region_contains_loop(
        func,
        region,
        workspace=Some(workspace),
        visits=Some(visits),
      ),
    )
  }
  assert_true(visits[0] <= 128, msg="loop scan visits=\{visits[0]}")
  @ir.hot_region_replace_body(func, region, [])
  assert_false(
    merge_blocks_region_contains_loop(
      func,
      @ir.HotRegionRef::root(),
      workspace=Some(workspace),
    ),
  )
}
