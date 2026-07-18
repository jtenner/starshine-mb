///|
test "precompute raw tlsf prologue repair produces valid lowered function" {
  let source =
    #|(module
    #|  (memory 1)
    #|  (func (local i32 i32 i32 i32 i32)
    #|    memory.size
    #|    i32.const 177263
    #|    i32.const -16
    #|    i32.and
    #|    local.tee 0
    #|    i32.const 67107
    #|    i32.add
    #|    i32.const -65536
    #|    i32.and
    #|    i32.const 16
    #|    i32.shr_u
    #|    i32.lt_s
    #|    if (result i32)
    #|      local.get 3
    #|      local.get 4
    #|      i32.sub
    #|      memory.grow
    #|      i32.const 0
    #|      i32.lt_s
    #|    else
    #|      i32.const 0
    #|    end
    #|    if
    #|      unreachable
    #|    end
    #|    loop
    #|      i32.const 0
    #|      local.tee 1
    #|      i32.const 23
    #|      i32.lt_u
    #|      if
    #|        loop
    #|          i32.const 0
    #|          local.tee 2
    #|          i32.const 16
    #|          i32.lt_u
    #|          if
    #|            br 1
    #|          end
    #|        end
    #|        br 1
    #|      end
    #|    end))
    #|)
  let mod_ = pass_test_module_from_wat(source)
  let func = match mod_.code_sec {
    Some(@lib.CodeSec(defs)) => defs[0]
    None => fail("expected code section")
  }
  let (rewritten, changed, reason) = match precompute_run_raw_func(func, None) {
    Some(result) => result
    None => fail("expected raw tlsf rewrite result")
  }
  assert_true(changed, msg=reason)
  let candidate = mod_.with_code_sec(@lib.CodeSec::new([rewritten]))
  match @validate.validate_module(candidate) {
    Ok(_) => ()
    Err(err) =>
      fail("expected valid raw tlsf rewrite, got \{err}; mod=\{candidate}")
  }
}

///|
test "precompute rejects multi-root constant-if chosen regions" {
  let func = @ir.HotFunc::new()
  let if_id = @ir.hot_build_if(
    func,
    @lib.BlockType::val_type(@lib.ValType::i32()),
    @ir.hot_build_const_i32(func, @lib.I32(0)),
    [@ir.hot_build_const_i32(func, @lib.I32(1))],
    else_body=Some([
      @ir.hot_build_const_i32(func, @lib.I32(2)),
      @ir.hot_build_const_i32(func, @lib.I32(3)),
    ]),
  )
  let else_region = @ir.hot_region_else_ref(func, if_id).unwrap()

  assert_false(
    precompute_constant_if_chosen_region_can_inline(func, else_region),
  )
}

///|
test "precompute flattens blocks whose concrete flow returns" {
  let input = [
    @lib.Instruction::block(
      @lib.BlockType::void_(),
      @lib.Expr::new([
        @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
        @lib.Instruction::return_(),
      ]),
    ),
  ]
  let (rewritten, changed) = precompute_raw_rewrite_instrs(input, None)
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
    @lib.Instruction::return_(),
  ])

  let type_idx = @lib.TypeIdx::new(0U)
  let input_module = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::funcref()]),
          ),
        ),
      ]),
    )
    .with_func_sec(@lib.FuncSec::new([type_idx]))
    .with_elem_sec(
      @lib.ElemSec::new([
        @lib.Elem::new(
          @lib.ElemMode::declarative(),
          @lib.ElemKind::funcs([@lib.FuncIdx::new(0U)]),
        ),
      ]),
    )
    .with_code_sec(
      @lib.CodeSec::new([
        @lib.Func::new(@lib.Locals::empty(), @lib.Expr::new(input)),
      ]),
    )
  let optimized = match
    run_hot_pipeline(input_module, HotPipelineOptions::new(), ["precompute"]) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected ref.func return-flow pipeline success, got \{err}")
  }
  let text = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(text.contains("ref.func"), msg=text)
  assert_true(text.contains("return"), msg=text)
  assert_false(text.contains("block"), msg=text)
}

