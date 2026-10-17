///|
test "simplify-locals revisiting a moved write preserves its live definition" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) (local i32) (local.set 0 (i32.const 42)) (local.get 0)))",
  )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let write = @ir.hot_root_get(func, 0)
  let node = @ir.hot_node_get(func, write)
  let sinkables = simplify_locals_new_sinkables(func)
  let gets = simplify_locals_count_local_gets(func)
  let deferred : Array[Int32] = []
  ignore(
    simplify_locals_record_local_set(
      func, write, node, sinkables, true, true, gets, deferred,
    ),
  )
  // Moving a block under its following value root can visit the same physical
  // write again with its prior pending entry. It cannot overwrite itself.
  ignore(
    simplify_locals_record_local_set(
      func, write, node, sinkables, true, true, gets, deferred,
    ),
  )
  assert_true(@ir.hot_node_op(func, write) is @ir.HotOp::LocalSet)
  let value = @ir.hot_child_get(func, write, 0)
  assert_true(@ir.hot_node_op(func, value) is @ir.HotOp::Const)
  assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, value).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(42)),
  )
  ignore(@ir.hot_verify_core(func).unwrap())
}
