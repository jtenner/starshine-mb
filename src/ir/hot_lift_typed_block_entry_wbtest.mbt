///|
test "hot lift keeps typed block entry lanes outside the block body" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 block (param i32 i32) (result i32) i32.div_s end))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let block = hot_root_get(func, 0)
  let node = hot_node_get(func, block)
  assert_eq(node.op, HotOp::Block)
  assert_eq(node.imm1, 2)
  assert_eq(hot_child_count(func, block), 3)
  assert_eq(hot_node_op(func, hot_child_get(func, block, 0)), HotOp::LocalGet)
  assert_eq(hot_node_op(func, hot_child_get(func, block, 1)), HotOp::LocalGet)
  assert_eq(hot_region_root_count(func, hot_region_body_ref(func, block)), 1)
  hot_verify_core(func).unwrap()
  hot_verify_control(func).unwrap()
  let lowered = hot_lower_func(func)
  assert_eq(lowered, input.code_sec.unwrap().0[0])
}

///|
test "hot typed block entry round trips shared tuple lanes labels and discarded results" {
  for
    source in [
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (result i64) (local i64) call 0 block (param i32 i64) (result i64) local.set 0 drop local.get 0 end))",
      "(module (func (param i32 i32) (result i32) local.get 0 local.get 1 block (param i32 i32) (result i32) i32.add br 0 end))",
      "(module (func (param i32 i32) local.get 0 local.get 1 block (param i32 i32) (result i32) i32.div_s end drop))",
      "(module (func (param i32) (result i32) unreachable i32.const 1 i32.const 2 block (param i32 i32) (result i32) i32.div_s end))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    @validate.validate_module(input).unwrap()
    let index = if input.import_sec is Some(_) { 1U } else { 0U }
    let func = match
      hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(index),
        hot_module_context_from_module(input),
      ) {
      Ok(func) => func
      Err(error) => fail("\{source}: \{error}")
    }
    hot_verify_core(func).unwrap()
    hot_verify_control(func).unwrap()
    let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
    @validate.validate_module(output).unwrap()
  }
}

///|
test "hot lower typed block prefix pops only its surviving value lanes" {
  let func = HotFunc::new()
  let effect = hot_build_call(func, 0, [], [])
  let value = hot_build_const_i32(func, @lib.I32(7))
  let block = hot_build_resolved_block(
    func,
    @lib.BlockType::type_idx(@lib.TypeIdx::new(0U)),
    [@lib.ValType::i32()],
    [],
    [effect, value, hot_build_drop(func, value)],
  )
  hot_node_set(func, block, { ..hot_node_get(func, block), imm1: 2, })
  let inputs = hot_lower_impl_input_info(func, block)
  assert_eq(inputs.nodes.to_owned(), [effect, value])
  assert_eq(inputs.pop_count, 1)
}
