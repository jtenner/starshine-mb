///|
test "reused capture callbacks preserve recursive local counts and remaps" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32 i32) (result i32) (local i32) local.get 0 if local.get 1 local.set 2 else loop local.get 1 local.tee 2 drop end end local.get 2))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let gets = Array::make(3, 0)
  let writes = Array::make(3, 0)
  let old_gets = Array::make(3, 0)
  let old_writes = Array::make(3, 0)
  pass_lower_count_locals(body, gets, writes)
  callback_reference_pass_lower_count_locals(body, old_gets, old_writes)
  assert_eq(gets, [1, 2, 1])
  assert_eq(writes, [0, 0, 2])
  assert_eq(gets, old_gets)
  assert_eq(writes, old_writes)
  assert_eq(
    pass_lower_remap_locals(body, [0, 2, 1]),
    callback_reference_pass_lower_remap_locals(body, [0, 2, 1]),
  )
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "reused traversal callbacks preserve forwarding state and balanced capture shape" {
  for
    source in [
      "(module (func (param i32) (result i32) (local i32) local.get 0 local.set 1 block (result i32) block (result i32) local.get 1 end end))",
      "(module (func (param i32 i64) (result i32 i64) block (result i32 i64) local.get 0 local.get 1 end))",
      "(module (import \"env\" \"produce\" (func $produce (result i32))) (import \"env\" \"consume\" (func $consume (param i32))) (func (result i32) (local i32) loop call $produce local.set 0 i32.const 7 call $consume local.get 0 drop end i32.const 9))",
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let context = @ir.hot_module_context_from_module(input)
    let params = rl_defined_func_param_cache(input)
    let func = input.code_sec.unwrap().0[0]
    let @lib.Func(_, @lib.Expr(body)) = func
    assert_eq(
      dae2_cleanup_forwarding(body, context),
      callback_reference_dae2_cleanup_forwarding(body, context),
    )
    let original = @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new([]))
    let effects = Some(fn(instr) {
      dae2_capture_stack_effect(instr, input, context)
    })
    let output = pass_lower_compact_captures_with_map(
      func,
      original,
      params[0],
      stack_effects=effects,
    )
    let reference = callback_reference_pass_lower_compact_captures_with_map(
      func,
      original,
      params[0],
      stack_effects=effects,
    )
    assert_eq(output, reference)
    @validate.validate_module(
      input.with_code_sec(@lib.CodeSec::new([output.0])),
    ).unwrap()
  }
}

///|
test "reused branchless callbacks reset child state and preserve label ordinal masks" {
  let input = pass_test_module_from_wat(
    "(module (func (param i32) block local.get 0 if br 1 end end block loop nop end end block local.get 0 if nop else nop end end))",
  )
  @validate.validate_module(input).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  let env = @validate.Env::new().with_module(input)
  let mask = []
  let old_mask = []
  let output = pass_lower_flatten_branchless_blocks(
    body,
    env,
    label_keep=Some(mask),
  )
  let reference = callback_reference_pass_lower_flatten_branchless_blocks(
    body,
    env,
    label_keep=Some(old_mask),
  )
  assert_eq(output, reference)
  assert_eq(mask, old_mask)
  assert_eq(mask, [true, true, false, true, false, true])
}
