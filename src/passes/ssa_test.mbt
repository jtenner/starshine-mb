///|
fn ssa_full_test_merge_plan(func : @ir.HotFunc) -> SsaFullRewritePlan {
  let graph = @ir.local_graph_build(func, @ir.cfg_build(func))
  ssa_full_build_merge_rewrite_plan(func, graph)
}

///|
fn ssa_full_test_plan_has_input(
  inputs : Array[SsaFullMergeInput],
  expected : SsaFullMergeInput,
) -> Bool {
  for input in inputs {
    if input == expected {
      return true
    }
  }
  false
}

///|
test "full ssa planner creates merge action for explicit diamond writes" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let else_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(9)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([else_set]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.original_local, 1)
  @debug.assert_eq(rewrite.merge_local, 2)
  @debug.assert_eq(rewrite.inputs.length(), 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(else_set),
    ),
  )
}

///|
test "full ssa planner models parameter-entry merge prepends" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.merge_local, 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ParamEntry(1),
    ),
  )
}

///|
test "full ssa planner models default-entry merges without prepends" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32()], locals=[
      @lib.ValType::i32(),
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    1,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 1)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 1)
  let rewrite = plan.merge_gets[0]
  @debug.assert_eq(rewrite.get_id, merge_get)
  @debug.assert_eq(rewrite.merge_local, 2)
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ExplicitWrite(then_set),
    ),
  )
  assert_true(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::DefaultEntry(1),
    ),
  )
  assert_false(
    ssa_full_test_plan_has_input(
      rewrite.inputs,
      SsaFullMergeInput::ParamEntry(1),
    ),
  )
}

///|
test "full ssa planner skips nondefaultable default-entry merges" {
  let heap = @lib.HeapType::new(@lib.TypeIdx::new(0U))
  let nonnull_ref = @lib.ValType::ref_type(@lib.RefType::new(false, heap))
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(params=[@lib.ValType::i32(), nonnull_ref], locals=[
      nonnull_ref,
    ]),
  )
  let then_set = @ir.hot_build_local_set(
    func,
    2,
    @ir.hot_build_local_get(func, 1),
  )
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::void_(),
    @ir.hot_build_local_get(func, 0),
    [then_set],
    else_body=Some([@ir.hot_build_nop(func)]),
  )
  let merge_get = @ir.hot_build_local_get(func, 2)
  @ir.hot_root_append(func, if_id)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, merge_get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 0)
}

///|
test "full ssa planner ignores single-source gets for no-merge sibling contrast" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32()]),
  )
  let set = @ir.hot_build_local_set(
    func,
    0,
    @ir.hot_build_const_i32(func, @lib.I32(7)),
  )
  let get = @ir.hot_build_local_get(func, 0)
  @ir.hot_root_append(func, set)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, get))

  let plan = ssa_full_test_merge_plan(func)

  @debug.assert_eq(plan.merge_gets.length(), 0)
}
