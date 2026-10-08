///|
test "control prefix stack retains mixed tuple suffixes and separate scalar runs" {
  let input = @wast.wast_to_binary_module(
    "(module (import \"host\" \"tuple\" (func (result i32 i64 f32))) (func nop))",
  ).unwrap()
  let func = hot_lift_func(input, @lib.FuncIdx::new(1U))
  let void_id = hot_root_get(func, 0)
  let scalar = hot_build_const_i32(func, @lib.I32(7))
  let tuple = hot_build_call(
    func,
    0,
    [@lib.ValType::i32(), @lib.ValType::i64(), @lib.ValType::f32()],
    [],
  )
  let block = hot_build_block(func, @lib.BlockType::void_(), [
    void_id, scalar, tuple, tuple, scalar,
  ])
  let stack : Array[HotLowerStackValue] = []
  hot_lower_impl_push_control_prefix(func, block, 5, stack)
  assert_eq(stack.map(fn(value) { value.node_id }), [
    scalar, tuple, tuple, scalar,
  ])
  assert_eq(stack.map(fn(value) { value.val_type }), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
    @lib.ValType::i32(),
  ])
  let full = hot_build_block(func, @lib.BlockType::void_(), [
    tuple, tuple, tuple,
  ])
  let full_stack : Array[HotLowerStackValue] = []
  hot_lower_impl_push_control_prefix(func, full, 3, full_stack)
  assert_eq(full_stack.map(fn(value) { value.val_type }), [
    @lib.ValType::i32(),
    @lib.ValType::i64(),
    @lib.ValType::f32(),
  ])
}

///|
test "mixed typed entry suffix retains a tuple call once in both capture modes" {
  for
    wat in [
      "(module (import \"host\" \"pair\" (func (result i32 i64))) (func (result i32 i64 i32) call 0 i32.const 7 block (param i64 i32) (result i64 i32) end))",
      "(module (import \"host\" \"triple\" (func (result i32 i64 f32))) (func (result i32 i64 f32 i32) call 0 i32.const 7 block (param i64 f32 i32) (result i64 f32 i32) end))",
    ] {
    let input = @wast.wast_to_binary_module(wat).unwrap()
    for captures in [false, true] {
      let func = hot_lift_func_with_context_result(
        input,
        @lib.FuncIdx::new(1U),
        hot_module_context_from_module(input),
        capture_stack_locals=captures,
        materialize_multi_values=captures,
      ).unwrap()
      let lowered = hot_lower_func(func)
      let @lib.Func(_, @lib.Expr(body)) = lowered
      assert_eq(hot_prefix_tuple_call_count(body), 1)
      @validate.validate_module(
        input.with_code_sec(@lib.CodeSec::new([lowered])),
      ).unwrap()
    }
  }
}

///|
fn hot_prefix_tuple_call_count(body : Array[@lib.Instruction]) -> Int {
  let mut count = 0
  for instr in body {
    match instr {
      @lib.Call(@lib.FuncIdx(0U)) => count += 1
      @lib.Block(_, @lib.Expr(nested))
      | @lib.Loop(_, @lib.Expr(nested))
      | @lib.TryTable(_, _, @lib.Expr(nested)) =>
        count += hot_prefix_tuple_call_count(nested)
      @lib.If(_, then_body, else_body) => {
        count += hot_prefix_tuple_call_count(then_body)
        if else_body is Some(body) {
          count += hot_prefix_tuple_call_count(body)
        }
      }
      _ => ()
    }
  }
  count
}
