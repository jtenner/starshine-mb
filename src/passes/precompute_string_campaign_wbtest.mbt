///|
test "campaign precompute WTF16 array uses exclusive end" {
  for range in [(1, 2), (2, 2), (0, 3), (3, 4)] {
    let (start, end) = range
    let body = [
      @lib.Instruction::i32_const(@lib.I32(65)),
      @lib.Instruction::i32_const(@lib.I32(66)),
      @lib.Instruction::i32_const(@lib.I32(67)),
      @lib.Instruction::i32_const(@lib.I32(68)),
      @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(4U)),
      @lib.Instruction::i32_const(@lib.I32(start)),
      @lib.Instruction::i32_const(@lib.I32(end)),
      @lib.Instruction::string_new_wtf16_array(),
    ]
    let (output, _) = precompute_raw_rewrite_instrs(body, None)
    let expected : Array[Byte] = []
    for i = start; i < end; i = i + 1 {
      expected.push((65 + i).to_byte())
    }
    @debug.assert_eq(output, [
      @lib.Instruction::string_const(Bytes::from_array(expected)),
    ])
  }
}

///|
test "campaign precompute WTF16 reversed range retains trap" {
  let body = [
    @lib.Instruction::i32_const(@lib.I32(65)),
    @lib.Instruction::i32_const(@lib.I32(66)),
    @lib.Instruction::i32_const(@lib.I32(67)),
    @lib.Instruction::i32_const(@lib.I32(68)),
    @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(4U)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::string_new_wtf16_array(),
  ]
  let (output, _) = precompute_raw_rewrite_instrs(body, None)
  assert_true(output.contains(@lib.Instruction::string_new_wtf16_array()))
}

///|
test "campaign HOT precompute WTF16 array uses exclusive end" {
  let array_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::pack_type(@lib.PackType::i16()),
                @lib.Mut::var_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::externref()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([func_type]))
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(
          @lib.Locals::empty(),
          @lib.Expr::new([
            @lib.Instruction::i32_const(@lib.I32(65)),
            @lib.Instruction::i32_const(@lib.I32(66)),
            @lib.Instruction::i32_const(@lib.I32(67)),
            @lib.Instruction::i32_const(@lib.I32(68)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(4U)),
            @lib.Instruction::i32_const(@lib.I32(1)),
            @lib.Instruction::i32_const(@lib.I32(2)),
            @lib.Instruction::string_new_wtf16_array(),
          ]),
        ),
      ]),
    )
  let func = @ir.hot_lift_func(input, @lib.FuncIdx::new(0U))
  let module_ctx = @ir.hot_module_context_from_module(input)
  let ctx = HotPassContext::new(
    precompute_descriptor(),
    @ir.HotAnalysisCache::new(),
    HotPipelineVerifyPolicy::after_each_pass(),
    false,
    fn(_) { () },
    module_ctx=Some(module_ctx),
  )
  let mut found = false
  for node_id = 0; node_id < @ir.hot_node_count(func); node_id = node_id + 1 {
    if @ir.hot_node_is_live(func, node_id) {
      match @ir.hot_node_exact_instr(func, node_id) {
        Some(@lib.StringNewWtf16Array) => {
          found = true
          assert_true(
            precompute_try_fold_fresh_string_new_wtf16(ctx, func, node_id),
            msg="string.new children=\{@ir.hot_child_count(func, node_id)}",
          )
        }
        _ => ()
      }
    }
  }
  assert_true(found)
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["precompute-propagate"],
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected string pipeline success, got \{err}")
  }
  let @lib.Func(_, @lib.Expr(body)) = optimized.code_sec.unwrap().0[0]
  @debug.assert_eq(body, [
    @lib.Instruction::string_const(Bytes::from_array([66])),
  ])
}
