///|
fn oi_fixed_point_profile(name : String) -> Unit raise {
  let profile = @validate.gen_valid_profile_by_name(name).unwrap()
  let input = @validate.gen_valid_module_result_from_seed(
    0x5eedUL,
    @validate.GenValidConfig::for_profile(profile),
  ).unwrap().wasm_module
  let once = run_hot_pipeline(
    input, HotPipelineOptions::new(), ["optimize-instructions"],
  ).unwrap()
  let twice = run_hot_pipeline(
    once, HotPipelineOptions::new(), ["optimize-instructions"],
  ).unwrap()
  let third = run_hot_pipeline(
    twice, HotPipelineOptions::new(), ["optimize-instructions"],
  ).unwrap()
  assert_true(@validate.validate_module(once).is_ok())
  assert_true(@validate.validate_module(twice).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = twice.code_sec.unwrap().0[0]
  match name {
    "flatten-ifs" => @debug.assert_eq(body, [
      @lib.Instruction::i32_const(@lib.I32(21)), @lib.Instruction::drop(),
    ])
    "ssa-merge-explicit" => match body {
      [@lib.I32Const(@lib.I32(7)), @lib.LocalSet(written), @lib.LocalGet(read), @lib.Drop] =>
        @debug.assert_eq(written, read)
      other => fail("expected the chosen arm's local write, got \{other}")
    }
    "flatten-loops" => match body {
      [@lib.Loop(_, @lib.Expr([@lib.I32Const(@lib.I32(29))])), @lib.Drop,
       @lib.I32Const(@lib.I32(16)), @lib.Loop(_, @lib.Expr([
         @lib.I32Const(@lib.I32(17)), @lib.LocalSet(written), @lib.Drop,
         @lib.LocalGet(read),
       ])), @lib.Drop] => @debug.assert_eq(written, read)
      other => fail("expected folded loop result and entry operand, got \{other}")
    }
    _ => fail("unexpected profile")
  }
  @debug.assert_eq(@binary.encode_module(twice), @binary.encode_module(third))
  @debug.assert_eq(once.code_sec, twice.code_sec)
  @debug.assert_eq(@binary.encode_module(once), @binary.encode_module(twice))
}

///|
test "optimize-instructions reaches fixed point for flatten-ifs" {
  oi_fixed_point_profile("flatten-ifs")
}

///|
test "optimize-instructions reaches fixed point for flatten-loops" {
  oi_fixed_point_profile("flatten-loops")
}

///|
test "optimize-instructions reaches fixed point for ssa-merge-explicit" {
  oi_fixed_point_profile("ssa-merge-explicit")
}

///|
test "optimize-instructions revisits a canonicalized HOT comparison" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.lt_s))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(), @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(), false, fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  let root = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::Const)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}
