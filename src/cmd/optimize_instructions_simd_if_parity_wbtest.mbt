///|
test "dispatcher hoists matching SIMD lane extract if arms" {
  let input = @passes.pass_test_module_from_wat(
    "(module (func (export \"run\") (param i32 v128 v128) (result i32) local.get 0 if (result i32) local.get 1 i32x4.extract_lane 3 else local.get 2 i32x4.extract_lane 3 end))",
  )
  let output = optimize_module_with_pass_flags(
    input,
    ["optimize-instructions"],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  @debug.assert_eq(body.length(), 3)
  @debug.assert_eq(body[0], @lib.Instruction::local_get(@lib.LocalIdx::new(0U)))
  match body[1] {
    @lib.If(
      block_type,
      [@lib.LocalGet(@lib.LocalIdx(1U))],
      Some([@lib.LocalGet(@lib.LocalIdx(2U))])
    ) =>
      @debug.assert_eq(
        block_type,
        @lib.BlockType::val_type(@lib.ValType::v128()),
      )
    other => fail("expected v128 if below hoisted extract, got \{other}")
  }
  @debug.assert_eq(
    body[2],
    @lib.Instruction::i32x4_extract_lane(@lib.LaneIdx::new(b'\x03')),
  )
}

///|
test "dispatcher closes campaign SIMD result if through seven passes" {
  let source =
    #|(module
    #|  (func (export "run") (param i32) (result i32)
    #|    (local v128 v128 v128)
    #|    v128.const i32x4 1 2 3 4 local.set 1
    #|    i32.const 9 i32x4.splat local.set 2
    #|    v128.const i32x4 -1 0 -1 0 local.set 3
    #|    local.get 2 local.get 1 local.get 3 v128.bitselect local.set 1
    #|    local.get 0
    #|    if (result i32)
    #|      local.get 1 i32x4.extract_lane 3
    #|    else
    #|      local.get 2 i32x4.extract_lane 3
    #|    end))
  let input = @passes.pass_test_module_from_wat(source)
  let output = optimize_module_with_pass_flags(
    input,
    [
      "optimize-instructions", "precompute", "vacuum", "local-cse", "simplify-locals",
      "remove-unused-brs", "dead-code-elimination",
    ],
    OptimizeOptions::new(),
  ).unwrap()
  assert_true(@validate.validate_module(output).is_ok())
  let pretty = output.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_false(pretty.contains("local.set (Local 1)"), msg=pretty)
  assert_false(pretty.contains("local.set (Local 3)"), msg=pretty)
  let @lib.Func(_, @lib.Expr(body)) = output.code_sec.unwrap().0[0]
  assert_true(
    body.contains(@lib.Instruction::local_tee(@lib.LocalIdx::new(2U))),
    msg=pretty,
  )
  assert_true(pretty.contains("i32x4.extract_lane"), msg=pretty)
}
