///|
test "typed block mixed void and value prefix lowers encodes and validates" {
  let input = @wast.wast_to_binary_module(
    "(module (type (func (param i32) (result i32))) (import \"host\" \"tick\" (func)) (func (result i32) i32.const 9))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
  let value = hot_root_get(func, 0)
  let effect = hot_build_call(func, 0, [], [])
  let body = hot_build_binary(
    func,
    @lib.ValType::i32(),
    value,
    hot_build_const_i32(func, @lib.I32(1)),
  )
  hot_node_exact_instr_set(func, body, @lib.Instruction::i32_add())
  let type_idx = @lib.TypeIdx::new(0U)
  let block = hot_build_block(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    [effect, value, body],
  )
  let ty = hot_type_intern_resolved_block_result(
    func,
    @lib.BlockType::type_idx(type_idx),
    [@lib.ValType::i32()],
    [@lib.ValType::i32()],
  )
  hot_control_result_type_set(func, block, ty)
  let node = hot_node_get(func, block)
  hot_node_set(func, block, { ..node, imm1: 2, })
  hot_root_set(func, 0, block)
  hot_verify_control(func).unwrap()
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(output).unwrap()
  let bytes = @binary.encode_module(output).unwrap()
  @validate.validate_module(@binary.decode_module(bytes).unwrap()).unwrap()
}

///|
test "typed block verifier rejects invalid explicit prefix boundaries and concrete types" {
  let source = "(module (func (param i32 i64) (result i64) local.get 0 local.get 1 block (param i32 i64) (result i64) local.set 1 drop local.get 1 end))"
  for malformed in 0..<3 {
    let input = @wast.wast_to_binary_module(source).unwrap()
    let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
    let block = hot_root_get(func, 0)
    let node = hot_node_get(func, block)
    match malformed {
      0 => hot_node_set(func, block, { ..node, imm1: node.child_count + 1, })
      1 => hot_node_set(func, block, { ..node, imm1: 1, })
      _ => {
        let first = hot_child_get(func, block, 0)
        let second = hot_child_get(func, block, 1)
        hot_child_set(func, block, 0, second)
        hot_child_set(func, block, 1, first)
      }
    }
    assert_true(hot_verify_control(func).is_err())
  }
}

///|
test "typed block prefix verification accepts declared reference subtypes" {
  let input = @wast.wast_to_binary_module(
    "(module (type $base (sub (struct))) (type $child (sub $base (struct))) (type $entry (func (param i32 (ref $base)) (result i32))) (func (result i32) i32.const 7 struct.new $child block (type $entry) drop end))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(0U))
  hot_verify_control(func).unwrap()
  let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
  @validate.validate_module(
    @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
  ).unwrap()
}