///|
test "precompute admits and folds Binaryen v131 shared ref.func fixture" {
  let input = match
    @binary.decode_module(
      Bytes::from_array([
        0x00, 0x61, 0x73, 0x6d, 0x01, 0x00, 0x00, 0x00, 0x01, 0x11, 0x03, 0x65, 0x60,
        0x00, 0x01, 0x63, 0x65, 0x70, 0x60, 0x00, 0x01, 0x70, 0x60, 0x00, 0x01, 0x64,
        0x00, 0x03, 0x04, 0x03, 0x01, 0x00, 0x02, 0x09, 0x06, 0x01, 0x03, 0x00, 0x02,
        0x00, 0x01, 0x0a, 0x21, 0x03, 0x05, 0x00, 0xd2, 0x00, 0x0f, 0x0b, 0x05, 0x00,
        0xd2, 0x01, 0x0f, 0x0b, 0x13, 0x00, 0x02, 0x64, 0x00, 0x02, 0x64, 0x01, 0xd2,
        0x00, 0xd2, 0x01, 0x0c, 0x01, 0x0b, 0x1a, 0xd2, 0x01, 0x0b, 0x0b,
      ]),
    ) {
    Ok(mod_) => mod_
    Err(err) => fail("expected shared ref.func fixture decode, got \{err}")
  }
  let trace : Array[String] = []
  let optimized = match
    run_hot_pipeline(
      input,
      HotPipelineOptions::new(trace=Some(fn(line) { trace.push(line) })),
      ["precompute"],
    ) {
    Ok(mod_) => mod_
    Err(err) =>
      fail("expected shared ref.func fixture optimization, got \{err}")
  }
  let text = optimized.pretty_print_func(@lib.FuncIdx::new(2U))
  assert_true(text.contains("ref.func"), msg="\{text}\ntrace=\{trace}")
  assert_false(text.contains("block"), msg="\{text}\ntrace=\{trace}")
  assert_false(text.contains("br "), msg="\{text}\ntrace=\{trace}")
}

///|
test "precompute resolves nested typed branch flow" {
  let inner = @lib.Instruction::block(
    @lib.BlockType::val_type(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(1U)),
          exact=true,
        ),
      ),
    ),
    @lib.Expr::new([
      @lib.Instruction::ref_func(@lib.FuncIdx::new(0U)),
      @lib.Instruction::drop(),
      @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
      @lib.Instruction::br(@lib.LabelIdx::new(1U)),
      @lib.Instruction::br_if(@lib.LabelIdx::new(0U)),
    ]),
  )
  let outer = @lib.Instruction::block(
    @lib.BlockType::val_type(
      @lib.ValType::ref_type(
        @lib.RefType::new(
          false,
          @lib.HeapType::new(@lib.TypeIdx::new(0U)),
          exact=true,
        ),
      ),
    ),
    @lib.Expr::new([
      inner,
      @lib.Instruction::drop(),
      @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
    ]),
  )
  let (rewritten, changed) = precompute_raw_rewrite_instrs([outer], None)
  assert_true(changed)
  @debug.assert_eq(rewritten, [
    @lib.Instruction::ref_func(@lib.FuncIdx::new(1U)),
  ])
}

///|
test "precompute folds Binaryen v131 WTF-16 string operations" {
  let (equal, equal_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::string_const(Bytes::from_array([97, 98])),
      @lib.Instruction::string_const(Bytes::from_array([97, 98])),
      @lib.Instruction::string_eq(),
    ],
    None,
  )
  assert_true(equal_changed)
  @debug.assert_eq(equal, [@lib.Instruction::i32_const(@lib.I32(1))])

  let (concat, concat_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::string_const(Bytes::from_array([97])),
      @lib.Instruction::string_const(Bytes::from_array([98])),
      @lib.Instruction::string_concat(),
    ],
    None,
  )
  assert_true(concat_changed)
  @debug.assert_eq(concat, [
    @lib.Instruction::string_const(Bytes::from_array([97, 98])),
  ])

  let unicode = Bytes::from_array([
    0x24, 0x5f, 0xc2, 0xa3, 0x5f, 0xe2, 0x82, 0xac, 0x5f, 0xf0, 0x90, 0x8d, 0x88,
  ])
  let (measured, measured_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::string_const(unicode),
      @lib.Instruction::string_measure_wtf16(),
    ],
    None,
  )
  assert_true(measured_changed)
  @debug.assert_eq(measured, [@lib.Instruction::i32_const(@lib.I32(8))])

  let (codeunit, codeunit_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::string_const(unicode),
      @lib.Instruction::i32_const(@lib.I32(6)),
      @lib.Instruction::stringview_wtf16_get_codeunit(),
    ],
    None,
  )
  assert_true(codeunit_changed)
  @debug.assert_eq(codeunit, [@lib.Instruction::i32_const(@lib.I32(0xd800))])

  let source = Bytes::from_array([97, 98, 99, 100, 0xc2, 0xa3, 102, 103, 104])
  let (slice, slice_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::string_const(source),
      @lib.Instruction::i32_const(@lib.I32(3)),
      @lib.Instruction::i32_const(@lib.I32(6)),
      @lib.Instruction::stringview_wtf16_slice(),
    ],
    None,
  )
  assert_true(slice_changed)
  @debug.assert_eq(slice, [
    @lib.Instruction::string_const(Bytes::from_array([100, 0xc2, 0xa3, 102])),
  ])

  let supplementary = Bytes::from_array([97, 0xf0, 0x90, 0x8d, 0x86, 98])
  let invalid = [
    @lib.Instruction::string_const(supplementary),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(2)),
    @lib.Instruction::stringview_wtf16_slice(),
  ]
  let (retained, retained_changed) = precompute_raw_rewrite_instrs(
    invalid,
    None,
  )
  assert_false(retained_changed)
  @debug.assert_eq(retained, invalid)
}

