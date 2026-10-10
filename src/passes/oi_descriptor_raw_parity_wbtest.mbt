///|
fn oi_descriptor_raw_parity_fixture(seed : UInt64) -> @lib.Module {
  let profile = @validate.gen_valid_profile_by_name("pass-oi-descriptor-gc").unwrap()
  @validate.gen_valid_module_result_from_seed(
    seed,
    @validate.GenValidConfig::for_profile(profile),
  ).unwrap().wasm_module
}

///|
fn oi_descriptor_raw_parity_check_null_case(
  seed : UInt64,
  expected_bytes : Int,
  effectful : Bool,
) -> Unit raise {
  let input = oi_descriptor_raw_parity_fixture(seed)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let types = output.type_sec.unwrap().0
  @debug.assert_eq(types.length(), 3)
  @debug.assert_eq(types[0], input.type_sec.unwrap().0[0])
  @debug.assert_eq(output.func_sec.unwrap().0, [
    @lib.TypeIdx::new(2U),
    @lib.TypeIdx::new(3U),
  ])
  @debug.assert_eq(
    @binary.encode_module(output).unwrap().length(),
    expected_bytes,
  )
  let funcs = output.code_sec.unwrap().0
  let @lib.Func(_, @lib.Expr(nullable_body)) = funcs[0]
  let @lib.Func(_, @lib.Expr(nonnull_body)) = funcs[1]
  let bottom_null = @lib.Instruction::ref_null(
    @lib.HeapType::abs(@lib.AbsHeapType::none()),
  )
  if effectful {
    let effects = [
      @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
      @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::global_get(@lib.GlobalIdx::new(0U)),
      @lib.Instruction::drop(),
    ]
    @debug.assert_eq(nullable_body, effects + [bottom_null])
    @debug.assert_eq(nonnull_body, effects + [@lib.Instruction::unreachable_()])
  } else {
    @debug.assert_eq(nullable_body, [bottom_null])
    @debug.assert_eq(nonnull_body, [@lib.Instruction::unreachable_()])
  }
}

///|
test "OI descriptor null casts use bottom null and prune one unused signature" {
  oi_descriptor_raw_parity_check_null_case(2UL, 56, false)
  oi_descriptor_raw_parity_check_null_case(0UL, 56, false)
}

///|
test "OI descriptor effectful null casts keep effects without result block" {
  oi_descriptor_raw_parity_check_null_case(3UL, 81, true)
}

///|
test "OI descriptor producer preserves recursive metadata and prunes two signatures" {
  let input = oi_descriptor_raw_parity_fixture(1UL)
  let output = run_hot_pipeline(input, HotPipelineOptions::new(), [
    "optimize-instructions",
  ]).unwrap()
  @validate.validate_module(output).unwrap()
  let types = output.type_sec.unwrap().0
  @debug.assert_eq(types.length(), 2)
  @debug.assert_eq(types[0], input.type_sec.unwrap().0[0])
  @debug.assert_eq(output.func_sec.unwrap().0, [@lib.TypeIdx::new(2U)])
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.length(), 9)
  @debug.assert_eq(
    body[0],
    @lib.Instruction::struct_new_default(@lib.TypeIdx::new(1U)),
  )
  @debug.assert_eq(
    body[1],
    @lib.Instruction::struct_new_default_desc(@lib.TypeIdx::new(0U)),
  )
  @debug.assert_eq(
    body[2],
    @lib.Instruction::ref_get_desc(@lib.TypeIdx::new(0U)),
  )
  @debug.assert_eq(@binary.encode_module(output).unwrap().length(), 58)
}

///|
test "OI descriptor encoding leaves unselected function bodies unchanged" {
  let output = run_hot_pipeline(
    oi_descriptor_raw_parity_fixture(2UL),
    HotPipelineOptions::new(),
    ["optimize-instructions"],
  ).unwrap()
  let funcs = output.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = funcs[0]
  let typed_null = @lib.Instruction::ref_null_type(
    @lib.RefType::new(
      true,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  funcs[0] = @lib.Func::new(locals, @lib.Expr::new([typed_null]))
  let post_hot = output.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(post_hot).unwrap()
  let cleaned = oi_cleanup_module_encoding(
    post_hot,
    touched=Some([false, false]),
  )
  @debug.assert_eq(cleaned.code_sec, post_hot.code_sec)
}

///|
test "OI descriptor encoding flattens a branchless effect then trap" {
  let output = run_hot_pipeline(
    oi_descriptor_raw_parity_fixture(3UL),
    HotPipelineOptions::new(),
    ["optimize-instructions"],
  ).unwrap()
  let funcs = output.code_sec.unwrap().0.copy()
  let @lib.Func(locals, _) = funcs[1]
  let effects_then_trap = [
    @lib.Instruction::local_get(@lib.LocalIdx::new(0U)),
    @lib.Instruction::global_set(@lib.GlobalIdx::new(0U)),
    @lib.Instruction::unreachable_(),
  ]
  let result = @lib.ValType::ref_type(
    @lib.RefType::new(
      false,
      @lib.HeapType::new(@lib.TypeIdx::new(0U)),
      exact=true,
    ),
  )
  funcs[1] = @lib.Func::new(
    locals,
    @lib.Expr::new([
      @lib.Instruction::block(
        @lib.BlockType::val_type(result),
        @lib.Expr::new(effects_then_trap),
      ),
    ]),
  )
  let post_hot = output.with_code_sec(@lib.CodeSec::new(funcs))
  @validate.validate_module(post_hot).unwrap()
  let cleaned = oi_cleanup_module_encoding(post_hot)
  @validate.validate_module(cleaned).unwrap()
  let @lib.Func(_, @lib.Expr(body)) = cleaned.code_sec.unwrap().0[1]
  @debug.assert_eq(body, effects_then_trap)
  assert_true(
    @binary.encode_module(cleaned).unwrap().length() <
    @binary.encode_module(post_hot).unwrap().length(),
  )
}
