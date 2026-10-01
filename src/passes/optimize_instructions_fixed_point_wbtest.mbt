///|
fn oi_fixed_point_profile(name : String) -> Unit raise {
  let profile = @validate.gen_valid_profile_by_name(name).unwrap()
  let input = @validate.gen_valid_module_result_from_seed(
      0x5eedUL,
      @validate.GenValidConfig::for_profile(profile),
    ).unwrap().wasm_module
  let once = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let twice = run_hot_pipeline(once, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let third = run_hot_pipeline(twice, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(once).is_ok())
  assert_true(@validate.validate_module(twice).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = twice.code_sec.unwrap().0[0]
  match name {
    "flatten-ifs" =>
      @debug.assert_eq(body, [
        @lib.Instruction::i32_const(@lib.I32(21)),
        @lib.Instruction::drop(),
      ])
    "ssa-merge-explicit" =>
      match body {
        [
          @lib.I32Const(@lib.I32(7)),
          @lib.LocalSet(written),
          @lib.LocalGet(read),
          @lib.Drop,
        ] => @debug.assert_eq(written, read)
        other => fail("expected the chosen arm's local write, got \{other}")
      }
    "flatten-loops" =>
      match body {
        [
          @lib.Loop(_, @lib.Expr([@lib.I32Const(@lib.I32(29))])),
          @lib.Drop,
          @lib.I32Const(@lib.I32(16)),
          @lib.Loop(
            _,
            @lib.Expr(
              [
                @lib.I32Const(@lib.I32(17)),
                @lib.LocalSet(written),
                @lib.Drop,
                @lib.LocalGet(read),
              ]
            )
          ),
          @lib.Drop,
        ] => @debug.assert_eq(written, read)
        other =>
          fail("expected folded loop result and entry operand, got \{other}")
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
test "optimize-instructions direct HOT constant comparison folds in one visit" {
  let func = pass_test_lift_first_func(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.lt_s))",
  )
  let ctx = HotPassContext::new(
    optimize_instructions_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
  )
  ignore(hot_pass_run(ctx, func).unwrap())
  let root = @ir.hot_root_get(func, 0)
  assert_true(@ir.hot_node_get(func, root).op is @ir.HotOp::Const)
  @debug.assert_eq(
    @ir.hot_const_get(func, @ir.hot_node_get(func, root).imm0),
    @ir.HotConstPayload::i32_const(@lib.I32(1)),
  )
}

///|
test "optimize-instructions finishes sunk local writes for zero and nonzero conditions" {
  for condition in [0, 1, -1] {
    let input = pass_test_module_from_wat(
      "(module (func (result i32) (local i32) i32.const \{condition} if i32.const 7 local.set 0 else i32.const 9 local.set 0 end local.get 0))",
    )
    let once = run_hot_pipeline(input, HotPipelineOptions::new(), [
      "optimize-instructions",
    ]).unwrap()
    let @lib.Func(_, @lib.Expr(body)) = once.code_sec.unwrap().0[0]
    @debug.assert_eq(body, [
      @lib.Instruction::i32_const(@lib.I32(if condition == 0 { 9 } else { 7 })),
      @lib.Instruction::local_set(@lib.LocalIdx::new(0U)),
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    ])
    assert_true(@validate.validate_module(once).is_ok())
  }
}

///|
test "optimize-instructions finishes nested scalar control without another pass" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 2 i32.lt_s if (result i32) i32.const 3 i32.const 4 i32.lt_s if (result i32) i32.const 20 i32.const 1 i32.add else i32.const 0 end else i32.const -1 end))",
  )
  let once = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = once.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [@lib.Instruction::i32_const(@lib.I32(21))])
  assert_true(@validate.validate_module(once).is_ok())
}

///|
test "optimize-instructions constant if retains its chosen branch target" {
  let input = pass_test_module_from_wat(
    "(module (func (result i32) i32.const 1 i32.const 1 i32.eq if (result i32) i32.const 20 i32.const 1 i32.add br 0 else unreachable end))",
  )
  let once = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let twice = run_hot_pipeline(once, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  assert_true(@validate.validate_module(once).is_ok())
  @debug.assert_eq(@binary.encode_module(once), @binary.encode_module(twice))
  let @lib.Func(_, @lib.Expr(body)) = once.code_sec.unwrap().0[0]
  match body {
    [
      @lib.Block(
        _,
        @lib.Expr([@lib.I32Const(@lib.I32(21)), @lib.Br(@lib.LabelIdx(0U))])
      ),
    ] => ()
    other =>
      fail("expected a retained branch target and chosen value, got \{other}")
  }
}

///|
test "optimize-instructions finishes value-if drop shells exposed by raw rewrites" {
  // GenValid oi-boolean-select:value-if-drop-shell, case 35 at seed 0x5eed.
  // Constant conditions select 55 and 5 without effects or traps. Finishing
  // those folds saves 16 bytes against v132 and matches the old two-pass result.
  let input = pass_test_module_from_wat(
    "(module (func i32.const 0 if (result i32) i32.const 44 else i32.const 55 end drop i32.const 1 if i32.const 5 drop else i32.const 6 drop end))",
  )
  let once = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let twice = run_hot_pipeline(once, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = once.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [
    @lib.Instruction::i32_const(@lib.I32(55)),
    @lib.Instruction::drop(),
    @lib.Instruction::i32_const(@lib.I32(5)),
    @lib.Instruction::drop(),
  ])
  assert_true(@validate.validate_module(once).is_ok())
  @debug.assert_eq(@binary.encode_module(once).unwrap().length(), 30)
  @debug.assert_eq(@binary.encode_module(once), @binary.encode_module(twice))
}