///|
test "precompute folds fresh valid WTF-16 arrays to string constants" {
  let (rewritten, changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::i32_const(@lib.I32(65)),
      @lib.Instruction::i32_const(@lib.I32(66)),
      @lib.Instruction::i32_const(@lib.I32(67)),
      @lib.Instruction::i32_const(@lib.I32(68)),
      @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(4U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(4)),
      @lib.Instruction::string_new_wtf16_array(),
    ],
    None,
  )
  assert_true(changed)
  match rewritten {
    [@lib.StringConst(bytes)] =>
      @debug.assert_eq(bytes, Bytes::from_array([65, 66, 67, 68]))
    _ => fail("expected one ABCD string.const, got \{rewritten}")
  }

  let (pair, pair_changed) = precompute_raw_rewrite_instrs(
    [
      @lib.Instruction::i32_const(@lib.I32(0xd800)),
      @lib.Instruction::i32_const(@lib.I32(0xdc00)),
      @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(2U)),
      @lib.Instruction::i32_const(@lib.I32(0)),
      @lib.Instruction::i32_const(@lib.I32(2)),
      @lib.Instruction::string_new_wtf16_array(),
    ],
    None,
  )
  assert_true(pair_changed)
  match pair {
    [@lib.StringConst(bytes)] =>
      @debug.assert_eq(bytes, Bytes::from_array([0xf0, 0x90, 0x80, 0x80]))
    _ => fail("expected one supplementary string.const, got \{pair}")
  }

  let invalid = [
    @lib.Instruction::i32_const(@lib.I32(0xd800)),
    @lib.Instruction::array_new_fixed(@lib.TypeIdx::new(0U), @lib.U32(1U)),
    @lib.Instruction::i32_const(@lib.I32(0)),
    @lib.Instruction::i32_const(@lib.I32(1)),
    @lib.Instruction::string_new_wtf16_array(),
  ]
  let (retained, retained_changed) = precompute_raw_rewrite_instrs(
    invalid,
    None,
  )
  assert_false(retained_changed)
  @debug.assert_eq(retained, invalid)
}

///|
test "precompute recognizes fresh WTF-16 strings in HOT" {
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
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::i32_const(@lib.I32(4)),
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
  let text = optimized.pretty_print_func(@lib.FuncIdx::new(0U))
  assert_true(text.contains("string.const"), msg="\{text}\ntrace=\{trace}")
  assert_false(text.contains("string.new_wtf16_array"), msg=text)
}

///|
test "precompute recognizes fresh immutable array reads in HOT" {
  let array_type = @lib.TypeIdx::new(0U)
  let func_type = @lib.TypeIdx::new(1U)
  let input = @lib.Module::new()
    .with_type_sec(
      @lib.TypeSec::new([
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::array(
              @lib.FieldType::new(
                @lib.StorageType::val_type(@lib.ValType::i32()),
                @lib.Mut::const_(),
              ),
            ),
          ),
        ),
        @lib.RecType::new(
          @lib.SubType::comp_type(
            @lib.CompType::func([], [@lib.ValType::i32()]),
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
            @lib.Instruction::i32_const(@lib.I32(42)),
            @lib.Instruction::array_new_fixed(array_type, @lib.U32(1U)),
            @lib.Instruction::i32_const(@lib.I32(0)),
            @lib.Instruction::array_get(array_type),
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
        Some(@lib.ArrayGet(_)) => {
          found = true
          assert_true(
            precompute_try_fold_fresh_array_get(ctx, func, node_id),
            msg="array.get children=\{@ir.hot_child_count(func, node_id)}",
          )
        }
        _ => ()
      }
    }
  }
  assert_true(found)
}
