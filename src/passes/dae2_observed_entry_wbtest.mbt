///|
test "DAE2 preserves observable readonly void parameters without first lifting their bodies" {
  let input = pass_test_module_from_wat(
    "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func $store (param i32) local.get 0 global.set $g) (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (param i32) local.get 0 call $store))",
  )
  let saved = @binary.encode_module(input).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
  )
  assert_eq(output.code_sec.unwrap().0[0], input.code_sec.unwrap().0[0])
  assert_eq(output.code_sec.unwrap().0[3], input.code_sec.unwrap().0[3])
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[2]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(1U))])
  assert_eq(@binary.encode_module(input).unwrap(), saved)
}

///|
test "DAE2 keeps written parameter entry values dead when only the replacement is observable" {
  let input = pass_test_module_from_wat(
    "(module (global $g (export \"g\") (mut i32) (i32.const 0)) (func $store (param i32) i32.const 11 local.set 0 local.get 0 global.set $g) (func (export \"run\") i32.const 9 call $store))",
  )
  let output = dae2_run_module_pass(input, false).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([], [])),
  )
  let @lib.Func(_, @lib.Expr(caller)) = output.code_sec.unwrap().0[1]
  assert_eq(caller, [@lib.Instruction::call(@lib.FuncIdx::new(0U))])
}

///|
test "DAE2 observes every readonly store operand and preserves private imported-call wrappers" {
  for
    source in [
      "(memory 1) (func $keep (param i32 i32) local.get 0 local.get 1 i32.store) (func (export \"keep\") (param i32 i32) local.get 0 local.get 1 call $keep)",
      "(import \"host\" \"keep\" (func $effect (param i32 i32))) (func $keep (param i32 i32) local.get 0 local.get 1 call $effect) (func (export \"keep\") (param i32 i32) local.get 0 local.get 1 call $keep)",
    ] {
    let input = pass_test_module_from_wat(
      "(module \{source} (func $helper (param i32) (result i32) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
    @validate.validate_module(output).unwrap()
    assert_eq(lifts[0], 0)
    for index in 0..<2 {
      assert_eq(
        output.code_sec.unwrap().0[index],
        input.code_sec.unwrap().0[index],
      )
    }
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 retains HOT analysis for intentionally unsupported branched observable control" {
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $keep (param i32) local.get 0 global.set $g block br 0 end) (func (export \"keep\") (param i32) local.get 0 call $keep))",
  )
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, analysis_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 1)
  assert_eq(
    @ir.hot_module_resolve_func_type(
      @ir.hot_module_context_from_module(output),
      @lib.FuncIdx::new(0U),
    ),
    Some(@lib.FuncType::new([@lib.ValType::i32()], [])),
  )
}

///|
test "DAE2 rejects invalid readonly store bodies before skipping HOT analysis" {
  // Intentionally invalid: the global.set has no value on the operand stack.
  let input = pass_test_module_from_wat(
    "(module (global $g (mut i32) (i32.const 0)) (func $keep (param i32) local.get 0 global.set $g) (func (export \"keep\") (param i32) local.get 0 call $keep))",
  )
  let @lib.Func(_, @lib.Expr(body)) = input.code_sec.unwrap().0[0]
  body.push(@lib.Instruction::global_set(@lib.GlobalIdx::new(0U)))
  assert_true(dae2_run_module_pass(input, false) is Err(_))
}
