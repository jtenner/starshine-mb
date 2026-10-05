///|
test "virtual typed entry retains ordered source local access placeholders" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) unreachable block (param i32 i32) (result i32) local.get 0 local.tee 0 drop i32.div_s end drop local.get 0 drop))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  for captures in [false, true] {
    let func = hot_lift_func_with_context_result(
      input,
      @lib.FuncIdx::new(0U),
      hot_module_context_from_module(input),
      capture_stack_locals=captures,
      materialize_multi_values=captures,
    ).unwrap()
    let accesses = hot_lift_local_accesses(func)
    assert_eq(accesses.gets.map(fn(access) { access.0 }), [0, 0])
    assert_eq(accesses.writes, [(0, -1)])
    assert_eq(accesses.gets[0].1, -1)
    assert_true(accesses.gets[1].1 >= 0)
    let output = input.with_code_sec(@lib.CodeSec::new([hot_lower_func(func)]))
    @validate.validate_module(
      @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
    ).unwrap()
  }
}
