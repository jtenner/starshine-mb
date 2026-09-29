///|
test "DAE2 HOT analysis preserves a stacked entry read before a block-local overwrite" {
  let input = pass_test_module_from_wat(
    "(module (func $h (param i32 i32 i32) (result i32) local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
  )
  @validate.validate_module(input).unwrap()
  let saved = @binary.encode_module(input).unwrap()
  let output = dae2_run_module_pass(
    input,
    false,
    raw_analysis=false,
    raw_rewrite=false,
  ).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(dae_wb_param_count(output, 0), 1)
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::call(@lib.FuncIdx::new(0U)),
  ])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 HOT stacked reads keep loop-carried writes and prune overwritten entry values" {
  for
    (source, expected_params, expected_writes) in [
      (
        "(module (func $h (param i32 i32 i32) (result i32) (local i32) i32.const 2 local.set 3 loop (result i32) local.get 1 local.get 1 i32.const 1 i32.add local.set 1 local.get 3 i32.const 1 i32.sub local.tee 3 br_if 0 end local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
        1, 1,
      ),
      (
        "(module (func $h (param i32 i32 i32) (result i32) i32.const 5 local.set 1 local.get 1 block i32.const 11 local.set 1 end local.get 1 i32.add) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
        0, 2,
      ),
    ] {
    let input = pass_test_module_from_wat(source)
    @validate.validate_module(input).unwrap()
    let saved = @binary.encode_module(input).unwrap()
    let output = dae2_run_module_pass(
      input,
      false,
      raw_analysis=false,
      raw_rewrite=false,
    ).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(dae_wb_param_count(output, 0), expected_params)
    let func = @ir.hot_lift_func(output, @lib.FuncIdx::new(0U))
    let mut writes = 0
    for node_id in 0..<@ir.hot_node_count(func) {
      if @ir.hot_node_is_live(func, node_id) {
        let node = @ir.hot_node_get(func, node_id)
        if (node.op is @ir.LocalSet || node.op is @ir.LocalTee) &&
          node.imm0 == 0 {
          writes += 1
        }
      }
    }
    assert_eq(writes, expected_writes)
    @ir.hot_verify_all(func).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
