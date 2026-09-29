///|
test "dae2 skips rewrite relift when indexed controls cannot reference changed type families" {
  let mod_ = pass_test_module_from_wat(
    "(module (type $dead (func (param i32) (result i32))) (type $keep (func (result i32))) (func $helper (type $dead) i32.const 7) (func (export \"run\") (result i32) i32.const 9 call $helper) (func (export \"keep\") (type $keep) block (type $keep) i32.const 3 end))",
  )
  let original = @binary.encode_module(mod_).unwrap()
  let lifts = [0]
  let output = dae2_run_module_pass(mod_, false, rewrite_lifts=Some(lifts)).unwrap()
  @validate.validate_module(output).unwrap()
  assert_eq(lifts[0], 0)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[2]
  assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(3))])
  assert_eq(@binary.encode_module(mod_).unwrap(), original)
  let dispatched = run_hot_pipeline(mod_, HotPipelineOptions::new(), ["dae2"]).unwrap()
  @validate.validate_module(dispatched).unwrap()
  assert_eq(dispatched.func_sec.unwrap().0.length(), 3)
}
