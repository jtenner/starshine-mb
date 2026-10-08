///|
test "virtual control inputs retain local access order in all arms and catches" {
  for
    (control, get_count, write_count) in [
      (
        "loop (param i32 i32) (result i32) local.get 0 local.tee 0 drop i32.div_s end",
        1, 1,
      ),
      (
        "if (param i32 i32) (result i32) local.get 0 local.tee 0 drop i32.div_s else local.get 0 local.tee 0 drop i32.div_s end",
        2, 2,
      ),
      (
        "(try (param i32 i32) (result i32) (do local.get 0 local.tee 0 drop i32.div_s) (catch_all local.get 0 local.tee 0))",
        2, 2,
      ),
      (
        "try_table (param i32 i32) (result i32) local.get 0 local.tee 0 drop i32.div_s end",
        1, 1,
      ),
    ] {
    let input = @wast.wast_to_binary_module(
      "(module (func (param i32) (result i32) unreachable " +
      control +
      " drop local.get 0 drop))",
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
      assert_eq(accesses.gets.length(), get_count + 1)
      assert_eq(accesses.writes.length(), write_count)
      for index = 0; index < get_count; index = index + 1 {
        assert_eq(accesses.gets[index], (0, -1))
      }
      for access in accesses.writes {
        assert_eq(access, (0, -1))
      }
      assert_true(accesses.gets[get_count].1 >= 0)
      let output = input.with_code_sec(
        @lib.CodeSec::new([hot_lower_func(func)]),
      )
      @validate.validate_module(
        @binary.decode_module(@binary.encode_module(output).unwrap()).unwrap(),
      ).unwrap()
    }
  }
}

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
