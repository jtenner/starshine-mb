///|
test "DAE2 projects scalar tee values and writes without a second HOT lift" {
  let bodies = [
    "local.get 1 i32.const 7 i32.add local.tee 0 local.get 0 i32.add", "local.get 1 local.tee 0 drop local.get 0",
    "local.get 1 local.tee 0", "local.get 1 local.tee 0 drop i32.const 7", "local.get 0 local.get 1 local.tee 0 i32.add",
    "local.get 1 local.tee 0 drop i32.const 7 local.tee 0 drop local.get 0", "local.get 1 local.tee 3 drop local.get 3",
    "local.get 1 local.tee 0 local.tee 3 drop local.get 0 local.get 3 i32.add", "local.get 1 i32.load local.tee 0 drop local.get 0",
    "call $value local.tee 0 drop local.get 0 local.get 1 i32.add", "local.get 1 local.tee 0 global.set $g local.get 0",
    "local.get 1 local.tee 0 return",
  ]
  for body in bodies {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (global $g (mut i32) (i32.const 0)) (import \"m\" \"value\" (func $value (result i32))) (func $h (param i32 i32 i32) (result i32) (local i32) \{body}) (func (export \"run\") (param i32) (result i32) i32.const 9 local.get 0 i32.const 8 call $h))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    let first_lifts = [0]
    let second_lifts = [0]
    let output = dae2_run_module_pass(
      input,
      false,
      analysis_lifts=Some(first_lifts),
      rewrite_lifts=Some(second_lifts),
    ).unwrap()
    assert_eq(first_lifts[0], 0)
    assert_eq(second_lifts[0], 0)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    assert_true(dae_wb_param_count(output, 1) < 3)
  }
}

///|
test "DAE2 scalar tee projections preserve mandatory effects when the function result disappears" {
  for
    body in [
      "local.get 1 local.tee 0", "local.get 1 i32.load local.tee 0", "call $value local.tee 0 local.get 0 i32.add",
      "local.get 1 local.tee 0 drop local.get 0 global.set $g i32.const 7",
    ] {
    let input = pass_test_module_from_wat(
      "(module (memory 1) (global $g (mut i32) (i32.const 0)) (import \"m\" \"value\" (func $value (result i32))) (func $h (param i32 i32 i32) (result i32) \{body}) (func (export \"run\") (param i32) i32.const 9 local.get 0 i32.const 8 call $h drop))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
    assert_eq(lifts[0], 0)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
    let context = @ir.hot_module_context_from_module(output)
    let @lib.FuncType(_, results) = @ir.hot_module_resolve_func_type(
      context,
      @lib.FuncIdx::new(1U),
    ).unwrap()
    assert_true(results.is_empty())
  }
}

///|
test "DAE2 scalar tee pruning preserves float reinterpretation without arithmetic" {
  for (scalar, integer) in [("f32", "i32"), ("f64", "i64")] {
    let input = pass_test_module_from_wat(
      "(module (func $h (param \{scalar} \{scalar} \{scalar}) (result \{scalar}) local.get 1 local.tee 0 drop local.get 0) (func (export \"bits\") (param \{integer}) (result \{integer}) \{scalar}.const 0 local.get 0 \{scalar}.reinterpret_\{integer} \{scalar}.const 0 call $h \{integer}.reinterpret_\{scalar}))",
    )
    let saved = @binary.encode_module(input).unwrap()
    let reference = dae2_run_module_pass(input, false, raw_analysis=false).unwrap()
    let lifts = [0]
    let output = dae2_run_module_pass(input, false, rewrite_lifts=Some(lifts)).unwrap()
    assert_eq(lifts[0], 0)
    assert_eq(
      @binary.encode_module(output).unwrap(),
      @binary.encode_module(reference).unwrap(),
    )
    assert_eq(dae_wb_param_count(output, 0), 1)
    @validate.validate_module(output).unwrap()
    assert_eq(@binary.encode_module(input).unwrap(), saved)
  }
}
