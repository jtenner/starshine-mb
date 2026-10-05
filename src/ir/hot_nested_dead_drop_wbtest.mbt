///|
test "HOT lowering consumes unused concrete results of a final nonfallthrough block" {
  let input = @wast.wast_to_binary_module(
    "(module (func block (result i32) unreachable end drop))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let drop = hot_root_get(func, hot_root_count(func) - 1)
  assert_true(hot_node_op(func, drop) is HotOp::Drop)
  let block = hot_child_get(func, drop, 0)
  // A pass exposes this unused value as a root. Lowering must consume its
  // declared result even though the block's runtime execution cannot return.
  hot_root_set(func, hot_root_count(func) - 1, block)
  hot_delete_node(func, drop)
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(output).unwrap()
  let bytes = @binary.encode_module(output).unwrap()
  @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
}

///|
test "HOT round trip retains the declared nested result drop before any pass" {
  let input = @wast.wast_to_binary_module(
    "(module (table 1 funcref) (func (export \"f\") i32.const 0 i32.const 0 table.get 0 i32.const 0 table.fill 0 block (result v128) unreachable end f32.const 2.5 block end drop drop block (result funcref) block ref.null func i32.const 0 br_table 1 1 end unreachable end drop))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let lowered = hot_lower_func(func)
  let @lib.Func(_, @lib.Expr(body)) = lowered
  assert_true(body[body.length() - 1] is @lib.Drop)
  let output = input.with_code_sec(@lib.CodeSec::new([lowered]))
  @validate.validate_module(output).unwrap()
  let bytes = @binary.encode_module(output).unwrap()
  @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
}

///|
test "terminal void replacement block restores outer frame polymorphism" {
  let input = @wast.wast_to_binary_module(
    "(module (func (result i32) unreachable))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let old = hot_root_get(func, 0)
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    hot_build_unreachable(func),
  ])
  hot_root_set(func, 0, block)
  hot_delete_node(func, old)
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}

///|
test "own label branch in void block retains normal outer fallthrough" {
  let input = @wast.wast_to_binary_module(
    "(module (func (result i32) block br 0 end i32.const 7))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(func)
  assert_false(body.any(fn(instr) { instr is @lib.Unreachable }))
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}

///|
test "invalid missing result after normal own-label exit cannot be repaired by an invented trap" {
  let input = @wast.wast_to_binary_module(
    "(module (func block br 0 unreachable end))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  hot_body_result_type_set(
    func,
    hot_type_intern_block_result(
      func,
      @lib.BlockType::val_type(@lib.ValType::i32()),
    ),
  )
  let @lib.Func(_, @lib.Expr(body)) = hot_lower_func(func)
  assert_false(body.any(fn(instr) { instr is @lib.Unreachable }))
  assert_true(
    @validate.validate_func_body_against_functype(
      @validate.empty_env(),
      @lib.FuncType::new([], [@lib.ValType::i32()]),
      hot_lower_func(func),
    ).is_err(),
  )
}
