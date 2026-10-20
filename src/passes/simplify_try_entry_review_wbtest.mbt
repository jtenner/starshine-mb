///|
fn sl_review_try_with_entry(
  func : @ir.HotFunc,
  table : Bool,
  entry : Int32,
) -> Int32 {
  let body = [@ir.hot_build_local_get(func, 0)]
  let control = if table {
    @ir.hot_build_try_table(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
      [],
      body,
    )
  } else {
    @ir.hot_build_try(func, @lib.BlockType::val_type(@lib.ValType::i32()), body)
  }
  let children = @ir.hot_child_span(func, control)
  children.push(entry)
  ignore(@ir.hot_replace_child_span(func, control, children))
  @ir.hot_root_append(func, control)
  control
}

///|
test "simplify locals distinguishes try entry operands from protected regions" {
  for table in [false, true] {
    let func = @ir.HotFunc::new(
      locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
    )
    let input = @ir.hot_build_local_get(func, 0)
    let control = sl_review_try_with_entry(func, table, input)
    assert_true(simplify_locals_is_region_child_slot(func, control, 0))
    assert_true(simplify_locals_is_region_child_slot(func, control, 1))
    assert_false(simplify_locals_is_region_child_slot(func, control, 2))
    let replacement = @ir.hot_build_const_i32(func, @lib.I32(9))
    assert_true(
      simplify_locals_try_inline_local_get_child(
        func,
        control,
        0,
        replacement,
        true,
        [],
      ),
    )
    assert_eq(@ir.hot_child_get(func, control, 2), replacement)
    let body = @ir.hot_region_get(
      func,
      @ir.hot_region_body_ref(func, control),
      0,
    )
    assert_true(@ir.hot_node_get(func, body).op is @ir.HotOp::LocalGet)
  }
}

///|
test "simplify locals records local writes in try entry operands" {
  for table in [false, true] {
    let func = @ir.HotFunc::new(
      locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
    )
    let entry = @ir.hot_build_local_tee(
      func,
      0,
      @ir.hot_build_const_i32(func, @lib.I32(7)),
    )
    let control = sl_review_try_with_entry(func, table, entry)
    let reads : Array[Int32] = []
    let writes : Array[Int32] = []
    simplify_locals_collect_subtree_local_effects(
      func,
      control,
      reads,
      writes,
      [-1],
      [-1],
      1,
    )
    assert_eq(writes, [0])
    assert_eq(reads, [0])
  }
}
