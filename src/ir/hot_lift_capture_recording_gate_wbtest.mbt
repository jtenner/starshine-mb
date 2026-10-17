///|
test "capture recording allocates no unobservable journal when source recording is off" {
  let input = @wast.wast_to_binary_module(
    "(module (func (param i32) (result i32) local.get 0 i32.const 7 local.set 0 i32.const 1 i32.add))",
  ).unwrap()
  @validate.validate_module(input).unwrap()
  let context = hot_module_context_from_module(input)
  let plain = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    context,
    capture_stack_locals=true,
    materialize_multi_values=true,
    record_local_accesses=false,
  ).unwrap()
  let requested = hot_lift_func_with_context_result(
    input,
    @lib.FuncIdx::new(0U),
    context,
    capture_stack_locals=true,
    materialize_multi_values=true,
    record_local_accesses=false,
    record_capture_sources=true,
  ).unwrap()
  assert_eq(plain.children, requested.children)
  assert_eq(plain.roots, requested.roots)
  assert_eq(hot_local_count(plain), hot_local_count(requested))
  assert_eq(hot_node_count(plain), hot_node_count(requested))
  for node in 0..<hot_node_count(plain) {
    @debug.assert_eq(hot_node_get(plain, node), hot_node_get(requested, node))
  }
  hot_verify_all_or_abort(plain)
  hot_verify_all_or_abort(requested)
  @debug.assert_eq(hot_lower_func(plain), hot_lower_func(requested))
  assert_true(requested.lifted_local_accesses is None)
  for body in ["local.get 99", "local.set 0", "f32.const 1 local.set 0"] {
    let invalid = @wast.wast_to_binary_module(
      "(module (func (param i32) " + body + "))",
    ).unwrap()
    let invalid_context = hot_module_context_from_module(invalid)
    let expected_error = hot_lift_func_with_context_result(
      invalid,
      @lib.FuncIdx::new(0U),
      invalid_context,
      capture_stack_locals=true,
      materialize_multi_values=true,
      record_local_accesses=false,
    ).unwrap_err()
    let actual_error = hot_lift_func_with_context_result(
      invalid,
      @lib.FuncIdx::new(0U),
      invalid_context,
      capture_stack_locals=true,
      materialize_multi_values=true,
      record_local_accesses=false,
      record_capture_sources=true,
    ).unwrap_err()
    assert_eq(actual_error, expected_error)
  }
  let scratch = HotFunc::new(
    locals=HotLocals::new(params=[@lib.ValType::i32()]),
  )
  let frames = hot_lift_impl_new_label_frames(
    scratch,
    capture_stack_locals=true,
    materialize_multi_values=true,
    record_local_accesses=false,
    record_capture_sources=true,
  )
  // Actual private allocation decision, after complete graph/lower guards.
  assert_true(frames.capture_sources is None)
}
