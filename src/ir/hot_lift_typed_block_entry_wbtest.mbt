///|
test "hot typed block boundaries preserve live single parameter labels and partial mixed tuples" {
  for
    source in [
      "(module (func (param i32 i32) (result i32) local.get 0 block (param i32) (result i32) local.get 1 br_if 0 end))",
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (result i32 i64) call 0 block (param i64) (result i64) i64.const 1 i64.add end))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    @validate.validate_module(input).unwrap()
    let index = if input.import_sec is Some(_) { 1U } else { 0U }
    for captures in [false, true] {
      let func = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(index),
        hot_module_context_from_module(input),
        capture_stack_locals=captures,
        materialize_multi_values=captures,
      ).unwrap()
      hot_verify_core(func).unwrap()
      hot_verify_control(func).unwrap()
      let output = input.with_code_sec(
        @lib.CodeSec::new([hot_lower_func(func)]),
      )
      match @validate.validate_module(output) {
        Ok(_) => ()
        Err(err) =>
          fail(
            "typed boundary captures=\{captures}: \{source}: \{err}; lowered=\{output.code_sec.unwrap().0[0]}",
          )
      }
      let bytes = @binary.encode_module(output).unwrap()
      @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
    }
  }
}

///|
test "hot typed block virtual input admission validates the entire child frame" {
  for prefix in ["", "i32.const 7 "] {
    let input = @wast.wast_to_binary_module(
      "(module (func (param i32) (result i32) unreachable " +
      prefix +
      "block (param i32 i32) (result i32) i32.div_s end))",
    ).unwrap()
    @validate.validate_module(input).unwrap()
    let func = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
    ).unwrap()
    hot_verify_core(func).unwrap()
    hot_verify_control(func).unwrap()
    let lowered = hot_lower_func(func)
    let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
    @validate.validate_module(output).unwrap()
  }
  for body in ["f64.add", "drop drop i64.const 9"] {
    let input = @wast.wast_to_binary_module(
      "(module (func (result i32) unreachable block (param i32 i32) (result i32) " +
      body +
      " end))",
    ).unwrap()
    assert_true(
      hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(0U),
        hot_module_context_from_module(input),
      ).is_err(),
    )
  }
}

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

///|
test "typed multi param entry consumes only the mixed tuple suffix" {
  for
    source in [
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (export \"run\") (result i32 i64 i32) call 0 i32.const 7 block (param i64 i32) (result i64 i32) end))",
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (export \"run\") (result i32 i64) call 0 i32.const 7 block (param i64 i32) (result i64) drop i64.const 1 i64.add end))",
    ] {
    let input = @wast.wast_to_binary_module(source).unwrap()
    @validate.validate_module(input).unwrap()
    for captures in [false, true] {
      let func = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(1U),
        hot_module_context_from_module(input),
        capture_stack_locals=captures,
        materialize_multi_values=captures,
      ).unwrap()
      hot_verify_control(func).unwrap()
      let output = input.with_code_sec(
        @lib.CodeSec::new([hot_lower_func(func)]),
      )
      @validate.validate_module(
        @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
      ).unwrap()
    }
  }
}
