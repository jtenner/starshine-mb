///|
test "dae2 does not relift unchanged definitions after another signature changes" {
  let wat =
    #|(module
    #| (func $helper (param i32) (result i32) i32.const 7)
    #| (func (export "run") (result i32) i32.const 8 call $helper)
    #| (func (export "keep") (result i32) i32.const 9))
  let input = pass_test_module_from_wat(wat)
  let original_codes = pass_test_module_from_wat(wat).code_sec
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(input.code_sec, original_codes)
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  let @lib.CodeSec(funcs) = output.code_sec.unwrap()
  assert_eq(funcs[2], input.code_sec.unwrap().0[2])
  assert_true(lifts[0] <= 2, msg="rewrite lifts: \{lifts[0]}")
}

///|
test "dae2 retains relift for unchanged definitions with indexed control types" {
  let wat =
    #|(module (type $sig (func (param i32) (result i32)))
    #| (func $helper (type $sig) i32.const 7)
    #| (func (export "run") (result i32) i32.const 8 call $helper)
    #| (func (export "keep") (result i32)
    #|   i32.const 3 block (type $sig) drop i32.const 9 br 0 end))
  let input = pass_test_module_from_wat(wat)
  let original_codes = pass_test_module_from_wat(wat).code_sec
  let lifts = [0]
  let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(input.code_sec, original_codes)
  let context = @ir.hot_module_context_from_module(output)
  assert_eq(
    @ir.hot_module_resolve_func_type(context, @lib.FuncIdx::new(0U)),
    Some(@lib.FuncType::new([], [@lib.ValType::i32()])),
  )
  assert_eq(lifts[0], 3)
}
