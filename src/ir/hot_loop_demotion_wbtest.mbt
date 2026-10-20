///|
fn loop_demotion_body(func : HotFunc, loop_id : NodeId) -> Array[NodeId] {
  let region = hot_region_body_ref(func, loop_id)
  Array::makei(hot_region_root_count(func, region), fn(i) {
    hot_region_get(func, region, i)
  })
}

///|
test "HOT loop demotion preserves entry operands and uses block result arity" {
  let module_ = @wast.wast_to_binary_module(
    "(module (import \"m\" \"pair\" (func $pair (result i32 i64))) (func (result i64) (local i64) call $pair loop (param i32 i64) (result i64) i64.const 1 i64.add local.set 0 drop local.get 0 end))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let loop_id = hot_root_get(func, 0)
  let body = loop_demotion_body(func, loop_id)
  let entries = [
    hot_child_get(func, loop_id, 0),
    hot_child_get(func, loop_id, 1),
  ]
  let label = hot_control_node_label(func, loop_id)
  @debug.assert_eq(hot_label_branch_arity(func, label), 2)
  let revision = hot_revision_current(func)
  hot_control_demote_loop_to_block(func, loop_id)
  @debug.assert_eq(hot_revision_current(func), revision + 1)
  @debug.assert_eq(hot_node_get(func, loop_id).op, HotOp::Block)
  @debug.assert_eq(hot_label_kind(func, label), HotLabelKind::BlockLabel)
  @debug.assert_eq(hot_label_branch_arity(func, label), 1)
  @debug.assert_eq(loop_demotion_body(func, loop_id), body)
  @debug.assert_eq(hot_child_get(func, loop_id, 0), entries[0])
  @debug.assert_eq(hot_child_get(func, loop_id, 1), entries[1])
  hot_verify_all_or_abort(func)
  let lowered = hot_lower_func(func)
  @validate.validate_module(module_.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  let @lib.Func(_, @lib.Expr(instrs)) = lowered
  @debug.assert_eq(instrs[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  assert_true(instrs[1] is @lib.Block(_, _))
}

///|
test "HOT loop demotion preserves an effectful scalar entry consumed by a void body" {
  let module_ = @wast.wast_to_binary_module(
    "(module (import \"m\" \"value\" (func $value (result i32))) (func call $value loop (param i32) drop end))",
  ).unwrap()
  @validate.validate_module(module_).unwrap()
  let func = hot_lift_func(module_, @lib.FuncIdx::new(1U))
  let loop_id = hot_root_get(func, 0)
  let body = loop_demotion_body(func, loop_id)
  hot_control_demote_loop_to_block(func, loop_id)
  @debug.assert_eq(loop_demotion_body(func, loop_id), body)
  @debug.assert_eq(
    hot_label_branch_arity(func, hot_control_node_label(func, loop_id)),
    0,
  )
  hot_verify_all_or_abort(func)
  let lowered = hot_lower_func(func)
  @validate.validate_module(module_.with_code_sec(@lib.CodeSec::new([lowered]))).unwrap()
  let @lib.Func(locals, @lib.Expr(instrs)) = lowered
  @debug.assert_eq(instrs[0], @lib.Instruction::call(@lib.FuncIdx::new(0U)))
  @debug.assert_eq(locals, @lib.Locals::empty())
  @debug.assert_eq(instrs, [
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
    @lib.Instruction::drop(),
  ])
  let framed = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::call(@lib.FuncIdx::new(0U)),
      @lib.Instruction::block(
        hot_lower_impl_control_block_type(func, loop_id),
        @lib.Expr::new([@lib.Instruction::drop()]),
      ),
    ]),
  )
  let smaller = @binary.encode_module(
    module_.with_code_sec(@lib.CodeSec::new([lowered])),
  ).unwrap()
  let larger = @binary.encode_module(
    module_.with_code_sec(@lib.CodeSec::new([framed])),
  ).unwrap()
  assert_eq(smaller.length() + 3, larger.length())
}
