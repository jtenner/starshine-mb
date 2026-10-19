///|
fn merge_locals_source_order_context() -> HotPassContext {
  HotPassContext::new(
    merge_locals_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
}

///|
fn merge_locals_source_order_result(func : @ir.HotFunc) -> Int32 raise {
  let @lib.Func(locals_, @lib.Expr(body)) = @ir.hot_lower_func(func)
  let locals = Array::make(locals_.length(), 0)
  let stack : Array[Int32] = []
  for instruction in body {
    match instruction {
      @lib.I32Const(@lib.I32(value)) => stack.push(value)
      @lib.LocalGet(@lib.LocalIdx(index)) => stack.push(locals[index.to_int()])
      @lib.LocalSet(@lib.LocalIdx(index)) =>
        locals[index.to_int()] = stack.pop().unwrap()
      @lib.I32Add => {
        let rhs = stack.pop().unwrap()
        stack.push(stack.pop().unwrap() + rhs)
      }
      _ => fail("unexpected source-order fixture instruction: \{instruction}")
    }
  }
  assert_eq(stack.length(), 1)
  stack[0]
}

///|
test "merge-locals preserves carried reads rebuilt after the copy allocation" {
  let func = @ir.HotFunc::new(
    locals=@ir.HotLocals::new(locals=[@lib.ValType::i32(), @lib.ValType::i32()]),
  )
  let old_read = @ir.hot_build_local_get(func, 0)
  let copy = @ir.hot_build_local_set(func, 1, @ir.hot_build_local_get(func, 0))
  let rebuilt_read = @ir.hot_build_local_get(func, 0)
  @ir.hot_preserve_replacement_position(func, rebuilt_read, old_read)
  @ir.hot_delete_node(func, old_read)
  @ir.hot_root_append(func, copy)
  @ir.hot_root_append(func, @ir.hot_build_drop(func, rebuilt_read))
  assert_true(rebuilt_read > copy)
  assert_true(
    @ir.hot_node_get(func, rebuilt_read).order <
    @ir.hot_node_get(func, copy).order,
  )
  // This read is evaluated before the copy and then carried to its consumer.
  assert_true(
    merge_locals_region_has_stack_carried_copy(func, @ir.HotRegionRef::root()),
  )
  ignore(merge_locals_run(merge_locals_source_order_context(), func))
  @debug.assert_eq(@ir.hot_node_get(func, rebuilt_read).imm0, 0)
}

///|
test "merge-locals retargets reads after a copy rebuilt at its source position" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) (local i32 i32) i32.const 7 local.set 0 local.get 0 local.set 1 local.get 0 local.get 1 i32.add))",
  )
  let original_copy = @ir.hot_root_get(func, 1)
  let copy_value = @ir.hot_child_get(func, original_copy, 0)
  let rebuilt_copy = @ir.hot_build_local_set(func, 1, copy_value)
  @ir.hot_preserve_replacement_position(func, rebuilt_copy, original_copy)
  @ir.hot_root_set(func, 1, rebuilt_copy)
  @ir.hot_delete_node(func, original_copy)
  let sum = @ir.hot_root_get(func, 2)
  let after_read = @ir.hot_child_get(func, sum, 0)
  assert_true(after_read < rebuilt_copy)
  assert_true(
    @ir.hot_node_get(func, after_read).order >
    @ir.hot_node_get(func, rebuilt_copy).order,
  )
  @debug.assert_eq(merge_locals_source_order_result(func), 14)
  ignore(merge_locals_run(merge_locals_source_order_context(), func))
  @debug.assert_eq(@ir.hot_node_get(func, after_read).imm0, 1)
  @debug.assert_eq(merge_locals_source_order_result(func), 14)
}
