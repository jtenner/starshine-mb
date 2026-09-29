///|
test "DAE2 scalar tee projection keeps the HOT shape for repeated unread capture writes" {
  for
    body in [
      "local.get 1 local.tee 0 i32.const 7 i32.add local.tee 0", "local.get 1 local.tee 0 i32.const 7 i32.add local.tee 0 i32.const 11 i32.mul local.tee 0",
      "local.get 1 local.tee 0 local.get 1 local.tee 0 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param i32 i32 i32) (result i32) \{body}) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
    assert_eq(lifts[0], 0)
    assert_eq(dae_wb_param_count(output, 0), dae_wb_param_count(reference, 0))
    assert_true(dae_wb_param_count(output, 0) < 3)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}

///|
test "DAE2 scalar tee projection removes unread body-local writes like HOT rewriting" {
  for
    body in [
      "local.get 1 local.tee 3", "i32.const 7 local.set 3 local.get 3 local.get 1 local.tee 3 i32.add",
      "local.get 1 local.set 0 local.get 0 local.get 1 local.tee 0 i32.add", "local.get 1 local.tee 1",
      "local.get 1 local.tee 1 i32.const 7 i32.add local.tee 1", "local.get 1 local.tee 3 drop i32.const 7 local.set 3 local.get 3",
      "local.get 1 local.get 1 local.tee 3 i32.add", "local.get 1 local.get 1 local.tee 1 i32.add",
      "local.get 1 i32.load local.tee 3", "local.get 1 local.tee 3 i32.const 7 i32.add local.tee 4",
      "local.get 1 local.tee 3 local.get 1 local.tee 4 i32.add",
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (func $h (param i32 i32 i32) (result i32) (local i32 i32) \{body}) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_rewrite=false).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
    assert_eq(lifts[0], 0)
    assert_eq(dae_wb_param_count(output, 0), dae_wb_param_count(reference, 0))
    assert_true(dae_wb_param_count(output, 0) < 3)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
